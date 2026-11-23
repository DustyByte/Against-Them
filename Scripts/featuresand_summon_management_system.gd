extends Node

@onready var player: Player = $".."
@onready var summonFlags: Node = $"../SummonFlags"
@onready var expManager: Area2D = $"../ExpManagementSystem"
@onready var playerStats: PlayerStats = player.stats
@onready var playerStatsActiveModifiers: Dictionary = playerStats.activeModifiers
@onready var detector: BodyDetect = global.DETECTOR
@onready var onRunFeatures: Script = global.ON_RUN_FEATURES
@onready var playerCarryingWeapons: Array[Weapon] = global.PLAYERS_WEAPON_SYSTEM.carryingWeapons
var playerCarryingWeaponsStats: Array[Dictionary]
var starOrbitalsScript: Script = preload("res://Scripts/star_orbital.gd")
var lightningBluePrint: PackedScene = preload("res://Scenes/Effects/lightning.tscn")
var hexaSnailBluePrint: PackedScene = preload("res://Scenes/Allies&Summons/hexa_snail.tscn")
var anomalyBluePrint: PackedScene = preload("res://Scenes/Allies&Summons/anomaly.tscn")
var silverStormBluePrint: PackedScene = preload("res://Scenes/Allies&Summons/tornado.tscn")
var auraBluePrint: PackedScene = preload("res://Scenes/Allies&Summons/aura.tscn")
var recallKnifeBluePrint: PackedScene = preload("res://Scenes/Allies&Summons/recall_knife.tscn")
var retriManagerBP: PackedScene = preload("res://Scenes/Systems/retribution_manager.tscn")
var fieryFieldManagerBP: PackedScene = preload("res://Scenes/Allies&Summons/field_fire_manager.tscn")
var cryoliteBP: PackedScene = preload("res://Scenes/Allies&Summons/cryolite.tscn")
var shotBulletCount: int = 0
var hasNotLightning: bool = true
var hasRhythmCount: int = 0
var rhythmFailedCount: int = 1
var hasRhythmAccumulate: bool = false
var isSummonAdrenalineActive: bool = false
var isAdrenalineActive: bool = false
var relentlessPulseCount: int = 0
var hasReapersRebate: int = 0
var reapersRebateCount: int = 0
var hasMonsterHunter: bool = false
var hasSlayersTithe: bool = false
# Caps for upgrades that used to stack without end.
const AURA_FARM_MAX_PICKS: int = 3      # aura damage x8 at most
const LIFE_STEAL_MAX_PICKS: int = 5     # 0.5% of icicle damage at most
const REGEN_MAX_PICKS: int = 3          # 15 HP every 5 seconds at most
const RECALL_DAGGER_MAX_PICKS: int = 20  # 20 daggers at most (fan spacing: recall_knives_manager.gd)
var auraFarmCount: int = 0

# Shortest cooldowns upgrades can bring things down to, in seconds. Without a
# floor, stacking cooldown cuts reached zero or went negative (things firing
# every frame, which also tanks the frame rate). Key: "<stats key>.<field>".
const MIN_COOLDOWNS: Dictionary = {
	"auraStats.cd": 0.25,
	"silStormStats.cd": 0.75,
	"recallKnifeStats.cd": 0.5,
	"starStats.cd": 0.15,        # orbit time: lower is a faster orbit
	"orbStats.cd": 0.4,
	"gravityBombStats.cd": 1.0,
	"gravityBombStats.hitCD": 0.1,
	"fieryFieldStats.cd": 1.0,
	"fieryFieldStats.hitCD": 0.1,
	"cryoliteStats.cd": 0.2,
}
const DEFAULT_MIN_COOLDOWN: float = 0.2
const MIN_WEAPON_COOLDOWN: float = 0.06   # about 16 shots a second

