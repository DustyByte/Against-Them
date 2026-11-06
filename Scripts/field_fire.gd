class_name FieldFire
extends Area2D

const SPEED: float = 2000.0
var explosionParticles: GPUParticles2D = null
var fire: GPUParticles2D = null
var avatar: Sprite2D = null
var stats: Dictionary = {}
var target: Vector2
var dir: Vector2 = Vector2.ZERO
var active: bool = true
var damageType: int = -1


func handle_exit() -> void:
	fire.emitting = false
	await get_tree().create_timer(fire.lifetime).timeout
	queue_free()


func launch(formGlob: Vector2, toGlob: Vector2) -> void:
	global_position = formGlob
	target = toGlob
	dir = global_position.direction_to(target)
	avatar.rotation += Vector2.DOWN.angle_to(dir)
	requiredTravelDist = (toGlob - formGlob).length()


func explode() -> void:
	explosionParticles.visible = true 
	fire.visible = true 
	explosionParticles.emitting = true
	fire.emitting = true
	monitoring = true
	
	global.activeCamera.shake(5.0)
	
	global.WORLD.audio_2d_play(preload("res://Assets/SFX/FireBombImpact.wav"), global_position, "game_world", randf_range(0.9, 1.1))
	
	explosionParticles.finished.connect(explosionParticles.queue_free)
	get_tree().create_timer(stats.duration).timeout.connect(handle_exit)
	
	hit()


func hit() -> void:
	var enemies: Array[Node2D] = get_overlapping_bodies()
	for enemy in enemies:
		var damage: float = stats.damage
		enemy.get_hit(damage)
		global.add_damage_text(enemy.global_position, damage, damageType)
	
	get_tree().create_timer(stats.hitCD).timeout.connect(hit)


func burn_at_entry(body: Node2D) -> void:
	global.ON_RUN_FEATURES.burn_inflict(body, stats.burnDamage)


func explode_frozen_enemies_at_entry(enemy: Node2D) -> void:
	if not enemy.marks.has('freeze'):
		return
	
	enemy.get_hit(INF, false)
	var icicleBP: PackedScene = load("res://Scenes/Allies&Summons/icicle.tscn")
	var world: Node2D = global.WORLD
	var d: float = 5.0
	var kbi: float = 10.0
	var from: Vector2 = enemy.global_position
	const PARAM: float = TAU / 3
	for i in range(3):
		var icicle: Icicle = icicleBP.instantiate()
		var direction: Vector2 = Vector2.from_angle((i+1) * PARAM)
		icicle.global_position = from
		icicle.setup(direction, d, 2, kbi, 0.0)
		world.add_child.call_deferred(icicle)


func _ready() -> void:
	explosionParticles = $Explosion
	fire = $Fire
	avatar = $Sprite2D
	stats = get_parent().stats
	
	var rad: float = stats.radius
	fire.process_material.emission_sphere_radius = rad
	$CollisionShape2D.shape.radius = rad
	
	damageType = global.DAMAGE_TYPES.INFERNO
	
	body_entered.connect(burn_at_entry)
	if stats.hasBrittleVeins:
		body_entered.connect(explode_frozen_enemies_at_entry)


var travelledDist: float = 0.0
var requiredTravelDist: float = -1.0
func _process(delta: float) -> void:
	if active:
		if travelledDist >= requiredTravelDist:
			global_position += dir * 16.65
			explode()
			avatar.queue_free()
			active = false
			return
		var step: Vector2 = dir * SPEED * delta
		travelledDist += step.length()
		position += step
