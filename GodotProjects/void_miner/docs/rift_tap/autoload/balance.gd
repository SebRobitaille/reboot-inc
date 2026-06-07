extends Node
## Single source of truth for tunable constants and curve functions.
## Rule: no magic numbers anywhere else in the codebase.

# --- Simulation ---
const ECON_TICK: float = 0.1          # fixed economy timestep (10 Hz)
const RING_COUNT: int = 4             # rings 0..3 (0 = innermost, nearest portal)
const SLOTS_PER_RING: int = 4

# Fraction of a ring's in-flight essence that moves outward each tick.
# < 1.0 so essence lingers, giving collectors (and the player) time to grab it.
const FLOW_FRACTION: float = 0.4

# Fraction of *outflowing* essence lost as it crosses to the next ring.
# Lenient early-game; Stabilizers / Conveyors will reduce this from M2 on.
const DRIFT_LOSS: float = 0.10

# --- Manual bootstrap (phased out by prestige later) ---
const MANUAL_EMIT: float = 1.0        # essence injected into ring 0 per portal tap
const MANUAL_COLLECT: float = 1.0     # essence grabbed per collect tap

# --- Throughput byproduct ---
const FLUX_RATE: float = 0.02         # Flux per unit of essence captured

# --- Cost scaling (used from M2) ---
const DEFAULT_COST_GROWTH: float = 1.13

static func building_cost(base_cost: float, growth: float, owned: int) -> float:
	return base_cost * pow(growth, owned)

# --- Placement & support (M2) ---
# Bonus to a building's output when placed on its BuildingData.preferred_ring.
const PREFERRED_RING_BONUS: float = 0.25
# Stabilizers can't drive drift-loss below this fraction of its base value.
const MIN_DRIFT_MULT: float = 0.1

# --- Surges (M3) ---
# Phase durations.
const SURGE_WARNING: float = 45.0       # prep/re-place phase before the window
const SURGE_WINDOW: float = 90.0        # resist window; must clear within this
# Cadence (FAST while building M3; the real ~25-min wall is tuned via SURGE_FACTOR
# and cost_growth together — see GDD §11, not via these timers).
const SURGE_FIRST_DELAY: float = 90.0   # first surge after run start
const SURGE_INTERVAL: float = 180.0     # gap between surges

# Rubber-band threshold.
const PEAK_WINDOW: float = 120.0        # rolling window for peak capture-rate (~2 min)
const SURGE_FACTOR: float = 3.0         # how far above recent peak you must push
const DEPTH_THRESHOLD_SCALAR: float = 0.1   # threshold grows per depth tier

## Total destabilization (essence captured during the window) needed to clear.
## peak_net_capture is essence/sec; multiplying by SURGE_WINDOW turns that rate into
## a window total, and SURGE_FACTOR sets how far above your recent peak you must push
## DURING the window — the rubber-band wall. Tune SURGE_FACTOR with cost_growth.
static func surge_threshold(peak_net_capture: float, depth: int) -> float:
	return peak_net_capture * SURGE_FACTOR * (1.0 + DEPTH_THRESHOLD_SCALAR * depth) * SURGE_WINDOW

# Rewards for clearing a surge.
const CORES_PER_CLEAR: int = 1          # Rift Cores per cleared surge
const DEPTH_MULT_BONUS: float = 0.10    # base extraction/collection bump per tier

# --- Overclock ability (M3): the "survive the wall" tool ---
const OVERCLOCK_MULT: float = 3.0       # emission + collection multiplier while active
const OVERCLOCK_DURATION: float = 15.0  # seconds of burst
const OVERCLOCK_COOLDOWN: float = 60.0  # cooldown after it ends
const OVERCLOCK_UNLOCK_CORES: int = 1   # unlocked once you've earned this many cores

# --- Echoes / prestige (M4) ---
const ECHO_K: float = 1.0
const ECHO_EXP: float = 1.5
const CORE_BONUS: float = 0.25

static func echoes_gained(depth: int, cores: int) -> float:
	return floor(ECHO_K * pow(float(depth), ECHO_EXP) * (1.0 + cores * CORE_BONUS))

# Base seconds between auto-clicks at AUTOCLICK strength 1.0 (higher strength = faster).
const AUTOCLICK_INTERVAL: float = 2.0

# --- Persistence (M5) ---
const AUTOSAVE_INTERVAL: float = 15.0   # seconds between background autosaves
# Collapse value must grow by at least this fraction per second to count as "still
# growing"; below it, the Collapse button glows (plateau = time to prestige).
const PRESTIGE_PLATEAU_GROWTH: float = 0.02
