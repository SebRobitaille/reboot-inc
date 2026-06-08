extends Area2D
## A drop of Essence (top-down): flung outward from the void, it drifts and settles
## on the ground around the void, glowing until the player clicks it to collect.

signal collected(amount: int)

const DRAG := 3.0          # how fast outward motion bleeds off (lower = travels further)
const STOP_SPEED := 10.0
const RADIUS := 15.0

var _vel := Vector2.ZERO
var _settled := false

func setup(pos: Vector2, vel: Vector2) -> void:
	position = pos
	_vel = vel

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input)

func _process(delta: float) -> void:
	if not _settled:
		position += _vel * delta
		_vel -= _vel * DRAG * delta
		if _vel.length() < STOP_SPEED:
			_vel = Vector2.ZERO
			_settled = true
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + 5.0, Color(0.4, 0.9, 1.0, 0.18))   # soft glow
	draw_circle(Vector2.ZERO, RADIUS, Color(0.55, 0.92, 1.0))
	draw_circle(Vector2(-4.0, -4.0), RADIUS * 0.45, Color(1, 1, 1, 0.85))  # highlight

func _on_input(_viewport: Node, event: InputEvent, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collected.emit(1)
		get_viewport().set_input_as_handled()
		queue_free()
