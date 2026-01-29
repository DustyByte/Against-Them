class_name EnemySpawner

var spawningIn
var player: CharacterBody2D
var maxSpawn: int = 50
var spawned: int = 0
var enemy1BluePrint: PackedScene
var spawnDistanceRange: Vector2 = Vector2(1000, 1500) # (from, to)


func _init(spawnEnemiesAsChildOf, playerRef: CharacterBody2D) -> void:
	player = playerRef
	spawningIn = spawnEnemiesAsChildOf
	enemy1BluePrint = load("res://Scenes/enemy_1.tscn")


func spawn() -> void:
	if spawned == maxSpawn:
		return
	# get a random enemy from enemy types
	var enemy: CharacterBody2D = enemy1BluePrint.instantiate()
	
	var enemyPosition = get_random_position_around_player()
	enemy.position = enemyPosition
	
	spawningIn.add_child(enemy)
	spawned += 1


func get_random_position_around_player() -> Vector2:
	var playerPosition: Vector2 = player.global_position
	
	var r: float = randf_range(spawnDistanceRange.x, spawnDistanceRange.y)
	var theta: float = randf_range(0, 360)
	
	return playerPosition + Vector2.RIGHT.rotated(deg_to_rad(theta))*r
