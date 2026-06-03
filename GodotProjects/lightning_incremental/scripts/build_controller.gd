## Drives placement during the between-waves build phase: tracks the selected
## placeable, draws the grid + a valid/invalid ghost, and commits clicks
## (spend gold -> instantiate -> mark the cell solid). Active only while building.
class_name BuildController
extends Node2D

signal placed(def: PlaceableDef)

var _nav: NavGrid
var _world: Node2D
var _active: bool = false
var _selected: PlaceableDef
var _hover_cell: Vector2i = Vector2i.ZERO
var _has_hover: bool = false

func setup(nav: NavGrid, world: Node2D) -> void:
	_nav = nav
	_world = world

func set_active(active: bool) -> void:
	_active = active
	if not active:
		_selected = null
		_has_hover = false
	queue_redraw()

func set_selected(def: PlaceableDef) -> void:
	_selected = def
	queue_redraw()

func _process(_delta: float) -> void:
	if not _active or _selected == null:
		return
	var cell := _nav.world_to_cell(get_global_mouse_position())
	if not _has_hover or cell != _hover_cell:
		_hover_cell = cell
		_has_hover = true
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _selected == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place(_nav.world_to_cell(get_global_mouse_position()))

func _try_place(cell: Vector2i) -> void:
	if GoldWallet.gold < _selected.cost or not _nav.can_place(cell):
		return
	if not GoldWallet.try_spend(_selected.cost):
		return
	var node := _instantiate(_selected)
	node.position = _nav.cell_to_world(cell)
	_world.add_child(node)
	_nav.place(cell, node)
	placed.emit(_selected)
	queue_redraw()

func _instantiate(def: PlaceableDef) -> Node2D:
	if def.kind == PlaceableDef.Kind.WALL:
		var w := Wall.new()
		w.configure(def)
		return w
	var t := Tower.new()
	t.configure(def)
	return t

func _draw() -> void:
	if not _active:
		return
	var view := get_viewport_rect().size
	var line := Color(1, 1, 1, 0.06)
	var x := 0.0
	while x <= view.x:
		draw_line(Vector2(x, 0), Vector2(x, view.y), line)
		x += NavGrid.CELL
	var y := 0.0
	while y <= view.y:
		draw_line(Vector2(0, y), Vector2(view.x, y), line)
		y += NavGrid.CELL

	if _selected != null and _has_hover:
		var ok := _nav.can_place(_hover_cell) and GoldWallet.gold >= _selected.cost
		var fill := Color(0.4, 1.0, 0.4, 0.45) if ok else Color(1.0, 0.3, 0.3, 0.45)
		var origin := _nav.cell_to_world(_hover_cell) - Vector2(NavGrid.CELL, NavGrid.CELL) / 2.0
		draw_rect(Rect2(origin, Vector2(NavGrid.CELL, NavGrid.CELL)), fill)
