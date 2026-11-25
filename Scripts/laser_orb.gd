class_name LaserOrb
extends Node2D

## The Wisp (the level-up option is named "Wisp"; the files keep the old
## laser-orb names). A little red flame-spirit beside Echo that fires a laser
## beam at the nearest enemy.
##
## Look: a body sprite with its star-eye (WispBody.svg), a living flame behind
## it (WispFlame.svg + wisp_flame.gdshader) and sparks above it
## (wisp_sparks.gdshader on a blank quad). The beam is one stretched quad
## (wisp_beam.gdshader); the muzzle flare and the impact splash are two small
## quads (wisp_burst.gdshader).
##
## A shot: CHARGE_TIME of charge (the eye brightens, an aiming thread runs
## out), then the beam bursts on and hits, holds briefly, and FADE_TIME of fade
## (it breaks into tapering pieces that shed embers). With Focus the beam stays
## locked on until the enemy dies; with Eliminate it grows every second, each
## step sending a pulse down the beam and shaking the screen.

const BEAM_MAX_REACH: float = 1500.0
const BREATHE_ANIMATION_RANGE: float = 10.0
# Eliminate: every second the beam stays locked on the same enemy, it gets
# 20% thicker and stronger, up to 3x. Resets when that enemy dies.
const ELIMINATE_INTERVAL: float = 1.0
const ELIMINATE_GROWTH: float = 0.2
const ELIMINATE_MAX: float = 3.0
const CHARGE_TIME: float = 0.15
const SHOT_HOLD: float = 0.15
const FADE_TIME: float = 0.4
const BEAM_CAP: float = 70.0          # the beam quad starts this far behind the eye
## The everyday beam is drawn at this share of its old width; a fully grown
## Eliminate beam (3x) still reaches the old full width.
const BEAM_WIDTH_SHARE: float = 0.55
## Screen shake for each Eliminate step: grows from the first step to the last.
const ELIMINATE_SHAKE_MIN: float = 6.0
const ELIMINATE_SHAKE_MAX: float = 16.0
## Where the eye is, relative to the body texture's centre (px).
const EYE_OFFSET: Vector2 = Vector2(0, 10)

const FLAME_TEXTURE: Texture2D = preload("res://Assets/Alles&Summons/LaserOrb/WispFlame.svg")
const FLAME_SHADER: Shader = preload("res://Shaders/wisp_flame.gdshader")
const SPARKS_SHADER: Shader = preload("res://Shaders/wisp_sparks.gdshader")
const BEAM_SHADER: Shader = preload("res://Shaders/wisp_beam.gdshader")
const BURST_SHADER: Shader = preload("res://Shaders/wisp_burst.gdshader")
const SPARKS_AREA: Vector2 = Vector2(48, 80)

@onready var player: Player = global.PLAYER
@onready var collision: CollisionShape2D = $Beam/CollisionShape2D
@onready var collisionShape: Shape2D = collision.shape
@onready var beamArea: Area2D = $Beam
@onready var avatar: Sprite2D = $Sprite2D
@onready var burnMethod: Callable = global.ON_RUN_FEATURES.burn_inflict
@onready var tree: SceneTree = get_tree()
@export var beamCurve: Curve = null
@export var breatheAnimationCurve: Curve = null
var avatarOffsetYinit: float = NAN
var stats: Dictionary = {}
var damageType: int = global.DAMAGE_TYPES.INFERNO
var towards: Vector2 = Vector2.RIGHT
var lockedHitTime: float = 0.0
var isLockedOn: bool = false
var lockedEnemy: CharacterBody2D = null
var lockedDuration: float = 0.0
var eliminateBoost: float = 1.0

var _flame: Sprite2D
var _sparks: Sprite2D
var _beamQuad: Sprite2D
var _beamMat: ShaderMaterial
var _muzzle: Sprite2D
var _muzzleMat: ShaderMaterial
var _impact: Sprite2D
var _impactMat: ShaderMaterial
var _fadeTween: Tween = null
var _shotId: int = 0   # a fade only hides the beam if no newer shot has started


func setup(givenStats: Dictionary) -> void:
	stats = givenStats


func hit() -> void:
	var enemies: Array[Node2D] = beamArea.get_overlapping_bodies()
	var d: float = stats.damage * eliminateBoost
	for enemy in enemies:
		AchievementManager.hit(enemy, d, &"laser_orb")
		global.add_damage_text(enemy.global_position, d, damageType)
		if not enemy.marks.has('burn'):
			burnMethod.call(enemy, stats.burnDamage)


# --- The beam's look ------------------------------------------------------------

func _set_beam(key: String, value) -> void:
	_beamMat.set_shader_parameter(key, value)


