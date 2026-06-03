## Follows a grid path to the core (routing around placed towers/walls), takes
## chain damage, pays gold on death. Area2D so the core's Area2D detects contact;
## movement is integrated manually along NavGrid waypoints.
class_name Enemy
extends Area2D

signal died(enemy: Enemy)

@export var def: EnemyDef

var _health: float = 0.0
var _core_pos: Vector2 = Vector2.ZERO
var _nav: NavGrid
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0

func _ready() -> void:
	add_to_group("enemies")
	if def == null:
		push_warning("Enemy spawned without an EnemyDef")
		return
	_health = def.max_health
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = def.radius
	shape.shape = circle
	add_child(shape)
	_recompute_path()
	queue_redraw()

## Set before adding to the tree so _ready sees the def and can path.
func configure(p_def: EnemyDef, core_pos: Vector2, nav: NavGrid) -> void:
	def = p_def
	_core_pos = core_pos
	_nav = nav

func _recompute_path() -> void:
	if _nav != null:
		_path = _nav.path_points(global_position, _core_pos)
		_path_i = 0

func _physics_process(delta: float) -> void:
	if def == null:
		return
	var target := _current_target()
	var to_target := target - global_position
	if to_target.length() > 0.5:
		global_position += to_target.normalized() * def.speed * delta

## Consume reached waypoints; head to the core centre once the path is exhausted.
func _current_target() -> Vector2:
	while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) <= 6.0:
		_path_i += 1
	if _path_i < _path.size():
		return _path[_path_i]
	return _core_pos

func take_damage(amount: float) -> void:
	_health -= amount
	if _health <= 0.0:
		GoldWallet.add(def.gold_reward)
		died.emit(self)
		queue_free()

func _draw() -> void:
	if def == null:
		return
	draw_circle(Vector2.ZERO, def.radius, def.color)
