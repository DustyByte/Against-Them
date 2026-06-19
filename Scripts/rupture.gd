extends Weapon

var maxAmmo: int = 7

@onready var weaponSystem: Node2D = get_parent()
@onready var muzzleFlash: PointLight2D = $"../PointLight2D"
@onready var WeaponShootAS: AudioStreamPlayer = $AudioStreamPlayer
var muzzleFlashColor: Color = Color(0.871, 0.933, 1.0)
var bulletBluePrintPath: String = "res://Scenes/Weapons/rupture_ammo.tscn"


func shoot_bullet(gunHoldersKnockBackIntensityBuff: float = 0,  gunHoldersDamageBuff: float = 0, towards: Vector2 = currentlyPointingTowards) -> int:
	muzzleFlash.flash(muzzleFlashColor, barrel.global_position)
	
	if global.SFX_TYPES_PERM["game_world"]:
		WeaponShootAS.pitch_scale = randf_range(0.7, 1.3)
		WeaponShootAS.play()
	
	return shoot_bullet_only(gunHoldersKnockBackIntensityBuff, gunHoldersDamageBuff, towards)


func _ready() -> void:
	setup(global.WEAPON_STATS.RUPTURE.duplicate_deep(), bulletBluePrintPath)
