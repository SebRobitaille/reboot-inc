extends Node
## Persistence (M5): serializes run + meta state to user://save.json. Autosaves on a
## timer and on key events, saves on quit, and loads on launch. NO offline rewards —
## state restores exactly as left; time away grants nothing. Each owning system
## provides its own to_dict/from_dict, so SaveManager stays a thin orchestrator.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Set false by the balance harness so its throwaway state never overwrites a save.
var enabled: bool = true
var _autosave_accum: float = 0.0

func _ready() -> void:
	# Save on the moments that matter, beyond the periodic autosave.
	EventBus.building_placed.connect(_on_event.unbind(3))
	EventBus.surge_resolved.connect(_on_event.unbind(1))
	EventBus.prestige_completed.connect(_on_event.unbind(1))
	EventBus.prestige_node_purchased.connect(_on_event.unbind(1))

func _process(delta: float) -> void:
	_autosave_accum += delta
	if _autosave_accum >= Balance.AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_game()

func _on_event() -> void:
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	if not enabled:
		return
	var data := {
		"version": SAVE_VERSION,
		"saved_unix": Time.get_unix_time_from_system(),
		"game": GameState.to_dict(),
		"prestige": PrestigeManager.to_dict(),
		"inflight": Economy.inflight_to_array(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

## Returns true if a save was loaded. Restores meta first (so prestige factors are
## set before run state is rebuilt), then run state, then in-flight essence.
func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: corrupt save, ignoring.")
		return false
	PrestigeManager.from_dict(parsed.get("prestige", {}))
	GameState.from_dict(parsed.get("game", {}))
	Economy.inflight_from_array(parsed.get("inflight", []))
	EventBus.game_loaded.emit()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
