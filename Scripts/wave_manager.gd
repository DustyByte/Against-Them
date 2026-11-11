class_name WaveManager
extends Node

signal waveFinished
signal waveBegun

# Wave enemy counts follow a decelerating curve instead of growing indefinitely.
# Approximate targets: wave 1 = 12, wave 10 = 48, wave 50 = 149, wave 100 = 200.
# The curve reaches the hard cap on WAVE_TO_REACH_ENEMY_CAP and stays there.
const MAX_ENEMIES_PER_WAVE: int = 200
const WAVE_TO_REACH_ENEMY_CAP: int = 100
const STARTING_WAVE_ENEMY_COUNT: int = 12
const ENEMY_COUNT_VARIATION: float = 0.05
const ENEMY_GROWTH_CURVE_SHARPNESS: float = 2.0

# Enemy HP and damage step up every 5 waves. Each step adds the base growth
# plus a small random offset, so the curve trends linearly but stays jagged.
# Around wave 100 this is roughly 4.4x HP and 1.56x damage, with run-to-run
# variation from the jitter.
const ENEMY_STAT_STEP_WAVES: int = 5
const ENEMY_HP_GROWTH_PER_STEP: float = 0.18
const ENEMY_HP_GROWTH_JITTER: float = 0.03
const ENEMY_DAMAGE_GROWTH_PER_STEP: float = 0.03
const ENEMY_DAMAGE_GROWTH_JITTER: float = 0.006

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
var distanceFromPlayer: Vector2 = Vector2(500.0, 1000.0)
var currentWave: int = 1
var killedEnemyAmount: int = 0
var wavesCompleted: int = 0
var bossesKilled: int = 0
var currentWaveTotalEnemies: int = 0
var waveHeadingBP: PackedScene = preload("res://Scenes/HUD/wave_heading.tscn")
@onready var sceneTree: SceneTree = get_tree()
@onready var HUDCanvas: CanvasLayer = $"../CanvasLayer"
var currentWaveDrops: Array[Dictionary]
var nextWaveDrops: Array[Dictionary]
var nextWaveDropsReady: bool = false
var dropBossNow: bool = false
var currentEnemyStatStep: int = -1
var waveEnemyHPMultiplier: float = 1.0
var waveEnemyDamageMultiplier: float = 1.0


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


func get_wave_enemy_amount_range(wave: int) -> Vector2i:
	var growth_wave_span: float = float(maxi(WAVE_TO_REACH_ENEMY_CAP - 1, 1))
	var normalized_wave: float = clampf(float(maxi(wave - 1, 0)) / growth_wave_span, 0.0, 1.0)

	# Exponential ease-out, normalized so the curve reaches exactly the cap on
	# WAVE_TO_REACH_ENEMY_CAP instead of growing without bound.
	var curve_scale: float = maxf(1.0 - exp(-ENEMY_GROWTH_CURVE_SHARPNESS), 0.0001)
	var normalized_growth: float = (1.0 - exp(-ENEMY_GROWTH_CURVE_SHARPNESS * normalized_wave)) / curve_scale
	var target_amount: int = clampi(roundi(lerpf(float(STARTING_WAVE_ENEMY_COUNT), float(MAX_ENEMIES_PER_WAVE), normalized_growth)), 1, MAX_ENEMIES_PER_WAVE)

	var variation: int = maxi(roundi(float(target_amount) * ENEMY_COUNT_VARIATION), 1)
	if target_amount >= MAX_ENEMIES_PER_WAVE:
		variation = 0

	var minimum_amount: int = clampi(target_amount - variation, 1, MAX_ENEMIES_PER_WAVE)
	var maximum_amount: int = clampi(target_amount + variation, minimum_amount, MAX_ENEMIES_PER_WAVE)

	return Vector2i(minimum_amount, maximum_amount)


