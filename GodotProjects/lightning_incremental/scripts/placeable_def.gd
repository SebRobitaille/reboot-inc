## Data-driven definition of a placeable (tower or wall). Authored as .tres.
class_name PlaceableDef
extends Resource

enum Kind { TOWER, WALL }

@export var title: String = ""
@export var kind: Kind = Kind.TOWER
@export var cost: int = 10
@export var color: Color = Color.WHITE
@export var radius: float = 16.0          # tower circle radius / wall half-extent
@export var tower_stats: CombatStats       # the emitter's stats; null for walls
