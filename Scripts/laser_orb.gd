class_name LaserOrb
extends Node2D

const BEAM_MAX_REACH: float = 1500.0
const BREATHE_ANIMATION_RANGE: float = 10.0

@onready var beam: Line2D = $Beam/Line2D
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
var beamInitWidth: float = -1.0
var stats: Dictionary = {}
var damageType: int = global.DAMAGE_TYPES.INFERNO
var towards: Vector2 = Vector2.RIGHT
var lockedHitTime: float = 0.0
var isLockedOn: bool = false
var lockedEnemy: CharacterBody2D = null


func setup(givenStats: Dictionary) -> void:
	stats = givenStats


func hit() -> void:
	var enemies: Array[Node2D] = beamArea.get_overlapping_bodies()
	var d: float = stats.damage
	for enemy in enemies:
		AchievementManager.hit(enemy, d, &"laser_orb")
		global.add_damage_text(enemy.global_position, d, damageType)
		var t: int = Time.get_ticks_usec()
		if not enemy.marks.has('burn'):
			burnMethod.call(enemy, stats.burnDamage)


func beam_width_tween_method(val: float) -> void:
	beam.width = beamCurve.sample_baked(val) * beamInitWidth


func discharge_reset() -> void:
	beam.visible = false
	beamArea.monitoring = false


func adjust_beam_thickness() -> void:
	var beamThickness: float = stats.beamThickness
	beamInitWidth = beamThickness
	collisionShape.size.y = beamThickness + 3


func discharge_make_ready() -> void:
	beam.visible = true
	beamArea.monitoring = true
	adjust_beam_thickness()


func discharge() -> void:
	var enemy: CharacterBody2D = player.get_nearest_attackable_or_null()
	if not enemy:
		get_tree().create_timer(stats.cd).timeout.connect(lock_discharge if stats.hasLock else discharge)
		return
	
	discharge_make_ready()
	
	towards = global_position.direction_to(enemy.global_position) # add sprite offset here
	beamArea.rotation = towards.angle()
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(beam_width_tween_method, 0.0, 1.0, 0.2)
	tween.finished.connect(discharge_reset)
	
	tween.finished.connect(func():
		tree.create_timer(stats.cd).timeout.connect(lock_discharge if stats.hasLock else discharge)
	)
	
	await tree.physics_frame
	await tree.physics_frame
	hit()


func lock_discharge() -> void:
	lockedEnemy = player.get_nearest_attackable_or_null()
	if not lockedEnemy:
		tree.create_timer(stats.cd).timeout.connect(lock_discharge)
		return
	
	isLockedOn = true
	lockedEnemy.tree_exited.connect(func():
		discharge_reset()
		isLockedOn = false
		lockedEnemy = null
		lockedHitTime = 0.0
		tree.create_timer(stats.cd).timeout.connect(lock_discharge)
	)
	discharge_make_ready()
	
	var method: Callable = func(val: float):
		beam.width = beamInitWidth * beamCurve.sample_baked(val)
	tree.create_tween().tween_method(method, 0.0, 0.2, 0.1)
	
	await tree.physics_frame
	await tree.physics_frame
	await tree.physics_frame
	hit()


func _process(delta: float) -> void:
	if isLockedOn:
		towards = global_position.direction_to(lockedEnemy.global_position) # add sprite offset here
		beamArea.rotation = towards.angle()
		lockedHitTime += delta
		if lockedHitTime >= 0.3:
			hit()
			lockedHitTime = 0.0


func breathe_animation_method(val: float) -> void:
	avatar.offset.y = avatarOffsetYinit + BREATHE_ANIMATION_RANGE * breatheAnimationCurve.sample_baked(val)


func animate() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(breathe_animation_method, 0.0, 1.0, 2.0)
	tween.finished.connect(animate)


func _ready() -> void:
	adjust_beam_thickness()
	get_tree().create_timer(stats.cd).timeout.connect(lock_discharge if stats.hasLock else discharge)
	avatarOffsetYinit = avatar.offset.y
	
	animate()
