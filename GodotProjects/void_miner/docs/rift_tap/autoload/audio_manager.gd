extends Node
## Procedural audio (M6): synthesizes short decaying-sine blips at startup — no asset
## files — and plays them on key EventBus signals. A small voice pool avoids cutting
## sounds off. Headless/dummy audio drivers make play() a harmless no-op.

const RATE := 22050
const VOICES := 6

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _sfx: Dictionary = {}

func _ready() -> void:
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# id -> (start_hz, end_hz, seconds, volume). A rising sweep reads "good", falling "bad".
	_sfx["tap"] = _blip(523.0, 523.0, 0.07, 0.30)
	_sfx["buy"] = _blip(740.0, 740.0, 0.09, 0.33)
	_sfx["surge"] = _blip(150.0, 150.0, 0.50, 0.45)
	_sfx["clear"] = _blip(523.0, 880.0, 0.30, 0.40)
	_sfx["fail"] = _blip(220.0, 120.0, 0.35, 0.40)
	_sfx["collapse"] = _blip(330.0, 160.0, 0.60, 0.45)

	EventBus.portal_tapped.connect(_play.bind("tap"))
	EventBus.building_placed.connect(_play.bind("buy").unbind(3))
	EventBus.surge_started.connect(_play.bind("surge").unbind(1))
	EventBus.surge_resolved.connect(func(ok: bool) -> void: _play("clear" if ok else "fail"))
	EventBus.prestige_completed.connect(_play.bind("collapse").unbind(1))

func _play(id: String) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sfx[id]
	p.play()

## Build a 16-bit mono blip: sine sweeping start_hz -> end_hz with a short attack and
## exponential decay so it doesn't click.
func _blip(start_hz: float, end_hz: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var attack := clampf(t / 0.004, 0.0, 1.0)
		var env := attack * exp(-t * 5.0) * vol
		var freq := lerpf(start_hz, end_hz, t / dur)
		var sample := clampf(sin(TAU * freq * t) * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
