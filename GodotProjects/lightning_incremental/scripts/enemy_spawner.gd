## Spawns wave groups at screen edges, then waits for the battlefield to clear and
## emits wave_cleared. It does NOT auto-advance: the run (main) opens the shop and
## calls continue_to_next_wave() when the player is done. Endless after the last wave.
class_name EnemySpawner
extends Node2D

signal wave_started(number: int)
signal wave_cleared(number: int)

const EnemyScene := preload("res://scenes/enemy.tscn")
const DEFAULT_WAVES := [
	preload("res://resources/wave_1.tres"),
	preload("res://resources/wave_2.tres"),
	preload("res://resources/wave_3.tres"),
]

@export var waves: Array[WaveDef] = []
@export var endless_count_scale: float = 1.25

var _core_position: Vector2 = Vector2.ZERO
var _nav: NavGrid
var _wave_index: int = 0
var _running: bool = false

func _ready() -> void:
	if waves.is_empty():
		waves.assign(DEFAULT_WAVES)

func set_core_position(p: Vector2) -> void:
	_core_position = p

func set_nav(nav: NavGrid) -> void:
	_nav = nav

func start() -> void:
	if _running:
		return
	_running = true
	_run_wave()

func stop() -> void:
	_running = false

## Called by the run after the shop closes.
func continue_to_next_wave() -> void:
	if not _running:
		return
	_wave_index += 1
	_run_wave()

func _run_wave() -> void:
	var wave := _wave_for(_wave_index)
	var multiplier := 1.0
	if _wave_index >= waves.size():
		multiplier = pow(endless_count_scale, _wave_index - waves.size() + 1)
	wave_started.emit(_wave_index + 1)
	await _spawn_wave(wave, multiplier)
	await _wait_until_cleared()
	if not _running:
		return
	wave_cleared.emit(_wave_index + 1)

func _wait_until_cleared() -> void:
	while _running:
		await get_tree().process_frame
		if get_tree().get_nodes_in_group("enemies").is_empty():
			return

func _wave_for(index: int) -> WaveDef:
	if waves.is_empty():
		return null
	return waves[min(index, waves.size() - 1)]

func _spawn_wave(wave: WaveDef, multiplier: float) -> void:
	if wave == null:
		return
	for i in range(wave.defs.size()):
		var def := wave.defs[i] as EnemyDef
		var count := int(round(int(wave.counts[i]) * multiplier))
		var interval := float(wave.intervals[i])
		for n in range(count):
			if not _running:
				return
			_spawn_one(def)
			if interval > 0.0:
				await get_tree().create_timer(interval).timeout

func _spawn_one(def: EnemyDef) -> void:
	if def == null:
		return
	var enemy := EnemyScene.instantiate() as Enemy
	enemy.global_position = _edge_spawn_point()
	enemy.configure(def, _core_position, _nav)
	add_child(enemy)

func _edge_spawn_point() -> Vector2:
	var view := get_viewport_rect().size
	var margin := 40.0
	match randi() % 4:
		0: return Vector2(randf_range(0.0, view.x), -margin)
		1: return Vector2(view.x + margin, randf_range(0.0, view.y))
		2: return Vector2(randf_range(0.0, view.x), view.y + margin)
		_: return Vector2(-margin, randf_range(0.0, view.y))
