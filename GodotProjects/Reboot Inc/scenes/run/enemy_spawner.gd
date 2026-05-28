class_name EnemySpawner
extends Node

signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, was_killed: bool)
signal spawning_complete

@export var grid_system: GridSystem   # keep this — spawner needs grid for perimeter

var spawn_cells: Array[Vector2i] = []
var _base: Base = null
var _enemy_container: Node = null
var _current_wave: WaveData = null
var _spawned: int = 0
var _spawn_timer: float = 0.0
var _is_active: bool = false

func setup(base: Base, container: Node) -> void:
	_base = base
	_enemy_container = container

func run_wave(wave: WaveData) -> void:
	_current_wave = wave
	_spawned = 0
	_spawn_timer = 0.0
	_is_active = true

func stop_wave() -> void:
	_is_active = false
	_current_wave = null

func _process(delta: float) -> void:
	if not _is_active or _current_wave == null:
		return
	if _spawned >= _current_wave.enemy_count:
		_is_active = false
		spawning_complete.emit()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_enemy()
		_spawned += 1
		_spawn_timer = _current_wave.spawn_interval

func _spawn_enemy() -> void:
	if _current_wave.enemy_scene == null or not is_instance_valid(_base):
		return
	var enemy: Enemy = _current_wave.enemy_scene.instantiate()
	_enemy_container.add_child(enemy)
	enemy.global_position = _get_perimeter_spawn()
	enemy.setup(_base)
	enemy.died.connect(_on_enemy_died)
	enemy_spawned.emit(enemy)

func _on_enemy_died(enemy: Enemy, was_killed: bool) -> void:
	enemy_died.emit(enemy, was_killed)

func _get_perimeter_spawn() -> Vector2:
	if grid_system == null:
		return Vector2(640, 360)
	if not spawn_cells.is_empty():
		var cell := spawn_cells[randi() % spawn_cells.size()]
		return grid_system.cell_to_world(cell)
	var side: int = randi() % 4
	var cell := Vector2i.ZERO
	match side:
		0: cell = Vector2i(randi() % GridSystem.GRID_WIDTH, 0)
		1: cell = Vector2i(GridSystem.GRID_WIDTH - 1, randi() % GridSystem.GRID_HEIGHT)
		2: cell = Vector2i(randi() % GridSystem.GRID_WIDTH, GridSystem.GRID_HEIGHT - 1)
		3: cell = Vector2i(0, randi() % GridSystem.GRID_HEIGHT)
	return grid_system.cell_to_world(cell)
