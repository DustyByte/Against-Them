extends Area2D


signal levelUp

const ATTRACTING_SPEED: float = 600.0
## Soft "plip" when a drop reaches Echo (water-drop sound, A5). Each one is
## nudged a little sharp or flat (within PICKUP_PITCH_SPREAD, under a semitone
## either way), so pickups sound almost the same but not mechanically
## identical. At most one every PICKUP_SOUND_GAP seconds, so a big burst
## doesn't pile up.
const PICKUP_SOUND: AudioStream = preload("res://Assets/SFX/ExpPickup.wav")
const PICKUP_PITCH_SPREAD: float = 0.04   # pitch_scale 0.96 - 1.04 (about 0.7 semitone)
const PICKUP_SOUND_GAP: float = 0.05
const PICKUP_VOLUME_DB: float = -7.0
## EXP needed to finish level 1. Each later level needs LEVEL_EXP_GROWTH
## times more than the one before (exponential), so a big drop (the red, 100
## EXP) is worth a level or more when first seen and soon only part of one.
## From GROWTH_EASE_FROM_LEVEL on, the growth eases off towards
## LATE_EXP_GROWTH (the gap shrinks by GROWTH_EASE each level), so late levels
## keep getting harder without running away:
## level 2 needs 17, level 5 28, level 10 64, level 20 337, level 30 900,
## level 50 2276 (the early levels take longer than they used to; by level 30
## the total EXP is about what it was).
const LEVEL_1_EXP_REQUIREMENT: float = 14.5
const LEVEL_EXP_GROWTH: float = 1.18
const GROWTH_EASE_FROM_LEVEL: int = 20
const LATE_EXP_GROWTH: float = 1.04
const GROWTH_EASE: float = 0.85

@onready var player: CharacterBody2D = $".."
@onready var expBar: ProgressBar = global.ON_RUN_HUD.expBar
@onready var playerStats: PlayerStats = player.stats
@onready var weaponSystem: Node2D = $"../VisualWrapper/WeaponSystem"
@onready var carryingWeapons: Array[Weapon] = global.PLAYERS_WEAPON_SYSTEM.carryingWeapons
var carryingWeaponsStats: Array[Dictionary]
# Pickup reach. This Area2D no longer monitors anything: the drops are plain
# data in global.WORLD.expDrops, checked by distance to this circle's radius.
# Bonuses all add up on the scene's base radius (never on each other):
#   radius = base x (1 + Magnetism share + Greed share)
# e.g. base 150, Magnetism +35%, 5 Greed picks (+50% each): 150 x 3.85 = 578.
var rangeShape: CircleShape2D = null
var _baseRadius: float = 0.0
var _greedShare: float = 0.0
var currentLevel: int = 1
var _pickupPlayer: AudioStreamPlayer = null
var _pickupSoundReadyAt: float = 0.0
var currentExpMilestone: float = 0.0
var hasMomentumPickups: int = 0
var hasRecycle: int = 0


## EXP needed to go from `level` to the next one.
static func exp_requirement(level: int) -> float:
	var early: int = mini(level, GROWTH_EASE_FROM_LEVEL) - 1
	var requirement: float = LEVEL_1_EXP_REQUIREMENT * pow(LEVEL_EXP_GROWTH, early)
	for l in range(GROWTH_EASE_FROM_LEVEL + 1, level + 1):
		var ease: float = pow(GROWTH_EASE, l - GROWTH_EASE_FROM_LEVEL)
		requirement *= LATE_EXP_GROWTH + (LEVEL_EXP_GROWTH - LATE_EXP_GROWTH) * ease
	return requirement


func revaluate_exp_barand_milestone() -> void:
	currentExpMilestone = exp_requirement(currentLevel)
	expBar.max_value = currentExpMilestone
	expBar.value = playerStats.currentExp   # EXP carried over from the last level
	expBar.set("level", currentLevel)   # level badge on the bar


func _ready() -> void:
	# Magnetism. The shape is shared with the saved scene, so change a copy.
	monitoring = false
	monitorable = false
	var rangeNode: CollisionShape2D = $Range
	rangeNode.shape = rangeNode.shape.duplicate()
	rangeShape = rangeNode.shape
	_baseRadius = rangeShape.radius
	_update_reach()
	
	revaluate_exp_barand_milestone()
	_pickupPlayer = AudioStreamPlayer.new()
	_pickupPlayer.stream = PICKUP_SOUND
	_pickupPlayer.volume_db = PICKUP_VOLUME_DB
	_pickupPlayer.max_polyphony = 4
	add_child(_pickupPlayer)
	var s: int = carryingWeapons.size()
	carryingWeaponsStats.resize(s)
	for i in range(s):
		carryingWeaponsStats[i] = carryingWeapons[i].stats


## Greed: adds `share` of the base radius (0.5 = +50%).
func add_pickup_bonus(share: float) -> void:
	_greedShare += share
	_update_reach()


func _update_reach() -> void:
	var magnetism: float = UpgradeManager.pickup_radius_multiplier() - 1.0
	rangeShape.radius = _baseRadius * (1.0 + magnetism + _greedShare)


func _play_pickup_sound() -> void:
	var now: float = Time.get_ticks_msec() * 0.001
	if now < _pickupSoundReadyAt or not global.SFX_TYPES_PERM["game_world"]:
		return
	_pickupSoundReadyAt = now + PICKUP_SOUND_GAP
	_pickupPlayer.pitch_scale = 1.0 + randf_range(-PICKUP_PITCH_SPREAD, PICKUP_PITCH_SPREAD)
	_pickupPlayer.play()


func _process(delta: float) -> void:
	var collected: PackedFloat32Array = global.WORLD.expDrops.update_pickup(global_position, rangeShape.radius, ATTRACTING_SPEED, delta)
	if not collected.is_empty():
		_play_pickup_sound()
	for expAmount in collected:
		var gainedExp: float = expAmount * UpgradeManager.exp_multiplier() # Fortune
		var currentExp: float = playerStats.add_exp(gainedExp)
		expBar.value = currentExp
		
		if hasMomentumPickups and randf() <= 0.005:
			for stat in carryingWeaponsStats:
				var factor: float = maxf(1.0 - hasMomentumPickups * 0.01, 0.5)
				global.FEATURE_AND_SUMMON_MANAGEMENT_SYSTEM.scale_weapon_cooldown(stat, factor)
		
		if hasRecycle and randf() <= 0.05:
			var w: Weapon = weaponSystem.weapon
			var ammo: int = w.ammoRemaining + hasRecycle
			var maxAmmo: int = w.stats.maxAmmo
			if maxAmmo < ammo:
				w.ammoRemaining = maxAmmo
			else:
				w.ammoRemaining = ammo
		
		# EXP past the milestone counts towards the next level, and one big drop
		# can be worth several levels (each one gets its own choice).
		while currentExp >= currentExpMilestone:
			currentExp = playerStats.add_exp(-currentExpMilestone)
			currentLevel += 1
			AchievementManager.register_level_reached(currentLevel)
			revaluate_exp_barand_milestone()
			levelUp.emit()
