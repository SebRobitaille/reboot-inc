## One stat change applied to PlayerStats. `op` mirrors PlayerStats.OP_ADD / OP_MULT.
class_name StatModifier
extends Resource

enum Op { ADD, MULT }

@export var stat: String = ""
@export var op: Op = Op.ADD
@export var amount: float = 0.0

const _LABELS := {
	"base_damage": "Damage",
	"max_targets": "Chain Targets",
	"chain_range": "Chain Range",
	"chain_falloff": "Chain Retention",
	"energy_cost": "Energy Cost",
	"cast_cooldown": "Cast Cooldown",
	"cast_range": "Cast Range",
	"core_max_health": "Core HP",
	"energy_max": "Max Energy",
	"energy_regen": "Energy Regen",
}

## Human-readable line for the card UI, e.g. "+10 Damage" or "-15% Cast Cooldown".
func describe() -> String:
	var label: String = _LABELS.get(stat, stat)
	if op == Op.ADD:
		var prefix := "+" if amount >= 0.0 else ""
		return "%s%s %s" % [prefix, _fmt(amount), label]
	var pct := roundi((amount - 1.0) * 100.0)
	var prefix2 := "+" if pct >= 0 else ""
	return "%s%d%% %s" % [prefix2, pct, label]

func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(value))
	return str(value)
