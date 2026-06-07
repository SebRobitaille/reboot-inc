extends VBoxContainer
## The ring × slot placement board. Clicking an empty slot places the building
## currently armed in the shop. Talks only to GameState (state) and EventBus
## (selection + placement) — never directly to the shop.

const BuildingScene := preload("res://scenes/buildings/Building.tscn")

var _selected: BuildingData = null
var _slot_buttons: Dictionary = {}   # cell_key -> Button

func _ready() -> void:
	_build_grid()
	EventBus.build_selection_changed.connect(_on_selection_changed)
	EventBus.building_placed.connect(_on_building_placed)
	# Reflect any placements that already exist (the starter loadout).
	for p in GameState.placements:
		_mark_slot(p["data"], p["ring"], p["slot"])

func _build_grid() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "BOARD  (ring 0 = innermost, nearest portal)"
	add_child(title)
	for ring in Balance.RING_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		var rlabel := Label.new()
		rlabel.text = "R%d" % ring
		rlabel.custom_minimum_size = Vector2(28, 0)
		row.add_child(rlabel)
		for slot in Balance.SLOTS_PER_RING:
			var b := Button.new()
			b.custom_minimum_size = Vector2(64, 64)
			b.pressed.connect(_on_slot_pressed.bind(ring, slot))
			row.add_child(b)
			_slot_buttons[_cell_key(ring, slot)] = b

func _on_selection_changed(data: BuildingData) -> void:
	_selected = data

func _on_slot_pressed(ring: int, slot: int) -> void:
	if _selected == null:
		return
	# try_place validates affordability + occupancy; failure is a silent no-op.
	GameState.try_place(_selected, ring, slot)

func _on_building_placed(data: BuildingData, ring: int, slot: int) -> void:
	_mark_slot(data, ring, slot)

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
