class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy, was_killed: bool)

const FLASH_DURATION: float = 0.1
const _WAYPOINT_REACH_DIST: float = 12.0

@export var max_health: float = 30.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var gold_reward: int = 5
@export_range(0.0, 0.95) var damage_reduction: float = 0.0
@export var face_movement_direction: bool = false
@export var damage_number_scene: PackedScene

var _health: float = 0.0
var _primary_target: Node2D = null
var _current_target: Node2D = null
var _path: PackedVector2Array = []
var _path_index: int = 0

func _ready() -> void:
	_health = max_health
	add_to_group("enemies")

func setup(base: Node2D) -> void:
	_primary_target = base
	_current_target = base
	call_deferred("refresh_path")

func refresh_path() -> void:
	if not is_instance_valid(_primary_target):
		return
	var params := NavigationPathQueryParameters2D.new()
	params.map = get_world_2d().get_navigation_map()
	params.start_position = global_position
	params.target_position = _primary_target.global_position
	var result := NavigationPathQueryResult2D.new()
	NavigationServer2D.query_path(params, result)
	_path = result.path
	_path_index = 1 if _path.size() > 1 else 0

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_current_target):
		_current_target = _primary_target
		return
	velocity = _get_steering_velocity()
	if face_movement_direction and velocity.length_squared() > 0.001:
		rotation = velocity.angle()
	move_and_slide()

func _get_steering_velocity() -> Vector2:
	if _path.is_empty() or _path_index >= _path.size():
		return global_position.direction_to(_primary_target.global_position) * move_speed
	var target: Vector2 = _path[_path_index]
	while global_position.distance_to(target) < _WAYPOINT_REACH_DIST:
		_path_index += 1
		if _path_index >= _path.size():
			return global_position.direction_to(_primary_target.global_position) * move_speed
		target = _path[_path_index]
	return global_position.direction_to(target) * move_speed

func take_damage(amount: float) -> void:
	var actual: float = amount * (1.0 - damage_reduction)
	_health -= actual
	_spawn_damage_number(actual)
	_flash()
	if _health <= 0.0:
		_die(true)

func reached_destination() -> void:
	_die(false)

func get_contact_damage() -> float:
	return contact_damage

func get_gold_reward() -> int:
	return gold_reward

func _spawn_damage_number(amount: float) -> void:
	if damage_number_scene == null:
		return
	var number: Node2D = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = global_position
	if number.has_method("setup"):
		number.setup(amount)

func _flash() -> void:
	modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, FLASH_DURATION)

func _die(was_killed: bool) -> void:
	died.emit(self, was_killed)
	queue_free()
