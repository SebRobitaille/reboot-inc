class_name BalanceSim
extends RefCounted
## Headless balance harness (M6 balance pass, GDD §11). Drives the REAL economy
## (Economy._tick) with a documented greedy bot to measure how long a competent
## player takes to clear successive surges, then sweeps surge_factor x cost_growth
## against the ~25-minute frontier target. Dev tool only — main.gd gates it behind
## --balance and it never runs in the shipped game path.
##
## Bot policy (kept deliberately simple and explicit; results are RELATIVE to it —
## human playtests still matter, per §11):
##   - Uses only the always-available starters (Channeler, Gather-Sprite).
##   - Each step buys greedily, keeping collection capacity ~1.15x emission to
##     limit Rift loss; extractors fill inner rings, collectors outer.
##   - During a surge window it dumps its banked Essence (spiking output above the
##     rolling peak) and fires Overclock once unlocked — the intended "clear" play.

const TICK := 0.1
const WINDOW := 90.0               # matches Balance.SURGE_WINDOW
const PEAK_WINDOW := 120.0         # matches Balance.PEAK_WINDOW
const DEPTH_SCALAR := 0.1          # matches Balance.DEPTH_THRESHOLD_SCALAR
const OVERCLOCK_MULT := 3.0
const OVERCLOCK_DUR := 15.0
const CAPACITY_TARGET := 1.15      # bot keeps capacity ~ this x emission
const RESERVE_SLOTS := 6           # slots kept free while growing, for the surge dump
const ATTEMPT_INTERVAL := 60.0     # bot grows this long, then attempts a surge
const MAX_SIM_SECONDS := 5400.0    # 90 min safety cap per run
const MAX_SURGES := 8
const TARGET_MIN := 25.0

var _channeler: BuildingData
var _sprite: BuildingData
var _growth: float
var _owned := {}
var _peak_samples: Array = []
var _sim_t := 0.0

func run() -> void:
	_channeler = GameState.find_in_catalog(&"channeler")
	_sprite = GameState.find_in_catalog(&"gather_sprite")
	print("=== Rift Tap balance sweep (bot-driven, single-run) ===")
	print("current Balance.SURGE_FACTOR = %.2f ; clearability is board-limited, so this" % Balance.SURGE_FACTOR)
	print("reports surges cleared per fresh run. cost_growth is not the surge lever.\n")
	var factors: Array = [1.0, 1.1, 1.15, 1.2, 1.3]
	var growths: Array = [1.13, 1.16]
	for g in growths:
		for f in factors:
			var res := _simulate(f, g)
			print("growth=%.2f  factor=%.2f  ->  cleared %d surges  spacing(min)=%s" % [
				g, f, res["clears"].size(), _fmt_spacing(res["clears"])])
		print("")

# --- One single-run simulation for a (factor, growth) pair ---

func _simulate(factor: float, growth: float) -> Dictionary:
	_reset()
	_growth = growth
	var clears: Array = []
	var last_attempt := 0.0
	while _sim_t < MAX_SIM_SECONDS and clears.size() < MAX_SURGES:
		_grow_step()
		if _sim_t - last_attempt >= ATTEMPT_INTERVAL:
			last_attempt = _sim_t
			if _attempt_surge(factor, GameState.depth):
				GameState.advance_depth()
				clears.append(_sim_t)
				last_attempt = _sim_t
	return { "clears": clears }

func _grow_step() -> void:
	var before := GameState.essence
	Economy._tick()
	_record_peak((GameState.essence - before) / TICK)
	_sim_t += TICK
	_bot_buy(true)

