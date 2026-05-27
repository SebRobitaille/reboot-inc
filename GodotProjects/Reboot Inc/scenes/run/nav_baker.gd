extends NavigationRegion2D

@export var grid_system: GridSystem

func _ready() -> void:
	if grid_system != null:
		grid_system.grid_changed.connect(_rebuild)
	call_deferred("_rebuild")

func _rebuild() -> void:
	var origin := GridSystem.ARENA_ORIGIN
	var arena_size := Vector2(
		GridSystem.GRID_WIDTH * GridSystem.CELL_SIZE,
		GridSystem.GRID_HEIGHT * GridSystem.CELL_SIZE
	)

	# Start with the full arena as walkable
	var walkable: Array = [PackedVector2Array([
		origin,
		origin + Vector2(arena_size.x, 0),
		origin + arena_size,
		origin + Vector2(0, arena_size.y),
	])]

	# Subtract each occupied cell using polygon clipping
	var half := GridSystem.CELL_SIZE / 2.0 + 1.0
	var holes_carved := 0
	for x in GridSystem.GRID_WIDTH:
		for y in GridSystem.GRID_HEIGHT:
			var cell := Vector2i(x, y)
			var state := grid_system.get_cell(cell)
			if state == GridSystem.CellState.TOWER or state == GridSystem.CellState.WALL:
				var center := grid_system.cell_to_world(cell)
				var hole := PackedVector2Array([
					center + Vector2(-half, -half),
					center + Vector2( half, -half),
					center + Vector2( half,  half),
					center + Vector2(-half,  half),
				])
				var next: Array = []
				for region: PackedVector2Array in walkable:
					next.append_array(Geometry2D.clip_polygons(region, hole))
				walkable = next
				holes_carved += 1

	# Build NavigationPolygon directly from clipped regions — no baking needed
	var poly := NavigationPolygon.new()
	var all_verts := PackedVector2Array()
	for region: PackedVector2Array in walkable:
		var start := all_verts.size()
		all_verts.append_array(region)
		var indices := PackedInt32Array()
		for i in region.size():
			indices.append(start + i)
		poly.add_polygon(indices)
	poly.vertices = all_verts
	navigation_polygon = poly
	print("[nav] rebuilt: %d holes carved, %d walkable regions" % [holes_carved, walkable.size()])
