extends Area2D

const FOLLOW_SPEED: float = 150.0

@onready var avatarWrapper: Node2D = $SpritesWrapper
var expDropBluePrint: PackedScene = preload("res://Scenes/Systems/exp_drop.tscn")
var stats: EnemyStats = EnemyStats.new(global.ENEMY_BASE_STATS.Type_1)
var knockBackVelocity: Vector2 = Vector2.ZERO
var knockBackDecay: float = 5.0
var externalVelocity: Vector2 = Vector2.ZERO
var externalVelocityDecay: float = 100.0
var shrinking: bool = false
@export var curve: Curve = Curve.new()
var velocity: Vector2 = Vector2.ZERO
var hasSelfPushed: bool = false


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
	process_mode = Node.PROCESS_MODE_DISABLED
	
	var mat: ShaderMaterial = global.DEATH_CORRODE_SHADER_MATERIAL.duplicate()
	avatarWrapper.material = mat
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, 'shader_parameter/threshold', 0.0, 0.3).from(1.0)
	
	tween.finished.connect(drop_exp)
	tween.finished.connect(queue_free)


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


func push() -> void:
	var areas: Array[Area2D] = get_overlapping_areas()
	for area in areas:
		var dir: Vector2 = global_position.direction_to(area.global_position)
	
		externalVelocity -= dir * 100.0
	
	monitoring = false


func _physics_process(_delta: float) -> void:
	if shrinking:
		return
	
	var followDirection: Vector2 = global_position.direction_to(global.PLAYER.global_position)
	var followVelocity: Vector2 = followDirection * FOLLOW_SPEED
	
	velocity = followVelocity + knockBackVelocity + externalVelocity
	position += velocity * _delta
	
	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
	if externalVelocity:
		externalVelocity = externalVelocity.move_toward(Vector2.ZERO, externalVelocityDecay)
	else:
		monitoring = true
		push()
