class_name GravityBomb
extends Area2D

const SPEED: float = 1500.0
## The zone's look (Shaders/gravity_fracture.gdshader): cracks splitting out
## on impact, held for the duration, closing up at the end.
const CRACK_OPEN_TIME: float = 0.35
const CRACK_CLOSE_TIME: float = 0.5
var pullStrength: float = -1.0
var isActive: bool = false
var damageType: int = -1
var stats: Dictionary = {}
var _resonance: Dictionary = {}   # enemy in range -> its connected resonate callable


## The bomb sits where it will land; only its sprite flies in from
## `fromGlob` (spinning, speeding up) while its shadow grows on the ground.
func launch(fromGlob: Vector2, toGlob: Vector2) -> void:
	global_position = toGlob
	var avatar: Sprite2D = $BombAvatar
	var shadow: Sprite2D = $Shadow
	var fallTime: float = (toGlob - fromGlob).length() / SPEED
	avatar.position = fromGlob - toGlob
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(avatar, "position", Vector2.ZERO, fallTime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(avatar, "rotation", TAU * 0.6, fallTime)
	tween.tween_property(shadow, "scale", Vector2(1.1, 0.6), fallTime)
	tween.tween_property(shadow, "modulate:a", 1.0, fallTime)
	tween.chain().tween_callback(explode)


func explode() -> void:
	$BombAvatar.queue_free()
	$Shadow.queue_free()
	isActive = true

	var zone: Sprite2D = $Zone
	var mat: ShaderMaterial = zone.material
	mat.set_shader_parameter("seed", randf() * 100.0)   # every bomb cracks differently
	zone.visible = true
	create_tween().tween_method(_set_zone.bind("spawn"), 0.0, 1.0, CRACK_OPEN_TIME)
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
	isActive = false
	var tween: Tween = create_tween()
	tween.tween_method(_set_zone.bind("collapse"), 0.0, 1.0, CRACK_CLOSE_TIME)
	tween.finished.connect(queue_free)


func _set_zone(value: float, parameter: String) -> void:
	$Zone.material.set_shader_parameter(parameter, value)


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
	$Zone.scale = Vector2(r, 0.65 * r)
	$CollisionShape2D.shape.radius = 100.0 * r

func _physics_process(delta: float) -> void:
	if not isActive:
		return
	var enemies: Array[Node2D] = get_overlapping_bodies()
	for enemy in enemies:
		enemy.global_position += enemy.global_position.direction_to(global_position) * pullStrength * delta
