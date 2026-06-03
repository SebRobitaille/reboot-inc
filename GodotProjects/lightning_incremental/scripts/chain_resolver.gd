## Pure, scene-free chain-lightning targeting. The caller supplies the candidate
## list (typically nodes in the "enemies" group), so any emitter — the core now,
## M3 towers later — can reuse this with its own CombatStats.
class_name ChainResolver
extends RefCounted

## One resolved link: which enemy is struck, for how much, at which jump index.
class ChainHit extends RefCounted:
	var enemy: Node2D
	var damage: float
	var jump: int

	func _init(p_enemy: Node2D, p_damage: float, p_jump: int) -> void:
		enemy = p_enemy
		damage = p_damage
		jump = p_jump

## Greedy nearest-unvisited chain starting at `seed`, up to stats.max_targets hits.
static func resolve(seed: Node2D, candidates: Array, stats: CombatStats) -> Array[ChainHit]:
	var hits: Array[ChainHit] = []
	if seed == null or stats == null:
		return hits

	var visited: Dictionary = {}
	var current: Node2D = seed
	var damage: float = stats.base_damage
	visited[current] = true
	hits.append(ChainHit.new(current, damage, 0))

	while hits.size() < stats.max_targets:
		var next: Node2D = _nearest_unvisited(current, candidates, visited, stats.chain_range)
		if next == null:
			break
		damage *= stats.chain_falloff
		visited[next] = true
		hits.append(ChainHit.new(next, damage, hits.size()))
		current = next

	return hits

static func _nearest_unvisited(from: Node2D, candidates: Array, visited: Dictionary, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = max_range
	for c in candidates:
		var node := c as Node2D
		if node == null or not is_instance_valid(node) or visited.has(node):
			continue
		var d: float = from.global_position.distance_to(node.global_position)
		if d <= best_dist:
			best = node
			best_dist = d
	return best
