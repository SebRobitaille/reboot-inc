extends PanelContainer
## Prestige overlay (GDD §7): Echoes balance, the Collapse action (glows at a
## plateau), and the three upgrade trees. Toggled from the HUD. Reads PrestigeManager
## and listens to EventBus — it never touches other systems directly.

const BRANCH_NAMES := ["EXTRACTION", "COLLECTION", "RESONANCE"]
const OWNED_COLOR := Color(0.55, 0.90, 0.55)
const LOCKED_COLOR := Color(0.50, 0.50, 0.50)
const UNAFFORD_COLOR := Color(1.00, 0.60, 0.60)
const AFFORD_COLOR := Color.WHITE
const GLOW_COLOR := Color(1.00, 0.95, 0.40)

var _echoes_label: Label
var _collapse_btn: Button
var _rows: Array[Dictionary] = []   # [{ node, button }]
var _glow: bool = false

func _ready() -> void:
	_build()
	EventBus.echoes_changed.connect(_on_changed.unbind(1))
	EventBus.prestige_node_purchased.connect(_on_changed.unbind(1))
	EventBus.prestige_ready.connect(_on_prestige_ready)
	_refresh()

func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var title := Label.new()
	title.text = "PRESTIGE"
	header.add_child(title)
	_echoes_label = Label.new()
	header.add_child(_echoes_label)
	var close := Button.new()
	close.text = "Close ✕"
	close.pressed.connect(func() -> void: hide())
	header.add_child(close)

	_collapse_btn = Button.new()
	_collapse_btn.pressed.connect(func() -> void: PrestigeManager.collapse())
	root.add_child(_collapse_btn)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)
	for branch in BRANCH_NAMES.size():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.custom_minimum_size = Vector2(250, 0)
		columns.add_child(col)
		var heading := Label.new()
		heading.text = BRANCH_NAMES[branch]
		col.add_child(heading)
		# Nodes of this branch, ordered by cost so prereq chains read top-down.
		var nodes := PrestigeManager.catalog.filter(func(n: PrestigeNode) -> bool: return n.tree == branch)
		nodes.sort_custom(func(a: PrestigeNode, b: PrestigeNode) -> bool: return a.cost < b.cost)
		for node in nodes:
			var btn := Button.new()
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.tooltip_text = node.description
			btn.pressed.connect(_on_node_pressed.bind(node))
			col.add_child(btn)
			_rows.append({ "node": node, "button": btn })

func _on_node_pressed(node: PrestigeNode) -> void:
	PrestigeManager.buy_node(node)   # refresh comes via prestige_node_purchased

func _on_prestige_ready(_value: float, glow: bool) -> void:
	_glow = glow
	_refresh()

func _on_changed() -> void:
	_refresh()

func _refresh() -> void:
	_echoes_label.text = "Echoes: %s" % NumberFormat.format(PrestigeManager.echoes)

	var collapse_value := PrestigeManager.echoes_on_collapse()
	_collapse_btn.text = "⟳ COLLAPSE for %s Echoes" % NumberFormat.format(collapse_value)
	_collapse_btn.disabled = collapse_value <= 0.0
	_collapse_btn.modulate = GLOW_COLOR if (_glow and collapse_value > 0.0) else Color.WHITE

	for r in _rows:
		var node: PrestigeNode = r["node"]
		var b: Button = r["button"]
		if PrestigeManager.is_owned(node.id):
			b.text = "✓ %s" % node.display_name
			b.disabled = true
			b.modulate = OWNED_COLOR
		elif not PrestigeManager.is_available(node):
			b.text = "🔒 %s  (%s ✧)" % [node.display_name, NumberFormat.format(node.cost)]
			b.disabled = true
			b.modulate = LOCKED_COLOR
		else:
			var affordable := PrestigeManager.can_buy(node)
			b.text = "%s  (%s ✧)" % [node.display_name, NumberFormat.format(node.cost)]
			b.disabled = not affordable
			b.modulate = AFFORD_COLOR if affordable else UNAFFORD_COLOR
