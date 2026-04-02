extends Weapon

var torcherAmmoBluePrintPath: String = "res://Scenes/Weapons/torcher_ammo.tscn"
@onready var muzzleFlash: PointLight2D = $"../PointLight2D"
var muzzleFlashColor: Color = Color(1.0, 0.41, 0.42, 1.0)


func shoot_bullet(gunHoldersKnockBackIntensityBuff: float = 0,  gunHoldersDamageBuff: float = 0, towards: Vector2 = currentlyPointingTowards) -> int:
	global.activeCamera.shake(10.0)
	muzzleFlash.flash(muzzleFlashColor, barrel.global_position)
	gunHolder.get_knocked_back(-currentlyPointingTowards, stats.knockBackIntensity * 0.4)
	
	return shoot_bullet_only(gunHoldersKnockBackIntensityBuff, gunHoldersDamageBuff, towards)


func _ready() -> void:
	setup(global.WEAPON_STATS.TORCHER, torcherAmmoBluePrintPath)
