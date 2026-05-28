extends Node2D

@onready var _base: Base = $Base
@onready var _enemies: Node2D = $Enemies
@onready var _spawner: EnemySpawner = $EnemySpawner
@onready var _wave_manager: WaveManager = $WaveManager
@onready var _nav_baker: NavigationRegion2D = $NavigationRegion2D
@onready var _grid: GridSystem = $GridSystem

func _ready() -> void:
	_spawner.spawn_cells = _grid.get_spawn_cells()
	_spawner.setup(_base, _enemies)
	_base.base_destroyed.connect(_on_base_destroyed)
	_nav_baker.nav_rebuilt.connect(_on_nav_rebuilt)

func _on_base_destroyed() -> void:
	_wave_manager.trigger_defeat()

func _on_nav_rebuilt() -> void:
	for enemy: Node in _enemies.get_children():
		if enemy.has_method("refresh_path"):
			enemy.refresh_path()
