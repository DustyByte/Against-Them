extends Node2D

@onready var featuresFunctions: Script = preload("res://Scripts/on_run_features.gd")
@onready var lightningBluePrint: PackedScene = preload("res://Scenes/lightning.tscn")
@onready var player: CharacterBody2D = $".."
@onready var enemyDetectionRange: Area2D = $"../WeaponSystem/EnemyDetectionRange"
var shotBulletCount: int = 0


func get_random_nearby_enemy() -> CharacterBody2D:
	var enemies: Array = enemyDetectionRange.get_overlapping_bodies()
	
	if enemies.size() == 0:
		return null
	
	return enemies.pick_random()


func handle_shoot() -> void:
	var playerStats: PlayerStats = player.stats
	
	if not playerStats.activeModifiers.has("L_StrikeOnShoot"):
		return
	
	shotBulletCount += 1
	if shotBulletCount % playerStats.activeModifiers.L_StrikeAfterAmmo == 0:
		for strikeNo in playerStats.activeModifiers.L_StrikeAmount:
			var enemyToStrike: CharacterBody2D = get_random_nearby_enemy()
			if enemyToStrike != null:
				featuresFunctions.lightning_strike(lightningBluePrint, enemyToStrike.global_position)
		
		shotBulletCount = 0;


func add_hexa_snail() -> void:
	pass


func implement_option_choice(optionChosen: Option) -> void:
	var playerStats: PlayerStats = player.stats
	match optionChosen.name:
		"Lightning Strike":
			if not playerStats.activeModifiers.has("L_StrikeOnShoot"):
				for key in optionChosen.modifiers:
					var value = optionChosen.modifiers[key]
					playerStats.activeModifiers[key] = value
				optionChosen.make_immediate_children_available()
				return
			
			playerStats.activeModifiers["L_StrikeAmount"] += optionChosen.modifiers.L_StrikeAmount
		
		"Hexa Snail":
			if not playerStats.activeModifiers.has("snailAmmount"):
				for key in optionChosen.modifiers:
					var value = optionChosen.modifiers[key]
					playerStats.activeModifiers[key] = value
				
				add_hexa_snail()
				return
			
			playerStats.activeModifiers.snailAmmount += optionChosen.modifiers.snailAmmount
			add_hexa_snail()
