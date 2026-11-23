extends Area2D


signal levelUp

const ATTRACTING_SPEED: float = 600.0
## EXP needed to finish level 1. Each later level needs LEVEL_EXP_GROWTH
## times more than the one before (exponential), so a big drop (the red, 100
## EXP) is worth a level or more when first seen and soon only part of one.
## From GROWTH_EASE_FROM_LEVEL on, the growth eases off towards
## LATE_EXP_GROWTH (the gap shrinks by GROWTH_EASE each level), so late levels
## keep getting harder without running away:
## level 13 needs 65, level 16 128, level 20 312, level 25 690, level 30 1105,
## level 40 1957.
const LEVEL_1_EXP_REQUIREMENT: float = 4.5
const LEVEL_EXP_GROWTH: float = 1.25
const GROWTH_EASE_FROM_LEVEL: int = 20
const LATE_EXP_GROWTH: float = 1.04
const GROWTH_EASE: float = 0.85

@onready var player: CharacterBody2D = $".."
@onready var expBar: ProgressBar = global.ON_RUN_HUD.expBar
@onready var playerStats: PlayerStats = player.stats
@onready var weaponSystem: Node2D = $"../VisualWrapper/WeaponSystem"
@onready var carryingWeapons: Array[Weapon] = global.PLAYERS_WEAPON_SYSTEM.carryingWeapons
var carryingWeaponsStats: Array[Dictionary]
# Pickup reach. Grows with the Magnetism upgrade and the Greed option, which
# change this circle's radius. This Area2D no longer monitors anything: the
# drops are plain data in global.WORLD.expDrops, checked by distance.
var rangeShape: CircleShape2D = null
var currentLevel: int = 1
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
	rangeShape.radius *= UpgradeManager.pickup_radius_multiplier()
	
	revaluate_exp_barand_milestone()
	var s: int = carryingWeapons.size()
	carryingWeaponsStats.resize(s)
	for i in range(s):
		carryingWeaponsStats[i] = carryingWeapons[i].stats


func _process(delta: float) -> void:
	var collected: PackedFloat32Array = global.WORLD.expDrops.update_pickup(global_position, rangeShape.radius, ATTRACTING_SPEED, delta)
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
