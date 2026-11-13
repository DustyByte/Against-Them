extends Weapon

var torcherAmmoBluePrintPath: String = "res://Scenes/Weapons/torcher_ammo.tscn"
@onready var muzzleFlash: PointLight2D = $"../PointLight2D"
@onready var WeaponShootAS: AudioStreamPlayer = $AudioStreamPlayer
var muzzleFlashColor: Color = Color(1.0, 0.41, 0.42, 1.0)


func shoot_bullet(gunHoldersKnockBackIntensityBuff: float = 0,  gunHoldersDamageBuff: float = 0, towards: Vector2 = currentlyPointingTowards) -> int:
	global.activeCamera.shake(10.0)
	muzzleFlash.flash(muzzleFlashColor, barrel.global_position)
	# Recoil ignores the Impact / Backdraft upgrades, which only push enemies harder.
	gunHolder.get_knocked_back(-currentlyPointingTowards, stats.knockBackIntensity / stats.upgradeKnockBackMultiplier * 0.4)
	
	if global.SFX_TYPES_PERM["game_world"]:
		WeaponShootAS.pitch_scale = randf_range(0.7, 1.3)
		WeaponShootAS.play()
	
	return shoot_bullet_only(gunHoldersKnockBackIntensityBuff, gunHoldersDamageBuff, towards)


func _ready() -> void:
	setup(UpgradeManager.apply_weapon_upgrades("torcher", global.WEAPON_STATS.TORCHER.duplicate_deep()), torcherAmmoBluePrintPath)
