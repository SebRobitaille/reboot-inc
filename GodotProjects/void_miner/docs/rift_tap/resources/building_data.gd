class_name BuildingData
extends Resource
## Data-driven definition of a building type. Instances live as .tres files in
## data/buildings/ so designers can add content in the Inspector without touching
## systems code. Systems (GameState, Economy, UI) read these; they never hardcode
## building stats.

## Shared enums — the single source of truth for building category & buy currency.
## GameState and UI reference BuildingData.Category / BuildingData.Currency.
enum Category { EXTRACTOR, COLLECTOR, SUPPORT }
enum Currency { ESSENCE, FLUX, RIFT_CORE }

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.EXTRACTOR
@export var buy_currency: Currency = Currency.ESSENCE

# --- Cost scaling (exponential in the count of THIS building type) ---
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.13

# --- Production (extractors emit, collectors capture) ---
@export var base_emission: float = 0.0   # essence/sec injected (EXTRACTOR)
@export var base_collect: float = 0.0    # essence/sec captured (COLLECTOR)

# --- Support effects (SUPPORT category) ---
## Refinery: each adds this to the global Flux multiplier (0.5 = +50%).
@export var flux_bonus: float = 0.0
## Stabilizer: each reduces global drift-loss by this fraction (0.3 = -30%),
## applied multiplicatively and floored by Balance.MIN_DRIFT_MULT.
@export var drift_reduction: float = 0.0

# --- Placement & unlocks ---
## Soft hint: placing on this ring grants Balance.PREFERRED_RING_BONUS. -1 = none.
@export var preferred_ring: int = -1
## Rift Cores required before this type can be bought. 0 = available from turn 1.
@export var unlock_requirement: int = 0

# --- Presentation ---
@export var icon: Texture2D
@export var description: String = ""
