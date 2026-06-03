extends Node
## Autoload. The single home for tunable numbers. M2's shop mutates these through
## apply_modifier(); a fresh run restores them via reset().
##
## We work on a *duplicate* of the base CombatStats so the on-disk .tres stays
## pristine and reset() can restore it cleanly.

signal stats_changed

const OP_ADD := 0
const OP_MULT := 1

const _BASE_STATS: CombatStats = preload("res://resources/player_stats.tres")
const BASE_CORE_MAX_HEALTH := 100.0
const BASE_ENERGY_MAX := 100.0
const BASE_ENERGY_REGEN := 18.0

# Stat keys routed to the weapon resource vs. the run-level fields below.
const _WEAPON_STATS := [
	"base_damage", "max_targets", "chain_range", "chain_falloff",
	"energy_cost", "cast_cooldown", "cast_range",
]
const _RUN_STATS := ["core_max_health", "energy_max", "energy_regen"]

var stats: CombatStats
var core_max_health: float
var energy_max: float
var energy_regen: float

func _ready() -> void:
	reset()

## Restore base values. Called at startup and on each new run.
func reset() -> void:
	stats = _BASE_STATS.duplicate(true)
	core_max_health = BASE_CORE_MAX_HEALTH
	energy_max = BASE_ENERGY_MAX
	energy_regen = BASE_ENERGY_REGEN
	stats_changed.emit()

## Apply one stat change. `op` is OP_ADD or OP_MULT; the key picks the target field.
func apply_modifier(stat: String, op: int, amount: float) -> void:
	var target: Object
	if _WEAPON_STATS.has(stat):
		target = stats
	elif _RUN_STATS.has(stat):
		target = self
	else:
		push_warning("PlayerStats.apply_modifier: unknown stat '%s'" % stat)
		return
	var current := float(target.get(stat))
	var updated := current + amount if op == OP_ADD else current * amount
	if stat == "max_targets":
		updated = maxf(1.0, roundf(updated))
	target.set(stat, updated)
	stats_changed.emit()
