extends Node
## Bootstrap + HUD host. Builds the currency/rate readout and bootstrap taps in
## code, then mounts the M2 shop (BuildMenu) and placement Board scenes. The
## economy runs from the data-driven starter loadout immediately.

const BoardScene := preload("res://scenes/main/Board.tscn")
const BuildMenuScene := preload("res://scenes/ui/BuildMenu.tscn")
const SurgeBannerScene := preload("res://scenes/ui/SurgeBanner.tscn")
const PrestigeScreenScene := preload("res://scenes/ui/PrestigeScreen.tscn")

var _essence_label: Label
var _flux_label: Label
var _rate_label: Label
var _depth_label: Label
var _echoes_label: Label
var _prestige_screen: PanelContainer

func _ready() -> void:
	# Loadout first: the shop reads GameState.catalog and the board reads
	# GameState.placements during their _ready, so state must exist before mount.
	GameState.setup_run()

	_build_ui()

	EventBus.essence_changed.connect(_on_essence_changed)
	EventBus.flux_changed.connect(_on_flux_changed)
	EventBus.stats_updated.connect(_on_stats_updated)
	EventBus.depth_changed.connect(_on_depth_or_cores_changed.unbind(1))
	EventBus.rift_cores_changed.connect(_on_depth_or_cores_changed.unbind(1))
	EventBus.echoes_changed.connect(_on_echoes_changed)

	_on_essence_changed(GameState.essence)
	_on_flux_changed(GameState.flux)
	_on_depth_or_cores_changed()
	_on_echoes_changed(PrestigeManager.echoes)

	print("[Rift Tap] M4 running. Economy tick = %s s." % Balance.ECON_TICK)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 24)
	panel.add_theme_constant_override("separation", 8)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "RIFT TAP — M4"
	panel.add_child(title)

	_essence_label = Label.new()
	panel.add_child(_essence_label)

	_flux_label = Label.new()
	panel.add_child(_flux_label)

	_depth_label = Label.new()
	panel.add_child(_depth_label)

	_echoes_label = Label.new()
	panel.add_child(_echoes_label)

	_rate_label = Label.new()
	_rate_label.text = "emit/s: -   captured/s: -   lost to Rift/s: -   in-flight: -"
	panel.add_child(_rate_label)

	var tap := Button.new()
	tap.text = "Tap Portal (extract)"
	tap.pressed.connect(func() -> void: Economy.manual_extract())
	panel.add_child(tap)

	var collect := Button.new()
	collect.text = "Collect Essence"
	collect.pressed.connect(func() -> void: Economy.manual_collect())
	panel.add_child(collect)

	# M2 shop, under the bootstrap controls.
	var menu := BuildMenuScene.instantiate()
	panel.add_child(menu)

	# M2 placement board, clear of the HUD/shop panel on the left.
	var board := BoardScene.instantiate()
	board.position = Vector2(560, 24)
	layer.add_child(board)

	# M3 surge banner, below the board.
	var banner := SurgeBannerScene.instantiate()
	banner.position = Vector2(560, 360)
	layer.add_child(banner)

	# M4 prestige screen (hidden overlay) + a HUD toggle to open it.
	_prestige_screen = PrestigeScreenScene.instantiate()
	_prestige_screen.position = Vector2(180, 90)
	_prestige_screen.hide()
	layer.add_child(_prestige_screen)

	var prestige_toggle := Button.new()
	prestige_toggle.text = "Prestige ▸"
	prestige_toggle.pressed.connect(func() -> void: _prestige_screen.visible = not _prestige_screen.visible)
	panel.add_child(prestige_toggle)

func _on_essence_changed(value: float) -> void:
	_essence_label.text = "Essence: %s" % NumberFormat.format(value)

func _on_flux_changed(value: float) -> void:
	_flux_label.text = "Flux: %s" % NumberFormat.format(value)

func _on_depth_or_cores_changed() -> void:
	_depth_label.text = "Depth: %d    Rift Cores: %d" % [GameState.depth, GameState.rift_cores]

func _on_echoes_changed(value: float) -> void:
	_echoes_label.text = "Echoes: %s" % NumberFormat.format(value)

func _on_stats_updated(stats: Dictionary) -> void:
	_rate_label.text = "emit/s: %s   captured/s: %s   lost to Rift/s: %s   in-flight: %s" % [
		NumberFormat.format(stats["emit_per_sec"]),
		NumberFormat.format(stats["captured_per_sec"]),
		NumberFormat.format(stats["lost_per_sec"]),
		NumberFormat.format(stats["inflight_total"]),
	]
