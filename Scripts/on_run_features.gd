static var lightningBP: PackedScene = global.FREQUENT_EFFECTS_BLUEPRINTS.LIGHTNING_BLUEPRINT
static var burnBP: PackedScene = global.FREQUENT_EFFECTS_BLUEPRINTS.BURN_EMISSION
static var freezeBP: PackedScene = global.FREQUENT_EFFECTS_BLUEPRINTS.FREEZE
static var bleedBP: PackedScene = global.FREQUENT_EFFECTS_BLUEPRINTS.BLEED
static var explosionBP: PackedScene = preload("res://Scenes/Effects/explosion_particles.tscn")


## `source` credits kills for achievements: Lightning Strike / Hexa Snail by default.
static func lightning_strike(target: CharacterBody2D, damage: float, toChainAmount: int = 0, source: StringName = &"lightning") -> void:
	var worldAddChild: Callable = global.WORLD.add_child
	var lightning: Lightning = lightningBP.instantiate()
	var targetGlobalPosition: Vector2 = target.global_position
	var playerActiveModifiers: Dictionary = global.PLAYER.stats.activeModifiers
	var playerHasOverload: bool = playerActiveModifiers.has('overload')
	var playerHasOverloadExplosion: bool = playerActiveModifiers.has('overloadExplosion')
	var overloadDamageMultiplier: float
	var world: Node2D = global.WORLD
	var detector: BodyDetect = global.DETECTOR
	if playerHasOverload:
		overloadDamageMultiplier = playerActiveModifiers.overloadMultiplier
	
	lightning.global_position = targetGlobalPosition
	worldAddChild.call_deferred(lightning)
	
	AchievementManager.hit(target, damage, source)
	global.add_damage_text(targetGlobalPosition, damage, 1)
	var enemiesHit: int = 1
	
	if playerHasOverload and target.marks.has('burn'):
		var oDmg: float = overloadDamageMultiplier * damage
		var enemyJustDied: bool = AchievementManager.hit(target, oDmg, source) <= 0.0
		
		if playerHasOverloadExplosion:
			if enemyJustDied and not target.is_in_group("explodable"):
				overload_explode(target, oDmg * playerActiveModifiers.overloadExplosionMult, targetGlobalPosition, world, detector, source)
		
		global.add_damage_text(targetGlobalPosition, oDmg, 3, true)
	
	if toChainAmount:
		var toBeExcluded: Array[RID] = [target.get_rid()]
		var prevEnemy: CharacterBody2D = target
		var nextEnemy: CharacterBody2D = null
		var tree: SceneTree = global.get_tree()
		for i in range(1, toChainAmount+1):
			var prevEnemyGlobalPosition: Vector2 = prevEnemy.global_position
			nextEnemy = detector.get_nearest_enemy_or_null_from(prevEnemyGlobalPosition, toBeExcluded, 300)
			if not nextEnemy:
				break
			
			damage *= playerActiveModifiers.lightningStats.chainDamageRetention
			var nextEnemyGlobalPosition: Vector2 = nextEnemy.global_position
			lightning = lightningBP.instantiate()
			lightning.setup_as_chain(prevEnemyGlobalPosition, i)
			lightning.global_position = nextEnemyGlobalPosition
			worldAddChild.call_deferred(lightning)
			
			AchievementManager.hit(nextEnemy, damage, source)
			global.add_damage_text(nextEnemyGlobalPosition, damage, 1)
			enemiesHit += 1
			AchievementManager.register_lightning_chain_hits(enemiesHit)
			
			if playerHasOverload and nextEnemy.marks.has('burn'):
				var oDmg: float = overloadDamageMultiplier * damage
				var remHP: float = AchievementManager.hit(nextEnemy, oDmg, source)
				
				if playerHasOverloadExplosion:
					if remHP <= 0.0 and not nextEnemy.is_in_group("explodable"):
						overload_explode(nextEnemy, oDmg*playerActiveModifiers.overloadExplosionMult, nextEnemyGlobalPosition, world, detector, source)
				
				global.add_damage_text(targetGlobalPosition, oDmg, 3, true)
			
			toBeExcluded.append(nextEnemy.get_rid())
			prevEnemy = nextEnemy
			
			await tree.create_timer(0.1).timeout


static func burn_inflict(on: CharacterBody2D, damage: float = 3.0) -> void:
	var burnEmission: Burn = global.FREQUENT_EFFECTS_BLUEPRINTS.BURN_EMISSION.instantiate()
	burnEmission.set_damage(damage)
	on.add_child(burnEmission)
	AchievementManager.register_burn_applied()


static func freeze_inflict(on: CharacterBody2D, duration: float = 2.0) -> void:
	if on.asBoss:
		return
	
	if on.freezeEffect:
		on.freezeEffect.add_duration(duration)
		return
	
	var freeze: Freeze = freezeBP.instantiate()
	AchievementManager.register_freeze_applied()
	freeze.setup(duration)
	on.freezeEffect = freeze
	on.add_child(freeze)


static func bleed_inflict(on: CharacterBody2D, damage: float) -> void:
	var bleed : Bleed = bleedBP.instantiate()
	bleed.set_damage(damage)
	on.add_child(bleed)


static func overload_explode(target: CharacterBody2D, oeDmg: float, targetGlobalPosition: Vector2, whereToAddChild: Node2D, detector: BodyDetect, source: StringName = &"lightning") -> void:
	await whereToAddChild.get_tree().process_frame
	var explosionParticles: GPUParticles2D = explosionBP.instantiate()
	explosionParticles.self_modulate = Color.LIGHT_CORAL
	explosionParticles.global_position = targetGlobalPosition
	whereToAddChild.add_child.call_deferred(explosionParticles)
	explosionParticles.finished.connect(explosionParticles.queue_free)
	explosionParticles.emitting = true
	
	var enemies: Array[CharacterBody2D] = detector.get_all_enemies_from(targetGlobalPosition, [target.get_rid()], 150.0)
	AchievementManager.push_source(source)
	AchievementManager.begin_explosion()
	for enemy in enemies:
		enemy.get_hit(oeDmg)
		global.add_damage_text(enemy.global_position, oeDmg, 3)
	AchievementManager.end_explosion()
	AchievementManager.pop_source()
