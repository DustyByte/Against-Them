class_name GravityBomb
extends Area2D

const SPEED: float = 1500.0
var pullStrength: float = -1.0
var dir: Vector2 = Vector2.ZERO
var target: Vector2
var isActive: bool = false
var damageType: int = -1
var stats: Dictionary = {}


func launch(fromGlob: Vector2, toGlob: Vector2) -> void:
	global_position = fromGlob
	dir = fromGlob.direction_to(toGlob)
	target = toGlob
	isActive = true


func explode() -> void:
	$BombAvatar.queue_free()
	
	$outwardEffect.visible = true
	var outwardEffectTween: Tween = get_tree().create_tween()
	outwardEffectTween.tween_property($outwardEffect.material, 'shader_parameter/radius', 0.75, 0.5)
	outwardEffectTween.finished.connect(func():
		$outwardEffect.queue_free()
	)
	
	$inwardEffect.visible = true
	get_tree().create_tween().tween_property($inwardEffect.material, 'shader_parameter/wave_color:a', 0.32, 0.3).from(0.0)
	get_tree().create_timer(stats.duration).timeout.connect(handle_exit)
	
	global.activeCamera.shake(5.0)
	
	collision_mask = 4
	hit()


func hit() -> void:
	var enemies: Array[Node2D] = get_overlapping_bodies()
	for enemy in enemies:
		var d: float = stats.damage
		enemy.get_hit(d, false)
		global.add_damage_text(enemy.global_position, d, damageType)
	
	get_tree().create_timer(stats.hitCD).timeout.connect(hit)


func handle_exit() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property($inwardEffect.material, 'shader_parameter/wave_color:a', 0.0, 0.5)
	tween.finished.connect(queue_free)


func resonate(d: float, resonatedFrom: CharacterBody2D) -> void:
	var enemies: Array[Node2D] = get_overlapping_bodies()
	for enemy in enemies:
		if enemy != resonatedFrom:
			enemy.get_hit(d, false)
			var t: int = Time.get_ticks_usec()
			global.add_damage_text(enemy.global_position, d, damageType)
			print(Time.get_ticks_usec() - t)
		

func on_enemy_entered(enemy: Node2D) -> void:
	enemy.got_hit.connect(resonate.bind(enemy))


func on_enemy_left(enemy: Node2D) -> void:
	enemy.got_hit.disconnect(resonate)


func _ready() -> void:
	stats = get_parent().stats
	damageType = stats.damageType
	pullStrength = stats.pullStrength
	if stats.hasResonance:
		body_entered.connect(on_enemy_entered)
		body_exited.connect(on_enemy_left)
	
	var outTex: GradientTexture2D = $outwardEffect.texture
	var inTex: GradientTexture2D = $inwardEffect.texture
	var r: float = stats.range
	var o: int = int(r * 300.0)
	var i: int = int(r * 200.0)
	outTex.width = o
	outTex.height = o
	inTex.width = i
	inTex.height = i
	$CollisionShape2D.shape.radius = 100.0 * r


func _physics_process(delta: float) -> void:
	if isActive:
		var distSq: float = global_position.distance_squared_to(target)
		if distSq < 626.0:
			explode()
			isActive = false
		global_position += dir * SPEED * delta
		return
	
	var enemies: Array[Node2D] = get_overlapping_bodies()
	for enemy in enemies:
		enemy.global_position += enemy.global_position.direction_to(global_position) * pullStrength * delta
