extends CharacterBody2D

## Enemy 7 (prototype): a two-legged spitter. It walks towards Echo like the
## others until it is in range, then holds its distance - stepping back if
## Echo comes too close - and spits round blobs (enemy_blob.gd) from its mouth.
## The walk is animated here (legs swing, body and head bob) as its parts are
## separate textures, not in the shared enemy atlas yet.

signal got_hit

const ENEMY_TYPE: int = 7
const BLOB_SCRIPT: Script = preload("res://Scripts/enemy_blob.gd")

## Distance band it keeps from Echo: walks in beyond KEEP_MAX, backs off
## inside KEEP_MIN, stands still in between.
const KEEP_MIN: float = 300.0
const KEEP_MAX: float = 440.0
const BACK_OFF_SPEED: float = 0.55   # share of its walk speed when backing off
const SHOOT_RANGE: float = 520.0
const SHOOT_CD: float = 2.6
const SHOOT_CD_JITTER: float = 0.6   # so a group doesn't spit in unison
## Head pulls back for WINDUP_TIME, then snaps forward and lets the blob go.
const WINDUP_TIME: float = 0.35
const RECOIL_TIME: float = 0.2
## The mouth: the head's front tip, in the head node's coordinates (the head
## turns on the end of its neck stalk, where it meets the body).
const MOUTH: Vector2 = Vector2(-66, -2)
## Where the neck meets the body, and the body's height, in the body node's
## coordinates (the body stands on its bottom), so the head rides the breath.
const NECK_ON_BODY: Vector2 = Vector2(-12, -77)
## Spitting: the head tips back on its neck, then snaps forward.
const WINDUP_TILT: float = 0.32      # radians
const RECOIL_TILT: float = 0.18
## Breathing: the body swells and settles on its feet, slower when standing.
const BREATH_TIME: float = 1.6
const BREATH_STRETCH: float = 0.045  # share of its height
## One full stride (both legs).
const STRIDE_TIME: float = 0.5
const LEG_SWING: float = 0.45        # radians each way
const BODY_BOB: float = 4.0          # px

var asBoss: bool = false
var bossWave: int = 0
var followSpeed: float = 85.0 * global.ENEMY_SPEED_MULTIPLIER
## Size EnemyCrowd keeps around this enemy. 0 once it stops taking up room.
var crowdRadius: float = 30.0
## Set by EnemyCrowd when a boulder is in its way.
var avoidCorner: Vector2 = Vector2.ZERO
var avoidWeight: float = 0.0
var avoidSide: int = 0
@onready var avatarWrapper: Node2D = $Wrapper
@onready var body: Sprite2D = $Wrapper/Body
@onready var head: Sprite2D = $Wrapper/Head
@onready var legFront: Sprite2D = $Wrapper/LegFront
@onready var legBack: Sprite2D = $Wrapper/LegBack
@onready var player: CharacterBody2D = global.PLAYER
var stats: EnemyStats = EnemyStats.new(global.ENEMY_BASE_STATS.Type_7)
var knockBackVelocity: Vector2 = Vector2.ZERO
var knockBackDecay: float = 10.0
var externalNonDecayVelocity: Vector2 = Vector2.ZERO
var marks: Dictionary = {}
var shrinking: bool = false
var dead: bool = false
var freezeEffect: Freeze = null
var reverseInertia: float = 3.0

var _stride: float = 0.0             # 0..1 through the walk cycle
var _shootTimer: float = SHOOT_CD * randf()
var _windup: float = -1.0            # counts up while winding up a spit, -1 when not
var _recoil: float = 0.0             # counts down after a spit
var _breath: float = randf()        # 0..1 through a breath
var _bodyRest: Vector2
var _headRest: Vector2
var _legFrontRest: Vector2
var _legBackRest: Vector2


func set_as_boss() -> void:
	asBoss = true
	bossWave = global.WAVE_MANAGER.currentWave
	stats = EnemyStats.new(global.ENEMY_BOSS_BASE_STATS.Type_7)


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	knockBackVelocity = knockBackDirection * knockBackIntensity * reverseInertia


func get_hit(incomingDamage: float, emitSignal: bool = true) -> float:
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

	if marks.has("freeze"):
		global.WORLD.audio_2d_play(global.ENEMY_DEATH_STREAM_01, global_position, "game_world", randf_range(1.4, 1.8))
		global.WORLD.frozenShatter.shatter(self, avatarWrapper, func():
			drop_exp()
			queue_free())
		return

	var mat: ShaderMaterial = global.DEATH_CORRODE_SHADER_MATERIAL
	avatarWrapper.modulate = Color.WHITE
	avatarWrapper.use_parent_material = true
	material = mat
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(mat, 'shader_parameter/threshold', 0.0, 0.3).from(1.0)
	global.WORLD.audio_2d_play(global.ENEMY_DEATH_STREAM_01, global_position, "game_world", randf_range(0.8, 1.2))
	tween.finished.connect(drop_exp)
	tween.finished.connect(queue_free)


