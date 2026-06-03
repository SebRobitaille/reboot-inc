## Player-defended core. Click an enemy to fire a chain via the shared ChainEmitter
## (gated by energy + cooldown); takes contact damage from enemies that reach it.
## Firing is suppressed during the build phase so field clicks place instead.
class_name Core
extends Area2D

signal core_health_changed(current: float, maximum: float)
signal core_destroyed

const PICK_TOLERANCE := 56.0  # how close to an enemy the click must land to seed it

@export var radius: float = 26.0

var building: bool = false  # set by the run during the build phase

var _health: float = 0.0
var _alive: bool = true
var _emitter: ChainEmitter

func _ready() -> void:
	_health = PlayerStats.core_max_health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_emitter = ChainEmitter.new()
	_emitter.stats = PlayerStats.stats  # shared object; in-run upgrades mutate it in place
	add_child(_emitter)
	area_entered.connect(_on_area_entered)
	PlayerStats.stats_changed.connect(_on_stats_changed)
	core_health_changed.emit(_health, PlayerStats.core_max_health)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _alive or building:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_fire(get_global_mouse_position())

func _try_fire(aim: Vector2) -> void:
	if not _emitter.can_fire():
		return
	var candidates := get_tree().get_nodes_in_group("enemies")
	var seed := _pick_seed(aim, candidates, PlayerStats.stats.cast_range)
	if seed == null:
		return  # clicked empty space — no fire, no energy spent
	_emitter.try_fire(seed, candidates)

## Seed = the enemy nearest the cursor that is within cast range and the click tolerance.
func _pick_seed(aim: Vector2, candidates: Array, cast_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for c in candidates:
		var node := c as Node2D
		if node == null or not is_instance_valid(node):
			continue
		if global_position.distance_to(node.global_position) > cast_range:
			continue
		var d := aim.distance_to(node.global_position)
		if d < best_dist:
			best = node
			best_dist = d
	if best != null and best_dist <= PICK_TOLERANCE + (best as Enemy).def.radius:
		return best
	return null

func _on_area_entered(area: Area2D) -> void:
	var enemy := area as Enemy
	if enemy == null or enemy.def == null:
		return
	take_damage(enemy.def.contact_damage)
	enemy.queue_free()

func take_damage(amount: float) -> void:
	if not _alive:
		return
	_health = maxf(0.0, _health - amount)
	core_health_changed.emit(_health, PlayerStats.core_max_health)
	if _health <= 0.0:
		_alive = false
		core_destroyed.emit()

## Re-emit current HP so a HUD that connects after _ready still initialises.
func emit_health() -> void:
	core_health_changed.emit(_health, PlayerStats.core_max_health)

## A shop purchase may raise (or lower) the core's max HP; clamp and refresh the bar.
func _on_stats_changed() -> void:
	_health = minf(_health, PlayerStats.core_max_health)
	core_health_changed.emit(_health, PlayerStats.core_max_health)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.3, 0.7, 1.0))
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 32, Color(0.6, 0.9, 1.0), 2.0)
