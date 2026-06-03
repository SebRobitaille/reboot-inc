## Data-driven definition of an enemy type. Authored as .tres files.
class_name EnemyDef
extends Resource

@export var max_health: float = 40.0
@export var speed: float = 60.0           # px per second toward the core
@export var gold_reward: int = 5          # paid out on death (not on core contact)
@export var contact_damage: float = 10.0  # dealt to the core on contact
@export var radius: float = 14.0          # collision + draw radius
@export var color: Color = Color(0.9, 0.45, 0.35)
