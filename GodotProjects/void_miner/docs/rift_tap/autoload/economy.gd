extends Node
## Deterministic, fixed-timestep ring-flow simulation — the heart of the game.
## This is authoritative state. The (future) visual particle layer is cosmetic
## and must NEVER feed back into this simulation.

var inflight: PackedFloat64Array      # essence currently traversing each ring
var _accumulator: float = 0.0

# Rolling 1-second stat accumulators (for the HUD).
var _stat_window: float = 0.0
var _emitted_acc: float = 0.0
var _captured_acc: float = 0.0
var _lost_acc: float = 0.0

func _ready() -> void:
	inflight = PackedFloat64Array()
	inflight.resize(Balance.RING_COUNT)

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
	# Support modifiers (M2): Stabilizers cut drift, Refineries boost Flux.
	var drift_loss := Balance.DRIFT_LOSS * GameState.global_drift_mult()

	# 1. Emit into rings (extractors; in M1 all emission is at ring 0).
	var emitted_this_tick := 0.0
	for r in Balance.RING_COUNT:
		var e: float = emission[r] * tick
		inflight[r] += e
		emitted_this_tick += e

	var captured_this_tick := 0.0
	var lost_this_tick := 0.0

	# 2. Flow inner -> outer.
	for r in Balance.RING_COUNT:
		# Collectors in this ring capture what they can this tick.
		var cap: float = capacity[r] * tick
		var captured: float = minf(inflight[r], cap)
		inflight[r] -= captured
		captured_this_tick += captured

		# Remaining essence flows outward.
		var outflow: float = inflight[r] * Balance.FLOW_FRACTION
		inflight[r] -= outflow

		# Drift loss on traversal (reduced by Stabilizers).
		var drift: float = outflow * drift_loss
		lost_this_tick += drift
		var kept: float = outflow - drift

		if r < Balance.RING_COUNT - 1:
			inflight[r + 1] += kept
		else:
			# Past the outer ring -> reclaimed by the Rift.
			lost_this_tick += kept

	# 3. Bank captured essence + the Flux throughput byproduct.
	GameState.add_essence(captured_this_tick)
	GameState.add_flux(captured_this_tick * Balance.FLUX_RATE * GameState.flux_mult())

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
		})
		_stat_window = 0.0
		_emitted_acc = 0.0
		_captured_acc = 0.0
		_lost_acc = 0.0

func _inflight_total() -> float:
	var t := 0.0
	for v in inflight:
		t += v
	return t
