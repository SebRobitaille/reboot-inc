## Builds the run: background, nav grid, core, spawner, HUD, build controller, and
## the between-waves build+shop phase. The build phase does NOT pause the tree (so
## AStar paths/validation stay live and there are no enemies to freeze anyway);
## core firing is suppressed instead. Core death still pauses for the restart prompt.
extends Node2D

const CoreScene := preload("res://scenes/core.tscn")
const HUDScene := preload("res://scenes/hud.tscn")
const SpawnerScene := preload("res://scenes/enemy_spawner.tscn")

var _nav: NavGrid
var _core: Core
var _spawner: EnemySpawner
var _hud: HUD
var _shop: ShopManager
var _shop_ui: ShopUI
var _build: BuildController
var _game_over: bool = false

func _ready() -> void:
	_reset_globals()

	var center := get_viewport_rect().size * 0.5

	_nav = NavGrid.new()
	add_child(_nav)
	_nav.set_core_cell(center)

	_core = CoreScene.instantiate()
	_core.position = center
	add_child(_core)

	_spawner = SpawnerScene.instantiate()
	add_child(_spawner)
	_spawner.set_core_position(center)
	_spawner.set_nav(_nav)

	_build = BuildController.new()
	add_child(_build)
	_build.setup(_nav, self)

	_hud = HUDScene.instantiate()
	add_child(_hud)
	_hud.bind_core(_core)
	_hud.bind_spawner(_spawner)

	_shop = ShopManager.new()
	add_child(_shop)

	_shop_ui = ShopUI.new()
	add_child(_shop_ui)
	_shop_ui.bind(_shop)
	_shop_ui.placeable_selected.connect(_build.set_selected)
	_shop_ui.continue_pressed.connect(_on_build_done)

	_core.core_destroyed.connect(_on_core_destroyed)
	_spawner.wave_cleared.connect(_on_wave_cleared)
	_spawner.start()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.07, 0.08, 0.12))

func _reset_globals() -> void:
	PlayerStats.reset()  # before EnergyPool.reset so it sees base energy_max
	EnergyPool.reset()
	GoldWallet.reset()

func _on_wave_cleared(_number: int) -> void:
	if _game_over:
		return
	_core.building = true
	_build.set_active(true)
	_shop.open()
	_shop_ui.show_shop()

func _on_build_done() -> void:
	_shop_ui.hide_shop()
	_build.set_active(false)
	_core.building = false
	_spawner.continue_to_next_wave()

func _on_core_destroyed() -> void:
	_game_over = true
	_spawner.stop()
	get_tree().paused = true
