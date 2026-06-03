## Auto-firing placeable. Reuses ChainEmitter unchanged (the same component the core
## uses), so a single-target "railgun" is just a CombatStats with max_targets = 1.
## Draws from the shared EnergyPool, creating the cursor-vs-tower energy tradeoff.
class_name Tower
extends Node2D

var def: PlaceableDef
var _emitter: ChainEmitter

## Set before adding to the tree so _ready/_draw see the def.
func configure(p_def: PlaceableDef) -> void:
	def = p_def

func _ready() -> void:
	add_to_group("towers")
	_emitter = ChainEmitter.new()
	_emitter.stats = def.tower_stats
	add_child(_emitter)
	queue_redraw()

func _process(_delta: float) -> void:
	if _emitter == null or not _emitter.can_fire():
		return
	var candidates := get_tree().get_nodes_in_group("enemies")
	var seed := ChainEmitter.nearest_enemy(global_position, candidates, def.tower_stats.cast_range)
	if seed != null:
		_emitter.try_fire(seed, candidates)

func _draw() -> void:
	if def == null:
		return
	draw_circle(Vector2.ZERO, def.radius, def.color)
	draw_arc(Vector2.ZERO, def.radius + 3.0, 0.0, TAU, 24, def.color.lightened(0.35), 2.0)
