class_name Anomaly
extends Area2D


@export var curve: Curve = null


func on_hit_connect(body: Node2D) -> void:
	if body.shrinking:
		return
	
	body.set_process(false)
	var shrinkTween: Tween = get_tree().create_tween()
	var method: Callable = func(value: float):
		body.scale = Vector2.ONE * curve.sample(value)
		body.global_position = body.global_position.move_toward(global_position, 10.0)
	shrinkTween.tween_method(method,
		0.0, 0.75, 0.15
	)
	shrinkTween.finished.connect(func():
		AchievementManager.push_source(&"black_hole")
		body.handle_death()
		AchievementManager.pop_source()
	)
	
	body.collision_layer = 0
	body.collision_mask = 0
	body.shrinking = true
