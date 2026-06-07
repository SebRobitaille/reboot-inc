extends Node
## Owns the meta layer (GDD §7): persistent Echoes + purchased tree nodes, the
## Collapse action, modifier aggregation/application, the auto-clicker, and the
## "prestige now" plateau signal. Echoes persist across collapses (in-memory for
## M4; disk save arrives in M5). Reads/writes run state only through GameState.

const PRESTIGE_DIR := "res://data/prestige/"

# Persistent across collapses.
var echoes: float = 0.0
var _owned: Dictionary = {}             # StringName -> true

var catalog: Array[PrestigeNode] = []   # every node, loaded from PRESTIGE_DIR

# Auto-clicker + plateau tracking.
var _autoclick: float = 0.0             # summed AUTOCLICK magnitude (0 = off)
var _echo_mult: float = 1.0             # summed ECHO_MULT (applied at collapse)
var _click_accum: float = 0.0
var _plateau_accum: float = 0.0
var _last_collapse_value: float = 0.0

func _ready() -> void:
	_load_catalog()
	apply_modifiers()                   # neutral at first launch (no nodes owned)

func _process(delta: float) -> void:
	_tick_autoclick(delta)
	_tick_plateau(delta)

# --- Collapse ---

func echoes_on_collapse() -> float:
	return floor(Balance.echoes_gained(GameState.depth, GameState.rift_cores) * _echo_mult)

func can_collapse() -> bool:
	return echoes_on_collapse() > 0.0

## Bank Echoes from the current run, then reset into a fresh run with modifiers applied.
func collapse() -> void:
	if not can_collapse():
		return
	var gained := echoes_on_collapse()
	echoes += gained
	EventBus.echoes_changed.emit(echoes)
	EventBus.prestige_completed.emit(gained)
	_start_new_run()

func _start_new_run() -> void:
	apply_modifiers()                   # refresh GameState.prestige_* factors first
	GameState.reset_run_state()         # then reset, seeding start essence / pre-places

# --- Buying nodes ---

func is_owned(id: StringName) -> bool:
	return _owned.has(id)

func is_available(node: PrestigeNode) -> bool:
	if is_owned(node.id):
		return false
	return node.prereq == &"" or _owned.has(node.prereq)

func can_buy(node: PrestigeNode) -> bool:
	return is_available(node) and echoes >= node.cost

func buy_node(node: PrestigeNode) -> bool:
	if not can_buy(node):
		return false
	echoes -= node.cost
	_owned[node.id] = true
	EventBus.echoes_changed.emit(echoes)
	apply_modifiers()                   # take effect immediately on the live run
	EventBus.prestige_node_purchased.emit(node)
	return true

# --- Modifier aggregation ---

## Sum each effect across owned nodes and push the results into GameState's
## persistent prestige_* factors (and our local auto-click / echo state).
func apply_modifiers() -> void:
	var sums := {}
	for node in catalog:
		if _owned.has(node.id):
			sums[node.effect] = sums.get(node.effect, 0.0) + node.magnitude

	GameState.prestige_extraction_mult = 1.0 + sums.get(PrestigeNode.Effect.EXTRACTION_MULT, 0.0)
	GameState.prestige_collection_mult = 1.0 + sums.get(PrestigeNode.Effect.COLLECTION_MULT, 0.0)
	GameState.prestige_flux_mult = 1.0 + sums.get(PrestigeNode.Effect.FLUX_MULT, 0.0)
	GameState.prestige_drift_mult = maxf(1.0 - sums.get(PrestigeNode.Effect.DRIFT_REDUCTION, 0.0), 0.0)
	GameState.prestige_start_essence = sums.get(PrestigeNode.Effect.START_ESSENCE, 0.0)
	GameState.prestige_core_bonus = int(sums.get(PrestigeNode.Effect.CORE_GAIN, 0.0))
	GameState.prestige_preplace = int(sums.get(PrestigeNode.Effect.PREPLACE_STARTER, 0.0))

	_autoclick = sums.get(PrestigeNode.Effect.AUTOCLICK, 0.0)
	_echo_mult = 1.0 + sums.get(PrestigeNode.Effect.ECHO_MULT, 0.0)

# --- Auto-clicker (Resonance auto-bootstrap) ---

func _tick_autoclick(delta: float) -> void:
	if _autoclick <= 0.0:
		return
	_click_accum += delta
	var interval := Balance.AUTOCLICK_INTERVAL / _autoclick
	while _click_accum >= interval:
		_click_accum -= interval
		Economy.manual_extract()
		Economy.manual_collect()

# --- "Prestige now" plateau signal ---

func _tick_plateau(delta: float) -> void:
	_plateau_accum += delta
	if _plateau_accum < 1.0:
		return
	_plateau_accum = 0.0
	var value := echoes_on_collapse()
	# Glow when there's something to bank but it has stopped growing meaningfully —
	# i.e. Echoes/min has flattened, the signal to collapse.
	var grew := value > _last_collapse_value * (1.0 + Balance.PRESTIGE_PLATEAU_GROWTH)
	var glow := value > 0.0 and not grew
	_last_collapse_value = value
	EventBus.prestige_ready.emit(value, glow)

# --- Loading ---

func _load_catalog() -> void:
	catalog.clear()
	var dir := DirAccess.open(PRESTIGE_DIR)
	if dir == null:
		push_warning("PrestigeManager: cannot open %s" % PRESTIGE_DIR)
		return
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load(PRESTIGE_DIR + name)
		if res is PrestigeNode:
			catalog.append(res)
