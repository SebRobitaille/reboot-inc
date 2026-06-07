extends Node
## Deterministic, fixed-timestep ring-flow simulation — the heart of the game.
## This is authoritative state. The (future) visual particle layer is cosmetic
## and must NEVER feed back into this simulation.

var inflight: PackedFloat64Array      # essence currently traversing each ring
var _accumulator: float = 0.0

# Rolling 1-second stat accumulators (for the HUD + stats panel).
var _stat_window: float = 0.0
var _emitted_acc: float = 0.0
var _captured_acc: float = 0.0
var _lost_acc: float = 0.0
# Per-ring captured / lost accumulators (parallel to the totals above).
var _captured_ring: PackedFloat64Array
var _lost_ring: PackedFloat64Array

func _ready() -> void:
	inflight = PackedFloat64Array()
	inflight.resize(Balance.RING_COUNT)
	_captured_ring = PackedFloat64Array()
	_captured_ring.resize(Balance.RING_COUNT)
	_lost_ring = PackedFloat64Array()
	_lost_ring.resize(Balance.RING_COUNT)

func _process(delta: float) -> void:
	_accumulator += delta
	var steps := 0
	while _accumulator >= Balance.ECON_TICK and steps < 50:
		_accumulator -= Balance.ECON_TICK
		_tick()
		steps += 1
	# Drop any excessive backlog (e.g. after a long pause). Real offline progress
	# (M5) will replay elapsed time properly instead of catching up here.
	if _accumulator > Balance.ECON_TICK:
		_accumulator = 0.0
	_update_stat_window(delta)

func _tick() -> void:
	var emission := GameState.emission_by_ring()
	var capacity := GameState.collection_by_ring()
	var tick := Balance.ECON_TICK
	# Support modifiers: Stabilizers (global) + Conveyors (per-ring) cut drift.
	var global_drift := Balance.DRIFT_LOSS * GameState.global_drift_mult()
	var ring_drift := GameState.drift_mult_by_ring()

	# 1. Emit into rings (extractors; in M1 all emission is at ring 0).
	var emitted_this_tick := 0.0
	for r in Balance.RING_COUNT:
		var e: float = emission[r] * tick
		inflight[r] += e
		emitted_this_tick += e

	var captured_this_tick := 0.0
	var lost_this_tick := 0.0
	var lost_ring_tick := PackedFloat64Array()
	lost_ring_tick.resize(Balance.RING_COUNT)

	# 2. Flow inner -> outer.
	for r in Balance.RING_COUNT:
		# Collectors in this ring capture what they can this tick.
		var cap: float = capacity[r] * tick
		var captured: float = minf(inflight[r], cap)
		inflight[r] -= captured
		captured_this_tick += captured
		_captured_ring[r] += captured

		# Remaining essence flows outward.
		var outflow: float = inflight[r] * Balance.FLOW_FRACTION
		inflight[r] -= outflow

		# Drift loss on traversal (reduced by Stabilizers globally + Conveyors here).
		var drift: float = outflow * global_drift * ring_drift[r]
		lost_ring_tick[r] += drift
		var kept: float = outflow - drift

		if r < Balance.RING_COUNT - 1:
			inflight[r + 1] += kept
		else:
			lost_ring_tick[r] += kept   # past the outer ring -> reclaimed by the Rift
	for r in Balance.RING_COUNT:
		lost_this_tick += lost_ring_tick[r]

	# 3. Flux from collector throughput (computed before any siphon top-up).
	GameState.add_flux(captured_this_tick * Balance.FLUX_RATE * GameState.flux_mult())

	# 4. Void Siphons reclaim a fraction of Rift loss as extra captured essence.
	var siphon := GameState.siphon_fraction()
	if siphon > 0.0:
		var keep := 1.0 - siphon
		captured_this_tick += lost_this_tick * siphon
		lost_this_tick *= keep
		for r in Balance.RING_COUNT:
			lost_ring_tick[r] *= keep

	# 5. Commit per-ring loss + bank essence.
	for r in Balance.RING_COUNT:
		_lost_ring[r] += lost_ring_tick[r]
	GameState.add_essence(captured_this_tick)

	_emitted_acc += emitted_this_tick
	_captured_acc += captured_this_tick
	_lost_acc += lost_this_tick

# --- Manual bootstrap (start-of-run only) ---
func manual_extract() -> void:
	inflight[0] += Balance.MANUAL_EMIT
	_emitted_acc += Balance.MANUAL_EMIT

func manual_collect() -> void:
	var want := Balance.MANUAL_COLLECT
	for r in Balance.RING_COUNT:
		if want <= 0.0:
			break
		var take: float = minf(inflight[r], want)
		inflight[r] -= take
		want -= take
		GameState.add_essence(take)
		_captured_acc += take

# --- HUD stats (smoothed over ~1s) ---
func _update_stat_window(delta: float) -> void:
	_stat_window += delta
	if _stat_window >= 1.0:
		var inv := 1.0 / _stat_window
		EventBus.stats_updated.emit({
			"emit_per_sec": _emitted_acc * inv,
			"captured_per_sec": _captured_acc * inv,
			"lost_per_sec": _lost_acc * inv,
			"inflight_total": _inflight_total(),
			"captured_by_ring": _scaled(_captured_ring, inv),
			"lost_by_ring": _scaled(_lost_ring, inv),
			"inflight_by_ring": inflight.duplicate(),
		})
		_stat_window = 0.0
		_emitted_acc = 0.0
		_captured_acc = 0.0
		_lost_acc = 0.0
		for r in Balance.RING_COUNT:
			_captured_ring[r] = 0.0
			_lost_ring[r] = 0.0

func _scaled(arr: PackedFloat64Array, factor: float) -> PackedFloat64Array:
	var out := arr.duplicate()
	for i in out.size():
		out[i] *= factor
	return out

func _inflight_total() -> float:
	var t := 0.0
	for v in inflight:
		t += v
	return t

# --- Save / load (M5) ---
func inflight_to_array() -> Array:
	return Array(inflight)

func inflight_from_array(a: Array) -> void:
	for r in mini(a.size(), inflight.size()):
		inflight[r] = float(a[r])
