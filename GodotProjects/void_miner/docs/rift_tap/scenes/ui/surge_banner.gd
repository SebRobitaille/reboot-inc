extends PanelContainer
## Surge HUD: shows the idle countdown, the warning prompt, and the live
## destabilization bar during the window, plus the Overclock button and a
## resolve toast. Polls SurgeManager for smooth countdowns (GDD §8 allows UI
## polling for display); listens to EventBus only for the discrete resolve event.

const TOAST_DURATION: float = 5.0

var _status: Label
var _bar: ProgressBar
var _detail: Label
var _overclock_btn: Button
var _toast: Label
var _toast_time: float = 0.0

func _ready() -> void:
	_build()
	EventBus.surge_resolved.connect(_on_resolved)

func _build() -> void:
	custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var title := Label.new()
	title.text = "PORTAL SURGE"
	box.add_child(title)

	_status = Label.new()
	box.add_child(_status)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.visible = false
	box.add_child(_bar)

	_detail = Label.new()
	_detail.visible = false
	box.add_child(_detail)

	_overclock_btn = Button.new()
	_overclock_btn.pressed.connect(func() -> void: SurgeManager.activate_overclock())
	box.add_child(_overclock_btn)

	_toast = Label.new()
	_toast.visible = false
	box.add_child(_toast)

func _process(delta: float) -> void:
	_update_status()
	_update_overclock()
	if _toast.visible:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.visible = false

func _update_status() -> void:
	var left := SurgeManager.phase_seconds_left()
	if SurgeManager.phase == SurgeManager.Phase.WINDOW:
		var d := SurgeManager.destabilization()
		var t := SurgeManager.threshold()
		_status.text = "SURGE ACTIVE — %s left" % _fmt_time(left)
		_bar.visible = true
		_detail.visible = true
		_bar.value = clampf(d / t, 0.0, 1.0) if t > 0.0 else 0.0
		_detail.text = "Destabilization %s / %s" % [NumberFormat.format(d), NumberFormat.format(t)]
	elif SurgeManager.phase == SurgeManager.Phase.WARNING:
		_status.text = "⚠ SURGE INCOMING in %s — re-place freely!" % _fmt_time(left)
		_bar.visible = false
		_detail.visible = false
	else:
		_status.text = "Next surge in %s" % _fmt_time(left)
		_bar.visible = false
		_detail.visible = false

func _update_overclock() -> void:
	var s := SurgeManager.overclock_state()
	if not s["unlocked"]:
		_overclock_btn.disabled = true
		_overclock_btn.text = "Overclock — locked (clear a surge)"
	elif s["active"]:
		_overclock_btn.disabled = true
		_overclock_btn.text = "Overclock ACTIVE — %ds" % int(ceil(s["time_left"]))
	elif s["on_cooldown"]:
		_overclock_btn.disabled = true
		_overclock_btn.text = "Overclock cooldown — %ds" % int(ceil(s["time_left"]))
	else:
		_overclock_btn.disabled = false
		_overclock_btn.text = "Overclock  (×%s emit+collect, %ds)" % [Balance.OVERCLOCK_MULT, int(Balance.OVERCLOCK_DURATION)]

func _on_resolved(success: bool) -> void:
	if success:
		_toast.text = "✔ SURGE CLEARED  ·  +%d Rift Core  ·  Depth %d" % [Balance.CORES_PER_CLEAR, GameState.depth]
	else:
		_toast.text = "✘ Surge faded — keep growing, it'll return."
	_toast.visible = true
	_toast_time = TOAST_DURATION

func _fmt_time(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 60:
		return "%d:%02d" % [s / 60, s % 60]
	return "%ds" % s
