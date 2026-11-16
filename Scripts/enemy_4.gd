extends CharacterBody2D

signal got_hit

const ENEMY_TYPE: int = 4
const BOSS_MATERIAL: Material = preload("res://Shaders/Material/enemy_boss.tres")
## Length of one hop: the speed curve below and the body bob in enemy.gdshader.
const HOP_TIME: float = 0.8

## Leap: when Echo is LEAP_MIN_RANGE to LEAP_MAX_RANGE away and no other enemy
## is in the way, this enemy lunges straight at where Echo stands, with no
## warning, and hits for LEAP_DAMAGE_MULTIPLIER times its normal damage. Only
## one leap at a time across the whole field: after any enemy 4 leaps, none
## leaps again until the shared cooldown (world.enemyLeapReadyAt) is over.
const LEAP_MIN_RANGE: float = 110.0
const LEAP_MAX_RANGE: float = 260.0
const LEAP_SPEED: float = 1100.0        # px/s, a 260 px leap takes about 0.28 s
const LEAP_OVERSHOOT: float = 50.0      # carries on past the spot it aimed at
const LEAP_DAMAGE_MULTIPLIER: float = 2.0
const LEAP_CD_FIRST_WAVE: float = 7.0   # shared cooldown at wave 1...
const LEAP_CD_LAST_WAVE: float = 4.0    # ...shrinking to this by LEAP_CD_END_WAVE
const LEAP_CD_END_WAVE: int = 50
## How often each enemy looks for a leap. Each starts at a random point of the
## interval, so the line-of-sight checks spread over frames.
const LEAP_CHECK_INTERVAL: float = 0.25
const ENEMY_COLLISION_LAYER: int = 4

## One ray query shared by every enemy 4 (filled in before each check).
static var _leapRay: PhysicsRayQueryParameters2D = null

var asBoss: bool = false
var followSpeed : float = 100.0 * global.ENEMY_SPEED_MULTIPLIER
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
var leaping: bool = false
var leapDirection: Vector2 = Vector2.ZERO
var leapDistanceLeft: float = 0.0
var leapCheckTimer: float = randf() * LEAP_CHECK_INTERVAL


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
	global.WORLD.expDrops.add(global_position, global.EXP_DROP_TYPES.TYPE_3 if randf() < 0.01 else global.EXP_DROP_TYPES.TYPE_2)


## Shared leap cooldown for the current wave: 7 s at wave 1 down to 4 s.
static func leap_cooldown() -> float:
	var wave: int = 1
	if is_instance_valid(global.WAVE_MANAGER):
		wave = global.WAVE_MANAGER.currentWave
	var t: float = clampf(float(wave - 1) / float(LEAP_CD_END_WAVE - 1), 0.0, 1.0)
	return lerpf(LEAP_CD_FIRST_WAVE, LEAP_CD_LAST_WAVE, t)


## Called by the player when this enemy's leap lands, and when the leap runs out.
func end_leap() -> void:
	leaping = false


func _can_leap() -> bool:
	# Frozen enemies have followSpeed 0; shrinking ones are falling into a black hole.
	return not shrinking and followSpeed > 0.0


func _try_leap(delta: float) -> void:
	leapCheckTimer -= delta
	if leapCheckTimer > 0.0:
		return
	leapCheckTimer = LEAP_CHECK_INTERVAL

	var world: Node2D = global.WORLD
	if world.elapsedTime < world.enemyLeapReadyAt or not _can_leap():
		return
	var toPlayer: Vector2 = player.global_position - global_position
	var distSq: float = toPlayer.length_squared()
	if distSq < LEAP_MIN_RANGE * LEAP_MIN_RANGE or distSq > LEAP_MAX_RANGE * LEAP_MAX_RANGE:
		return

	# Only leap with a clear line: any enemy body on the way blocks it.
	if _leapRay == null:
		_leapRay = PhysicsRayQueryParameters2D.new()
		_leapRay.collision_mask = ENEMY_COLLISION_LAYER
	var exclude: Array[RID] = [get_rid()]
	_leapRay.from = global_position
	_leapRay.to = player.global_position
	_leapRay.exclude = exclude
	if not get_world_2d().direct_space_state.intersect_ray(_leapRay).is_empty():
		return

	world.enemyLeapReadyAt = world.elapsedTime + leap_cooldown()
	var dist: float = sqrt(distSq)
	leapDirection = toPlayer / dist
	leapDistanceLeft = dist + LEAP_OVERSHOOT
	leaping = true


func _physics_process(delta: float) -> void:
	if leaping:
		if not _can_leap():
			leaping = false
		else:
			var step: float = minf(LEAP_SPEED * delta, leapDistanceLeft)
			position += leapDirection * step + (knockBackVelocity + externalNonDecayVelocity) * delta
			leapDistanceLeft -= step
			if leapDistanceLeft <= 0.0:
				leaping = false
			if knockBackVelocity:
				knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)
			externalNonDecayVelocity = Vector2.ZERO
			avatarWrapper.scale.x = -1.0 if leapDirection.x > 0 else 1.0
			time = fmod(time + delta, HOP_TIME)   # stays in step with the shader's bob
			return

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

	_try_leap(delta)


func _ready() -> void:
	# Start the body bob (enemy.gdshader) in step with this enemy's hops, which
	# start now (time = 0).
	avatarWrapper.modulate.r = fposmod(-global.WORLD.enemyAnimTime / HOP_TIME, 1.0)
	if asBoss:
		avatarWrapper.material = BOSS_MATERIAL
	global.WORLD.enemyCrowd.add(self)
