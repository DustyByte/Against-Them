class_name Anomaly
extends Area2D

## The Miniature Star's final form: a black hole circling Echo.
## - Ordinary enemies that touch it are swallowed at once.
## - Bosses are too massive to swallow while healthy. While touching one they
##   take DRAIN_DAMAGE_FACTOR x the star's damage every DRAIN_INTERVAL (more as
##   Feed the Monster grows the black hole), walk at BOSS_SLOW of their speed
##   and are tugged towards it; so the player's whole build gets to hit them.
## - Once a boss is down to FINISHER_HP_SHARE of its health, the next black
##   hole it touches swallows it: a slow spiral in, with a flash, a ring and a
##   screen shake. It still drops its EXP spray.

@export var curve: Curve = null

const DRAIN_INTERVAL: float = 0.33
const DRAIN_DAMAGE_FACTOR: float = 6.0
const DRAIN_DAMAGE_TYPE: int = global.DAMAGE_TYPES.EXOTIC
const BOSS_SLOW: float = 0.4
const BOSS_TUG: float = 45.0           # px/s towards the centre: under the slowed walk, so never stuck
const FINISHER_HP_SHARE: float = 0.1
const FINISHER_TIME: float = 0.9
const FINISHER_TURNS: float = 1.75     # times round the centre while falling in
const FINISHER_RING_RADIUS: float = 260.0
const FINISHER_RING_TINT := Color(1.0, 0.55, 1.0)
# A boss can touch two black holes at once: count the slows, keep its speed.
const SLOW_COUNT_META: StringName = &"_black_hole_slows"
const BASE_SPEED_META: StringName = &"_black_hole_base_speed"

var _bosses: Dictionary = {}   # boss touching it -> seconds until its next drain


func _ready() -> void:
	body_exited.connect(_on_body_exited)


func on_hit_connect(body: Node2D) -> void:
	if body.shrinking:
		return
	if body.get("asBoss") == true:
		_boss_entered(body)
		return

	body.set_process(false)
	var shrinkTween: Tween = get_tree().create_tween()
	var method: Callable = func(value: float):
		body.scale = Vector2.ONE * curve.sample(value)
		body.global_position = body.global_position.move_toward(global_position, 10.0)
	shrinkTween.tween_method(method,
		0.0, 0.75, 0.15
	)
	shrinkTween.finished.connect(func():
		AchievementManager.push_source(&"black_hole")
		body.handle_death()
		AchievementManager.pop_source()
	)

	body.collision_layer = 0
	body.collision_mask = 0
	body.shrinking = true
	body.crowdRadius = 0.0


# --- Bosses -------------------------------------------------------------------

func _boss_entered(boss: Node2D) -> void:
	if _bosses.has(boss):
		return
	if _finisher_ready(boss):
		_swallow_boss(boss)
		return
	_bosses[boss] = 0.0   # the first drain lands right away
	_set_slowed(boss, true)


func _on_body_exited(body: Node2D) -> void:
	if _bosses.has(body):
		_bosses.erase(body)
		_set_slowed(body, false)


func _physics_process(delta: float) -> void:
	if _bosses.is_empty():
		return
	for boss in _bosses.keys():
		if not is_instance_valid(boss) or boss.shrinking or boss.dead:
			_bosses.erase(boss)
			continue
		if _finisher_ready(boss):
			_swallow_boss(boss)
			continue
		boss.externalNonDecayVelocity += boss.global_position.direction_to(global_position) * BOSS_TUG
		_bosses[boss] -= delta
		if _bosses[boss] <= 0.0:
			_bosses[boss] += DRAIN_INTERVAL
			_drain(boss)


func _drain(boss: Node2D) -> void:
	var stats = global.PLAYER.stats.activeModifiers.get("starStats") if is_instance_valid(global.PLAYER) else null
	var star_damage: float = stats.damage if stats else 15.0
	var damage: float = DRAIN_DAMAGE_FACTOR * star_damage * scale.x   # scale grows with Feed the Monster
	global.add_damage_text(boss.global_position, damage, DRAIN_DAMAGE_TYPE)
	AchievementManager.hit(boss, damage, &"black_hole")


func _finisher_ready(boss: Node2D) -> bool:
	return boss.stats.maxHp > 0.0 and boss.stats.hp > 0.0 \
		and boss.stats.hp <= boss.stats.maxHp * FINISHER_HP_SHARE


## Slows the boss while it touches a black hole (`on`), back to its own
## speed once it touches none.
func _set_slowed(boss: Node2D, on: bool) -> void:
	if not is_instance_valid(boss):
		return
	var count: int = boss.get_meta(SLOW_COUNT_META, 0)
	if on:
		if count == 0:
			boss.set_meta(BASE_SPEED_META, boss.followSpeed)
			boss.followSpeed *= BOSS_SLOW
		boss.set_meta(SLOW_COUNT_META, count + 1)
	elif count > 0:
		boss.set_meta(SLOW_COUNT_META, count - 1)
		if count == 1:
			boss.followSpeed = boss.get_meta(BASE_SPEED_META)


## The finisher: the boss spirals in, spinning faster as it falls, with a
## flash, a ring, a rumble and a shake; then dies as usual (EXP spray included).
func _swallow_boss(boss: Node2D) -> void:
	_bosses.erase(boss)
	boss.shrinking = true
	boss.crowdRadius = 0.0
	boss.collision_layer = 0
	boss.collision_mask = 0
	boss.set_physics_process(false)
	var start_offset: Vector2 = boss.global_position - global_position
	var start_scale: Vector2 = boss.scale

	global.activeCamera.shake(14.0)
	global.vibrate_handheld(220, 0.5)
	global.WORLD.audio_2d_play(preload("res://Assets/SFX/GravityBombImpact.wav"), global_position, "game_world")
	var ring: Node2D = preload("res://Scripts/revive_shockwave.gd").new()
	ring.maxRadius = FINISHER_RING_RADIUS
	ring.modulate = FINISHER_RING_TINT
	ring.global_position = global_position
	global.WORLD.add_child(ring)
	var sprite: Node2D = $EffectSprite
	var pulse := create_tween()
	pulse.tween_property(sprite, "scale", sprite.scale * 1.35, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(sprite, "scale", sprite.scale, FINISHER_TIME)

	boss.modulate = Color(2.2, 2.2, 2.2)   # a flash as it is caught
	var tween := get_tree().create_tween()
	tween.tween_property(boss, "modulate", Color.WHITE, 0.25)
	tween.parallel().tween_method(func(t: float):
		if not is_instance_valid(boss):
			return
		var fall: float = t * t
		var angle: float = FINISHER_TURNS * TAU * fall
		boss.global_position = global_position + start_offset.rotated(angle) * (1.0 - fall)
		boss.scale = start_scale * (1.0 - fall)
		boss.rotation = angle * 0.5
	, 0.0, 1.0, FINISHER_TIME)
	tween.finished.connect(func():
		if not is_instance_valid(boss):
			return
		AchievementManager.push_source(&"black_hole")
		boss.handle_death()
		AchievementManager.pop_source()
	)


func _exit_tree() -> void:
	for boss in _bosses:
		_set_slowed(boss, false)
	_bosses.clear()
