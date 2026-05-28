class_name BuildButton
extends Button

signal build_requested(scene: PackedScene, data: StructureData)

@export var structure_scene: PackedScene
@export var structure_data: StructureData

var _gold_system: GoldSystem = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	custom_minimum_size = Vector2(120, 60)
	_refresh_text("")

func set_shortcut_hint(key_label: String) -> void:
	_refresh_text(key_label)

func _refresh_text(key_label: String) -> void:
	if structure_data == null:
		return
	if key_label.is_empty():
		text = "%s\n%d g" % [structure_data.display_name, structure_data.gold_cost]
	else:
		text = "%s  [%s]\n%d g" % [structure_data.display_name, key_label, structure_data.gold_cost]

func bind(gold_system: GoldSystem) -> void:
	_gold_system = gold_system
	if _gold_system != null:
		_gold_system.gold_changed.connect(_on_gold_changed)
	_refresh_state()

func _refresh_state() -> void:
	if _gold_system == null or structure_data == null:
		return
	disabled = not _gold_system.has_enough(structure_data.gold_cost)

func _on_gold_changed(_current: int, _change: int) -> void:
	_refresh_state()

func activate() -> void:
	if not disabled:
		_on_pressed()

func _on_pressed() -> void:
	if structure_scene != null and structure_data != null:
		build_requested.emit(structure_scene, structure_data)
