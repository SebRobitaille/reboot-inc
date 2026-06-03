## Indestructible blocking placeable. No logic — it just occupies its grid cell
## (NavGrid marks the cell solid), forcing enemies to route around it.
class_name Wall
extends Node2D

var def: PlaceableDef

func configure(p_def: PlaceableDef) -> void:
	def = p_def

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if def == null:
		return
	var half := Vector2(def.radius, def.radius)
	draw_rect(Rect2(-half, half * 2.0), def.color)