# Greedy buy: keep capacity ~CAPACITY_TARGET x emission. In grow mode the bot keeps
# RESERVE_SLOTS free and banks the rest (a war chest for the surge); in dump mode
# (during the window) it spends everything into all remaining slots to spike output.
func _bot_buy(grow: bool) -> void:
	for _i in 64:
		if grow and _free_count() <= RESERVE_SLOTS:
			return
		var emis := _sum(GameState.emission_by_ring())
		var cap := _sum(GameState.collection_by_ring())
		var data := _sprite if cap < emis * CAPACITY_TARGET else _channeler
		var c := _cost(data)
		if GameState.essence < c:
			var other := _channeler if data == _sprite else _sprite
			if GameState.essence < _cost(other):
				return
			data = other
			c = _cost(other)
		var slot := _free_slot(data)
		if slot.is_empty():
			return
		GameState.essence -= c
		GameState._place(data, slot[0], slot[1])
		_owned[data.id] = _owned.get(data.id, 0) + 1

# Simulate a 90s window: bot dumps + overclocks; clear if destabilization >= threshold.
func _attempt_surge(factor: float, depth: int) -> bool:
	var threshold := _peak() * factor * (1.0 + DEPTH_SCALAR * depth) * WINDOW
	if threshold <= 0.0:
		return false
	var destab := 0.0
	var oc_left := OVERCLOCK_DUR if depth >= 1 else 0.0   # Overclock unlocked after 1st core
	var t := 0.0
	while t < WINDOW:
		if oc_left > 0.0:
			GameState.surge_emission_mult = OVERCLOCK_MULT
			GameState.surge_collection_mult = OVERCLOCK_MULT
			oc_left -= TICK
			if oc_left <= 0.0:
				GameState.surge_emission_mult = 1.0
				GameState.surge_collection_mult = 1.0
		var before := GameState.essence
		Economy._tick()
		var captured := GameState.essence - before
		destab += captured
		_record_peak(captured / TICK)
		_bot_buy(false)
		t += TICK
		_sim_t += TICK
	GameState.surge_emission_mult = 1.0
	GameState.surge_collection_mult = 1.0
	return destab >= threshold

# --- Helpers ---

func _reset() -> void:
	_owned.clear()
	_peak_samples.clear()
	_sim_t = 0.0
	GameState.reset_run_state()
	for i in Economy.inflight.size():
		Economy.inflight[i] = 0.0
	GameState.depth = 0
	GameState.extraction_mult = 1.0
	GameState.collection_mult = 1.0
	GameState.surge_emission_mult = 1.0
	GameState.surge_collection_mult = 1.0

func _cost(data: BuildingData) -> float:
	return data.base_cost * pow(_growth, _owned.get(data.id, 0))

func _free_slot(data: BuildingData) -> Array:
	var inner_first := data.category == BuildingData.Category.EXTRACTOR
	for ri in Balance.RING_COUNT:
		var ring := ri if inner_first else Balance.RING_COUNT - 1 - ri
		for slot in Balance.SLOTS_PER_RING:
			if GameState.is_slot_free(ring, slot):
				return [ring, slot]
	return []

func _free_count() -> int:
	var n := 0
	for ring in Balance.RING_COUNT:
		for slot in Balance.SLOTS_PER_RING:
			if GameState.is_slot_free(ring, slot):
				n += 1
	return n

func _record_peak(rate: float) -> void:
	_peak_samples.append([_sim_t, rate])
	var cutoff := _sim_t - PEAK_WINDOW
	while not _peak_samples.is_empty() and _peak_samples[0][0] < cutoff:
		_peak_samples.pop_front()

func _peak() -> float:
	var p := 0.0
	for s in _peak_samples:
		p = maxf(p, s[1])
	return p

func _sum(arr: PackedFloat64Array) -> float:
	var t := 0.0
	for v in arr:
		t += v
	return t

func _fmt_spacing(clears: Array) -> String:
	if clears.is_empty():
		return "[]"
	var parts: Array = []
	var prev := 0.0
	for t in clears:
		parts.append("%.1f" % ((t - prev) / 60.0))
		prev = t
	return "[" + ", ".join(parts) + "]"
