class_name Tornado
extends Area2D

const BASE_SPEED: float = 300.0

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var onRunFeatures: Script = global.ON_RUN_FEATURES
@onready var player: Player = global.PLAYER

var direction: Vector2 = Vector2.ZERO
var lifeTime: float = 4.0
var time: float = 0.0 # in sec
var stats: Dictionary = {}
var hasFreeze: bool = false
var hasLightning: bool = false


func init(startFromGlobal: Vector2, givenDirection: Vector2, givenStats: Dictionary) -> void:
	global_position = startFromGlobal
	direction = givenDirection
	stats = givenStats
	
	dirWSpeed = direction * BASE_SPEED


func respawn() -> void:
	var nearestEnemy = player.get_nearest_attackable_or_null()
	var playerGlobalPosition: Vector2 = player.global_position
	
	time = 0.0
	global_position = playerGlobalPosition
	visible = true
	particles.lifetime = 1.9
	particles.emitting = true
	
	if nearestEnemy:
		direction = playerGlobalPosition.direction_to(nearestEnemy.global_position)
	else:
		direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	dirWSpeed = direction * BASE_SPEED
	set_process(true)


func deactivate() -> void:
	visible = false
	particles.emitting = false
	particles.lifetime = 0.01
	set_process(false)


func handle_hit_connect(body: Node2D) -> void:
	var d: float = stats.damage
	AchievementManager.hit(body, d, &"silver_storm")
	global.add_damage_text(body.global_position, d, 2)
	if hasFreeze or stats.has('freeze'):
		hasFreeze = true
		onRunFeatures.freeze_inflict(body)
	if hasLightning or stats.has('lightning'):
		hasLightning = true
		onRunFeatures.lightning_strike(body, d, 0, &"silver_storm")


func _ready() -> void:
	body_entered.connect(handle_hit_connect)


var dirWSpeed: Vector2
func _process(delta: float) -> void:
	position += delta * dirWSpeed
	
	time += delta
	if time >= lifeTime:
		get_tree().create_timer(stats.cd).timeout.connect(respawn)
		deactivate()
