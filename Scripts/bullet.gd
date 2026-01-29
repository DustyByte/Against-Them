class_name Bullet
extends Area2D

@onready var GPUParticlesBluePrint: PackedScene = preload("res://Scenes/particles_throw.tscn")
@onready var polygon: Polygon2D = $Polygon2D
var GPUParticles: GPUParticles2D
var shotDirection: Vector2 = Vector2.ZERO
var shooter: PhysicsBody2D = null
var speed: float = 1500.0
var carryingKnockBackIntensity: float = 0
var carryingDamage: float = 0


func set_shot_direction(direction: Vector2) -> void:
	shotDirection = direction


func set_shooter(givenShooter: PhysicsBody2D) -> void:
	shooter = givenShooter


func throw_particles() -> void:
	GPUParticles = GPUParticlesBluePrint.instantiate()
	add_child(GPUParticles)
	GPUParticles.emitting = true


func _process(delta: float) -> void:
	if shotDirection:
		position += speed * shotDirection * delta
	
	if shooter.global_position.distance_to(global_position) > 5000:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		throw_particles()
		polygon.visible = false
		speed = 0
		collision_layer = 0
		collision_mask = 0
		
		body.get_knocked_back(shotDirection, carryingKnockBackIntensity)
		body.get_hit(carryingDamage)
		
		await GPUParticles.finished
		queue_free()