# Cooldown options. Each one's cut is sized so CD_OPTION_MAX_PICKS picks take
# its cooldown from the starting value to the floor above:
# factor = (floor / start) ^ (1 / 5), rounded down so the 5th pick lands on it.
# The option stops being offered after 5 picks, or as soon as its cooldown is
# already at the floor (other options cutting the same cooldown get it there sooner).
const CD_OPTION_MAX_PICKS: int = 5
const CD_OPTION_FACTORS: Dictionary = {
	"Faster Orbit": 0.748,         # star orbit 0.64 s -> 0.15 s
	"Quicker Stroms": 0.757,       # 3.0 s -> 0.75 s
	"Quick Draw": 0.724,           # 2.5 s -> 0.5 s
	"Rhythm Increase": 0.757,      # aura tick 1.0 s -> 0.25 s
	"Quicker Strikes": 0.724,      # 2.0 s -> 0.4 s
	"Crushing Weight": 0.724,      # gravity zone tick 0.5 s -> 0.1 s
	"Relentless Pulse": 0.669,     # fire field tick 0.74 s -> 0.1 s
	"Rapid Manifestation": 0.724,  # every summon: none starts more than 5x its floor
	"Hasten The Beast": 0.724,
	"Faster": 0.683,               # weapons: Torcher 0.4 s -> 0.06 s (Rupture 0.25 s gets there in 4)
}
const CD_OPTION_SHORTEN: float = 0.8   # Quicker Wildfire: fire drop -0.8 s a pick
const RAPID_IGNITION_DAMAGE: float = 3.0   # Rapid Ignition: fire area hit damage +3 a pick
const QUICKER_WILDFIRE_MAX_PICKS: int = 4
var _cdOptionPicks: Dictionary = {}    # option name -> times picked this run


func cooldown_floor(statsKey: String, field: String = "cd") -> float:
	return MIN_COOLDOWNS.get("%s.%s" % [statsKey, field], DEFAULT_MIN_COOLDOWN)


func is_cooldown_floored(statsKey: String, field: String = "cd") -> bool:
	return playerStatsActiveModifiers[statsKey][field] <= cooldown_floor(statsKey, field) + 0.0001


## Counts a pick of a cooldown option and retires it after `maxPicks` picks
## (CD_OPTION_MAX_PICKS unless the option has its own limit) or once
## `floored` (its cooldown can't go any lower). Call it after
## make_immediate_children_available(): run on a retired option, that would
## mark the children as used up instead.
func _count_cd_option_pick(option: Option, floored: bool, maxPicks: int = CD_OPTION_MAX_PICKS) -> void:
	var picks: int = _cdOptionPicks.get(option.name, 0) + 1
	_cdOptionPicks[option.name] = picks
	if picks >= maxPicks or floored:
		option.deactivate(true)


## Summon stat keys that have a cooldown (Lightning Strike has none).
func _summon_cooldown_keys() -> Array:
	var keys: Array = []
	for key in playerStatsActiveModifiers:
		var val = playerStatsActiveModifiers[key]
		if val is Dictionary and val.has('isSummon') and val.has('cd'):
			keys.append(key)
	return keys


## Multiplies a summon cooldown, never going below its floor.
func scale_cooldown(statsKey: String, factor: float, field: String = "cd") -> void:
	var s: Dictionary = playerStatsActiveModifiers[statsKey]
	s[field] = maxf(s[field] * factor, MIN_COOLDOWNS.get("%s.%s" % [statsKey, field], DEFAULT_MIN_COOLDOWN))


## Takes seconds off a summon cooldown, never going below its floor.
func shorten_cooldown(statsKey: String, seconds: float, field: String = "cd") -> void:
	var s: Dictionary = playerStatsActiveModifiers[statsKey]
	s[field] = maxf(s[field] - seconds, MIN_COOLDOWNS.get("%s.%s" % [statsKey, field], DEFAULT_MIN_COOLDOWN))


## Multiplies a weapon's cooldown (attack speed), never going below the floor.
static func scale_weapon_cooldown(weaponStats: Dictionary, factor: float) -> void:
	weaponStats.cd = maxf(weaponStats.cd * factor, MIN_WEAPON_COOLDOWN)
var lifeStealCount: int = 0
var regenCount: int = 0


func handle_kill() -> void:
	if hasRhythmCount:
		var chance: float = 1.0 - pow(0.99, hasRhythmCount)
		if hasRhythmAccumulate:
			chance *= rhythmFailedCount 
		
		if randf() <= chance:
			rhythmFailedCount = 1
			for weaponStat in playerCarryingWeaponsStats:
				weaponStat.damage *= 1.01
		else:
			rhythmFailedCount += 1
	
	if hasReapersRebate:
		if reapersRebateCount >= 99:
			reapersRebateCount = 0
			player.take_heal(20.0)


