## Owns the card pool, rolls between-waves offers, and applies purchases to
## PlayerStats / GoldWallet. UI-agnostic so any view (ShopUI) can drive it.
class_name ShopManager
extends Node

signal offer_changed(cards: Array)
signal purchased(card: ShopCard)

const CARD_POOL: Array = [
	preload("res://resources/cards/overcharge.tres"),
	preload("res://resources/cards/arc_splitter.tres"),
	preload("res://resources/cards/conductive_coil.tres"),
	preload("res://resources/cards/capacitor_bank.tres"),
	preload("res://resources/cards/rapid_discharge.tres"),
	preload("res://resources/cards/reinforced_core.tres"),
	preload("res://resources/cards/flux_regulator.tres"),
	preload("res://resources/cards/superconductor.tres"),
	preload("res://resources/cards/tesla_tuning.tres"),
]

@export var offer_size: int = 3
@export var reroll_base_cost: int = 5
@export var reroll_step: int = 5

var _offer: Array = []
var _sold: Dictionary = {}      # cards bought in the current offer
var _retired: Dictionary = {}   # non-repeatable cards bought this run
var _reroll_cost: int = 0

## Begin a fresh shop visit: clear sold flags, reset reroll cost, draw an offer.
func open() -> void:
	_sold.clear()
	_reroll_cost = reroll_base_cost
	_roll()

func get_offer() -> Array:
	return _offer

func get_reroll_cost() -> int:
	return _reroll_cost

func is_sold(card: ShopCard) -> bool:
	return _sold.has(card)

func can_afford(card: ShopCard) -> bool:
	return not _sold.has(card) and GoldWallet.gold >= card.cost

func purchase(card: ShopCard) -> bool:
	if _sold.has(card):
		return false
	if not GoldWallet.try_spend(card.cost):
		return false
	for m in card.modifiers:
		var mod := m as StatModifier
		PlayerStats.apply_modifier(mod.stat, mod.op, mod.amount)
	_sold[card] = true
	if not card.repeatable:
		_retired[card] = true
	purchased.emit(card)
	return true

func reroll() -> bool:
	if not GoldWallet.try_spend(_reroll_cost):
		return false
	_reroll_cost += reroll_step
	_sold.clear()
	_roll()
	return true

func _roll() -> void:
	_offer = _draw(offer_size)
	offer_changed.emit(_offer)

func _draw(count: int) -> Array:
	var bag: Array = []
	for c in CARD_POOL:
		if not _retired.has(c):
			bag.append(c)
	var result: Array = []
	while result.size() < count and not bag.is_empty():
		var pick := _weighted_pick(bag)
		result.append(pick)
		bag.erase(pick)  # distinct within a single offer
	return result

func _weighted_pick(bag: Array) -> ShopCard:
	var total := 0.0
	for c in bag:
		total += (c as ShopCard).weight
	var roll := randf() * total
	for c in bag:
		roll -= (c as ShopCard).weight
		if roll <= 0.0:
			return c
	return bag.back()
