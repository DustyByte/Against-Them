extends CharacterBody2D


const SPEED = 300.0

@onready var lightningBluePrint: PackedScene = preload("res://Scenes/lightning.tscn")
@onready var onRunFeatures: Script = preload("res://Scripts/on_run_features.gd")
@onready var bulletBluePrint: PackedScene = preload("res://Scenes/bullet.tscn")
@onready var avatarWrapperNode: Node2D = $SpriteandPlayerAnimations
@onready var weapon: Node2D = $WeaponSystem/Gun
@onready var featuresandSummonManagementSystem: Node2D = $FeaturesandSummonManagementSystem
var joyStick: TouchScreenJoyStick = null
var directionFacing: Vector2 = Vector2.RIGHT
var enemySpawner: EnemySpawner
var stats: PlayerStats = PlayerStats.new()


# remove or adjust this func later
func init_spawner() -> void:
	enemySpawner.spawn()
	await get_tree().create_timer(2).timeout
	init_spawner()


## Registers damage and returns current HP.
func take_hit(incomingDamage) -> float:
	if not avatarWrapperNode.isHitAnimationPlaying:
		avatarWrapperNode.handle_hit_animation()
		global.activeCamera.shake(8)
		stats.currentHP -= incomingDamage
	return stats.currentHP


func handle_death() -> void:
	pass # take care of animation and all here
	var worldNode: Node2D = get_node("/root/World")
	var newCamera: Camera2D = Camera2D.new()
	newCamera.global_position = global.activeCamera.global_position
	newCamera.set_script(load("res://Scripts/on_run_camera.gd"))
	worldNode.add_child(newCamera)
	queue_free()


func _ready() -> void:
	joyStick = get_node("/root/World/CanvasLayer/JoyStick")
	enemySpawner = EnemySpawner.new($"..", self)
	init_spawner()
	global.PLAYER = self


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = joyStick.output.direction
	
	if direction:
		velocity = SPEED * direction
		
		directionFacing = direction
		
		if direction.x > 0:
			avatarWrapperNode.scale = Vector2.ONE
		else:
			avatarWrapperNode.scale = Vector2(-1, 1)
	else:
		velocity.x = move_toward(velocity.x, 0, 50)
		velocity.y = move_toward(velocity.y, 0, 50)
	
	move_and_slide()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("X"):
		weapon.shoot_bullet(weapon.currentlyPointingTowards)
		featuresandSummonManagementSystem.handle_shoot()
	#elif _event is InputEventMouseButton:
		#onRunFeatures.lightning_strike(load("res://Scenes/lightning.tscn"), get_global_mouse_position())


func _on_hit_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		var incomingDamage: float = body.stats.damage
		if take_hit(incomingDamage) <= 0:
			handle_death()
