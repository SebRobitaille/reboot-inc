## Grid pathfinding for enemies (AStarGrid2D) plus placement occupancy and the
## seal check. Synchronous: placing a cell and asking "can the edges still reach the
## core?" is one AStar query, so the build phase can forbid sealing instantly.
class_name NavGrid
extends Node2D

const CELL := 48

var _astar := AStarGrid2D.new()
var _cols: int = 0
var _rows: int = 0
var _core_cell: Vector2i = Vector2i.ZERO
var _occupied: Dictionary = {}  # Vector2i -> placeable Node

func _ready() -> void:
	add_to_group("nav_grid")
	# Derive from the configured resolution (always available; viewport size can be
	# uninitialised during _ready depending on run context).
	var w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	_cols = w / CELL
	_rows = h / CELL
	_astar.region = Rect2i(0, 0, _cols, _rows)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()

func set_core_cell(world: Vector2) -> void:
	_core_cell = world_to_cell(world)

func world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(world.x / CELL), 0, _cols - 1),
		clampi(int(world.y / CELL), 0, _rows - 1))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)

func is_border(cell: Vector2i) -> bool:
	return cell.x <= 0 or cell.y <= 0 or cell.x >= _cols - 1 or cell.y >= _rows - 1

## A cell is buildable if it's interior, empty, and not the core's cell.
func is_free(cell: Vector2i) -> bool:
	return not is_border(cell) and not _occupied.has(cell) and cell != _core_cell

## Can a placeable go here? Free AND it must not seal the core off from the edges.
func can_place(cell: Vector2i) -> bool:
	if not is_free(cell):
		return false
	_astar.set_point_solid(cell, true)
	var ok := _edges_can_reach_core()
	_astar.set_point_solid(cell, false)
	return ok

func place(cell: Vector2i, node: Node) -> void:
	_occupied[cell] = node
	_astar.set_point_solid(cell, true)

## World-space waypoints from one position to another (cell centres).
func path_points(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var ids := _astar.get_id_path(world_to_cell(from_world), world_to_cell(to_world))
	var pts := PackedVector2Array()
	for c in ids:
		pts.append(cell_to_world(c))
	return pts

func _edges_can_reach_core() -> bool:
	for sample in _edge_samples():
		if _astar.get_id_path(sample, _core_cell).is_empty():
			return false
	return true

func _edge_samples() -> Array:
	# Border cells are never buildable, so these are guaranteed traversable starts.
	var pts: Array = []
	for f in [0.2, 0.5, 0.8]:
		pts.append(Vector2i(int(_cols * f), 0))
		pts.append(Vector2i(int(_cols * f), _rows - 1))
		pts.append(Vector2i(0, int(_rows * f)))
		pts.append(Vector2i(_cols - 1, int(_rows * f)))
	return pts
