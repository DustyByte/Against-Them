class_name TorcherAmmo
extends Area2D


@onready var sprite: Sprite2D = $Sprite2D
@onready var GPUParticles: GPUParticles2D = $GPUParticles2D
@export var initSpeed: float = 500.0
@export var decelerationCurve: Curve
var speed: float = 0.0
var shotDirection: Vector2 = Vector2.ZERO
var carryingDamage: float = 0.0
var carryingKnockBackIntensity: float = 0.0
var slider: float = 0.0


func init(givenShotDirection: Vector2, barrelGlobalAt: Vector2, givenDamage: float, givenKnockBackIntensity: float, excessSpeed: float = 0.0) -> void:
	initSpeed += excessSpeed
	shotDirection = givenShotDirection
	carryingDamage = givenDamage
	carryingKnockBackIntensity = givenKnockBackIntensity
	
	rotation = Vector2.RIGHT.angle_to(shotDirection)
	global_position = barrelGlobalAt


func handleBulletConnect(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		body.get_hit(carryingDamage)
		body.get_knocked_back(shotDirection, carryingKnockBackIntensity)
		global.add_damage_text(body.global_position, carryingDamage, global.DAMAGE_TYPES.INFERNO)
		global.ON_RUN_FEATURES.burn_inflict(body)
		return 
	
	collision_mask = 0
	sprite.visible = false
	
	GPUParticles.one_shot = true
	GPUParticles.emitting = false
	GPUParticles.amount = 8
	GPUParticles.explosiveness = 1.0
	GPUParticles.finished.connect(queue_free)
	GPUParticles.emitting = true
	set_process(false)


func _ready() -> void:
	body_entered.connect(handleBulletConnect)
	speed = initSpeed


func _process(delta: float) -> void:
	position += shotDirection * speed * delta
	
	speed = initSpeed * decelerationCurve.sample_baked(slider)
	slider += 0.02
	if speed <= 0.0:
		queue_free()
