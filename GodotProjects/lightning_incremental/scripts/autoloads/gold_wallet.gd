extends Node
## Autoload. Run currency. Enemies pay in on death; M2's shop will spend via
## try_spend().

signal gold_changed(amount: int)

var gold: int = 0

func add(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func try_spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func reset() -> void:
	gold = 0
	gold_changed.emit(gold)
