## Reusable chain-lightning firing. Spends shared EnergyPool, resolves a chain via
## ChainResolver, and draws arcs from this node's global position. Owned by the Core
## (click-aimed) and by every Tower (auto-aimed) — same code, different stats/seed.
class_name ChainEmitter
extends Node2D

const LightningArcScene := preload("res://scenes/lightning_arc.tscn")

var stats: CombatStats
var _cooldown: float = 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func can_fire() -> bool:
	return stats != null and _cooldown <= 0.0

## Fire at `seed`, chaining through `candidates`. Returns true if it actually fired
## (off cooldown, valid seed, and enough shared energy).
func try_fire(seed: Node2D, candidates: Array) -> bool:
	if not can_fire() or seed == null:
		return false
	if not EnergyPool.try_spend(stats.energy_cost):
		return false
	_cooldown = stats.cast_cooldown
	_play_chain(ChainResolver.resolve(seed, candidates, stats))
	return true

func _play_chain(hits: Array) -> void:
	var prev: Vector2 = global_position
	for hit in hits:
		var h := hit as ChainResolver.ChainHit
		if h == null or not is_instance_valid(h.enemy):
			continue
		var hit_pos: Vector2 = h.enemy.global_position
		_spawn_arc(prev, hit_pos)
		h.enemy.take_damage(h.damage)
		prev = hit_pos

func _spawn_arc(from: Vector2, to: Vector2) -> void:
	var arc := LightningArcScene.instantiate()
	get_tree().current_scene.add_child(arc)  # world root at origin: arc points are world coords
	arc.setup(from, to)

## Nearest valid enemy to `origin` within `max_range` (used by towers to auto-target).
static func nearest_enemy(origin: Vector2, candidates: Array, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = max_range
	for c in candidates:
		var node := c as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var d := origin.distance_to(node.global_position)
		if d <= best_dist:
			best = node
			best_dist = d
	return best
