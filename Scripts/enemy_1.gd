extends CharacterBody2D

const FOLLOW_SPEED: float = 150.0

var stats: EnemyStats = EnemyStats.new(global.ENEMY_BASE_STATS.Type_1)
var canMove: bool = true


func follow(toFollow: CharacterBody2D) -> void:
	var direction: Vector2 = global_position.direction_to(toFollow.global_position)
	velocity = direction * FOLLOW_SPEED


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	canMove = false
	velocity = knockBackDirection * knockBackIntensity


func get_hit(incomingDamage: float) -> void:
	stats.hp -= incomingDamage
	if stats.hp <= 0:
		handle_death()


func handle_death() -> void:
	var expDrop: Area2D = load("res://Scenes/exp_drop.tscn").instantiate()
	expDrop.set_exp_type(global.EXP_DROP_TYPES.TYPE_1)
	expDrop.global_position = global_position
	get_node("/root/World").add_child.call_deferred(expDrop)
	
	queue_free()


func _physics_process(delta: float) -> void:
	if canMove and global.PLAYER:
		follow(global.PLAYER)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 100* delta)
		if velocity.length_squared() < 10:
			canMove = true
	
	move_and_slide()
