extends Node2D
## Prototype core loop (top-down): click the central void to charge it; every few
## clicks it releases one Essence, which scatters out and settles on the ground
## around the void. Click the drops to collect them. Scroll to zoom.

const EssenceScene := preload("res://scenes/prototype/Essence.tscn")
const VIEW := Vector2(1280, 720)
const PORTAL := Vector2(640, 360)
const PORTAL_RADIUS := 44.0
const CLICKS_PER_ESSENCE := 5

const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.5
const ZOOM_STEP := 1.1

var _essence := 0
var _click_count := 0
var _count_label: Label
var _click_pulse := 0.0
var _time := 0.0
var _camera: Camera2D

func _ready() -> void:
	_open_on_secondary_monitor()

	_camera = Camera2D.new()
	_camera.position = PORTAL          # zoom stays centred on the void
	_camera.zoom = Vector2.ONE
	add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	_count_label = Label.new()
	_count_label.position = Vector2(36, 28)
	_count_label.add_theme_font_size_override("font_size", 40)
	layer.add_child(_count_label)
	var hint := Label.new()
	hint.position = Vector2(36, 84)
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.text = "Click the void %d× to release essence — click essence to collect.  Scroll to zoom." % CLICKS_PER_ESSENCE
	layer.add_child(hint)
	_refresh()

## Dev convenience: open on the secondary monitor (not the primary). Toggling to
## windowed, moving, then back to fullscreen reliably relocates a fullscreen window.
func _open_on_secondary_monitor() -> void:
	if DisplayServer.get_screen_count() <= 1:
		return
	var primary := DisplayServer.get_primary_screen()
	for s in DisplayServer.get_screen_count():
		if s != primary:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_current_screen(s)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			return

func _process(delta: float) -> void:
	_time += delta
	if _click_pulse > 0.0:
		_click_pulse = maxf(_click_pulse - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	# Oversized backdrop so zooming out never reveals empty space.
	draw_rect(Rect2(PORTAL - Vector2(3000, 3000), Vector2(6000, 6000)), Color(0.04, 0.04, 0.09))
	# Spread-out floor rings — a pit seen from above.
	for i in 4:
		draw_arc(PORTAL, 160.0 + i * 150.0, 0.0, TAU, 96, Color(0.5, 0.45, 0.7, 0.06), 2.0, true)
	# The void: dark core with glowing rings, breathing idle + a pulse on click.
	var r := PORTAL_RADIUS + sin(_time * 1.5) * 2.0 + _click_pulse * 9.0
	draw_circle(PORTAL, r, Color(0.06, 0.03, 0.14))
	for i in 3:
		draw_arc(PORTAL, r * (1.0 - i * 0.2), 0.0, TAU, 48, Color(0.55, 0.40, 1.0, 0.6 - i * 0.15), 2.5, true)
	draw_arc(PORTAL, r + 3.0, 0.0, TAU, 48, Color(0.72, 0.55, 1.0, 0.9), 3.0, true)
	# Charge arc: progress toward the next Essence.
	if _click_count > 0:
		var frac := float(_click_count) / CLICKS_PER_ESSENCE
		draw_arc(PORTAL, r + 10.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(0.6, 0.95, 1.0, 0.95), 3.0, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if get_global_mouse_position().distance_to(PORTAL) <= PORTAL_RADIUS + 18.0:
				_click_void()

func _zoom(factor: float) -> void:
	var z := clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(z, z)

func _click_void() -> void:
	_click_pulse = 1.0
	_click_count += 1
	if _click_count >= CLICKS_PER_ESSENCE:
		_click_count = 0
		_spawn_essence()

func _spawn_essence() -> void:
	var dir := Vector2.from_angle(randf() * TAU)
	var orb := EssenceScene.instantiate()
	add_child(orb)
	# Emerge from the rim and fly clear of the void so it settles in a ring around it
	# (and never under the void's click area).
	orb.setup(PORTAL + dir * PORTAL_RADIUS, dir * randf_range(260.0, 460.0))
	orb.collected.connect(_on_collected)

func _on_collected(amount: int) -> void:
	_essence += amount
	_refresh()

func _refresh() -> void:
	_count_label.text = "Essence: %d" % _essence
