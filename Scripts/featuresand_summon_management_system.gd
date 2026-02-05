extends Node2D

@onready var player: CharacterBody2D = $".."
@onready var enemyDetectionRange: Area2D = $"../WeaponSystem/EnemyDetectionRange"
@onready var summonFlags: Node2D = $"../SummonFlags"
var playerStats: PlayerStats = null
var featuresFunctions: Script = preload("res://Scripts/on_run_features.gd")
var lightningBluePrint: PackedScene = preload("res://Scenes/lightning.tscn")
var hexaSnailBluePrint: PackedScene = preload("res://Scenes/hexa_snail.tscn")
var anomalyBluePrint: PackedScene = preload("res://Scenes/anomaly.tscn")
var starOrbitalsScript: Script = preload("res://Scripts/star_orbital.gd")
var shotBulletCount: int = 0


func get_random_nearby_enemy() -> CharacterBody2D:
	var enemies: Array = enemyDetectionRange.get_overlapping_bodies()
	
	if enemies.is_empty():
		return null
	
	return enemies.pick_random()


func handle_shoot() -> void:
	if not playerStats.activeModifiers.has("L_StrikeOnShoot"):
		return
	
	shotBulletCount += 1
	if shotBulletCount % playerStats.activeModifiers.L_StrikeAfterAmmo == 0:
		for strikeNo in playerStats.activeModifiers.L_StrikeAmount:
			var enemyToStrike: CharacterBody2D = get_random_nearby_enemy()
			
			if enemyToStrike:
				featuresFunctions.lightning_strike(enemyToStrike.global_position)
		
		shotBulletCount = 0;


func add_hexa_snail() -> void:
	var hexaSnail: Node2D = hexaSnailBluePrint.instantiate()
	
	hexaSnail.set_flag(summonFlags.get_new_flag())
	hexaSnail.set_stats(playerStats.activeModifiers.hexaSnailStats)
	hexaSnail.set_range(enemyDetectionRange)
	hexaSnail.position = player.global_position
	global.WORLD.add_child(hexaSnail) 


func add_star() -> void:
	var starOrbital: Node2D = player.get_node_or_null("SO") # SO = Star Orbital
	
	if not starOrbital: 
		starOrbital = Node2D.new()
		
		starOrbital.name = "SO"
		starOrbital.set_script(starOrbitalsScript)
		player.add_child(starOrbital)
		
		starOrbital.add_starand_adjust_position()
		return
	
	starOrbital.add_starand_adjust_position()


func _set_new_modifiers_into_player_stats(modifiers: Dictionary) -> void:
	for key in modifiers:
		var value = modifiers[key]
		playerStats.activeModifiers[key] = value


func implement_option_choice(optionChosen: Option) -> void:
	match optionChosen.name:
		"Lightning Strike":
			if not playerStats.activeModifiers.has("L_StrikeOnShoot"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				optionChosen.make_immediate_children_available()
				return
			
			playerStats.activeModifiers["L_StrikeAmount"] += optionChosen.modifiers.L_StrikeAmount
		
		"Hexa Snail":
			if not playerStats.activeModifiers.has("snailAmmount"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				add_hexa_snail()
				optionChosen.make_immediate_children_available()
				return
			
			playerStats.activeModifiers.snailAmmount += optionChosen.modifiers.snailAmmount
			add_hexa_snail()
		
		"Miniature Star":
			if not playerStats.activeModifiers.has("orbAmount"):
				_set_new_modifiers_into_player_stats(optionChosen.modifiers)
				add_star()
				optionChosen.make_immediate_children_available()
				return
			
			playerStats.activeModifiers.orbAmount += 1
			add_star()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		implement_option_choice($"../../ProgressionChoiceSystem".g)
	elif event.is_action_pressed("ui_down"):
		implement_option_choice($"../../ProgressionChoiceSystem".ba)


func _ready() -> void:
	playerStats = player.stats
