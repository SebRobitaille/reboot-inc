## A purchasable upgrade. `modifiers` is an untyped Array of StatModifier (kept
## untyped so the .tres files author cleanly).
class_name ShopCard
extends Resource

@export var title: String = ""
@export_multiline var description: String = ""  # optional; auto-built from modifiers if empty
@export var cost: int = 10
@export var weight: float = 1.0                 # relative draw weight in the pool
@export var repeatable: bool = true             # if false, leaves the pool once bought this run
@export var modifiers: Array = []               # StatModifier entries

func get_description() -> String:
	if not description.is_empty():
		return description
	var lines: PackedStringArray = []
	for m in modifiers:
		lines.append((m as StatModifier).describe())
	return "\n".join(lines)
