class_name BuildMenu
extends HBoxContainer

var placement_system: PlacementSystem = null
var wave_manager: WaveManager = null
var gold_system: GoldSystem = null

const _SHORTCUT_KEYS: Array[String] = ["Q", "W"]

func bind(placement: PlacementSystem, waves: WaveManager, gold: GoldSystem) -> void:
	placement_system = placement
	wave_manager = waves
	gold_system = gold

	var btn_idx := 0
	for child in get_children():
		if child is BuildButton:
			child.build_requested.connect(_on_build_requested)
			child.bind(gold_system)
			if btn_idx < _SHORTCUT_KEYS.size():
				child.set_shortcut_hint(_SHORTCUT_KEYS[btn_idx])
			btn_idx += 1

	if wave_manager != null:
		wave_manager.phase_changed.connect(_on_phase_changed)

	_refresh_visibility()

func _refresh_visibility() -> void:
	if wave_manager == null:
		visible = true
		return
	var phase := wave_manager.get_phase()
	visible = (phase == WaveManager.Phase.PREP or phase == WaveManager.Phase.WAVE_CLEARED)

# Q = first button (Laser Tower), W = second button (Wall)
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var buttons: Array[BuildButton] = []
	for child in get_children():
		if child is BuildButton:
			buttons.append(child)
	var idx := -1
	match event.keycode:
		KEY_Q: idx = 0
		KEY_W: idx = 1
	if idx < 0 or idx >= buttons.size():
		return
	buttons[idx].activate()
	get_viewport().set_input_as_handled()

func _on_build_requested(scene: PackedScene, data: StructureData) -> void:
	if placement_system != null:
		placement_system.start_placement(scene, data)

func _on_phase_changed(_new_phase: WaveManager.Phase) -> void:
	_refresh_visibility()
