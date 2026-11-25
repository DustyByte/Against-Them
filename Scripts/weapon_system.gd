extends Node2D


signal magEmptied

@onready var player: CharacterBody2D = $"../.."
@onready var playerSpriteAnimationPlayer: AnimationPlayer = $"../SpriteandPlayerAnimations/AnimationPlayer"
@onready var weaponUpdateTimer: Timer = $Timer
@onready var ammoIndicatingLabel: Label = $AmmoIndicator
@onready var reloadProgressBar: ProgressBarCustom = $ReloadProgressBar
@onready var ammoIcon: Panel = $AmmoIcon
var carryingWeapons: Array[Weapon] = []
var weapon: Weapon = null
var weaponIndex: int = -1
var updateInterval: float = 0.1
var walkOnShootTimerTime: float = 0.0
var onShootIncreaseTimerAmount: float = 0.2
var aimingTowards: Vector2 = Vector2.RIGHT
## True while the player aims by hand with the fire stick (on_run_hud.gd);
## auto aim at the nearest enemy waits until it is released.
var manualAim: bool = false


func handle_update_timer_timeout() -> void:
	if not manualAim:
		var nearestAttackable: Node2D = global.PLAYER.get_nearest_attackable_or_null()
		if nearestAttackable:
			_aim(global_position.direction_to(nearestAttackable.global_position))
	weaponUpdateTimer.start(updateInterval)


## Fire stick held: point the weapon (and Echo) the way the knob is pushed.
func set_manual_aim(direction: Vector2) -> void:
	manualAim = true
	_aim(direction)


## Fire stick released: back to auto aim, right away.
func clear_manual_aim() -> void:
	manualAim = false
	handle_update_timer_timeout()


func _aim(direction: Vector2) -> void:
	aimingTowards = direction
	player.selectedWeaponAimingTowards = direction
	weapon.update_direction(direction)


func change_player_speed_to(speed: float) -> void:
	player.speed = speed
	
	if speed == player.WALK_SPEED:
		playerSpriteAnimationPlayer.speed_scale = 0.70
		player.isWalking = true
		return
	
	playerSpriteAnimationPlayer.speed_scale = 1.25
	player.isWalking = false


func update_weapon_state_indicator() -> void:
	if weapon.ammoRemaining and not weapon.isReloading:   # auto reload shows its bar too
		ammoIndicatingLabel.visible = true
		ammoIcon.visible = true
		reloadProgressBar.visible = false
		ammoIndicatingLabel.text = str(weapon.ammoRemaining)
	else:
		ammoIndicatingLabel.visible = false
		ammoIcon.visible = false
		reloadProgressBar.visible = true


func shoot() -> void:
	if weapon.cdRemainig:
		return
	if weapon.isReloading:
		if weapon.ammoRemaining <= 0:
			return   # empty: has to finish reloading
		weapon.cancel_reload()   # bullets left (auto reload): firing cancels it
	
	if not walkOnShootTimerTime:
		change_player_speed_to(player.WALK_SPEED)
	walkOnShootTimerTime += onShootIncreaseTimerAmount
	
	var remainingAmmo: int = weapon.shoot_bullet()
	AchievementManager.register_weapon_fired(weapon.name)
	if remainingAmmo <= 0:
		weapon.reload()
		magEmptied.emit()
	
	update_weapon_state_indicator()
	global.FEATURE_AND_SUMMON_MANAGEMENT_SYSTEM.handle_shoot()


func select_weapon(givenWeapon: Weapon) -> void:
	weapon = givenWeapon
	weapon.get_selected()
	weapon.visible = true
	weapon.update_direction(aimingTowards)
	
	for w in carryingWeapons:
		if w.get_instance_id() != givenWeapon.get_instance_id():
			w.get_deselected()
			w.visible = false


func select_weapon_by_index(wi: int) -> void:
	weapon = carryingWeapons[wi]
	weapon.get_selected()
	weapon.visible = true
	weapon.update_direction(aimingTowards)
	
	for x in range(carryingWeapons.size()):
		if x != wi:
			carryingWeapons[x].get_deselected()
			carryingWeapons[x].visible = false


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("X"):
		shoot()
	if Input.is_action_just_pressed("C"):
		weaponIndex += 1
		if weaponIndex == carryingWeapons.size():
			weaponIndex = 0
		
		select_weapon_by_index(weaponIndex)
		
		update_weapon_state_indicator()


func _ready() -> void:
	var rupture: Weapon = load("res://Scenes/Weapons/rupture.tscn").instantiate()
	var torcher: Weapon = load("res://Scenes/Weapons/torcher.tscn").instantiate()
	add_child(rupture)
	add_child(torcher)
	carryingWeapons.append(rupture)
	carryingWeapons.append(torcher)
	
	weaponIndex = 0
	select_weapon_by_index(weaponIndex)
	
	global.PLAYERS_WEAPON_SYSTEM = self
	global.ON_RUN_HUD.fireButton.button_down.connect(shoot)
	
	weaponUpdateTimer.one_shot = true
	weaponUpdateTimer.start(updateInterval)
	weaponUpdateTimer.timeout.connect(handle_update_timer_timeout)
	
	update_weapon_state_indicator()


func _process(delta: float) -> void:
	if walkOnShootTimerTime > 0:
		walkOnShootTimerTime -= delta
		if walkOnShootTimerTime <= 0:
			change_player_speed_to(player.RUN_SPEED)
			walkOnShootTimerTime = 0.0