func drop_exp() -> void:
	if asBoss:
		global.WORLD.expDrops.spray_boss(global_position, bossWave)
	else:
		global.WORLD.expDrops.add(global_position, global.EXP_DROP_TYPES.TYPE_3 if randf() < 0.01 else global.EXP_DROP_TYPES.TYPE_2)


func _physics_process(delta: float) -> void:
	var frozen: bool = followSpeed <= 0.0   # Freeze sets it to 0
	var toPlayer: Vector2 = player.global_position - global_position
	var dist: float = toPlayer.length()
	var towards: Vector2 = toPlayer / dist if dist > 0.0 else Vector2.ZERO

	var moveDir: Vector2 = Vector2.ZERO
	var speed: float = followSpeed
	if dist > KEEP_MAX:
		moveDir = towards
		if avoidWeight > 0.0:   # a boulder in the way (EnemyCrowd)
			moveDir = moveDir.lerp(global_position.direction_to(avoidCorner), avoidWeight).normalized()
	elif dist < KEEP_MIN:
		moveDir = -towards
		speed *= BACK_OFF_SPEED
	if _windup >= 0.0:
		moveDir = Vector2.ZERO   # plants its feet to spit

	velocity = moveDir * speed + knockBackVelocity + externalNonDecayVelocity
	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
	externalNonDecayVelocity = Vector2.ZERO
	position += velocity * delta

	if frozen:
		return
	# Always faces Echo, even while backing off. The art faces left.
	avatarWrapper.scale.x = -1.0 if toPlayer.x > 0.0 else 1.0
	_animate(delta, moveDir != Vector2.ZERO)
	_update_spit(delta, dist)


func _animate(delta: float, walking: bool) -> void:
	if walking:
		_stride = fmod(_stride + delta / STRIDE_TIME, 1.0)
	else:
		# Settle back to standing: ease to the nearest point of the cycle where
		# the legs are together (0, 0.5 or 1).
		_stride = move_toward(_stride, roundf(_stride * 2.0) * 0.5, delta / STRIDE_TIME)
		if _stride >= 1.0:
			_stride = 0.0
	var swing: float = sin(_stride * TAU)
	var lift := Vector2(0, -absf(swing) * BODY_BOB)   # the whole body rises mid-step
	legFront.rotation = swing * LEG_SWING
	legBack.rotation = -swing * LEG_SWING
	legFront.position = _legFrontRest + lift
	legBack.position = _legBackRest + lift

	# Breathing: the body stretches up from its bottom and settles, gentler
	# while walking; the head rides on top of it.
	_breath = fmod(_breath + delta / BREATH_TIME, 1.0)
	var breathe: float = sin(_breath * TAU) * BREATH_STRETCH * (0.4 if walking else 1.0)
	body.scale = Vector2(1.0 - breathe * 0.5, 1.0 + breathe)
	body.position = _bodyRest + lift
	var neck: Vector2 = Vector2(NECK_ON_BODY.x * (body.scale.x - 1.0), NECK_ON_BODY.y * (body.scale.y - 1.0))

	# Head: stays on its neck; tips back for a spit and snaps forward after,
	# and nods a little with each breath.
	var tilt: float = -breathe * 1.5
	if _windup >= 0.0:
		tilt += WINDUP_TILT * ease(_windup / WINDUP_TIME, 0.5)
	elif _recoil > 0.0:
		tilt -= RECOIL_TILT * (_recoil / RECOIL_TIME)
	head.position = _headRest + lift + neck
	head.rotation = tilt


func _update_spit(delta: float, dist: float) -> void:
	if _recoil > 0.0:
		_recoil -= delta
	if _windup >= 0.0:
		_windup += delta
		if _windup >= WINDUP_TIME:
			_windup = -1.0
			_recoil = RECOIL_TIME
			_spit()
		return
	_shootTimer -= delta
	if _shootTimer <= 0.0 and dist <= SHOOT_RANGE and not shrinking:
		_shootTimer = SHOOT_CD + randf_range(-SHOOT_CD_JITTER, SHOOT_CD_JITTER)
		_windup = 0.0


func _spit() -> void:
	var blob: Node2D = BLOB_SCRIPT.new()
	global.WORLD.add_child(blob)
	blob.launch(head.global_transform * MOUTH, player.global_position + EnemyBlob.PLAYER_CENTRE_OFFSET, stats.damage)


func _ready() -> void:
	_bodyRest = body.position
	_headRest = head.position
	_legFrontRest = legFront.position
	_legBackRest = legBack.position
	global.WORLD.enemyCrowd.add(self)
