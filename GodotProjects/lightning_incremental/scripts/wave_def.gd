## One wave's spawn description as parallel arrays (kept untyped for simple .tres
## authoring). Group i spawns counts[i] of defs[i], one every intervals[i] seconds.
class_name WaveDef
extends Resource

@export var defs: Array = []       # EnemyDef per group
@export var counts: Array = []     # int per group
@export var intervals: Array = []  # float seconds per group
