extends Control
## Concentric-ring placement board. Four rings radiate from a central portal; each
## has 4 slots. Clicking an empty slot places the building armed in the shop. The
## drifting Essence particles are PURELY COSMETIC — they read Economy.inflight to
## show where Essence is flowing, and never feed back into the simulation.

const BuildingScene := preload("res://scenes/buildings/Building.tscn")

const BOARD_SIZE := 460.0
const CENTER := Vector2(230, 230)
const RING_RADII: Array = [62.0, 106.0, 150.0, 194.0]
const SLOT_SIZE := 50.0
const PORTAL_RADIUS := 26.0

const RING_COLOR := Color(0.35, 0.45, 0.6, 0.5)
const PORTAL_COLOR := Color(0.5, 0.85, 1.0)
const PARTICLE_COLOR := Color(0.55, 0.9, 1.0)
const MAX_PARTICLES := 240
const PARTICLE_SPEED := 38.0          # px/sec outward
const SPAWN_PER_INFLIGHT := 1.2       # particles/sec per unit of in-flight Essence

var _selected: BuildingData = null
var _slot_buttons: Dictionary = {}    # cell_key -> Button
var _particles: Array = []            # [{ pos, angle, radius, alpha }]
var _spawn_accum := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(BOARD_SIZE, BOARD_SIZE)
	size = Vector2(BOARD_SIZE, BOARD_SIZE)
	_build_ring_board()
	EventBus.build_selection_changed.connect(_on_selection_changed)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.run_reset.connect(_on_run_reset)
	_reflect_placements()

# --- Cosmetic particle flow (reads the sim, never writes it) ---

func _process(delta: float) -> void:
	var inflight_total := 0.0
	for v in Economy.inflight:
		inflight_total += v
	_spawn_accum += inflight_total * SPAWN_PER_INFLIGHT * delta
	while _spawn_accum >= 1.0 and _particles.size() < MAX_PARTICLES:
		_spawn_accum -= 1.0
		_particles.append({
			"angle": randf() * TAU,
			"radius": PORTAL_RADIUS,
			"alpha": 1.0,
		})
	var max_radius: float = RING_RADII[RING_RADII.size() - 1] + 14.0
	var keep: Array = []
	for p in _particles:
		p["radius"] += PARTICLE_SPEED * delta
		p["alpha"] = clampf(1.0 - p["radius"] / max_radius, 0.0, 1.0)
		if p["radius"] < max_radius:
			keep.append(p)
	_particles = keep
	queue_redraw()

func _draw() -> void:
	# Rings.
	for radius in RING_RADII:
		draw_arc(CENTER, radius, 0.0, TAU, 64, RING_COLOR, 2.0, true)
	# Flowing Essence.
	for p in _particles:
		var pos: Vector2 = CENTER + Vector2(cos(p["angle"]), sin(p["angle"])) * p["radius"]
		var c := PARTICLE_COLOR
		c.a = p["alpha"]
		draw_circle(pos, 2.5, c)
	# Portal at the core.
	draw_circle(CENTER, PORTAL_RADIUS, PORTAL_COLOR * Color(1, 1, 1, 0.85))
	draw_arc(CENTER, PORTAL_RADIUS, 0.0, TAU, 32, PORTAL_COLOR, 2.5, true)
	var font := ThemeDB.fallback_font
	draw_string(font, CENTER - Vector2(20, -4), "RIFT", HORIZONTAL_ALIGNMENT_CENTER, 40, 12,
		Color(0.05, 0.1, 0.15))

# --- Layout ---

func _build_ring_board() -> void:
	for ring in Balance.RING_COUNT:
		for slot in Balance.SLOTS_PER_RING:
			var b := Button.new()
			b.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
			b.size = Vector2(SLOT_SIZE, SLOT_SIZE)
			b.position = _slot_center(ring, slot) - Vector2(SLOT_SIZE, SLOT_SIZE) * 0.5
			b.tooltip_text = "Ring %d" % ring
			b.pressed.connect(_on_slot_pressed.bind(ring, slot))
			add_child(b)
			_slot_buttons[_cell_key(ring, slot)] = b

func _slot_center(ring: int, slot: int) -> Vector2:
	# Stagger each ring's angles so slots spread around the rings instead of
	# stacking into radial spokes.
	var step := 360.0 / Balance.SLOTS_PER_RING
	# Offset each ring by a quarter-step so all 16 slots get distinct angles
	# (no two rings share a spoke).
	var angle := deg_to_rad(-90.0 + slot * step + ring * (step / Balance.RING_COUNT))
	return CENTER + Vector2(cos(angle), sin(angle)) * RING_RADII[ring]

# --- Placement (unchanged behaviour) ---

func _on_selection_changed(data: BuildingData) -> void:
	_selected = data

func _on_slot_pressed(ring: int, slot: int) -> void:
	if _selected == null:
		return
	# try_place validates affordability + occupancy; failure is a silent no-op.
	GameState.try_place(_selected, ring, slot)

func _on_building_placed(data: BuildingData, ring: int, slot: int) -> void:
	_mark_slot(data, ring, slot)

func _on_run_reset() -> void:
	for key in _slot_buttons:
		var b: Button = _slot_buttons[key]
		for child in b.get_children():
			child.queue_free()
		b.disabled = false
	_reflect_placements()

func _reflect_placements() -> void:
	for p in GameState.placements:
		_mark_slot(p["data"], p["ring"], p["slot"])

func _mark_slot(data: BuildingData, ring: int, slot: int) -> void:
	var b: Button = _slot_buttons[_cell_key(ring, slot)]
	b.disabled = true
	var view := BuildingScene.instantiate()
	b.add_child(view)
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.configure(data)

func _cell_key(ring: int, slot: int) -> int:
	return ring * Balance.SLOTS_PER_RING + slot
