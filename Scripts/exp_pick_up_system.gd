extends Area2D

const ATTRACTING_SPEED: float = 600

@onready var player: CharacterBody2D = $".."
var expDropsBeingPickedUp: Array[Area2D] = []


func pick_up(expDrop: Area2D) -> void:
	expDropsBeingPickedUp.append(expDrop)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("exp") and not area.isPickedUp:
		pick_up(area)
		area.isPickedUp = true


func _process(delta: float) -> void:
	var i: int = 0
	while i < expDropsBeingPickedUp.size():
		var expDrop: Area2D = expDropsBeingPickedUp[i]
		if expDrop.global_position.distance_to(player.global_position) <= 20:
			player.stats.add_exp(expDrop.expAmount)
			expDrop.queue_free()
			expDropsBeingPickedUp.remove_at(i)
			i -= 1
		
		else:
			var flyDirection: Vector2 = expDrop.global_position.direction_to(player.global_position)
			expDrop.global_position += flyDirection * ATTRACTING_SPEED * delta
		i += 1
