extends NavigationRegion2D

signal nav_rebuilt

@export var grid_system: GridSystem

var _rebuild_gen: int = 0

func _ready() -> void:
	if grid_system != null:
		grid_system.grid_changed.connect(_rebuild)
	call_deferred("_rebuild")

func _rebuild() -> void:
	_rebuild_gen += 1
	var gen := _rebuild_gen

	var cs := float(GridSystem.CELL_SIZE)
	var ox := GridSystem.ARENA_ORIGIN.x
	var oy := GridSystem.ARENA_ORIGIN.y
	var ow := float(GridSystem.GRID_WIDTH) * cs
	var oh := float(GridSystem.GRID_HEIGHT) * cs

	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(PackedVector2Array([
		Vector2(ox, oy),
		Vector2(ox + ow, oy),
		Vector2(ox + ow, oy + oh),
		Vector2(ox, oy + oh),
	]))

	for y in GridSystem.GRID_HEIGHT:
		for x in GridSystem.GRID_WIDTH:
			if grid_system.is_walkable(Vector2i(x, y)):
				continue
			var tl := GridSystem.ARENA_ORIGIN + Vector2(x * cs, y * cs)
			source.add_obstruction_outline(PackedVector2Array([
				tl,
				tl + Vector2(cs, 0.0),
				tl + Vector2(cs, cs),
				tl + Vector2(0.0, cs),
			]))

	var poly := NavigationPolygon.new()
	poly.agent_radius = 14.0
	# bake_from_source_geometry_data is async — apply results only inside the callback
	NavigationServer2D.bake_from_source_geometry_data(poly, source,
		Callable(self, "_on_bake_done").bind(poly, gen))

func _on_bake_done(poly: NavigationPolygon, gen: int) -> void:
	# Callback may arrive on a background thread — defer back to main thread
	call_deferred("_apply_poly", poly, gen)

func _apply_poly(poly: NavigationPolygon, gen: int) -> void:
	if gen != _rebuild_gen:
		return  # A newer rebuild superseded this one
	navigation_polygon = poly
	NavigationServer2D.map_force_update(get_world_2d().get_navigation_map())
	nav_rebuilt.emit()
