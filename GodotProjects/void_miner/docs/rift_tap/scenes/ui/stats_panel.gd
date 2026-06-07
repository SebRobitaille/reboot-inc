extends PanelContainer
## Stats & legibility panel (GDD §8): global throughput rates plus a per-ring
## emission / capacity / captured / lost breakdown so the player can see exactly
## where essence is bleeding to the Rift. Toggle overlay; updates on stats_updated.

const LOST_HIGHLIGHT := 0.01            # lost/s above this marks a ring as bleeding
const BLEED_COLOR := Color(1.0, 0.55, 0.55)
const OK_COLOR := Color(0.6, 0.9, 0.6)

var _global: Label
var _rows: Array = []                   # per ring: { emit, cap, captured, lost }
var _hint: Label

func _ready() -> void:
	_build()
	EventBus.stats_updated.connect(_on_stats)

func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var title := Label.new()
	title.text = "STATS"
	header.add_child(title)
	var close := Button.new()
	close.text = "Close ✕"
	close.pressed.connect(func() -> void: hide())
	header.add_child(close)

	_global = Label.new()
	root.add_child(_global)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	root.add_child(grid)
	for h in ["Ring", "Emit/s", "Cap/s", "Captured/s", "Lost/s"]:
		var hl := Label.new()
		hl.text = h
		grid.add_child(hl)
	for r in Balance.RING_COUNT:
		var ring_lbl := Label.new()
		ring_lbl.text = "R%d" % r
		grid.add_child(ring_lbl)
		var emit := Label.new(); grid.add_child(emit)
		var cap := Label.new(); grid.add_child(cap)
		var captured := Label.new(); grid.add_child(captured)
		var lost := Label.new(); grid.add_child(lost)
		_rows.append({ "emit": emit, "cap": cap, "captured": captured, "lost": lost })

	_hint = Label.new()
	root.add_child(_hint)

func _on_stats(stats: Dictionary) -> void:
	var captured_s: float = stats["captured_per_sec"]
	var flux_s := captured_s * Balance.FLUX_RATE * GameState.flux_mult()
	_global.text = "Essence in: %s/s   Captured: %s/s   Lost to Rift: %s/s   Flux: %s/s   In-flight: %s\nDepth: %d   Rift Cores: %d   Echoes: %s" % [
		NumberFormat.format(stats["emit_per_sec"]),
		NumberFormat.format(captured_s),
		NumberFormat.format(stats["lost_per_sec"]),
		NumberFormat.format(flux_s),
		NumberFormat.format(stats["inflight_total"]),
		GameState.depth, GameState.rift_cores, NumberFormat.format(PrestigeManager.echoes),
	]

	var emission := GameState.emission_by_ring()
	var capacity := GameState.collection_by_ring()
	var captured_ring: PackedFloat64Array = stats["captured_by_ring"]
	var lost_ring: PackedFloat64Array = stats["lost_by_ring"]
	var worst_ring := -1
	var worst_lost := 0.0
	for r in Balance.RING_COUNT:
		var row: Dictionary = _rows[r]
		row["emit"].text = NumberFormat.format(emission[r])
		row["cap"].text = NumberFormat.format(capacity[r])
		row["captured"].text = NumberFormat.format(captured_ring[r])
		row["lost"].text = NumberFormat.format(lost_ring[r])
		var bleeding := lost_ring[r] > LOST_HIGHLIGHT
		row["lost"].modulate = BLEED_COLOR if bleeding else Color.WHITE
		if lost_ring[r] > worst_lost:
			worst_lost = lost_ring[r]
			worst_ring = r

	if worst_ring >= 0 and worst_lost > LOST_HIGHLIGHT:
		_hint.text = "⚠ Bleeding ~%s/s to the Rift around ring %d — add collectors there or upstream." % [
			NumberFormat.format(worst_lost), worst_ring]
		_hint.modulate = BLEED_COLOR
	else:
		_hint.text = "✓ Flow balanced — little lost to the Rift."
		_hint.modulate = OK_COLOR
