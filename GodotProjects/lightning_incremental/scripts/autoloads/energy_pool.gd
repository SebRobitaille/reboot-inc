extends Node
## Autoload. Regenerating energy that gates casting. Shared by the core now and by
## M3 towers later via try_spend(). Max/regen are read live from PlayerStats, so
## shop upgrades take effect immediately.

signal energy_changed(current: float, maximum: float)

var current: float = 0.0

func _ready() -> void:
	current = PlayerStats.energy_max
	PlayerStats.stats_changed.connect(_on_stats_changed)
	energy_changed.emit(current, PlayerStats.energy_max)

func _process(delta: float) -> void:
	var maximum: float = PlayerStats.energy_max
	if current < maximum:
		current = minf(maximum, current + PlayerStats.energy_regen * delta)
		energy_changed.emit(current, maximum)

func try_spend(amount: float) -> bool:
	if current < amount:
		return false
	current -= amount
	energy_changed.emit(current, PlayerStats.energy_max)
	return true

func reset() -> void:
	current = PlayerStats.energy_max
	energy_changed.emit(current, PlayerStats.energy_max)

func _on_stats_changed() -> void:
	# Reflect a new max at once (e.g. buying capacity while the shop is paused).
	current = minf(current, PlayerStats.energy_max)
	energy_changed.emit(current, PlayerStats.energy_max)