# Builds the next wave's spawn data. This is intentionally synchronous: the
# previous version ran this on a WorkerThreadPool task while the main thread was
# consuming the very same state, so a wave could begin with an empty drop list
# depending on how the two threads happened to interleave.
func _produce_next_wave_drops() -> void:
	nextWaveDropsReady = false
	var generatedDrops: Array[Dictionary] = []
	var amount_range: Vector2i = get_wave_enemy_amount_range(currentWave)
	var spawnAmount: int = clampi(randi_range(amount_range.x, amount_range.y), 1, MAX_ENEMIES_PER_WAVE)
	var spawnedAmount: int = 0

	while spawnedAmount < spawnAmount:
		var remaining: int = spawnAmount - spawnedAmount
		var drop: Dictionary = {}
		var dropType: int = get_random_drop_type()
		
		match dropType:
			DROP_TYPES.BATCH:
				drop = get_batch_drop(mini(randi_range(4, 7), remaining))
			
			DROP_TYPES.LONE:
				drop = get_lone_drop()
			
			DROP_TYPES.SEPERATED_MULTIPLE:
				drop = get_seperated_multiple_drop(mini(randi_range(2, 4), remaining))
		
		generatedDrops.append(drop)
		spawnedAmount += drop.dropData.size()
	
	generatedDrops[-1].nextSpawnInterval = -1.0
	nextWaveDrops = generatedDrops
	nextWaveDropsReady = true


func update_wave_difficulty() -> void:
	if currentWave % 5 == 0:
		dropBossNow = true
	
	# Enemy count is derived from currentWave in get_wave_enemy_amount_range().
	# It no longer compounds with every wave.
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


func update_wave_enemy_stat_multipliers(wave: int) -> void:
	var target_step: int = maxi(wave - 1, 0) / ENEMY_STAT_STEP_WAVES
	while currentEnemyStatStep < target_step:
		currentEnemyStatStep += 1
		if currentEnemyStatStep == 0:
			waveEnemyHPMultiplier = 1.0
			waveEnemyDamageMultiplier = 1.0
			continue

		waveEnemyHPMultiplier += ENEMY_HP_GROWTH_PER_STEP + randf_range(-ENEMY_HP_GROWTH_JITTER, ENEMY_HP_GROWTH_JITTER)
		waveEnemyDamageMultiplier += ENEMY_DAMAGE_GROWTH_PER_STEP + randf_range(-ENEMY_DAMAGE_GROWTH_JITTER, ENEMY_DAMAGE_GROWTH_JITTER)


func begin_current_wave() -> void:
	update_wave_enemy_stat_multipliers(currentWave)

	# Guard against starting an empty wave. With synchronous production this
	# should never happen, but it keeps a misconfigured wave amount from
	# permanently stalling the run.
	if not nextWaveDropsReady or nextWaveDrops.is_empty():
		_produce_next_wave_drops()
	
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
				enemy.tree_exited.connect(handle_boss_kill)
				currentWaveTotalEnemies -= 1
				dropBossNow = false
			else:
				enemy.tree_exited.connect(handle_enemy_kill)
			
			enemy.stats.apply_multipliers(waveEnemyHPMultiplier, waveEnemyDamageMultiplier)
			enemy.tree_exited.connect(features_handle_kill)
			world.add_child.call_deferred(enemy)
		
		var nsi: float = drop.nextSpawnInterval
		if nsi == -1.0:
			break
		
		await sceneTree.create_timer(nsi).timeout
	
	currentWave += 1
	update_wave_difficulty()

	# Produce the next wave now that the difficulty has been updated. The data
	# stays untouched in nextWaveDrops until begin_current_wave consumes it, so
	# there is exactly one place that clears it.
	_produce_next_wave_drops()


func handle_boss_kill() -> void:
	bossesKilled += 1


func handle_enemy_kill() -> void:
	killedEnemyAmount += 1
	global.TOTAL_ENEMY_KILLS += 1
	if killedEnemyAmount >= currentWaveTotalEnemies:
		killedEnemyAmount = 0
		wavesCompleted += 1
		waveFinished.emit(currentWave-1)
		sceneTree.create_timer(wave_transition_delay).timeout.connect(begin_current_wave)


func add_wave_heading() -> void:
	var heading: WaveHeading = waveHeadingBP.instantiate()
	heading.setup(currentWave)
	HUDCanvas.add_child.call_deferred(heading)


func _ready() -> void:
	global.WAVE_MANAGER = self
	
	distanceFromPlayer += Vector2.ONE * get_window().get_size().x
	
	begin_current_wave()
