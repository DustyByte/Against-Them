extends CharacterBody2D

signal got_hit

const ENEMY_TYPE: int = 4
const BOSS_MATERIAL: Material = preload("res://Shaders/Material/enemy_boss.tres")
## Length of one hop: the speed curve below and the body bob in enemy.gdshader.
const HOP_TIME: float = 0.8

var asBoss: bool = false
var followSpeed : float = 100.0
## Size EnemyCrowd keeps around this enemy (its collision circle). 0 once it
## stops taking up room (dying, shrinking into a black hole).
var crowdRadius: float = 34.0
@onready var avatarWrapper: Node2D = $Wrapper
@onready var player: CharacterBody2D = global.PLAYER
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
var dead: bool = false
var freezeEffect: Freeze = null
var reverseInertia: float = 3.0


func set_as_boss() -> void:
	asBoss = true
	stats = EnemyStats.new(global.ENEMY_BOSS_BASE_STATS.Type_4)
	reverseInertia *= 0.34


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	knockBackVelocity = knockBackDirection * knockBackIntensity * reverseInertia


func get_hit(incomingDamage: float, emitSignal: bool = true) -> float:
	# Already dying: hits landing during the death fade must not start the death
	# (and its EXP drop) again. Positive, as this hit killed nothing.
	if dead:
		return 1.0
	if asBoss:
		incomingDamage *= UpgradeManager.boss_damage_multiplier() # Boss Bane
	stats.hp -= incomingDamage
	AchievementManager.register_enemy_hit(incomingDamage)

	if emitSignal:
		got_hit.emit(incomingDamage)

	var remHP: float = stats.hp
	if remHP <= 0.0:
		handle_death()

	return remHP


func handle_death() -> void:
	if dead:
		return
	dead = true
	crowdRadius = 0.0
	AchievementManager.register_enemy_death(self)
	process_mode = Node.PROCESS_MODE_DISABLED

	var mat: ShaderMaterial = global.DEATH_CORRODE_SHADER_MATERIAL
	avatarWrapper.modulate = Color.WHITE # it held the bob phase for enemy.gdshader
	avatarWrapper.use_parent_material = true
	material = mat

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, 'shader_parameter/threshold', 0.0, 0.3).from(1.0)

	global.WORLD.audio_2d_play(global.ENEMY_DEATH_STREAM_02, global_position, "game_world", randf_range(0.8, 1.2))

	tween.finished.connect(drop_exp)
	tween.finished.connect(queue_free)


func drop_exp() -> void:
	global.WORLD.expDrops.add(global_position, global.EXP_DROP_TYPES.TYPE_2 if randf() < 0.01 else global.EXP_DROP_TYPES.TYPE_3)


func _physics_process(delta: float) -> void:
	direction = global_position.direction_to(player.global_position)
	followVelocity = direction * speedCurve.sample_baked(time) * followSpeed

	velocity = followVelocity + knockBackVelocity + externalNonDecayVelocity

	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
	externalNonDecayVelocity = Vector2.ZERO

	avatarWrapper.scale.x = -1.0 if direction.x > 0 else 1.0

	# Moved directly instead of move_and_slide(): enemies collide with nothing
	# (EnemyCrowd keeps them apart and the world has no solid objects), which
	# saves a physics motion test per enemy per frame.
	position += velocity * delta

	time += delta
	if time >= HOP_TIME:
		time -= HOP_TIME   # keeps the hops in step with the shader's bob


func _ready() -> void:
	# Start the body bob (enemy.gdshader) in step with this enemy's hops, which
	# start now (time = 0).
	avatarWrapper.modulate.r = fposmod(-global.WORLD.enemyAnimTime / HOP_TIME, 1.0)
	if asBoss:
		avatarWrapper.material = BOSS_MATERIAL
	global.WORLD.enemyCrowd.add(self)
