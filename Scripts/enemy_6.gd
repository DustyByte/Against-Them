extends CharacterBody2D

signal got_hit

const ENEMY_TYPE: int = 6

var asBoss: bool = false
var followSpeed: float = 200.0
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var avatarWrapper: Node2D = $Wrapper
@onready var rangeArea: Area2D = $Area2D
@onready var player: CharacterBody2D = global.PLAYER
var expDropBluePrint: PackedScene = preload("res://Scenes/Systems/exp_drop.tscn")
var explosionParticlesBP: PackedScene = preload("res://Scenes/Effects/explosion_particles.tscn")
var stats: EnemyStats = EnemyStats.new(global.ENEMY_BASE_STATS.Type_6)
var knockBackVelocity: Vector2 = Vector2.ZERO
var knockBackDecay: float = 10.0
var externalNonDecayVelocity: Vector2 = Vector2.ZERO
var followVelocity: Vector2 = Vector2.ZERO
var direction: Vector2
var attackables: Array[Node2D] = []
var marks: Dictionary = {}
var shrinking: bool = false
var freezeEffect: Freeze = null


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	knockBackVelocity = knockBackDirection * knockBackIntensity * 3


func get_hit(incomingDamage: float, emitSignal: bool = true) -> float:
	stats.hp -= incomingDamage
	AchievementManager.register_enemy_hit(incomingDamage)
	
	if emitSignal:
		got_hit.emit(incomingDamage)
	
	var remHP: float = stats.hp
	if remHP <= 0.0:
		explodeand_die()
	
	return remHP


func deactivate() -> void:
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_deferred('process_mode', Node.PROCESS_MODE_DISABLED)


func handle_death() -> void:
	if shrinking:
		return
	explodeand_die()


func explodeand_die(body: CharacterBody2D = null) -> void: # body here is always player, couldn't name player as it is already in use.
	if shrinking:
		return
	
	# Blowing up on contact with the player (body set) is not a kill by the player.
	AchievementManager.register_enemy_death(self, body == null)
	deactivate()
	
	var explosionParticles: GPUParticles2D = explosionParticlesBP.instantiate()
	explosionParticles.global_position = global_position
	global.WORLD.add_child(explosionParticles)
	explosionParticles.finished.connect(explosionParticles.queue_free)
	explosionParticles.emitting = true
	
	global.activeCamera.shake(10.0)
	
	rangeArea.collision_mask = 4 # bit 3
	
	global.WORLD.audio_2d_play(global.ENEMY_DEATH_STREAM_03, global_position, "game_world", randf_range(1.55, 1.8))
	
	await get_tree().create_timer(0.1).timeout
	
	if body:
		body.get_knocked_back(global_position.direction_to(body.global_position), 100.0)
		body.get_hit(stats.damage)
	
	attackables = rangeArea.get_overlapping_bodies()
	AchievementManager.begin_explosion()
	for attackable in attackables:
		attackable.get_knocked_back(global_position.direction_to(attackable.global_position), 100.0)
		attackable.get_hit(stats.damage)
	AchievementManager.end_explosion()
	
	drop_exp()
	queue_free()


func drop_exp() -> void:
	var expDrop: Area2D = expDropBluePrint.instantiate()
	
	expDrop.set_exp_type(global.EXP_DROP_TYPES.TYPE_2 if randf() < 0.01 else global.EXP_DROP_TYPES.TYPE_3)
	expDrop.global_position = global_position
	
	global.WORLD.add_child.call_deferred(expDrop)


func _physics_process(_delta: float) -> void:
	direction = global_position.direction_to(player.global_position)
	followVelocity = direction * followSpeed
	
	velocity = followVelocity + knockBackVelocity + externalNonDecayVelocity
	
	move_and_slide()
	
	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
	externalNonDecayVelocity = Vector2.ZERO
	
	avatarWrapper.scale.x = -0.5 if direction.x > 0.0 else 0.5


func _ready() -> void:
	rangeArea.body_entered.connect(explodeand_die)
