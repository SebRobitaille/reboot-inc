## Transient jagged bolt drawn between two world points, then fades and frees.
## Added under a node at world origin so its points can be set in world coords.
class_name LightningArc
extends Line2D

@export var segments: int = 6
@export var jitter: float = 12.0
@export var lifetime: float = 0.18

func _ready() -> void:
	width = 3.0
	default_color = Color(0.6, 0.85, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)

func setup(from: Vector2, to: Vector2) -> void:
	points = _build_points(from, to)

func _build_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var normal := (to - from).orthogonal().normalized()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var base := from.lerp(to, t)
		var offset := 0.0
		if i != 0 and i != segments:
			offset = randf_range(-jitter, jitter)
		pts.append(base + normal * offset)
	return pts
