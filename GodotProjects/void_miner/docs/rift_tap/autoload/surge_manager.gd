extends Node
## Runs Portal Surges (GDD §6): the ~25-minute allocation wall, plus the Overclock
## ability. Reads the economy ONLY through EventBus.stats_updated — it never touches
## the simulation. All timing is real-time (frame delta); the threshold rubber-bands
## to the player's recent peak capture rate so it always demands ~one growth cycle.

enum Phase { IDLE, WARNING, WINDOW }

var phase: Phase = Phase.IDLE
var _phase_time: float = 0.0            # seconds elapsed in the current phase
var _idle_target: float = 0.0          # IDLE seconds before the next warning

# Rolling peak capture-rate (essence/sec) over the last PEAK_WINDOW seconds.
var _capture_rate: float = 0.0         # latest smoothed captured/sec from stats
var _samples: Array[Vector2] = []      # (timestamp, captured/sec)
var _clock: float = 0.0                # monotonic clock for sample timestamps

# Active surge.
var _threshold: float = 0.0
var _destabilization: float = 0.0
var _progress_accum: float = 0.0       # throttles surge_progress to ~1 Hz

# Overclock ability. _oc_time_left holds either the remaining active time or the
# remaining cooldown, depending on the flags.
var _oc_active: bool = false
var _oc_on_cooldown: bool = false
var _oc_time_left: float = 0.0

func _ready() -> void:
	_idle_target = Balance.SURGE_FIRST_DELAY
	EventBus.stats_updated.connect(_on_stats_updated)
	_emit_overclock()

func _process(delta: float) -> void:
	_clock += delta
	_phase_time += delta
	_tick_overclock(delta)
	match phase:
		Phase.IDLE:
			if _phase_time >= _idle_target:
				_enter_warning()
		Phase.WARNING:
			var left := Balance.SURGE_WARNING - _phase_time
			EventBus.surge_warning.emit(maxf(left, 0.0))
			if left <= 0.0:
				_enter_window()
		Phase.WINDOW:
			# Integrate the latest capture rate over real time -> total captured.
			_destabilization += _capture_rate * delta
			var left := Balance.SURGE_WINDOW - _phase_time
			_progress_accum += delta
			if _progress_accum >= 1.0 or left <= 0.0:
				_progress_accum = 0.0
				EventBus.surge_progress.emit(_destabilization, _threshold, maxf(left, 0.0))
			if _threshold > 0.0 and _destabilization >= _threshold:
				_resolve(true)
			elif left <= 0.0:
				_resolve(false)

# --- Phase transitions ---

func _enter_warning() -> void:
	phase = Phase.WARNING
	_phase_time = 0.0
	EventBus.surge_warning.emit(Balance.SURGE_WARNING)

func _enter_window() -> void:
	phase = Phase.WINDOW
	_phase_time = 0.0
	_destabilization = 0.0
	_progress_accum = 0.0
	_threshold = Balance.surge_threshold(_peak_capture(), GameState.depth)
	EventBus.surge_started.emit(_threshold)

func _resolve(success: bool) -> void:
	phase = Phase.IDLE
	_phase_time = 0.0
	_idle_target = Balance.SURGE_INTERVAL
	if success:
		GameState.add_rift_cores(Balance.CORES_PER_CLEAR + GameState.prestige_core_bonus)
		GameState.advance_depth()
		_emit_overclock()   # earning a core may have just unlocked Overclock
	EventBus.surge_resolved.emit(success)

# --- Capture-rate tracking (rolling peak) ---

func _on_stats_updated(stats: Dictionary) -> void:
	_capture_rate = stats["captured_per_sec"]
	_samples.append(Vector2(_clock, _capture_rate))
	var cutoff := _clock - Balance.PEAK_WINDOW
	while not _samples.is_empty() and _samples[0].x < cutoff:
		_samples.pop_front()

func _peak_capture() -> float:
	var peak := _capture_rate
	for s in _samples:
		peak = maxf(peak, s.y)
	return peak

# --- Overclock ability ---

func overclock_unlocked() -> bool:
	return GameState.rift_cores >= Balance.OVERCLOCK_UNLOCK_CORES

## Player-triggered. Ignored unless unlocked, idle (not active, not cooling down).
func activate_overclock() -> void:
	if not overclock_unlocked() or _oc_active or _oc_on_cooldown:
		return
	_oc_active = true
	_oc_time_left = Balance.OVERCLOCK_DURATION
	GameState.surge_emission_mult = Balance.OVERCLOCK_MULT
	GameState.surge_collection_mult = Balance.OVERCLOCK_MULT
	_emit_overclock()

func _tick_overclock(delta: float) -> void:
	if _oc_active:
		_oc_time_left -= delta
		if _oc_time_left <= 0.0:
			_oc_active = false
			_oc_on_cooldown = true
			_oc_time_left = Balance.OVERCLOCK_COOLDOWN
			GameState.surge_emission_mult = 1.0
			GameState.surge_collection_mult = 1.0
		_emit_overclock()
	elif _oc_on_cooldown:
		_oc_time_left -= delta
		if _oc_time_left <= 0.0:
			_oc_on_cooldown = false
			_oc_time_left = 0.0
		_emit_overclock()

func overclock_state() -> Dictionary:
	return {
		"unlocked": overclock_unlocked(),
		"active": _oc_active,
		"on_cooldown": _oc_on_cooldown,
		"time_left": maxf(_oc_time_left, 0.0),
	}

func _emit_overclock() -> void:
	EventBus.overclock_changed.emit(overclock_state())

# --- Display helpers (UI polls these for smooth countdowns) ---

func phase_seconds_left() -> float:
	match phase:
		Phase.WARNING: return maxf(Balance.SURGE_WARNING - _phase_time, 0.0)
		Phase.WINDOW: return maxf(Balance.SURGE_WINDOW - _phase_time, 0.0)
		Phase.IDLE: return maxf(_idle_target - _phase_time, 0.0)
	return 0.0

func destabilization() -> float:
	return _destabilization

func threshold() -> float:
	return _threshold
