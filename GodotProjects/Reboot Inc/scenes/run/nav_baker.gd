extends NavigationRegion2D

@export var grid_system: GridSystem

func _ready() -> void:
	if grid_system != null:
		grid_system.grid_changed.connect(_rebuild)
	call_deferred("_rebuild")

func _rebuild() -> void:
	var poly := NavigationPolygon.new()
	poly.agent_radius = 14.0

	# Outer walkable boundary
	var origin := GridSystem.ARENA_ORIGIN
	var arena_size := Vector2(
		GridSystem.GRID_WIDTH * GridSystem.CELL_SIZE,
		GridSystem.GRID_HEIGHT * GridSystem.CELL_SIZE
	)
	poly.add_outline(PackedVector2Array([
		origin,
		origin + Vector2(arena_size.x, 0),
		origin + arena_size,
		origin + Vector2(0, arena_size.y),
	]))

	# Carve a hole for every occupied cell
	var half := GridSystem.CELL_SIZE / 2.0 + 1.0
	var holes_carved := 0
	for x in GridSystem.GRID_WIDTH:
		for y in GridSystem.GRID_HEIGHT:
			var cell := Vector2i(x, y)
			var state := grid_system.get_cell(cell)
			if state == GridSystem.CellState.TOWER or state == GridSystem.CellState.WALL:
				var center := grid_system.cell_to_world(cell)
				poly.add_outline(PackedVector2Array([
					center + Vector2(-half, -half),
					center + Vector2( half, -half),
					center + Vector2( half,  half),
					center + Vector2(-half,  half),
				]))
				holes_carved += 1

	poly.make_polygons_from_outlines()
	navigation_polygon = poly
	bake_navigation_polygon()
	print("[nav] rebuilt with %d carved cells" % holes_carved)
