extends CharacterBody2D

const FOLLOW_SPEED: float = 150.0

var expDropBluePrint: PackedScene = preload("res://Scenes/exp_drop.tscn")
var stats: EnemyStats = EnemyStats.new(global.ENEMY_BASE_STATS.Type_1)
var knockBackVelocity: Vector2 = Vector2.ZERO
var knockBackDecay: float = 10.0
var externalVelocity: Vector2 = Vector2.ZERO
var externalVelocityDecay: float = 100.0
var shrinking: bool = false
@export var curve: Curve = Curve.new()


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	knockBackVelocity = knockBackDirection * knockBackIntensity * 3


func apply_external_velocity(givenExternalVelocityWithDelta: Vector2) -> void:
	externalVelocity += givenExternalVelocityWithDelta


func get_hit(incomingDamage: float) -> void:
	stats.hp -= incomingDamage
	
	if stats.hp <= 0:
		handle_death()


func drop_exp() -> void:
	var expDrop: Area2D = expDropBluePrint.instantiate()
	
	expDrop.set_exp_type(global.EXP_DROP_TYPES.TYPE_1)
	expDrop.global_position = global_position
	
	global.WORLD.add_child.call_deferred(expDrop)


func handle_death() -> void:
	drop_exp()
	queue_free()


func shrinkand_die(anomaly: Node2D) -> void:
	if shrinking:
		return
	
	var shrinkTween: Tween = create_tween()
	
	shrinkTween.tween_method(func(value: float):
		scale = Vector2.ONE * curve.sample(value)
		global_position = global_position.move_toward(anomaly.global_position, 10),
		0.0, 0.75, 0.15
	)
	shrinkTween.tween_callback(handle_death)
	
	collision_layer = 0
	set_collision_layer_value(8, true)
	shrinking = true


func _physics_process(_delta: float) -> void:
	if shrinking:
		return
	
	var followDirection: Vector2 = global_position.direction_to(global.PLAYER.global_position)
	var followVelocity: Vector2 = followDirection * FOLLOW_SPEED
	
	velocity = followVelocity + knockBackVelocity + externalVelocity
	
	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
	if externalVelocity:
		externalVelocity = externalVelocity.move_toward(Vector2.ZERO, externalVelocityDecay)
	
	move_and_slide()
