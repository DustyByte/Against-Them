extends Node2D

const DAMAGE_TYPE: int = global.DAMAGE_TYPES.EXOTIC
@onready var mmRID: RID = $MultiMeshInstance2D.multimesh.get_rid()
@onready var mmiMesh: QuadMesh = $MultiMeshInstance2D.multimesh.mesh
@onready var player: CharacterBody2D = global.PLAYER
@onready var mmiMeshInistSize: Vector2 = mmiMesh.size
@export var animFirstStepCurve: Curve = null
var stats: Dictionary = {}
var particleColor: Color = Color(0.741, 0.675, 0.867)
var xforms: Array[Transform2D] = []
var scaleMain: Vector2 = Vector2.ZERO
var killCountD: int = 0
var killCountH: int = 0


func setup(retributionStats: Dictionary) -> void:
	stats = retributionStats


func trigger() -> void:
	var enemies: Array[Node2D] = player.get_all_enemies_in_rad(stats.range)
	var enemiesSize: int = enemies.size()
	if not enemiesSize:
		return
	
	visible = true
	
	var buffer: PackedFloat32Array = []
	buffer.resize(enemiesSize * 8)
	
	var bi: int = -1
	var enemyTransform: Transform2D = transform # self transform, so that dont have to unnecessarily build one.
	for i in range(enemiesSize):
		enemyTransform = enemies[i].transform
		bi = i * 8
		buffer[bi] = enemyTransform.x.x
		buffer[bi+1] = enemyTransform.y.x
		buffer[bi+2] = 0.0
		buffer[bi+3] = enemyTransform.origin.x
		buffer[bi+4] = enemyTransform.x.y
		buffer[bi+5] = enemyTransform.y.y
		buffer[bi+6] = 0.0
		buffer[bi+7] = enemyTransform.origin.y
	
	RenderingServer.multimesh_allocate_data(mmRID, enemiesSize, RenderingServer.MULTIMESH_TRANSFORM_2D, false, false)
	RenderingServer.multimesh_set_buffer(mmRID, buffer)
	RenderingServer.multimesh_set_visible_instances(mmRID, enemiesSize)
	
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(method_animation, 0.0, 0.37, 0.13)
	
	await tween.finished
	
	await global.freeze_world(0.15)
	
	var d: float = stats.damage
	var killMilestoneDamageIncrease: int = stats.severeJudgement
	var killMilestoneHPIncrease: int = stats.moreFatForYou
	for enemy in enemies:
		if enemy:
			if enemy.get_hit(d) <= 0.0:
				if killMilestoneDamageIncrease:
					killCountD += 1
					if killCountD == 500:
						killCountD = 0
						stats.damage *= 1 + killMilestoneDamageIncrease * stats.killMileStoneIncreaseDBy
				if killMilestoneHPIncrease:
					killCountH += 1
					if killCountH == 500:
						killCountH = 0
						player.stats.increase_max_hp(stats.killMileStoneIncreaseMaxHPBy)
			
			global.add_damage_text(enemy.global_position, d, 4)
		
	tween = get_tree().create_tween()
	tween.tween_method(method_animation, 0.37, 1.0, 0.16)
	tween.finished.connect(reset)


func reset() -> void:
	visible = false


func method_animation(val: float) -> void:
	mmiMesh.size = mmiMeshInistSize * animFirstStepCurve.sample_baked(val)


func _ready() -> void:
	global.PLAYERS_WEAPON_SYSTEM.magEmptied.connect(trigger)
