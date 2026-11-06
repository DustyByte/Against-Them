extends CharacterBody2D

signal got_hit

const ENEMY_TYPE: int = 1

var asBoss: bool = false
var followSpeed: float = 150.0

@onready var avatarWrapper: Node2D = $Wrapper
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
var expDropBluePrint: PackedScene = preload("res://Scenes/Systems/exp_drop.tscn")
var stats: EnemyStats = EnemyStats.new(global.ENEMY_BASE_STATS.Type_1)
var knockBackVelocity: Vector2 = Vector2.ZERO
var knockBackDecay: float = 10.0
var externalVelocity: Vector2 = Vector2.ZERO
var externalVelocityDecay: float = 100.0
var externalNonDecayVelocity: Vector2 = Vector2.ZERO
var shrinking: bool = false
@export var curve: Curve = Curve.new()
@export var twitchCurve: Curve = Curve.new()
var marks: Dictionary = {}
var twitchTween: Tween = null
var freezeEffect: Freeze = null
var reverseInertia: float = 3.0


func twitch() -> void:
	if twitchTween:
		return
	
	twitchTween = get_tree().create_tween()
	var method: Callable = func(val: float):
		scale = Vector2.ONE * twitchCurve.sample_baked(val)
	twitchTween.tween_method(method, 0.0, 0.32, 0.075)


func set_as_boss() -> void:
	asBoss = true
	stats = EnemyStats.new(global.ENEMY_BOSS_BASE_STATS.Type_1)
	reverseInertia *= 0.34


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	knockBackVelocity = knockBackDirection * knockBackIntensity * reverseInertia


func apply_external_velocity(givenExternalVelocityWithDelta: Vector2) -> void:
	externalVelocity += givenExternalVelocityWithDelta


func get_hit(incomingDamage: float, emitSignal: bool = true) -> float:
	stats.hp -= incomingDamage
	
	if emitSignal:
		got_hit.emit(incomingDamage)
	
	var remHP: float = stats.hp
	if remHP <= 0.0:
		handle_death()
	else:
		twitch()
	
	return remHP


func drop_exp() -> void:
	var expDrop: Area2D = expDropBluePrint.instantiate()
	
	expDrop.set_exp_type(global.EXP_DROP_TYPES.TYPE_1)
	expDrop.global_position = global_position
	
	global.WORLD.add_child.call_deferred(expDrop)


func handle_death() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	
	if asBoss:
		var headSprite: Sprite2D = $Wrapper/Head
		headSprite.use_parent_material = true
		headSprite.material = null
	
	var mat: ShaderMaterial = global.DEATH_CORRODE_SHADER_MATERIAL
	avatarWrapper.use_parent_material = true
	material = mat
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, 'shader_parameter/threshold', 0.0, 0.3).from(1.0)
	
	global.WORLD.audio_2d_play(global.ENEMY_DEATH_STREAM_01, global_position, "game_world", randf_range(0.8, 1.2))
	
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


func _physics_process(_delta: float) -> void:
	if shrinking:
		return
	
	var followDirection: Vector2 = global_position.direction_to(global.PLAYER.global_position)
	var followVelocity: Vector2 = followDirection * followSpeed
	
	velocity = followVelocity + knockBackVelocity + externalVelocity + externalNonDecayVelocity
	
	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
	if externalVelocity:
		externalVelocity = externalVelocity.move_toward(Vector2.ZERO, externalVelocityDecay)
	externalNonDecayVelocity = Vector2.ZERO
	
	move_and_slide()


func _ready() -> void:
	if asBoss:
		$Wrapper/Head.use_parent_material = false
		$Wrapper/Head.material = preload("res://Shaders/Material/boss_outline.tres")
