extends CharacterBody2D

signal got_hit

var followSpeed : float = 100.0
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var avatarWrapper: Node2D = $Wrapper
@onready var player: CharacterBody2D = global.PLAYER
var expDropBluePrint: PackedScene = preload("res://Scenes/Systems/exp_drop.tscn")
var stats: EnemyStats = EnemyStats.new(global.ENEMY_BASE_STATS.Type_4)
var knockBackVelocity: Vector2 = Vector2.ZERO
var knockBackDecay: float = 10.0
var externalNonDecayVelocity: Vector2 = Vector2.ZERO
var followVelocity: Vector2 = Vector2.ZERO
@export var speedCurve: Curve = Curve.new()
var time: float = 0.0
var direction: Vector2
var marks: Dictionary = {}
var shrinking: bool = false
var freezeEffect: Freeze = null


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	knockBackVelocity = knockBackDirection * knockBackIntensity * 3


func get_hit(incomingDamage: float, emitSignal: bool = true) -> float:
	stats.hp -= incomingDamage
	
	if emitSignal:
		got_hit.emit(incomingDamage)
	
	var remHP: float = stats.hp
	if remHP <= 0.0:
		handle_death()
	
	return remHP


func handle_death() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	
	var mat: ShaderMaterial = global.DEATH_CORRODE_SHADER_MATERIAL
	avatarWrapper.use_parent_material = true
	material = mat
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, 'shader_parameter/threshold', 0.0, 0.3).from(1.0)
	
	global.WORLD.audio_2d_play(global.ENEMY_DEATH_STREAM_02, global_position, "game_world", randf_range(0.8, 1.2))
	
	tween.finished.connect(drop_exp)
	tween.finished.connect(queue_free)


func drop_exp() -> void:
	var expDrop: Area2D = expDropBluePrint.instantiate()
	
	expDrop.set_exp_type(global.EXP_DROP_TYPES.TYPE_2 if randf() < 0.01 else global.EXP_DROP_TYPES.TYPE_3)
	expDrop.global_position = global_position
	
	global.WORLD.add_child.call_deferred(expDrop)


func _physics_process(delta: float) -> void:
	direction = global_position.direction_to(player.global_position)
	followVelocity = direction * speedCurve.sample_baked(time) * followSpeed
	
	velocity = followVelocity + knockBackVelocity + externalNonDecayVelocity
	
	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
	externalNonDecayVelocity = Vector2.ZERO

	avatarWrapper.scale.x = -1.0 if direction.x > 0 else 1.0
	
	move_and_slide()
	
	time += delta
	if time >= 0.8:
		time = 0.0
