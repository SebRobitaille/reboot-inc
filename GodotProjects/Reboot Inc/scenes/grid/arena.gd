class_name Arena
extends Node2D

const BG_COLOR: Color = Color(0.06, 0.06, 0.09)
const BORDER_COLOR: Color = Color(0.25, 0.3, 0.4)
const BORDER_WIDTH: float = 3.0
const FIXED_WALL_FILL: Color = Color(0.12, 0.15, 0.22)
const FIXED_WALL_EDGE: Color = Color(0.35, 0.45, 0.65)

@export var grid_system: GridSystem

func _ready() -> void:
	if grid_system == null:
		grid_system = get_parent().get_node_or_null("GridSystem") as GridSystem
	if grid_system != null:
		grid_system.grid_changed.connect(queue_redraw)

func _draw() -> void:
	var size := Vector2(
		GridSystem.GRID_WIDTH * GridSystem.CELL_SIZE,
		GridSystem.GRID_HEIGHT * GridSystem.CELL_SIZE
	)
	var rect := Rect2(GridSystem.ARENA_ORIGIN, size)
	draw_rect(rect, BG_COLOR)
	draw_rect(rect, BORDER_COLOR, false, BORDER_WIDTH)

	if grid_system == null:
		return
	var cs := float(GridSystem.CELL_SIZE)
	for y in GridSystem.GRID_HEIGHT:
		for x in GridSystem.GRID_WIDTH:
			if grid_system.get_cell(Vector2i(x, y)) == GridSystem.CellState.FIXED_WALL:
				var tl := GridSystem.ARENA_ORIGIN + Vector2(x * cs, y * cs)
				var wall_rect := Rect2(tl, Vector2(cs, cs))
				draw_rect(wall_rect, FIXED_WALL_FILL)
				draw_rect(wall_rect, FIXED_WALL_EDGE, false, 2.0)
