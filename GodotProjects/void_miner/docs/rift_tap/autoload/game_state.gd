extends Node
## Authoritative in-run state. All mutations emit via EventBus.
## M2: placements are BuildingData-driven. The economy still consumes the same
## emission_by_ring() / collection_by_ring() interface it did in M1.

const BUILDINGS_DIR := "res://data/buildings/"

var essence: float = 0.0
var flux: float = 0.0
var rift_cores: int = 0
var depth: int = 0

# Global multipliers (raised by prestige later; 1.0 for M2).
var extraction_mult: float = 1.0
var collection_mult: float = 1.0

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
		arr[i] *= extraction_mult
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
		arr[i] *= collection_mult
	return arr

## Global Flux multiplier from all Refineries (1.0 = no support).
func flux_mult() -> float:
	var m := 1.0
	for p in placements:
		var data: BuildingData = p["data"]
		if data.category == BuildingData.Category.SUPPORT:
			m += data.flux_bonus
	return m

## Global drift-loss multiplier from all Stabilizers, floored so loss never vanishes.
func global_drift_mult() -> float:
	var m := 1.0
	for p in placements:
		var data: BuildingData = p["data"]
		if data.category == BuildingData.Category.SUPPORT:
			m *= (1.0 - data.drift_reduction)
	return maxf(m, Balance.MIN_DRIFT_MULT)

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

# --- Setup ---

## M2 starter: load the catalog, then place the two free starters via the data
## path so the economy runs on launch (mirrors M1's feel). Everything beyond these
## is bought through the shop.
func setup_m2_starter() -> void:
	_load_catalog()
	placements.clear()
	_owned.clear()
	_occupied.clear()
	var channeler := find_in_catalog(&"channeler")
	var sprite := find_in_catalog(&"gather_sprite")
	if channeler:
		_place(channeler, 0, 0)
	if sprite:
		_place(sprite, 2, 0)   # two rings out on purpose — placement still matters

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
