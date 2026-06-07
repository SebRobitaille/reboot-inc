extends Node
## Authoritative in-run state. All mutations emit via EventBus.
## M2: placements are BuildingData-driven. The economy still consumes the same
## emission_by_ring() / collection_by_ring() interface it did in M1.

const BUILDINGS_DIR := "res://data/buildings/"

var essence: float = 0.0
var flux: float = 0.0
var rift_cores: int = 0
var depth: int = 0

# Global multipliers (raised by depth tiers / prestige later; 1.0 at run start).
var extraction_mult: float = 1.0
var collection_mult: float = 1.0

# Transient ability multipliers (Overclock, M3). 1.0 when inactive; SurgeManager
# owns the timing and writes these.
var surge_emission_mult: float = 1.0
var surge_collection_mult: float = 1.0

# Persistent prestige factors (M4). Written by PrestigeManager from owned nodes;
# they survive reset_run_state() and stack on top of the per-run multipliers.
var prestige_extraction_mult: float = 1.0
var prestige_collection_mult: float = 1.0
var prestige_flux_mult: float = 1.0
var prestige_drift_mult: float = 1.0
var prestige_start_essence: float = 0.0
var prestige_core_bonus: int = 0
var prestige_preplace: int = 0

## Every buildable BuildingData, loaded from BUILDINGS_DIR at startup. The shop
## reads this so adding a .tres adds content with no code change.
var catalog: Array[BuildingData] = []

## Placed buildings. Each entry: { data: BuildingData, ring: int, slot: int }.
var placements: Array[Dictionary] = []

## owned counts per building id, for exponential cost scaling.
var _owned: Dictionary = {}            # StringName -> int
## occupied board cells, keyed by _cell_key(ring, slot).
var _occupied: Dictionary = {}         # int -> true

# --- Currency mutators ---
func add_essence(amount: float) -> void:
	if amount == 0.0:
		return
	essence += amount
	EventBus.essence_changed.emit(essence)

func spend_essence(amount: float) -> bool:
	if essence < amount:
		return false
	essence -= amount
	EventBus.essence_changed.emit(essence)
	return true

func add_flux(amount: float) -> void:
	if amount == 0.0:
		return
	flux += amount
	EventBus.flux_changed.emit(flux)

func spend_flux(amount: float) -> bool:
	if flux < amount:
		return false
	flux -= amount
	EventBus.flux_changed.emit(flux)
	return true

# --- Depth & cores (M3) ---
func add_rift_cores(n: int) -> void:
	if n == 0:
		return
	rift_cores += n
	EventBus.rift_cores_changed.emit(rift_cores)

## Advance one depth tier and nudge the base production multipliers (a cleared
## surge makes you permanently a little stronger). Called by SurgeManager.
func advance_depth() -> void:
	depth += 1
	extraction_mult *= 1.0 + Balance.DEPTH_MULT_BONUS
	collection_mult *= 1.0 + Balance.DEPTH_MULT_BONUS
	EventBus.depth_changed.emit(depth)

# --- Economy interface (unchanged signatures since M1) ---

## Per-ring summed extractor emission, with global + preferred-ring bonuses applied.
## NOTE: recomputed each tick. Fine at M2 scale; cache if building counts explode.
func emission_by_ring() -> PackedFloat64Array:
	var arr := PackedFloat64Array()
	arr.resize(Balance.RING_COUNT)
	for p in placements:
		var data: BuildingData = p["data"]
		if data.category == BuildingData.Category.EXTRACTOR:
			arr[p["ring"]] += data.base_emission * _placement_bonus(data, p["ring"])
	for i in arr.size():
		arr[i] *= extraction_mult * surge_emission_mult * prestige_extraction_mult
	return arr

## Per-ring summed collector capacity, with global + preferred-ring bonuses applied.
func collection_by_ring() -> PackedFloat64Array:
	var arr := PackedFloat64Array()
	arr.resize(Balance.RING_COUNT)
	for p in placements:
		var data: BuildingData = p["data"]
		if data.category == BuildingData.Category.COLLECTOR:
			arr[p["ring"]] += data.base_collect * _placement_bonus(data, p["ring"])
	for i in arr.size():
		arr[i] *= collection_mult * surge_collection_mult * prestige_collection_mult
	return arr

## Global Flux multiplier from all Refineries plus the prestige Flux factor.
func flux_mult() -> float:
	var m := 1.0
	for p in placements:
		var data: BuildingData = p["data"]
		if data.category == BuildingData.Category.SUPPORT:
			m += data.flux_bonus
	return m * prestige_flux_mult

