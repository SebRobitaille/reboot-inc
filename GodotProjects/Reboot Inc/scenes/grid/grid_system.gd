class_name GridSystem
extends Node

signal grid_changed

enum CellState { EMPTY, BASE, TOWER, WALL, SPAWN, FIXED_WALL }

const CELL_SIZE: int = 48
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 14
const ARENA_ORIGIN: Vector2 = Vector2(160, 24)

# 2×2 base centered on (640, 360)
const BASE_CELLS: Array[Vector2i] = [
	Vector2i(9, 6), Vector2i(10, 6),
	Vector2i(9, 7), Vector2i(10, 7),
]
const BASE_GOAL_CELL: Vector2i = Vector2i(10, 7)

@export var map_data: MapData

var _cells: Array = []

func _ready() -> void:
	_init_grid()
	if map_data != null:
		for cell in map_data.fixed_walls:
			if is_in_bounds(cell):
				_cells[cell.x][cell.y] = CellState.FIXED_WALL
	for cell in BASE_CELLS:
		_cells[cell.x][cell.y] = CellState.BASE

func _init_grid() -> void:
	_cells.clear()
	for x in GRID_WIDTH:
		var col: Array[int] = []
		for y in GRID_HEIGHT:
			col.append(CellState.EMPTY)
		_cells.append(col)

func get_cell(cell: Vector2i) -> CellState:
	if not is_in_bounds(cell):
		return CellState.WALL
	return _cells[cell.x][cell.y]

func set_cell(cell: Vector2i, state: CellState) -> void:
	if not is_in_bounds(cell):
		return
	_cells[cell.x][cell.y] = state
	grid_changed.emit()

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT

func is_walkable(cell: Vector2i) -> bool:
	var state := get_cell(cell)
	return state == CellState.EMPTY or state == CellState.BASE or state == CellState.SPAWN

func is_placeable(cell: Vector2i) -> bool:
	return get_cell(cell) == CellState.EMPTY

func get_spawn_cells() -> Array[Vector2i]:
	if map_data != null and not map_data.spawn_cells.is_empty():
		return map_data.spawn_cells
	return []

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - ARENA_ORIGIN
	return Vector2i(int(local.x / CELL_SIZE), int(local.y / CELL_SIZE))

func cell_to_world(cell: Vector2i) -> Vector2:
	return ARENA_ORIGIN + Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		cell.y * CELL_SIZE + CELL_SIZE / 2.0
	)

func get_base_goal() -> Vector2i:
	return BASE_GOAL_CELL
