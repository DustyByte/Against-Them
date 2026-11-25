class_name Weapon
extends Node2D


var stats: Dictionary = {}
var weaponInitPositionX: float = 0.0
var currentlyPointingTowards: Vector2 = Vector2.RIGHT
var isReloading: bool = false
var reloadedTime: float = 0.0
var ammoRemaining: int = -1
var cdRemainig: float = 0.0
var isCurrentlySelected: bool = false
var reloadProgressBar: ProgressBarCustom = null
var ammoBP: PackedScene = null
var barrel: Node2D = null
var gunHolder: CharacterBody2D = null
var selfRefHangerCard: HangerWeaponCard = null
## Auto reload: a weapon that hasn't fired for AUTO_RELOAD_IDLE seconds (and
## isn't full) starts its normal reload - also while it's holstered after a
## swap. It doesn't count as emptying the magazine, so it doesn't set off
## Retribution. A weapon with a cooldown longer than that waits a little past
## its cooldown, so holding fire never reloads it.
const AUTO_RELOAD_IDLE: float = 0.5
var _sinceShot: float = 0.0


### A function to be called at ready of individual weapons
func setup(weaponStats: Dictionary, ammoScenePath: String) -> void:
	stats = weaponStats
	ammoRemaining = stats.maxAmmo
	
	weaponInitPositionX = global_position.x
	reloadProgressBar = $"../ReloadProgressBar"
	
	ammoBP = load(ammoScenePath)
	barrel = $Barrel
	gunHolder = $"../../.."
	
	selfRefHangerCard = load("res://Scenes/HUD/hanger_weapon_card.tscn").instantiate()
	global.ON_RUN_WEAPON_HANGER.add_child(selfRefHangerCard)
	selfRefHangerCard.set_weapon_ref(self)
	selfRefHangerCard.set_avatar(load(get_meta('hanger_use_avatar_path')))
	selfRefHangerCard.set_ammo_count(ammoRemaining)


func shoot_bullet_only(gunHoldersKnockBackIntensityBuff: float = 0,  gunHoldersDamageBuff: float = 0, towards: Vector2 = currentlyPointingTowards) -> int:
	var ammo = ammoBP.instantiate()
	ammo.init(towards, barrel.global_position, stats.damage+gunHoldersDamageBuff, stats.knockBackIntensity+gunHoldersKnockBackIntensityBuff, gunHolder.velocity.length())
	global.WORLD.add_child.call_deferred(ammo)
	
	ammoRemaining -= 1
	selfRefHangerCard.set_ammo_count(ammoRemaining)
	_sinceShot = 0.0
	
	cdRemainig = stats.cd
	
	return ammoRemaining


func get_selected() -> void:
	isCurrentlySelected = true
	selfRefHangerCard.switch_state_selected()


func get_deselected() -> void:
	isCurrentlySelected = false
	selfRefHangerCard.switch_state_deselected()


func update_direction(aimDirection: Vector2) -> void:
	if not aimDirection: # keeps pointing towards the last update direction
		return
	
	if aimDirection.x > 0:
		scale = Vector2.ONE
		position.x = weaponInitPositionX
	elif aimDirection.x <= 0:
		scale = Vector2(1, -1)
		position.x = -weaponInitPositionX
	
	var thetaRad: float = Vector2.RIGHT.angle_to(aimDirection)
	rotation = thetaRad
	currentlyPointingTowards = aimDirection


func reload() -> void:
	isReloading = true
	selfRefHangerCard.switch_state_reload()


## Stops a reload partway (the player fired with bullets still in the mag):
## the progress is lost and the mag keeps what it had.
func cancel_reload() -> void:
	isReloading = false
	reloadedTime = 0.0
	selfRefHangerCard.switch_state_ammo()
	selfRefHangerCard.set_ammo_count(ammoRemaining)


func project_self_to_reload_bar() -> void:
	reloadProgressBar.maxValue = stats.reloadTime
	reloadProgressBar.change_value(reloadedTime)


func _process(delta: float) -> void:
	if not isReloading and ammoRemaining < stats.maxAmmo:
		_sinceShot += delta
		if _sinceShot >= maxf(AUTO_RELOAD_IDLE, stats.cd + 0.1):
			reload()
			global.PLAYERS_WEAPON_SYSTEM.update_weapon_state_indicator()
	if isReloading:
		reloadedTime += delta
		selfRefHangerCard.set_reload_bar_values(reloadedTime, stats.reloadTime)
		
		if reloadedTime >= stats.reloadTime:
			ammoRemaining = stats.maxAmmo
			isReloading = false
			selfRefHangerCard.switch_state_ammo()
			selfRefHangerCard.set_ammo_count(ammoRemaining)
			reloadedTime = 0.0
			global.PLAYERS_WEAPON_SYSTEM.update_weapon_state_indicator()
		
		elif isCurrentlySelected:
			project_self_to_reload_bar()
	
	cdRemainig = cdRemainig-delta if cdRemainig > 0 else 0.0
