class_name GravityBomb
extends Area2D

const SPEED: float = 1500.0
var pullStrength: float = -1.0
var dir: Vector2 = Vector2.ZERO
var target: Vector2
var isActive: bool = false
var damageType: int = -1
var stats: Dictionary = {}
var _resonance: Dictionary = {}   # enemy in range -> its connected resonate callable


func launch(fromGlob: Vector2, toGlob: Vector2) -> void:
	global_position = fromGlob
	dir = fromGlob.direction_to(toGlob)
	target = toGlob
	isActive = true
	requiredTravelDist = (toGlob - fromGlob).length()


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
	
	global.WORLD.audio_2d_play(preload("res://Assets/SFX/GravityBombImpact.wav"), global_position, "game_world", randf_range(0.9, 1.1), 12.0)
	
	collision_mask = 4
	hit()


func hit() -> void:
	var enemies: Array[Node2D] = get_overlapping_bodies()
	for enemy in enemies:
		var d: float = stats.damage
		AchievementManager.hit(enemy, d, &"gravity_bomb", false)
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
			AchievementManager.hit(enemy, d, &"gravity_bomb", false)
			global.add_damage_text(enemy.global_position, d, damageType)
		

func on_enemy_entered(enemy: Node2D) -> void:
	if _resonance.has(enemy):
		return
	var callable: Callable = resonate.bind(enemy)
	_resonance[enemy] = callable
	enemy.got_hit.connect(callable)


## Disconnects the exact callable connected above: a plain `resonate` doesn't
## match the bound one, so the old disconnect failed with an error every time.
func on_enemy_left(enemy: Node2D) -> void:
	var callable = _resonance.get(enemy)
	if callable == null:
		return
	_resonance.erase(enemy)
	if enemy.got_hit.is_connected(callable):
		enemy.got_hit.disconnect(callable)


func _ready() -> void:
	stats = get_parent().stats
	damageType = stats.damageType
	pullStrength = stats.pullStrength
	if stats.hasResonance:
		body_entered.connect(on_enemy_entered)
		body_exited.connect(on_enemy_left)
	
	# The effect textures only give the shaders (which draw from UV) a quad of
	# the right size, so scale the sprites instead of resizing the shared
	# textures, which regenerated them on every throw.
	var r: float = stats.range
	$outwardEffect.scale = Vector2(r, 0.65 * r)
	$inwardEffect.scale = Vector2(r, 0.65 * r)
	$CollisionShape2D.shape.radius = 100.0 * r

var travelledDist: float = 0.0
var requiredTravelDist: float = -1.0
func _physics_process(delta: float) -> void:
	if isActive:
		var step: Vector2 = dir * SPEED * delta
		travelledDist += step.length()
		if travelledDist >= requiredTravelDist:
			explode()
			isActive = false
		global_position += step
		return
	
	var enemies: Array[Node2D] = get_overlapping_bodies()
	for enemy in enemies:
		enemy.global_position += enemy.global_position.direction_to(global_position) * pullStrength * delta