## Monster Hunter and Slayer's Tithe both pay out when a boss dies.
func _on_boss_killed(source: StringName) -> void:
	if hasMonsterHunter:
		# +5% weapon damage and a better Rhythm chance (one more Rhythm stack).
		for weaponStat in playerCarryingWeaponsStats:
			weaponStat.damage *= 1.05
		hasRhythmCount += 1
	if hasSlayersTithe:
		# Only the weapon that landed the killing blow, and for all future runs.
		for weaponStat in playerCarryingWeaponsStats:
			if weaponStat.get(&"weaponId", "") == String(source):
				var base: float = global.WEAPON_STATS[String(source).to_upper()].damage
				weaponStat.damage += UpgradeManager.add_slayers_tithe(String(source), base)


func handle_shoot() -> void:
	if hasNotLightning:
		return
	
	shotBulletCount += 1
	var playerLightningStats: Dictionary = playerStatsActiveModifiers.lightningStats
	if shotBulletCount % playerLightningStats.afterAmmo == 0:
		for strikeNo in playerLightningStats.amount:
			var enemyToStrike: CharacterBody2D = player.get_random_nearby_enemy_or_null()
			if enemyToStrike:
				onRunFeatures.lightning_strike(enemyToStrike, playerLightningStats.damage, playerLightningStats.chain)
		
		shotBulletCount = 0;


func add_hexa_snail() -> void:
	var hexaSnail: Node2D = hexaSnailBluePrint.instantiate()
	
	hexaSnail.set_flag(summonFlags.get_new_flag())
	hexaSnail.set_stats(playerStatsActiveModifiers.hexaSnailStats)
	hexaSnail.set_range(player.enemyDetectionRange)
	hexaSnail.position = player.global_position
	global.WORLD.add_child(hexaSnail) 


var starOrbital: StarOrbital = null
func add_star() -> void:
	starOrbital = player.get_node_or_null("SO") # SO = Star Orbital
	
	if not starOrbital: 
		var x := Node2D.new()
		
		x.name = "SO"
		x.set_script(starOrbitalsScript)
		starOrbital = x
		player.add_child(starOrbital)
		
		starOrbital.add_starand_adjust_position()
		return
	
	starOrbital.add_starand_adjust_position()


func add_silver_storm() -> void:
	var silverStorm: Tornado = silverStormBluePrint.instantiate()
	var enemy: Node2D = global.PLAYER.get_random_nearby_enemy_or_null()
	var direction: Vector2 = player.global_position.direction_to(enemy.global_position) if enemy else Vector2.from_angle(randf() * TAU)
	
	silverStorm.init(player.global_position, direction, playerStatsActiveModifiers.silStormStats)
	global.WORLD.add_child.call_deferred(silverStorm)


func add_aura() -> void:
	var aura: Aura = auraBluePrint.instantiate()
	aura.setup(playerStatsActiveModifiers.auraStats)
	player.add_child.call_deferred(aura)


func add_recall_knives_manager() -> void:
	var recallKnivesManager: RecallKnivesManager = load("res://Scenes/Allies&Summons/recall_knives_manager.tscn").instantiate()
	recallKnivesManager.setup(playerStatsActiveModifiers.recallKnifeStats)
	global.WORLD.add_child.call_deferred(recallKnivesManager)


func add_retri() -> void:
	var retriManager: Node2D = retriManagerBP.instantiate()
	
	retriManager.setup(playerStatsActiveModifiers.retriStats)
	global.WORLD.add_child(retriManager)


func add_fiery_field() -> void:
	var fieldFireManager: Node2D = fieryFieldManagerBP.instantiate()
	fieldFireManager.setup(playerStatsActiveModifiers.fieryFieldStats)
	global.WORLD.add_child(fieldFireManager)


func add_gravity_bomb() -> void:
	var gravityBombManager: GravityBombManager = load("res://Scenes/Allies&Summons/gravity_bomb_manager.tscn").instantiate()
	gravityBombManager.setup(playerStatsActiveModifiers.gravityBombStats)
	global.WORLD.add_child(gravityBombManager)


func add_cryolite() -> void:
	var cryolite: Cryolite = cryoliteBP.instantiate()
	cryolite.setup(playerStatsActiveModifiers.cryoliteStats)
	cryolite.offset = Vector2(0.0, -150.0)
	
	addedFloaterCount += 1
	addedFloaterRefs.append(cryolite)
	adjust_floaters()
	
	player.add_child(cryolite)


