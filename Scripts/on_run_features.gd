static func lightning_strike(lightningBluePrint: PackedScene, target: Vector2) -> void:
	var lightning: Line2D = lightningBluePrint.instantiate()
	lightning.position = target
	global.WORLD.add_child(lightning)
