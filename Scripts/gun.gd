extends Node2D

@onready var bulletBluePrint: PackedScene = preload("res://Scenes/bullet.tscn")
@onready var barrel: Node2D = $BarrelNode
var gunHolder: PhysicsBody2D = null
var currentlyPointingTowards: Vector2 = Vector2.RIGHT # this type data must be present in all weapons

var knockBackIntensity: float = 100
var damage: float = 20


func shoot_bullet(towards: Vector2, gunHoldersKnockBackIntensityBuff: float = 0,  gunHoldersDamageBuff: float = 0) -> void:
	var bullet: Bullet = bulletBluePrint.instantiate()
	bullet.set_shooter(gunHolder)
	bullet.set_shot_direction(towards)
	bullet.global_position = barrel.global_position
	bullet.rotation = Vector2.RIGHT.angle_to(towards) + PI/2
	bullet.speed += sqrt(pow(gunHolder.velocity.x, 2) + pow(gunHolder.velocity.y, 2))
	gunHolder.add_sibling(bullet)
	
	bullet.carryingKnockBackIntensity = knockBackIntensity + gunHoldersKnockBackIntensityBuff
	bullet.carryingDamage = damage + gunHoldersDamageBuff


func _ready() -> void:
	gunHolder = get_parent().get_parent()
