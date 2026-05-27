class_name BuildButton
extends Button

signal build_requested(scene: PackedScene, data: StructureData)

@export var structure_scene: PackedScene
@export var structure_data: StructureData

var _gold_system: GoldSystem = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	if structure_data != null:
		text = "%s\n%d g" % [structure_data.display_name, structure_data.gold_cost]
	custom_minimum_size = Vector2(120, 60)

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
