class_name WaveManager
extends Node

signal waveFinished
signal waveBegun

enum DROP_TYPES {
	BATCH,
	LONE,
	SEPERATED_MULTIPLE
}
const DROP_TYPES_RATE: Dictionary = {
	BATCH = 0.15,
	LONE = 0.50,
	SEPERATED_MULTIPLE = 0.35
}
var enemyPackedScenes: Array[PackedScene] = [
	preload("res://Scenes/Enemies/enemy_1.tscn"),
	preload("res://Scenes/Enemies/enemy_4.tscn"),
	preload("res://Scenes/Enemies/enemy_6.tscn")
]
var enemyDropWeights: Array[int] = [
	100,
	0,
	0
]
var enemyDropTotalWeight: int = 100
@onready var world: Node2D = get_parent()
@onready var player: Player = $"../Player"
@onready var features_handle_kill: Callable = global.FEATURE_AND_SUMMON_MANAGEMENT_SYSTEM.handle_kill
@export var wave_transition_delay: float = 0.75
@export var drop_speed_multiplier: float = 0.92
var dropInterval: Vector2 = Vector2(1.0, 2.0)
var minDropInterval: float = 0.15 
var dropAmount: Vector2i = Vector2i(10, 15) # 10, 15
var distanceFromPlayer: Vector2 = Vector2(500.0, 1000.0)
var currentWave: int = 1
var killedEnemyAmount: int = 0
var currentWaveTotalEnemies: int = 0
var waveHeadingBP: PackedScene = preload("res://Scenes/HUD/wave_heading.tscn")
@onready var sceneTree: SceneTree = get_tree()
@onready var HUDCanvas: CanvasLayer = $"../CanvasLayer"
var currentWaveDrops: Array[Dictionary]
var nextWaveDrops: Array[Dictionary]
var nextWaveDropsReady: bool = false
var nextWaveDropsProductionInProgress: bool = false
var dropBossNow: bool = false


