class_name Player
extends CharacterBody2D

signal got_hit

var RUN_SPEED = 300.0
var WALK_SPEED = 50.0

var weapon
@onready var enemyDetectionRange: Area2D = $"EnemyDetectionRange"
@onready var avatarWrapperNode: Node2D = $VisualWrapper/SpriteandPlayerAnimations
var lightningBluePrint: PackedScene = preload("res://Scenes/Effects/lightning.tscn")
var onRunFeatures: Script = preload("res://Scripts/on_run_features.gd")
var bulletBluePrint: PackedScene = preload("res://Scenes/Weapons/rupture_ammo.tscn")
var joyStick: TouchScreenJoyStick = null
var directionFacing: Vector2 = Vector2.RIGHT
var enemySpawner: EnemySpawner
var stats: PlayerStats = PlayerStats.new()
var speed: float = RUN_SPEED
var knockBackVelocity: Vector2 = Vector2.ZERO
var knockBackDecay: float = 10.0
var selectedWeaponAimingTowards: Vector2 = Vector2.RIGHT
var joystickDirection: Vector2 = Vector2.RIGHT
var isWalking: bool = false


func get_nearest_attackable_or_null() -> Node2D:
	var bodies: Array[Node2D] = enemyDetectionRange.get_overlapping_bodies()
	var nearestDistance: float = INF
	var nearestAttackable: Node2D = null
	
	for body in bodies:
		if body.is_in_group("attackable"):
			var distance: float = body.global_position.distance_squared_to(global_position)
			if distance < nearestDistance:
				nearestDistance = distance
				nearestAttackable = body
	
	return nearestAttackable if nearestAttackable else null


func get_random_nearby_enemy_or_null() -> CharacterBody2D:
	var enemies: Array = enemyDetectionRange.get_overlapping_bodies()
	
	if enemies.is_empty():
		return null
	
	return enemies.pick_random()


func get_all_enemies_in_rad(rad: float) -> Array[Node2D]:
	var shape: CollisionShape2D = enemyDetectionRange.get_child(0)
	var beforeRad: float = shape.shape.radius
	
	shape.shape.radius = rad
	var enemies: Array[Node2D] = enemyDetectionRange.get_overlapping_bodies()
	shape.shape.radius = beforeRad
	
	return enemies


# remove or adjust this func later
func init_spawner() -> void:
	enemySpawner.spawn()
	get_tree().create_timer(0.5).timeout.connect(init_spawner)


## Registers damage and returns current HP.
func get_hit(incomingDamage) -> float:
	if not avatarWrapperNode.isHitAnimationPlaying:
		avatarWrapperNode.handle_hit_animation()
		global.activeCamera.shake(8.0)
		stats.currentHP -= incomingDamage
	
	got_hit.emit()
	return stats.currentHP


func get_knocked_back(knockBackDirection: Vector2, knockBackIntensity: float = 0) -> void:
	knockBackVelocity += knockBackDirection * knockBackIntensity * 3


func handle_death() -> void:
	pass # take care of animation and all here
	var newCamera: Camera2D = Camera2D.new()
	newCamera.global_position = global.activeCamera.global_position
	newCamera.set_script(load("res://Scripts/on_run_camera.gd"))
	global.WORLD.add_child(newCamera)
	queue_free()


func _ready() -> void:
	weapon = get_node('VisualWrapper/WeaponSystem/Weapon')
	joyStick = get_node("/root/World/CanvasLayer/JoyStick")
	enemySpawner = EnemySpawner.new($"..", self)
	init_spawner()
	global.PLAYER = self


func _physics_process(_delta: float) -> void:
	joystickDirection = joyStick.output.direction
	
	if joystickDirection:
		velocity = speed * joystickDirection + knockBackVelocity
		directionFacing = selectedWeaponAimingTowards if isWalking else joystickDirection
	else:
		velocity = knockBackVelocity
		directionFacing = selectedWeaponAimingTowards
	
	avatarWrapperNode.scale = Vector2(sign(directionFacing.x), 1)
	move_and_slide()
	
	if knockBackVelocity:
		knockBackVelocity = knockBackVelocity.move_toward(Vector2.ZERO, knockBackDecay)


func _on_hit_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		var incomingDamage: float = body.stats.damage
		if get_hit(incomingDamage) <= 0:
			handle_death()
