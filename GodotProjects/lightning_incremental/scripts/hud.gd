## Reads global signals + the core/spawner to display energy, gold, core HP, wave.
## UI is built in code to keep the scene file trivial.
class_name HUD
extends CanvasLayer

var _energy_bar: ProgressBar
var _hp_bar: ProgressBar
var _gold_label: Label
var _wave_label: Label
var _game_over: Label
var _is_over: bool = false

func _ready() -> void:
	# Stay active while the tree is paused so the restart click is received.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EnergyPool.energy_changed.connect(_on_energy_changed)
	GoldWallet.gold_changed.connect(_on_gold_changed)
	# Autoloads are ready before us, so pull current values directly.
	_on_energy_changed(EnergyPool.current, PlayerStats.energy_max)
	_on_gold_changed(GoldWallet.gold)

func bind_core(core: Core) -> void:
	core.core_health_changed.connect(_on_core_health_changed)
	core.core_destroyed.connect(_on_core_destroyed)
	core.emit_health()  # initialise the HP bar (core emitted once before we connected)

func bind_spawner(spawner: EnemySpawner) -> void:
	spawner.wave_started.connect(_on_wave_started)

func _build_ui() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(16, 16)
	panel.add_theme_constant_override("separation", 4)
	add_child(panel)

	_wave_label = Label.new()
	_wave_label.text = "Wave 1"
	panel.add_child(_wave_label)

	_gold_label = Label.new()
	panel.add_child(_gold_label)

	panel.add_child(_make_caption("Energy"))
	_energy_bar = _make_bar(Color(0.4, 0.7, 1.0))
	panel.add_child(_energy_bar)

	panel.add_child(_make_caption("Core HP"))
	_hp_bar = _make_bar(Color(0.5, 0.9, 0.5))
	panel.add_child(_hp_bar)

	_game_over = Label.new()
	_game_over.text = "CORE DESTROYED\nClick to restart"
	_game_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over.add_theme_font_size_override("font_size", 32)
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_game_over.visible = false
	add_child(_game_over)

func _make_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _make_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 18)
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	bar.add_theme_stylebox_override("fill", style)
	return bar

func _on_energy_changed(current: float, maximum: float) -> void:
	_energy_bar.max_value = maximum
	_energy_bar.value = current

func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "Gold: %d" % amount

func _on_core_health_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current

func _on_wave_started(number: int) -> void:
	_wave_label.text = "Wave %d" % number

func _on_core_destroyed() -> void:
	_is_over = true
	_game_over.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not _is_over:
		return
	if event is InputEventMouseButton and event.pressed:
		get_tree().paused = false
		get_tree().reload_current_scene()