func add_laser_orb() -> void:
	var laserOrb: LaserOrb = load("res://Scenes/Allies&Summons/laser_orb.tscn").instantiate()
	laserOrb.setup(playerStatsActiveModifiers.orbStats)
	addedFloaterCount += 1
	addedFloaterRefs.append(laserOrb)
	
	adjust_floaters()
	player.add_child(laserOrb)


var addedFloaterCount: int = 0
var addedFloaterRefs: Array = []
func adjust_floaters() -> void:
	var centerPoint: Vector2 = Vector2(0.0, -105.0)
	var rad: float = 60.0
	var anglePerOrb: float = TAU/addedFloaterCount
	for i in range(addedFloaterCount):
		var angle: float = PI + i * anglePerOrb
		var floater = addedFloaterRefs[i]
		floater.position = centerPoint + rad * Vector2.from_angle(angle)
		
		if floater is Cryolite:
			floater.position += Vector2(0.0, 150.0)


func _set_new_modifiers_into_player_stats(modifiers: Dictionary) -> void:
	for key in modifiers:
		var value = modifiers[key]
		playerStatsActiveModifiers[key] = value


var notAnomalyOnceTaken: bool = true
var moreFusionCount: int = 0
var feedTheMonsterCount: int = 0
var thickerBeamCount: int = 0
var fasterOrbitCount: int = 0
var pickUpRangeCount: int = 0
var fasterCount: int = 0
var lightningStrikeCount: int = 0
var hexaSnailCount: int = 0
var silverStormCount: int = 0
var recallDaggerCount: int = 0
var miniatureStarCount: int = 0
var laserOrbCount: int = 0
var gravityBombCount: int = 0
var fieryFieldCount: int = 0
var cryoliteCount: int = 0
func implement_option_choice(optionChosen: Option) -> void:
	isHandlingLevelUp = false
	if pendingLevelUps > 0:
		# Next queued level-up, once this choice is applied and its screen closed.
		_show_pending_level_up.call_deferred()
	AchievementManager.register_option_picked(optionChosen)
	match optionChosen.name:
		"Lightning Strike":
			if hasNotLightning:
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
				hasNotLightning = false
			else:
				playerStatsActiveModifiers.lightningStats.amount += 1
			
			lightningStrikeCount += 1
			if lightningStrikeCount >= 5:
				optionChosen.deactivate(true)
		
		"Chain Reaction":
			playerStatsActiveModifiers.lightningStats.chain += 1
		
		"Hexa Snail":
			if not playerStatsActiveModifiers.has("snailAmmount"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				add_hexa_snail()
				optionChosen.make_immediate_children_available()
			else:
				playerStatsActiveModifiers.snailAmmount += optionChosen.modifiers.snailAmmount
				add_hexa_snail()
			
			hexaSnailCount += 1
			if hexaSnailCount >= 3:
				optionChosen.deactivate(true)
		
		"Aggresive Snail":
			playerStatsActiveModifiers.hexaSnailStats.damage *= 1.5
			optionChosen.make_immediate_children_available()
		
		"More Power Rabit!":
			playerStatsActiveModifiers.lightningStats.chainDamageRetention += 0.05
			optionChosen.make_immediate_children_available()
		
		"Hexa Adapt":
			playerStatsActiveModifiers.hexaSnailStats['hexaAdapt'] = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Retribution":
			if not playerStatsActiveModifiers.has("retriStats"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
				optionChosen.deactivate(true)
				add_retri()
		
		"Severe Judgement":
			var retriStats: Dictionary = playerStatsActiveModifiers.retriStats
			retriStats['severeJudgement'] += 1
			retriStats['killMileStoneIncreaseDBy'] = optionChosen.modifiers.killMileStoneIncreaseDBy
			optionChosen.make_immediate_children_available()
		
		"More Fat For You":
			var retriStats: Dictionary = playerStatsActiveModifiers.retriStats
			retriStats['moreFatForYou'] += 1
			retriStats['killMileStoneIncreaseMaxHPBy'] = optionChosen.modifiers.killMileStoneIncreaseMaxHPBy
			optionChosen.make_immediate_children_available()
		
		"Holy Might":
			playerStatsActiveModifiers.retriStats.damage += 10 * floor(playerStats.currentHP / 100.0)
			optionChosen.make_immediate_children_available()
		
		"Miniature Star":
			if not playerStatsActiveModifiers.has("orbAmount"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				add_star()
				optionChosen.make_immediate_children_available()
			else:
				playerStatsActiveModifiers.orbAmount += 1
				add_star()
			
			miniatureStarCount += 1
			if miniatureStarCount >= 2:
				optionChosen.deactivate(true)
		
		"More Fusion":
			starOrbital.increase_all_star_size(1.20)
			moreFusionCount += 1
			if moreFusionCount >= 2:
				optionChosen.make_immediate_children_available()
				if moreFusionCount == 3:
					optionChosen.deactivate(true)
		
		"Faster Orbit":
			scale_cooldown("starStats", CD_OPTION_FACTORS[optionChosen.name])
			fasterOrbitCount += 1
			var orbitFloored: bool = is_cooldown_floored("starStats")
			# Children open on the 2nd pick, or now if this is the last one.
			if fasterOrbitCount >= 2 or orbitFloored:
				optionChosen.make_immediate_children_available()
			_count_cd_option_pick(optionChosen, orbitFloored)
		
		"Anomaly":
			if notAnomalyOnceTaken:
				starOrbital.nowAsBH = true
				starOrbital.collapse_all_stars_into_blackhole()
				optionChosen.make_immediate_children_available()
				optionChosen.deactivate(true)
				notAnomalyOnceTaken = false
				global.PROGRESSION_CHOICE_SYSTEM.ga.deactivate(true) # More Fusion is gone once the star is a black hole
		
		"Feed the Monster":
			starOrbital.increase_all_star_size(1.1)
			optionChosen.make_immediate_children_available()
			feedTheMonsterCount += 1
			if feedTheMonsterCount == 3:
				optionChosen.deactivate(true)
		
		"Silver Storm":
			if not playerStatsActiveModifiers.has('silStormStats'):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
			
			add_silver_storm()
			silverStormCount += 1
			if silverStormCount >= 5:
				optionChosen.deactivate(true)
		
		"Cold Wind":
			playerStatsActiveModifiers.silStormStats['freeze'] = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Quicker Stroms":
			scale_cooldown("silStormStats", CD_OPTION_FACTORS[optionChosen.name])
			optionChosen.make_immediate_children_available()
			_count_cd_option_pick(optionChosen, is_cooldown_floored("silStormStats"))
		
		"Lightning Storm":
			playerStatsActiveModifiers.silStormStats['lightning'] = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Recall Dagger":
			if not playerStatsActiveModifiers.has('recallKnifeStats'):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
				add_recall_knives_manager()
			else:
				playerStatsActiveModifiers.recallKnifeStats.amount += 1
			
			recallDaggerCount += 1
			if recallDaggerCount >= RECALL_DAGGER_MAX_PICKS:
				optionChosen.deactivate(true)
		
		"Heavy Dagger":
			if not playerStatsActiveModifiers.recallKnifeStats.has('knockBackIntensity'):
				playerStatsActiveModifiers.recallKnifeStats['knockBackIntensity'] = 20.0
				optionChosen.make_immediate_children_available()
				return
			
			playerStatsActiveModifiers.recallKnifeStats['knockBackIntensity'] += 20.0
		
		"Quick Draw":
			scale_cooldown("recallKnifeStats", CD_OPTION_FACTORS[optionChosen.name])
			optionChosen.make_immediate_children_available()
			_count_cd_option_pick(optionChosen, is_cooldown_floored("recallKnifeStats"))
		
		"Soul Harveste":
			if not playerStatsActiveModifiers.has('recallKnifeKillMilestone'):
				playerStatsActiveModifiers['recallKnifeKillMilestone'] = 0
				playerStatsActiveModifiers['recallKnifeKillMilestoneMultiplier'] = 1.0
				return
			
			playerStatsActiveModifiers.recallKnifeKillMilestoneMultiplier += 1
		
		"Accumulate":
			playerStatsActiveModifiers.recallKnifeStats.toStackMult += 1
			optionChosen.make_immediate_children_available()
		
		"Aura":
			if not playerStatsActiveModifiers.has('auraStats'):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
			
			add_aura()
			optionChosen.deactivate(true)
		
		"Rhythm Increase":
			scale_cooldown("auraStats", CD_OPTION_FACTORS[optionChosen.name])
			optionChosen.make_immediate_children_available()
			_count_cd_option_pick(optionChosen, is_cooldown_floored("auraStats"))
		
		"Aura Farm":
			playerStatsActiveModifiers.auraStats.damage *= 2.0
			optionChosen.make_immediate_children_available()
			auraFarmCount += 1
			if auraFarmCount >= AURA_FARM_MAX_PICKS:
				optionChosen.deactivate(true)
		
		"Broader Field":
			playerStatsActiveModifiers.auraStats.range *= 1.25
			optionChosen.make_immediate_children_available()
		
		"Overflowing Might":
			playerStatsActiveModifiers.auraStats.killMilestoneMult += 1
			optionChosen.make_immediate_children_available()
		
		"Overload":
			_set_new_modifiers_into_player_stats(optionChosen.modifiers)
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Overload Explosion":
			if not playerStatsActiveModifiers.has('overloadExplosion'):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
				return
			
			playerStatsActiveModifiers.overloadExplosionMult += 0.01
		
		"Life":
			playerStats.increase_max_hp(optionChosen.modifiers.maxHPIncrease)
			optionChosen.make_immediate_children_available()
		
		"Force":
			for weapon in global.PLAYERS_WEAPON_SYSTEM.carryingWeapons:
				weapon.stats.damage *= optionChosen.modifiers.weaponDamageMultiplier
			optionChosen.make_immediate_children_available()
		
		"Rhythm":
			if not playerStatsActiveModifiers.has('rhythmCount'):
				playerStatsActiveModifiers['rhythmCount'] = 1
				optionChosen.make_immediate_children_available()
			
			hasRhythmCount += 1
			playerStatsActiveModifiers['rhythmCount'] += 1
		
		"Heavy Impact":
			for weaponStat in playerCarryingWeaponsStats:
				weaponStat.damage *= 1.2
				weaponStat.knockBackIntensity *= 1.3
			
			optionChosen.make_immediate_children_available()
		
		"Rhythm Accumulate":
			hasRhythmAccumulate = true
			optionChosen.make_immediate_children_available()
			for weaponStat in playerCarryingWeaponsStats:
				weaponStat.maxAmmo += 1
		
		"Slayer's Tithe":
			hasSlayersTithe = true
			optionChosen.deactivate(true)
		
		"Monster Hunter":
			hasMonsterHunter = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Greed":
			$"../ExpManagementSystem/Range".shape.radius *= optionChosen.modifiers.pickUpRangeMultiplier
			optionChosen.make_immediate_children_available()
			pickUpRangeCount += 1
			if pickUpRangeCount >= 5:
				optionChosen.deactivate(true)
			
		"Faster":
			var weaponsFloored: bool = true
			for weapon in global.PLAYERS_WEAPON_SYSTEM.carryingWeapons:
				scale_weapon_cooldown(weapon.stats, CD_OPTION_FACTORS[optionChosen.name])
				if weapon.stats.cd > MIN_WEAPON_COOLDOWN + 0.0001:
					weaponsFloored = false
			optionChosen.make_immediate_children_available()
			fasterCount += 1
			_count_cd_option_pick(optionChosen, weaponsFloored)
		
		"Fiery Field":
			if not playerStatsActiveModifiers.has("fieryFieldStats"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				add_fiery_field()
				optionChosen.make_immediate_children_available()
			else:
				playerStatsActiveModifiers.fieryFieldStats.amount += 1
			
			fieryFieldCount += 1
			if fieryFieldCount >= 5:
				optionChosen.deactivate(true)
		
		"Gravity Bomb":
			if not playerStatsActiveModifiers.has("gravityBombStats"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				add_gravity_bomb()
				optionChosen.make_immediate_children_available()
			else:
				playerStatsActiveModifiers.gravityBombStats.amount += 1
			
			gravityBombCount += 1
			if gravityBombCount >= 5:
				optionChosen.deactivate(true)
		
		"Cryolite":
			if not playerStatsActiveModifiers.has('cryoliteStats'):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
			
			add_cryolite()
			cryoliteCount += 1
			if cryoliteCount >= 3:
				optionChosen.deactivate(true)
		
		"Cryolite II":
			playerStatsActiveModifiers.cryoliteStats.damage += 5 * floor(playerStats.currentHP / 20.0)
			optionChosen.make_immediate_children_available()
		
		"Cryo Increase":
			playerStatsActiveModifiers.cryoliteStats.amount += 1
			optionChosen.make_immediate_children_available()
		
		"Colder":
			playerStatsActiveModifiers.cryoliteStats.freezeDuration += 0.4
			optionChosen.make_immediate_children_available()
		
		"Life Steal":
			if not playerStatsActiveModifiers.cryoliteStats.has('lifeSteal'):
				playerStatsActiveModifiers.cryoliteStats['lifeSteal'] = 0.001
			
			playerStatsActiveModifiers.cryoliteStats.lifeSteal += 0.001
			lifeStealCount += 1
			if lifeStealCount >= LIFE_STEAL_MAX_PICKS:
				optionChosen.deactivate(true)
		
		"Icicle Explosion":
			playerStatsActiveModifiers.cryoliteStats.icicleExplosion = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Laser Orb":
			if not playerStatsActiveModifiers.has('orbStats'):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
			
			add_laser_orb()
			laserOrbCount += 1
			if laserOrbCount >= 3:
				optionChosen.deactivate(true)
		
		"Thiccer Beam":
			var playerOrbStats: Dictionary = playerStatsActiveModifiers.orbStats
			playerOrbStats.beamThickness *= 1.35
			playerOrbStats.damage *= 2.5
			optionChosen.make_immediate_children_available()
			thickerBeamCount += 1
			if thickerBeamCount == 7:
				optionChosen.deactivate(true)
		
		"Quicker Strikes":
			scale_cooldown("orbStats", CD_OPTION_FACTORS[optionChosen.name])
			optionChosen.make_immediate_children_available()
			_count_cd_option_pick(optionChosen, is_cooldown_floored("orbStats"))
		
		"Focus":
			playerStatsActiveModifiers.orbStats.hasLock = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Eliminate":
			playerStatsActiveModifiers.orbStats['eliminate'] = true
			optionChosen.deactivate(true)
		
		"Adrenaline":
			var method: Callable = func():
				if isAdrenalineActive:
					return
				
				isAdrenalineActive = true
				var addedRunSpd: float = player.RUN_SPEED * 0.6
				var addedWalkSpd: float = player.WALK_SPEED * 0.6
				var addedSpd: float = player.speed * 0.6
				player.RUN_SPEED += addedRunSpd
				player.WALK_SPEED += addedWalkSpd
				player.speed += addedSpd
				
				var removedCD: Array[float] = []
				var size: int = playerCarryingWeaponsStats.size()
				removedCD.resize(size)
				
				for i in range(size):
					var s: Dictionary = playerCarryingWeaponsStats[i]
					var rcd: float = s.cd * 0.6
					s.cd -= rcd
					removedCD[i] = rcd
				
				get_tree().create_timer(5.0).timeout.connect(func():
					player.RUN_SPEED -= addedRunSpd
					player.WALK_SPEED -= addedWalkSpd
					player.speed -= addedSpd
					isAdrenalineActive = false
					
					for i in range(size):
						var s: Dictionary = playerCarryingWeaponsStats[i]
						s.cd += removedCD[i]
				)
			
			player.got_hit.connect(method)
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Rapid Manifestation":
			optionChosen.make_immediate_children_available()
			# Counted by picks only: a summon taken later starts at its full cooldown.
			for key in _summon_cooldown_keys():
				scale_cooldown(key, CD_OPTION_FACTORS[optionChosen.name])
			_count_cd_option_pick(optionChosen, false)
		
		"Summon Adrenaline":
			optionChosen.make_immediate_children_available()
			
			var method: Callable = func():
				if isSummonAdrenalineActive:
					return
				
				isSummonAdrenalineActive = true
				var keys: Array = playerStatsActiveModifiers.keys()
				var statDics: Array[Dictionary] = []
				var removedAmounts: Array[float] = []
				for key in keys:
					var val = playerStatsActiveModifiers[key]
					if val is Dictionary and val.has('isSummon') and val.has('cd'): # Lightning Strike has no cooldown
						statDics.append(val)
						var removedAmount: float = val.cd * 0.6
						removedAmounts.append(removedAmount)
						val.cd -= removedAmount
				
				get_tree().create_timer(5.0).timeout.connect(func():
					var size: int = statDics.size()
					for i in range(size):
						statDics[i].cd += removedAmounts[i]
					isSummonAdrenalineActive = false
				)
			
			player.got_hit.connect(method)
			optionChosen.deactivate(true)
		
		"Crushing Weight":
			optionChosen.make_immediate_children_available()
			scale_cooldown("gravityBombStats", CD_OPTION_FACTORS[optionChosen.name], "hitCD")
			_count_cd_option_pick(optionChosen, is_cooldown_floored("gravityBombStats", "hitCD"))
		
		"Extended Singularity":
			optionChosen.make_immediate_children_available()
			playerStatsActiveModifiers.gravityBombStats.range *= 1.1
		
		"Lasting Anomaly":
			playerStatsActiveModifiers.gravityBombStats.duration += 1.0
			optionChosen.make_immediate_children_available()
		
		"Resonance":
			playerStatsActiveModifiers.gravityBombStats.hasResonance = true
			optionChosen.deactivate(true)
			optionChosen.make_immediate_children_available()
		
		"Quicker Wildfire":
			shorten_cooldown("fieryFieldStats", CD_OPTION_SHORTEN)
			optionChosen.make_immediate_children_available()
			_count_cd_option_pick(optionChosen, is_cooldown_floored("fieryFieldStats"), QUICKER_WILDFIRE_MAX_PICKS)
		
		"Brittle Veins":
			playerStatsActiveModifiers.fieryFieldStats.hasBrittleVeins = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Rapid Ignition":
			var s: Dictionary = playerStatsActiveModifiers.fieryFieldStats
			s.radius *= 1.2
			s.damage += RAPID_IGNITION_DAMAGE   # each periodic hit of the fire area
			optionChosen.make_immediate_children_available()
			# Not a cooldown option any more, but keeps its limit of 5 picks.
			_count_cd_option_pick(optionChosen, false)
		
		"Relentless Pulse":
			scale_cooldown("fieryFieldStats", CD_OPTION_FACTORS[optionChosen.name], "hitCD")
			optionChosen.make_immediate_children_available()
			relentlessPulseCount += 1
			_count_cd_option_pick(optionChosen, is_cooldown_floored("fieryFieldStats", "hitCD"))
		
		"Reaper’s Rebate":
			hasReapersRebate += 1
			optionChosen.make_immediate_children_available()
		
		"Regen":
			optionChosen.make_immediate_children_available()
			player_periodic_regen()
			regenCount += 1
			if regenCount >= REGEN_MAX_PICKS:
				optionChosen.deactivate(true)
		
		"Momentum Pickups":
			expManager.hasMomentumPickups += 1
			optionChosen.make_immediate_children_available()
		
		"Recycle":
			expManager.hasRecycle += 1
			optionChosen.make_immediate_children_available()
		
		"Hasten The Beast":
			optionChosen.make_immediate_children_available()
			# Counted by picks only: a summon taken later starts at its full cooldown.
			for key in _summon_cooldown_keys():
				scale_cooldown(key, CD_OPTION_FACTORS[optionChosen.name])
			_count_cd_option_pick(optionChosen, false)
		
		"Enrage The Beast":
			optionChosen.make_immediate_children_available()
			var keys: Array = playerStatsActiveModifiers.keys()
			for key in keys:
				var val = playerStatsActiveModifiers[key]
				if val is Dictionary and val.has('isSummon'):
					val.damage *= 1.3


func player_periodic_regen() -> void:
	player.take_heal(5.0)
	get_tree().create_timer(5.0).timeout.connect(player_periodic_regen)


var isHandlingLevelUp: bool = false
## Level-ups reached while a choice was on screen (one drop can be worth several
## levels). Each gets its own choice afterwards, with options rolled after the
## previous pick, so a just-unlocked option can show up.
var pendingLevelUps: int = 0

func handle_player_level_up() -> void:
	if isHandlingLevelUp:
		pendingLevelUps += 1
		return
	
	isHandlingLevelUp = true
	var options: Array[Option] = global.PROGRESSION_CHOICE_SYSTEM.give_selectable_options(UpgradeManager.level_up_option_count()) # 6, +1 with Extra Choice
	global.ON_RUN_HUD.show_options(options)

	if global.ON_RUN_HUD.activeOptionDisplay == null:
		isHandlingLevelUp = false
		pendingLevelUps = 0   # nothing left to pick


func _show_pending_level_up() -> void:
	if pendingLevelUps <= 0 or isHandlingLevelUp:
		return
	pendingLevelUps -= 1
	handle_player_level_up()


func _ready() -> void:
	global.FEATURE_AND_SUMMON_MANAGEMENT_SYSTEM = self
	
	expManager.levelUp.connect(handle_player_level_up)
	global.ON_RUN_HUD.optionChosen.connect(implement_option_choice)
	AchievementManager.boss_killed.connect(_on_boss_killed)
	
	var s: int = playerCarryingWeapons.size()
	playerCarryingWeaponsStats.resize(s)
	for i in range(s):
		playerCarryingWeaponsStats[i] = playerCarryingWeapons[i].stats
