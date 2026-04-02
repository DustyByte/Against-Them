class_name EnemySpawner

var spawningIn: Node
var player: CharacterBody2D
var maxSpawn: int = 100
var spawned: int = 0
var spawnDistanceRange: Vector2 = Vector2(1000, 1500) # (from, to)
var allEnemyBPs: Dictionary = {}
var bp: PackedScene = preload("res://enemy.tscn")
var kill_handle: Callable


func _init(spawnEnemiesAsChildOf, playerRef: CharacterBody2D) -> void:
	player = playerRef
	spawningIn = spawnEnemiesAsChildOf
	allEnemyBPs = global.ENEMY_BPS
	kill_handle = global.FEATURE_AND_SUMMON_MANAGEMENT_SYSTEM.handle_kill


func spawn() -> void:
	#if spawned == maxSpawn:
		#return
	# get a random enemy from enemy types
	#var enemy: CharacterBody2D = allEnemyBPs['Type_4'].instantiate()
	var enemy: CharacterBody2D = allEnemyBPs[allEnemyBPs.keys().pick_random()].instantiate()
	
	var enemyPosition = get_random_position_around_player()
	enemy.position = enemyPosition
	
	spawningIn.add_child.call_deferred(enemy)
	#spawned += 1
	
	enemy.tree_exited.connect(kill_handle)


func spawn_horde(amount: int) -> void:
	for i in range(amount):
		spawn()


func get_random_position_around_player() -> Vector2:
	var playerPosition: Vector2 = player.global_position
	
	var r: float = randf_range(spawnDistanceRange.x, spawnDistanceRange.y)
	var theta: float = randf_range(0, 360)
	
	return playerPosition + Vector2.RIGHT.rotated(deg_to_rad(theta))*r
