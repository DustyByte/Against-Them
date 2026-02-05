extends Node2D

@onready var pullRange: Area2D = $EnemyDetectionRange


func _process(_delta: float) -> void:
	var enemies: Array = pullRange.get_overlapping_bodies()
	
	for body in enemies:
		body.shrinkand_die(self)
