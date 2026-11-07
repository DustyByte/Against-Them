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
			optionChosen.isAvailable = false
		
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
			playerStatsActiveModifiers.starStats.cd *= 0.82
			fasterOrbitCount += 1
			if fasterOrbitCount >= 2:
				optionChosen.make_immediate_children_available()
				if fasterOrbitCount == 6:
					optionChosen.deactivate(true)
		
		"Anomaly":
			if notAnomalyOnceTaken:
				starOrbital.nowAsBH = true
				starOrbital.collapse_all_stars_into_blackhole()
				optionChosen.make_immediate_children_available()
				optionChosen.isAvailable = false
				notAnomalyOnceTaken = false
				global.PROGRESSION_CHOICE_SYSTEM.ga.isAvailable = false # MORE FUSION Deactivated
		
		"Feed the Monster":
			starOrbital.increase_all_star_size(1.1)
			optionChosen.make_immediate_children_available()
			feedTheMonsterCount += 1
			if feedTheMonsterCount == 3:
				optionChosen.isAvailable = false
		
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
			optionChosen.isAvailable = false
		
		"Quicker Stroms":
			playerStatsActiveModifiers.silStormStats.cd *= 0.75
			optionChosen.make_immediate_children_available()
		
		"Lightning Storm":
			playerStatsActiveModifiers.silStormStats['lightning'] = true
			optionChosen.make_immediate_children_available()
			optionChosen.isAvailable = false
		
		"Recall Dagger":
			if not playerStatsActiveModifiers.has('recallKnifeStats'):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
				add_recall_knives_manager()
			else:
				playerStatsActiveModifiers.recallKnifeStats.amount += 1
			
			recallDaggerCount += 1
			if recallDaggerCount >= 5:
				optionChosen.deactivate(true)
		
		"Heavy Dagger":
			if not playerStatsActiveModifiers.recallKnifeStats.has('knockBackIntensity'):
				playerStatsActiveModifiers.recallKnifeStats['knockBackIntensity'] = 20.0
				optionChosen.make_immediate_children_available()
				return
			
			playerStatsActiveModifiers.recallKnifeStats['knockBackIntensity'] += 20.0
		
		"Quick Draw":
			playerStatsActiveModifiers.recallKnifeStats.cd *= 0.75
			optionChosen.make_immediate_children_available()
		
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
			playerStatsActiveModifiers.auraStats.cd *= 0.37
			optionChosen.make_immediate_children_available()
		
		"Aura Farm":
			playerStatsActiveModifiers.auraStats.damage *= 2.0
			optionChosen.make_immediate_children_available()
		
		"Broader Field":
			playerStatsActiveModifiers.auraStats.range *= 1.25
			optionChosen.make_immediate_children_available()
		
		"Overflowing Might":
			playerStatsActiveModifiers.auraStats.killMilestoneMult += 1
			optionChosen.make_immediate_children_available()
		
		"Overload":
			_set_new_modifiers_into_player_stats(optionChosen.modifiers)
			optionChosen.make_immediate_children_available()
			optionChosen.isAvailable = false 
		
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
			pass
		
		"Monster Hunt":
			pass
		
		"Greed":
			$"../ExpManagementSystem/Range".shape.radius *= optionChosen.modifiers.pickUpRangeMultiplier
			optionChosen.make_immediate_children_available()
			pickUpRangeCount += 1
			if pickUpRangeCount >= 5:
				optionChosen.deactivate(true)
			
		"Faster":
			for weapon in global.PLAYERS_WEAPON_SYSTEM.carryingWeapons:
				weapon.stats.cd *= optionChosen.modifiers.weaponAttackSpeedMultiplier
			optionChosen.make_immediate_children_available()
			fasterCount += 1
			if fasterCount >= 6:
				optionChosen.deactivate(true)
		
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
			playerStatsActiveModifiers.cryoliteStats.damage += 5 * floor(playerStats.currentHP / 100.0)
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
		
		"Icicle Explosion":
			playerStatsActiveModifiers.cryoliteStats.icicleExplosion = true
			optionChosen.make_immediate_children_available()
			optionChosen.isAvailable = false
		
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
				optionChosen.isAvailable = false
		
		"Quicker Strikes":
			playerStatsActiveModifiers.orbStats.cd *= 0.8
			optionChosen.make_immediate_children_available()
		
		"Focus":
			playerStatsActiveModifiers.orbStats.hasLock = true
			optionChosen.make_immediate_children_available()
			optionChosen.isAvailable = false
		
		"Eliminate":
			pass
		
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
			optionChosen.isAvailable = false
		
		"Rapid Manifestation":
			optionChosen.make_immediate_children_available()
			var keys: Array = playerStatsActiveModifiers.keys()
			for key in keys:
				var val = playerStatsActiveModifiers[key]
				if val is Dictionary and val.has('isSummon'):
					if val.has("cd"):
						val.cd *= 0.8696 # cd = cd/1.15
		
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
					if val is Dictionary and val.has('isSummon'):
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
			playerStatsActiveModifiers.gravityBombStats.hitCD *= 0.5
		
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
			playerStatsActiveModifiers.fieryFieldStats.cd -= 0.5
			optionChosen.make_immediate_children_available()
		
		"Brittle Veins":
			playerStatsActiveModifiers.fieryFieldStats.hasBrittleVeins = true
			optionChosen.make_immediate_children_available()
			optionChosen.deactivate(true)
		
		"Rapid Ignition":
			var s: Dictionary = playerStatsActiveModifiers.fieryFieldStats
			s.radius *= 1.2
			s.cd -= 0.1
			optionChosen.make_immediate_children_available()
		
		"Relentless Pulse":
			playerStatsActiveModifiers.fieryFieldStats.hitCD *= 0.5
			optionChosen.make_immediate_children_available()
			relentlessPulseCount += 1
			if relentlessPulseCount == 3:
				optionChosen.deactivate(true)
		
		"Reaper’s Rebate":
			hasReapersRebate += 1
			optionChosen.make_immediate_children_available()
		
		"Regen":
			optionChosen.make_immediate_children_available()
			player_periodic_regen()
		
		"Momentum Pickups":
			expManager.hasMomentumPickups += 1
			optionChosen.make_immediate_children_available()
		
		"Recycle":
			expManager.hasRecycle += 1
			optionChosen.make_immediate_children_available()
		
		"Hasten The Beast":
			optionChosen.make_immediate_children_available()
			var keys: Array = playerStatsActiveModifiers.keys()
			for key in keys:
				var val = playerStatsActiveModifiers[key]
				if val is Dictionary and val.has('isSummon'):
					val.cd *= 0.7
		
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

func handle_player_level_up() -> void:
	if isHandlingLevelUp:
		return
	
	isHandlingLevelUp = true
	var options: Array[Option] = global.PROGRESSION_CHOICE_SYSTEM.give_selectable_options(6)
	global.ON_RUN_HUD.show_options(options)

	if global.ON_RUN_HUD.activeOptionDisplay == null:
		isHandlingLevelUp = false


func _ready() -> void:
	global.FEATURE_AND_SUMMON_MANAGEMENT_SYSTEM = self
	
	expManager.levelUp.connect(handle_player_level_up)
	global.ON_RUN_HUD.optionChosen.connect(implement_option_choice)
	
	var s: int = playerCarryingWeapons.size()
	playerCarryingWeaponsStats.resize(s)
	for i in range(s):
		playerCarryingWeaponsStats[i] = playerCarryingWeapons[i].stats
