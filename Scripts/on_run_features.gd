static func lightning_strike(target: Vector2) -> void:
	var lightning: Line2D = global.FREQUENT_EFFECTS_BLUEPRINTS.LIGHTNING_BLUEPRINT.instantiate()
	lightning.position = target
	global.WORLD.add_child(lightning)
