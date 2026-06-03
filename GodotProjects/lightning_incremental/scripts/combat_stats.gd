## Tunable weapon stats for a chain-lightning emitter.
## Single source of weapon tuning: the core consumes one instance now, and M3
## towers will each own their own instance. M2's shop mutates these fields.
class_name CombatStats
extends Resource

@export var base_damage: float = 25.0     # damage applied to the seed target
@export var max_targets: int = 4          # total enemies hit, including the seed
@export var chain_range: float = 180.0    # max px distance for each jump
@export var chain_falloff: float = 0.7    # damage multiplier applied per jump (0..1)
@export var energy_cost: float = 20.0     # energy spent per cast
@export var cast_cooldown: float = 0.25   # seconds between casts
@export var cast_range: float = 600.0     # max px from emitter to a valid seed