func _tween_beam(key: String, from: float, to: float, time: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_method(func(v: float): _set_beam(key, v), from, to, time)
	return tween


## Beam width on screen grows gently with Thiccer Beam; the quad is made tall
## enough for the glow at the current Eliminate level, so it's never cut off.
func _beam_width_px() -> float:
	return (10.0 + stats.beamThickness * 1.7) * BEAM_WIDTH_SHARE


## How much wider the drawn beam is at an Eliminate boost: it grows faster than
## the boost, so the thinner everyday beam still reaches the same full width
## at the 3x cap (1 / BEAM_WIDTH_SHARE x 3).
func _visual_level(boost: float) -> float:
	var top: float = ELIMINATE_MAX / BEAM_WIDTH_SHARE
	return lerpf(1.0, top, (boost - 1.0) / (ELIMINATE_MAX - 1.0))


func adjust_beam_thickness() -> void:
	var beamThickness: float = stats.beamThickness * eliminateBoost
	collisionShape.size.y = beamThickness + 3
	var width: float = _beam_width_px()
	var height: float = clampf(width * _visual_level(eliminateBoost) * 4.5, 120.0, 900.0)
	_beamQuad.scale = Vector2(BEAM_MAX_REACH + BEAM_CAP, height)
	_set_beam("width_px", width)
	_set_beam("height_px", height)
	_set_beam("level", _visual_level(eliminateBoost))


func _aim(at: Vector2) -> void:
	towards = global_position.direction_to(at)
	beamArea.rotation = towards.angle()
	_impactMat.set_shader_parameter("aim", towards)


## Eye brightens, an aiming thread runs out; resolves when it's time to fire.
func _charge(at: Vector2) -> void:
	_shotId += 1
	if _fadeTween and _fadeTween.is_valid():
		_fadeTween.kill()   # a quick cooldown can start the next shot mid-fade
	_aim(at)
	_set_beam("fade", 0.0)
	_set_beam("power", 0.0)
	_set_beam("pulse", -1.0)
	_beamQuad.visible = true
	_muzzle.visible = true
	_muzzleMat.set_shader_parameter("looping", false)
	var eye: Tween = create_tween()
	eye.tween_method(func(v: float): _muzzleMat.set_shader_parameter("age", v), 1.0, 0.45, CHARGE_TIME)
	await _tween_beam("charge", 0.0, 1.0, CHARGE_TIME).finished


## The beam bursts on, with a muzzle flare and a splash where it lands.
func _fire(at: Vector2, held: bool) -> void:
	_set_beam("charge", 0.0)
	_tween_beam("power", 0.0, 1.0, 0.06)
	var flare: Tween = create_tween()
	flare.tween_method(func(v: float): _muzzleMat.set_shader_parameter("age", v), 0.0, 1.0, 0.35)
	_impact.global_position = at
	_impact.visible = true
	_impactMat.set_shader_parameter("looping", held)
	if held:
		_impactMat.set_shader_parameter("age", 0.0)
	else:
		var splash: Tween = create_tween()
		splash.tween_method(func(v: float): _impactMat.set_shader_parameter("age", v), 0.0, 1.0, 0.5)
	beamArea.monitoring = true


## The beam breaks up and fades; everything hides afterwards.
func _fade() -> void:
	beamArea.monitoring = false
	_impactMat.set_shader_parameter("looping", false)
	var splash: Tween = create_tween()
	splash.tween_method(func(v: float): _impactMat.set_shader_parameter("age", v), 0.3, 1.0, 0.3)
	var shot: int = _shotId
	_fadeTween = _tween_beam("fade", 0.0, 1.0, FADE_TIME)
	await _fadeTween.finished
	if shot != _shotId:
		return
	_set_beam("power", 0.0)
	_set_beam("pulse", -1.0)
	_beamQuad.visible = false
	_impact.visible = false


func discharge_reset() -> void:
	beamArea.monitoring = false
	_beamQuad.visible = false
	_impact.visible = false


# --- Firing ----------------------------------------------------------------------

func _next_shot() -> void:
	tree.create_timer(stats.cd).timeout.connect(lock_discharge if stats.hasLock else discharge)


func discharge() -> void:
	var enemy: CharacterBody2D = player.get_nearest_attackable_or_null()
	if not enemy:
		_next_shot()
		return
	var at: Vector2 = enemy.global_position
	await _charge(at)
	if is_instance_valid(enemy):
		at = enemy.global_position
		_aim(at)
	_fire(at, false)
	_next_shot()   # the cooldown runs from the shot, not from the end of the fade
	await tree.physics_frame
	await tree.physics_frame
	hit()
	await tree.create_timer(SHOT_HOLD).timeout
	await _fade()


func lock_discharge() -> void:
	lockedEnemy = player.get_nearest_attackable_or_null()
	if not lockedEnemy:
		_next_shot()
		return
	var target: CharacterBody2D = lockedEnemy
	await _charge(target.global_position)
	if not is_instance_valid(target) or target.get("dead") == true:
		discharge_reset()
		lockedEnemy = null
		_next_shot()
		return

	isLockedOn = true
	target.tree_exited.connect(func():
		isLockedOn = false
		lockedEnemy = null
		lockedHitTime = 0.0
		lockedDuration = 0.0
		eliminateBoost = 1.0
		_fade_then_reset()
	)
	_aim(target.global_position)
	_fire(target.global_position, true)
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	hit()


func _fade_then_reset() -> void:
	await _fade()
	adjust_beam_thickness()
	_next_shot()


## One Eliminate step: the beam swells, a pulse runs down it and the screen
## shakes, harder the further it has grown.
func _eliminate_step(boost: float) -> void:
	var from: float = eliminateBoost
	eliminateBoost = boost
	adjust_beam_thickness()
	_set_beam("level", _visual_level(from))
	_tween_beam("level", _visual_level(from), _visual_level(boost), 0.25)
	_tween_beam("pulse", 0.0, 1.0, 0.45)
	var t: float = (boost - 1.0) / (ELIMINATE_MAX - 1.0)
	global.activeCamera.shake(lerpf(ELIMINATE_SHAKE_MIN, ELIMINATE_SHAKE_MAX, t))


func _process(delta: float) -> void:
	# The sparks and flare follow the eye as the wisp bobs.
	var eye: Vector2 = Vector2(0, avatar.position.y + avatar.offset.y) + EYE_OFFSET
	_muzzle.position = eye
	beamArea.position = eye
	if isLockedOn and is_instance_valid(lockedEnemy):
		_aim(lockedEnemy.global_position)
		_impact.global_position = lockedEnemy.global_position
		lockedHitTime += delta
		if stats.get("eliminate", false):
			lockedDuration += delta
			var boost: float = minf(1.0 + ELIMINATE_GROWTH * floorf(lockedDuration / ELIMINATE_INTERVAL), ELIMINATE_MAX)
			if boost != eliminateBoost:
				_eliminate_step(boost)
		if lockedHitTime >= 0.3:
			hit()
			lockedHitTime = 0.0


# --- The wisp itself -------------------------------------------------------------

func breathe_animation_method(val: float) -> void:
	avatar.offset.y = avatarOffsetYinit + BREATHE_ANIMATION_RANGE * breatheAnimationCurve.sample_baked(val)
	_flame.position.y = avatar.offset.y
	_sparks.position.y = avatar.offset.y - 11.0 - SPARKS_AREA.y * 0.42


func animate() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(breathe_animation_method, 0.0, 1.0, 2.0)
	tween.finished.connect(animate)


func _blank_quad() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _build_look() -> void:
	var white: ImageTexture = _blank_quad()
	# Flame behind the body, sparks above it: children of the body sprite, so
	# they keep its y-sorting; breathe_animation_method moves them with it.
	_flame = Sprite2D.new()
	_flame.texture = FLAME_TEXTURE
	_flame.show_behind_parent = true
	var flameMat := ShaderMaterial.new()
	flameMat.shader = FLAME_SHADER
	flameMat.set_shader_parameter("phase", randf() * 20.0)
	_flame.material = flameMat
	avatar.add_child(_flame)

	_sparks = Sprite2D.new()
	_sparks.texture = white
	_sparks.scale = SPARKS_AREA
	_sparks.position.x = 2.0
	var sparksMat := ShaderMaterial.new()
	sparksMat.shader = SPARKS_SHADER
	sparksMat.set_shader_parameter("size_px", SPARKS_AREA)
	sparksMat.set_shader_parameter("phase", randf() * 10.0)
	_sparks.material = sparksMat
	avatar.add_child(_sparks)

	# Beam quad: inside the rotating Beam area, starting BEAM_CAP behind the eye.
	_beamQuad = Sprite2D.new()
	_beamQuad.texture = white
	_beamQuad.centered = false
	_beamQuad.offset = Vector2(0, -0.5)
	_beamQuad.position = Vector2(-BEAM_CAP, 0)
	_beamQuad.z_index = 2
	_beamQuad.visible = false
	_beamMat = ShaderMaterial.new()
	_beamMat.shader = BEAM_SHADER
	_beamMat.set_shader_parameter("length_px", BEAM_MAX_REACH + BEAM_CAP)
	_beamMat.set_shader_parameter("cap_px", BEAM_CAP)
	_beamQuad.material = _beamMat
	beamArea.add_child(_beamQuad)

	_muzzle = _burst_quad(white, 70.0, 0, 1.0)
	_muzzle.visible = false
	_muzzleMat = _muzzle.material
	add_child(_muzzle)

	_impact = _burst_quad(white, 110.0, 12, 0.5)
	_impact.top_level = true   # sits on the enemy, not on the wisp
	_impact.visible = false
	_impactMat = _impact.material
	add_child(_impact)


func _burst_quad(white: Texture2D, size: float, sparkCount: int, glint: float) -> Sprite2D:
	var quad := Sprite2D.new()
	quad.texture = white
	quad.scale = Vector2(size, size)
	quad.z_index = 3
	var mat := ShaderMaterial.new()
	mat.shader = BURST_SHADER
	mat.set_shader_parameter("size_px", size)
	mat.set_shader_parameter("sparks", sparkCount)
	mat.set_shader_parameter("glint", glint)
	mat.set_shader_parameter("age", 1.0)
	quad.material = mat
	return quad


func _ready() -> void:
	# Own copy of the beam shape: Eliminate thickens each wisp's beam separately.
	collisionShape = collisionShape.duplicate()
	collision.shape = collisionShape
	_build_look()
	adjust_beam_thickness()
	_next_shot()
	avatarOffsetYinit = avatar.offset.y
	breathe_animation_method(0.0)
	animate()
