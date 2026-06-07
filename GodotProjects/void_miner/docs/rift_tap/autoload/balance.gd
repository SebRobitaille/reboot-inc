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

# --- Surge threshold (M3) — placeholder, tune against cost_growth later ---
const SURGE_FACTOR: float = 3.0

static func surge_threshold(peak_net_capture: float, depth: int) -> float:
	return peak_net_capture * SURGE_FACTOR * (1.0 + 0.1 * depth)

# --- Echoes (M4) — placeholder ---
const ECHO_K: float = 1.0
const ECHO_EXP: float = 1.5
const CORE_BONUS: float = 0.25

static func echoes_gained(depth: int, cores: int) -> float:
	return floor(ECHO_K * pow(float(depth), ECHO_EXP) * (1.0 + cores * CORE_BONUS))
