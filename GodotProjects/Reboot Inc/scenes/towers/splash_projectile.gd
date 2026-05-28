class_name SplashProjectile
extends Node2D

const SPEED: float = 180.0
const INNER_FRACTION: float = 2.0 / 3.0
const EXPLOSION_DURATION: float = 0.35
const ORB_COLOR: Color = Color(1.0, 0.55, 0.05)
const RING_COLOR: Color = Color(1.0, 0.75, 0.2)

var _target_pos: Vector2
var _splash_radius: float
var _damage: float
var _outer_damage_fraction: float
var _traveling: bool = true
var _exp_t: float = 0.0

func setup(from: Vector2, to: Vector2, splash_radius: float, damage: float,
		outer_damage_fraction: float) -> void:
	global_position = from
	_target_pos = to
	_splash_radius = splash_radius
	_damage = damage
	_outer_damage_fraction = outer_damage_fraction

func _process(delta: float) -> void:
	if not _traveling:
		return
	var to_target: Vector2 = _target_pos - global_position
	var step: float = SPEED * delta
	if step >= to_target.length():
		global_position = _target_pos
		_traveling = false
		_explode()
	else:
		global_position += to_target.normalized() * step
	queue_redraw()

func _explode() -> void:
	for body in get_tree().get_nodes_in_group("enemies"):
		if not (body is Node2D) or not body.has_method("take_damage"):
			continue
		var dist: float = global_position.distance_to((body as Node2D).global_position)
		if dist > _splash_radius:
			continue
		var dmg: float = _damage
		if dist > _splash_radius * INNER_FRACTION:
			dmg *= _outer_damage_fraction
		body.take_damage(dmg)

	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _exp_t = t; queue_redraw(),
			0.0, 1.0, EXPLOSION_DURATION)
	tween.tween_callback(queue_free)

func _draw() -> void:
	if _traveling:
		draw_circle(Vector2.ZERO, 5.0, ORB_COLOR)
	else:
		var r: float = _splash_radius * _exp_t
		draw_circle(Vector2.ZERO, r,
				Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, (1.0 - _exp_t) * 0.25))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32,
				Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, 1.0 - _exp_t), 2.5)