## Global drift-loss multiplier from Stabilizers + prestige, floored so loss never
## fully vanishes.
func global_drift_mult() -> float:
	var m := 1.0
	for p in placements:
		var data: BuildingData = p["data"]
		if data.category == BuildingData.Category.SUPPORT:
			m *= (1.0 - data.drift_reduction)
	return maxf(m * prestige_drift_mult, Balance.MIN_DRIFT_MULT)

# --- Buy + place ---

func owned(id: StringName) -> int:
	return _owned.get(id, 0)

func current_cost(data: BuildingData) -> float:
	return Balance.building_cost(data.base_cost, data.cost_growth, owned(data.id))

func balance_for(currency: BuildingData.Currency) -> float:
	match currency:
		BuildingData.Currency.ESSENCE: return essence
		BuildingData.Currency.FLUX: return flux
		BuildingData.Currency.RIFT_CORE: return float(rift_cores)
	return 0.0

func is_unlocked(data: BuildingData) -> bool:
	return rift_cores >= data.unlock_requirement

func can_afford(data: BuildingData) -> bool:
	return is_unlocked(data) and balance_for(data.buy_currency) >= current_cost(data)

func is_slot_free(ring: int, slot: int) -> bool:
	return not _occupied.has(_cell_key(ring, slot))

## Attempt to buy `data` and place it at (ring, slot). Returns true on success.
func try_place(data: BuildingData, ring: int, slot: int) -> bool:
	if not is_slot_free(ring, slot) or not can_afford(data):
		return false
	if not _spend(data.buy_currency, current_cost(data)):
		return false
	_place(data, ring, slot)
	_owned[data.id] = owned(data.id) + 1
	EventBus.building_purchased.emit(data)
	EventBus.building_placed.emit(data, ring, slot)
	return true

# --- Setup & run reset ---

## Called once at launch: load the catalog, then start the first run.
func setup_run() -> void:
	_load_catalog()
	reset_run_state()

## Reset all per-run state to a fresh start, seeding the prestige bootstrap
## (starting Essence + pre-placed Channelers). Persistent prestige_* factors are
## left untouched. Emits run_reset so UI rebuilds. Used at launch and on collapse.
func reset_run_state() -> void:
	essence = prestige_start_essence
	flux = 0.0
	rift_cores = 0
	depth = 0
	extraction_mult = 1.0
	collection_mult = 1.0
	surge_emission_mult = 1.0
	surge_collection_mult = 1.0
	placements.clear()
	_owned.clear()
	_occupied.clear()
	_place_starters()
	EventBus.essence_changed.emit(essence)
	EventBus.flux_changed.emit(flux)
	EventBus.rift_cores_changed.emit(rift_cores)
	EventBus.depth_changed.emit(depth)
	EventBus.run_reset.emit()

## The two free starters (mirrors M1's feel), plus any prestige pre-placed
## Channelers filling the next open inner slots.
func _place_starters() -> void:
	var channeler := find_in_catalog(&"channeler")
	var sprite := find_in_catalog(&"gather_sprite")
	if channeler:
		_place(channeler, 0, 0)
	if sprite:
		_place(sprite, 2, 0)   # two rings out on purpose — placement still matters
	if channeler:
		var extras := prestige_preplace
		for ring in Balance.RING_COUNT:
			for slot in Balance.SLOTS_PER_RING:
				if extras <= 0:
					return
				if is_slot_free(ring, slot):
					_place(channeler, ring, slot)
					extras -= 1

func find_in_catalog(id: StringName) -> BuildingData:
	for d in catalog:
		if d.id == id:
			return d
	return null

# --- Internals ---

func _placement_bonus(data: BuildingData, ring: int) -> float:
	return 1.0 + Balance.PREFERRED_RING_BONUS if data.preferred_ring == ring else 1.0

func _spend(currency: BuildingData.Currency, amount: float) -> bool:
	match currency:
		BuildingData.Currency.ESSENCE: return spend_essence(amount)
		BuildingData.Currency.FLUX: return spend_flux(amount)
		BuildingData.Currency.RIFT_CORE:
			if rift_cores < int(ceil(amount)):
				return false
			rift_cores -= int(ceil(amount))
			return true
	return false

func _place(data: BuildingData, ring: int, slot: int) -> void:
	placements.append({ "data": data, "ring": ring, "slot": slot })
	_occupied[_cell_key(ring, slot)] = true

func _cell_key(ring: int, slot: int) -> int:
	return ring * Balance.SLOTS_PER_RING + slot

func _load_catalog() -> void:
	catalog.clear()
	var dir := DirAccess.open(BUILDINGS_DIR)
	if dir == null:
		push_warning("GameState: cannot open %s" % BUILDINGS_DIR)
		return
	for file in dir.get_files():
		# Godot exports .tres as .tres.remap in release; handle both.
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load(BUILDINGS_DIR + name)
		if res is BuildingData:
			catalog.append(res)
	catalog.sort_custom(func(a, b): return a.category < b.category)
