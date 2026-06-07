extends VBoxContainer
## Shop. Lists every BuildingData in the catalog as a buy button; clicking one arms
## it for placement (the Board listens via EventBus). Live cost + affordability.

const AFFORD_COLOR := Color.WHITE
const UNAFFORD_COLOR := Color(1.0, 0.55, 0.55)

var _rows: Array[Dictionary] = []   # [{ data, button }]

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_build()
	EventBus.essence_changed.connect(_on_balance_changed)
	EventBus.flux_changed.connect(_on_balance_changed)
	EventBus.building_placed.connect(_on_placed)
	EventBus.run_reset.connect(_refresh)   # owned counts reset -> costs back to base
	_refresh()

func _build() -> void:
	var title := Label.new()
	title.text = "BUILD  (select, then click a board slot)"
	add_child(title)
	for data in GameState.catalog:
		var b := Button.new()
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = data.description
		b.pressed.connect(_on_select.bind(data, b))
		add_child(b)
		_rows.append({ "data": data, "button": b })

func _on_select(data: BuildingData, button: Button) -> void:
	# Radio behavior: only one armed at a time.
	for r in _rows:
		r["button"].button_pressed = (r["button"] == button)
	EventBus.build_selection_changed.emit(data)

func _on_balance_changed(_value: float) -> void:
	_refresh()

func _on_placed(_data: BuildingData, _ring: int, _slot: int) -> void:
	# Cost of that type just rose; refresh all labels.
	_refresh()

func _refresh() -> void:
	for r in _rows:
		var data: BuildingData = r["data"]
		var b: Button = r["button"]
		var cost := GameState.current_cost(data)
		b.text = "%s — %s %s" % [data.display_name, NumberFormat.format(cost), _currency_label(data.buy_currency)]
		# Keep selectable even when unaffordable (arm now, save up); just signal it.
		b.add_theme_color_override("font_color", AFFORD_COLOR if GameState.can_afford(data) else UNAFFORD_COLOR)

func _currency_label(currency: BuildingData.Currency) -> String:
	match currency:
		BuildingData.Currency.ESSENCE: return "Essence"
		BuildingData.Currency.FLUX: return "Flux"
		BuildingData.Currency.RIFT_CORE: return "Cores"
	return "?"