func generate_jittered_points(center: Vector2, count: int, radius: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var side: float = ceil(sqrt(count)) 
	var cell_size: float = (radius * 2.0) / side
	
	for i in range(count):
		var row: float = i / side
		var col: int = i % int(side)
		
		var cell_origin: Vector2 = center + Vector2(col * cell_size - radius, row * cell_size - radius)
		
		var jitter: Vector2 = Vector2(randf(), randf()) * cell_size * 0.8
		points.append(cell_origin + jitter)
	
	return points


func get_random_drop_type() -> int:
	var pick: float = randf()
	var dropTypeKey: String = ""
	for key in DROP_TYPES_RATE:
		var dropRate: float = DROP_TYPES_RATE[key]
		pick -= dropRate
		if pick <= 0.0:
			dropTypeKey = key
			break
	
	return DROP_TYPES[dropTypeKey]


func get_weighted_random_enemy_type() -> PackedScene:
	var enemyBP: PackedScene = null
	var x: int = randi_range(0, enemyDropTotalWeight)
	for i in range(enemyDropWeights.size()):
		x -= enemyDropWeights[i]
		if x <= 0:
			enemyBP = enemyPackedScenes[i]
			break
	
	return enemyBP


func get_batch_drop(amount: int) -> Dictionary:
	var drop: Dictionary = {}
	var nextSpawnInterval: float = randf_range(dropInterval.x, dropInterval.y)
	
	var batchPosition: Vector2 = randf_range(distanceFromPlayer.x, distanceFromPlayer.y) * Vector2.from_angle(randf() * TAU)
	var enemyPositions: Array[Vector2] = generate_jittered_points(batchPosition, amount, 333.0)
	
	var enemyBP: PackedScene = get_weighted_random_enemy_type()
	
	var dropData: Array = []
	dropData.resize(amount)
	for i in range(amount):
		dropData[i] = [enemyBP, enemyPositions[i]]
	
	drop["dropData"] = dropData
	drop["nextSpawnInterval"] = nextSpawnInterval
	
	return drop


func get_lone_drop() -> Dictionary:
	var drop: Dictionary = {}
	var nextSpawnInterval: float = randf_range(dropInterval.x, dropInterval.y)
	
	var spawnPosition: Vector2 = randf_range(distanceFromPlayer.x, distanceFromPlayer.y) * Vector2.from_angle(randf() * TAU)
	
	var enemyBP: PackedScene = get_weighted_random_enemy_type()
	
	drop["dropData"] = [[enemyBP, spawnPosition]]
	drop["nextSpawnInterval"] = nextSpawnInterval
	
	return drop


func get_seperated_multiple_drop(amount: int) -> Dictionary:
	var drop: Dictionary = {}
	var nextSpawnInterval: float = randf_range(dropInterval.x, dropInterval.y)
	
	var dropData: Array = []
	for i in range(amount):
		var spawnPosition: Vector2 = randf_range(distanceFromPlayer.x, distanceFromPlayer.y) * Vector2.from_angle(randf() * TAU)
		dropData.append([get_weighted_random_enemy_type(), spawnPosition])
	
	drop["dropData"] = dropData
	drop["nextSpawnInterval"] = nextSpawnInterval
	
	return drop


func _worker_produce_next_wave_drops() -> void:
	nextWaveDropsReady = false
	nextWaveDropsProductionInProgress = true
	var generatedDrops: Array[Dictionary] = []
	var spawnAmount: int = randi_range(dropAmount.x, dropAmount.y)
	while spawnAmount > 0: # spawned amount could exceed spawnAmount. And that is intentional.
		var drop: Dictionary = {}
		var dropType: int = get_random_drop_type()
		
		match dropType:
			DROP_TYPES.BATCH:
				var amount: int = randi_range(4, 7)
				drop = get_batch_drop(amount)
				spawnAmount -= amount
			
			DROP_TYPES.LONE:
				drop = get_lone_drop()
				spawnAmount -= 1
			
			DROP_TYPES.SEPERATED_MULTIPLE:
				var amount: int = randi_range(2, 4)
				drop = get_seperated_multiple_drop(amount)
				spawnAmount -= amount
		
		generatedDrops.append(drop)
	
	generatedDrops[-1].nextSpawnInterval = -1.0
	nextWaveDrops = generatedDrops
	
	nextWaveDropsReady = true
	nextWaveDropsProductionInProgress = false


func update_wave_difficulty() -> void:
	if currentWave % 1 == 0:
		dropBossNow = true
	
	dropAmount += Vector2i.ONE * (10 + currentWave) 
	if dropInterval.x > minDropInterval:
		dropInterval.x = max(dropInterval.x * drop_speed_multiplier, minDropInterval)
		dropInterval.y = max(dropInterval.y * drop_speed_multiplier, minDropInterval * 1.5)

	var x: int = currentWave / 10
	var xRed: int = x
	x = clampi(x, 0, enemyDropWeights.size() - 1)
	for i in range(x):
		var randWeightShift: int = randi_range(-4, 4)
		enemyDropWeights[i] += randWeightShift
		enemyDropTotalWeight += randWeightShift
		if enemyDropWeights[i] <= 0:
			enemyDropWeights[i] += 20
			enemyDropTotalWeight += 20
	
	if currentWave % 10 == 0 and xRed < enemyDropWeights.size():
		enemyDropWeights[xRed] += 10
		enemyDropTotalWeight += 10


func begin_current_wave() -> void:
	if not nextWaveDropsReady:
		var waitAttempts: int = 0
		while nextWaveDropsProductionInProgress and waitAttempts < 20:
			await sceneTree.create_timer(0.05).timeout
			waitAttempts += 1
		if not nextWaveDropsReady:
			_worker_produce_next_wave_drops()
	
	currentWaveDrops = nextWaveDrops
	nextWaveDrops = []
	nextWaveDropsReady = false
	
	waveBegun.emit(currentWave)
	add_wave_heading()
	
	currentWaveTotalEnemies = 0
	for drop in currentWaveDrops:
		currentWaveTotalEnemies += drop.dropData.size()
	
	for drop in currentWaveDrops:
		for data in drop.dropData:
			var enemy: CharacterBody2D = data[0].instantiate()
			enemy.global_position = player.global_position + data[1]
			
			if enemy.ENEMY_TYPE != 6 and dropBossNow:
				enemy.set_as_boss()
				currentWaveTotalEnemies -= 1
				dropBossNow = false
			else:
				enemy.tree_exited.connect(handle_enemy_kill)
			
			enemy.tree_exited.connect(features_handle_kill)
			world.add_child.call_deferred(enemy)
		
		var nsi: float = drop.nextSpawnInterval
		if nsi == -1.0:
			break
		
		await sceneTree.create_timer(nsi).timeout
	
	currentWave += 1
	update_wave_difficulty()
	currentWaveDrops = nextWaveDrops
	nextWaveDrops = []
	WorkerThreadPool.add_task(_worker_produce_next_wave_drops)


func handle_enemy_kill() -> void:
	killedEnemyAmount += 1
	global.TOTAL_ENEMY_KILLS += 1
	if killedEnemyAmount >= currentWaveTotalEnemies:
		killedEnemyAmount = 0
		waveFinished.emit(currentWave-1)
		sceneTree.create_timer(wave_transition_delay).timeout.connect(begin_current_wave)


func add_wave_heading() -> void:
	var heading: WaveHeading = waveHeadingBP.instantiate()
	heading.setup(currentWave)
	HUDCanvas.add_child.call_deferred(heading)


func _ready() -> void:
	global.WAVE_MANAGER = self
	
	distanceFromPlayer += Vector2.ONE * get_window().get_size().x
	
	_worker_produce_next_wave_drops()
	begin_current_wave()
	
	WorkerThreadPool.add_task(_worker_produce_next_wave_drops)
