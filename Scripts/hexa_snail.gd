extends Node2D

@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var preStrikeEffectSprite: Sprite2D = $PreStrikeEffect
@export var speed: float = 100.0
@export var curve: Curve = Curve.new()
var features: Script = preload("res://Scripts/on_run_features.gd")
var preStrikeShader: Shader = preload("res://Shaders/starryGlow.gdshader")
var flag: Node2D = null
var velocity: Vector2 = Vector2.ZERO
var stats: Dictionary = {}
var enemyDetectionRange: Area2D = null


func set_stats(givenStats: Dictionary) -> void:
	stats = givenStats


func set_flag(givenFlag: Node2D) -> void:
	flag = givenFlag


func set_range(givenDetectionRange: Area2D) -> void:
	enemyDetectionRange = givenDetectionRange


func step_follow_flag(delta: float) -> void:
	var distanceSquared: float = global_position.distance_squared_to(flag.global_position)
	if  distanceSquared < 16:
		velocity = Vector2.ZERO
		return
	
	var direction: Vector2 = global_position.direction_to(flag.global_position)
	var displacement: Vector2 = direction * speed * delta
	
	velocity = displacement / delta
	global_position += displacement


func strike_random_nearby() -> void:
	var enemies: Array =  enemyDetectionRange.get_overlapping_bodies()
	if enemies.is_empty():
		return
	
	animate_strike_opening() # asynchronous
	var targetPosition: Vector2 = enemies.pick_random().global_position
	features.lightning_strike(targetPosition)


func animate_strike_opening() -> void:
	var tween: Tween = get_tree().create_tween()
	
	preStrikeEffectSprite.visible = true
	preStrikeEffectSprite.material.set_shader(preStrikeShader)
	
	tween.tween_method(
		func(changingCurveX: float): preStrikeEffectSprite.material.set_shader_parameter("radius", curve.sample(changingCurveX)),
		0.0, 1.0, 0.5
	)
	tween.finished.connect(func(): 
		preStrikeEffectSprite.material.set_shader(null)
		preStrikeEffectSprite.visible = false
	)


func handle_timer() -> void:
	strike_random_nearby()
	get_tree().create_timer(stats.baseCD * stats.attackSpeed).timeout.connect(handle_timer)


func _ready() -> void:
	get_tree().create_timer(stats.baseCD * stats.attackSpeed).timeout.connect(handle_timer)


func _process(delta: float) -> void:
	if flag:
		step_follow_flag(delta)
	
	if velocity: # merge this logic into step_follow_flag() to optimise computation and memory effeciency
		if velocity.x > 0:
			scale = Vector2.ONE
		else:
			scale = Vector2(-1, 1)
		return
