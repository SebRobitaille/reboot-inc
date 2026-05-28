class_name SplashTower
extends Tower

func _fire_at(target: Node2D) -> void:
	var proj := SplashProjectile.new()
	get_tree().current_scene.add_child(proj)
	var sd := data as SplashTowerData
	proj.setup(global_position, _predict_position(target, sd.splash_radius),
			sd.splash_radius, sd.damage, sd.outer_damage_fraction)

func _predict_position(target: Node2D, splash_radius: float) -> Vector2:
	var d: Vector2 = target.global_position - global_position
	var v: Vector2 = (target as CharacterBody2D).velocity if target is CharacterBody2D \
			else Vector2.ZERO

	var a: float = v.dot(v) - SplashProjectile.SPEED * SplashProjectile.SPEED
	var b: float = 2.0 * d.dot(v)
	var c: float = d.dot(d)

	var t: float = 0.0
	if abs(a) < 0.001:
		# Linear: projectile much faster than enemy, solve directly
		if abs(b) > 0.001:
			t = -c / b
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var sqrt_disc: float = sqrt(disc)
			var t1: float = (-b - sqrt_disc) / (2.0 * a)
			var t2: float = (-b + sqrt_disc) / (2.0 * a)
			if t1 > 0.0:
				t = t1
			elif t2 > 0.0:
				t = t2

	if t <= 0.0:
		return target.global_position

	var predicted: Vector2 = target.global_position + v * t
	# Clamp so the aim point is never more than 1 splash radius past the current position
	var max_lead: float = splash_radius
	if predicted.distance_to(target.global_position) > max_lead:
		predicted = target.global_position + \
				(predicted - target.global_position).normalized() * max_lead
	return predicted
