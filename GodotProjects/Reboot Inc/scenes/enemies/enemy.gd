class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy, was_killed: bool)

const FLASH_DURATION: float = 0.1
const _WAYPOINT_REACH_DIST: float = 12.0
const _PATH_GOAL_THRESHOLD: float = 72.0  # 1.5 × cell size — path must end this close to goal
const _MELEE_RANGE: float = 40.0
const _MELEE_INTERVAL: float = 1.0

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
var _blocking_target: Node2D = null
var _melee_timer: float = 0.0

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

	var path_reaches_goal := (
		_path.size() > 0
		and _path[-1].distance_to(_primary_target.global_position) <= _PATH_GOAL_THRESHOLD
	)
	if path_reaches_goal:
		_blocking_target = null
	elif _blocking_target == null or not is_instance_valid(_blocking_target):
		_blocking_target = _find_nearest_structure_toward_goal()

func _find_nearest_structure_toward_goal() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF
	var dir_to_goal := global_position.direction_to(_primary_target.global_position)
	for s: Node in get_tree().get_nodes_in_group("structures"):
		var node := s as Node2D
		if node == null or not is_instance_valid(node):
			continue
		if global_position.direction_to(node.global_position).dot(dir_to_goal) < 0.0:
			continue
		var d := global_position.distance_to(node.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = node
	return closest

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_current_target):
		_current_target = _primary_target
		return
	if _blocking_target != null:
		if not is_instance_valid(_blocking_target):
			_blocking_target = null
			call_deferred("refresh_path")
			return
		_handle_blocking_target(delta)
		return
	velocity = _get_steering_velocity()
	if face_movement_direction and velocity.length_squared() > 0.001:
		rotation = velocity.angle()
	move_and_slide()

func _handle_blocking_target(delta: float) -> void:
	var dist := global_position.distance_to(_blocking_target.global_position)
	if dist > _MELEE_RANGE:
		velocity = global_position.direction_to(_blocking_target.global_position) * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_melee_timer -= delta
		if _melee_timer <= 0.0:
			if _blocking_target.has_method("take_damage"):
				_blocking_target.take_damage(contact_damage)
			_melee_timer = _MELEE_INTERVAL

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
