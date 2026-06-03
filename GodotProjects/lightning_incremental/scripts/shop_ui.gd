## Between-waves build+shop panel (built in code). Anchored to the bottom so the
## playfield stays visible/clickable for placement. Hosts the upgrade cards, a
## placeables palette (emits placeable_selected), reroll, and continue.
class_name ShopUI
extends CanvasLayer

signal continue_pressed
signal placeable_selected(def: PlaceableDef)

const PLACEABLES := [
	preload("res://resources/placeables/lightning_tower.tres"),
	preload("res://resources/placeables/railgun.tres"),
	preload("res://resources/placeables/wall.tres"),
]

var _manager: ShopManager
var _header: Label
var _card_row: HBoxContainer
var _palette: HBoxContainer
var _reroll_button: Button

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	GoldWallet.gold_changed.connect(_on_gold_changed)

func bind(manager: ShopManager) -> void:
	_manager = manager
	manager.offer_changed.connect(_on_offer_changed)
	manager.purchased.connect(_on_purchased)

func show_shop() -> void:
	visible = true
	_refresh()

func hide_shop() -> void:
	# Clear any palette selection so the ghost doesn't linger into the next wave.
	for b in _palette.get_children():
		(b as Button).button_pressed = false
	visible = false

func _build() -> void:
	# Full-width tray docked to the bottom edge: short and symmetric so it only
	# covers the bottom rows, leaving the core/build area clear.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 20)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_header)

	# Cards (left) | tools (right), side by side to keep the tray short.
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)

	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 12)
	body.add_child(_card_row)

	body.add_child(VSeparator.new())

	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	body.add_child(tools)

	tools.add_child(_caption("Build (click the field to place):"))

	_palette = HBoxContainer.new()
	_palette.alignment = BoxContainer.ALIGNMENT_CENTER
	_palette.add_theme_constant_override("separation", 8)
	tools.add_child(_palette)
	var group := ButtonGroup.new()
	for def in PLACEABLES:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = "%s (%dg)" % [def.title, def.cost]
		b.set_meta("cost", def.cost)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				placeable_selected.emit(def))
		_palette.add_child(b)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	tools.add_child(buttons)

	_reroll_button = Button.new()
	_reroll_button.pressed.connect(_on_reroll_pressed)
	buttons.add_child(_reroll_button)

	var cont := Button.new()
	cont.text = "Start Wave ▶"
	cont.pressed.connect(func() -> void: continue_pressed.emit())
	buttons.add_child(cont)

func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _on_offer_changed(_cards: Array) -> void:
	if visible:
		_refresh()

func _on_purchased(_card: ShopCard) -> void:
	_refresh()

func _on_gold_changed(_amount: int) -> void:
	if visible:
		_refresh()

func _on_reroll_pressed() -> void:
	_manager.reroll()

func _refresh() -> void:
	if _manager == null:
		return
	_header.text = "BUILD PHASE — Gold: %d" % GoldWallet.gold
	_reroll_button.text = "Reroll (%dg)" % _manager.get_reroll_cost()
	_reroll_button.disabled = GoldWallet.gold < _manager.get_reroll_cost()
	for b in _palette.get_children():
		(b as Button).disabled = GoldWallet.gold < int(b.get_meta("cost"))
	_rebuild_cards()

func _rebuild_cards() -> void:
	for child in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()
	for card in _manager.get_offer():
		_card_row.add_child(_make_card(card))

func _make_card(card: ShopCard) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(180, 0)
	box.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = card.title
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var desc := Label.new()
	desc.text = card.get_description()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(180, 56)
	box.add_child(desc)

	var buy := Button.new()
	if _manager.is_sold(card):
		buy.text = "Sold"
		buy.disabled = true
	else:
		buy.text = "Buy (%dg)" % card.cost
		buy.disabled = not _manager.can_afford(card)
		buy.pressed.connect(func() -> void: _manager.purchase(card))
	box.add_child(buy)
	return box
