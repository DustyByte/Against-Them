class_name RuptureAmmo
extends Area2D

var GPUParticles: GPUParticles2D
var shotDirection: Vector2 = Vector2.ZERO
var shooter: CharacterBody2D = null
var speed: float = 1500.0
var carryingKnockBackIntensity: float = 0
var carryingDamage: float = 0
var maxDisplacement: float = 5000.0
var totalDisplacement: float = 0.0


func init(givenShotDirection: Vector2, barrelGlobalAt: Vector2, givenDamage: float, givenKnockBAckIntensity: float, excessSpeed: float = 0.0, givenShooter: CharacterBody2D = global.PLAYER) -> void:
	speed += excessSpeed
	
	shooter = givenShooter
	shotDirection = givenShotDirection
	
	global_position = barrelGlobalAt
	rotation = Vector2.RIGHT.angle_to(shotDirection)
	
	carryingDamage = givenDamage
	carryingKnockBackIntensity = givenKnockBAckIntensity


func throw_particles(particleColor: Color = Color.WHITE) -> void:
	GPUParticles = global.WORLD.get_throwable_gpu_particles()
	GPUParticles.position = global_position
	
	GPUParticles.modulate = particleColor
	GPUParticles.restart()


func _process(delta: float) -> void:
	if shotDirection:
		var displacement: float = speed * delta
		position += shotDirection * displacement
		totalDisplacement += displacement
		
		if totalDisplacement > maxDisplacement:
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_meta('avgColor'):
		throw_particles(body.get_meta('avgColor'))
	else:
		throw_particles()
	
	if body.is_in_group('enemy'):
		body.get_knocked_back(shotDirection, carryingKnockBackIntensity)
		body.get_hit(carryingDamage)
		
		global.add_damage_text(global_position, carryingDamage, global.DAMAGE_TYPES.PHYSICAL, randf()<0.1)
		
	queue_free()
