class_name Cryolite
extends Sprite2D

const BREATHE_ANIMATION_RANGE: float = 10.0
@export var breatheAnimationCurve: Curve = null
var player: CharacterBody2D = null
var world: Node2D = null
var icicleBP: PackedScene = preload("res://Scenes/Allies&Summons/icicle.tscn")
var avatarOffsetYinit: float = NAN
var damageType: int = -1
var stats: Dictionary = {}
var breatheAnimationMethod: Callable = func(val: float):
	offset.y = avatarOffsetYinit + BREATHE_ANIMATION_RANGE * breatheAnimationCurve.sample_baked(val)


func setup(statsGiven: Dictionary) -> void:
	stats = statsGiven


func throw_icicle() -> void:
	for i in range(stats.amount):
		await get_tree().create_timer(0.075).timeout
		
		var target: Node2D = player.get_nearest_attackable_or_null()
		if not target:
			continue
		
		var targetGlobPos: Vector2 = target.global_position
		var globPosWOffset: Vector2 = global_position + offset
		var towards: Vector2 = globPosWOffset.direction_to(targetGlobPos)
		var icicle: Icicle = icicleBP.instantiate()
		
		icicle.setup(towards, stats.damage, damageType, stats.knockBackIntensity, stats.freezeDuration, stats.lifeSteal, stats.icicleExplosion)
		icicle.global_position = globPosWOffset
		world.add_child(icicle)
		
	
	get_tree().create_timer(stats.cd).timeout.connect(throw_icicle)


func animate() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(breatheAnimationMethod, 0.0, 1.0, 2.0)
	tween.finished.connect(animate)


func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	player = global.PLAYER
	world = global.WORLD
	throw_icicle()
	
	avatarOffsetYinit = offset.y
	animate()
	
	damageType = stats.damageType
