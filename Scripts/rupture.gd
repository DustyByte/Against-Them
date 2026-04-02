extends Weapon

var maxAmmo: int = 7

@onready var weaponSystem: Node2D = get_parent()
@onready var muzzleFlash: PointLight2D = $"../PointLight2D"
var muzzleFlashColor: Color = Color(0.871, 0.933, 1.0)
var bulletBluePrintPath: String = "res://Scenes/Weapons/rupture_ammo.tscn"


func shoot_bullet(gunHoldersKnockBackIntensityBuff: float = 0,  gunHoldersDamageBuff: float = 0, towards: Vector2 = currentlyPointingTowards) -> int:
	muzzleFlash.flash(muzzleFlashColor, barrel.global_position)
	
	return shoot_bullet_only(gunHoldersKnockBackIntensityBuff, gunHoldersDamageBuff, towards)


func _ready() -> void:
	setup(global.WEAPON_STATS.RUPTURE, bulletBluePrintPath)
