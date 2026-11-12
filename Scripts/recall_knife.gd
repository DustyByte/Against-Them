class_name RecallKnife
extends Area2D

const DISPLACEMENT_TOTAL: float = 350.0
const RECALL_SPEED: float = 1000.0
@onready var spriteWrapper: Node2D = $spriteWrapper
@onready var playerStatsActiveModifiers: Dictionary = global.PLAYER.stats.activeModifiers
@onready var player: Player = global.PLAYER
@onready var manager: RecallKnivesManager = get_parent()
@onready var onRunFeatures: Script = global.ON_RUN_FEATURES
@export var recallVelCurve: Curve = Curve.new()
var stats: Dictionary = {}
var isTimeToRecall: bool = false
var offset: Vector2 = Vector2.UP * 64.0
var amountKilled: int = 0
var target_pos: Vector2
var distanceSq_to_target: float
var move_distance: float
var dir: Vector2
@onready var damageType: int = global.DAMAGE_TYPES.PHYSICAL


func handleHitConnect(body: Node2D) -> void:
	var d: float
	if not isTimeToRecall:
		d = stats.damage
		var toStackMult: int = stats.toStackMult
		if toStackMult:
			manager.stackAmount += toStackMult
		if stats.has('knockBackIntensity'):
			body.get_knocked_back(dir, stats['knockBackIntensity'])
	else:
		d = stats.damage + manager.stackAmount*2.0
	
	onRunFeatures.bleed_inflict(body, stats.bleedDamage)
	global.add_damage_text(body.global_position, d, damageType)
	
	if AchievementManager.hit(body, d, &"recall_dagger") <= 0.0 and playerStatsActiveModifiers.has('recallKnifeKillMilestone'):
		playerStatsActiveModifiers.recallKnifeKillMilestone += 1
		if playerStatsActiveModifiers.recallKnifeKillMilestone == 600:
			playerStatsActiveModifiers.recallKnifeKillMilestone = 0
			player.stats.increase_max_hp(50.0 * playerStatsActiveModifiers.recallKnifeKillMilestoneMultiplier)


func move_to(pos: Vector2) -> void:
	global_position = pos


func recall() -> void:
	monitoring = true
	monitorable = true
	spriteWrapper.rotation = 0.0
	spriteWrapper.skew = 0.0
	isTimeToRecall = true


func stick_to_ground() -> void:
	spriteWrapper.rotation_degrees = 90.0 - rotation_degrees
	spriteWrapper.skew = 0.785398
	monitoring = false
	monitorable = false
	
	get_tree().create_timer(1.0).timeout.connect(recall)


func throw(towards: Vector2) -> void:
	dir = towards
	visible = true
	monitorable = true
	monitoring = true
	global_position = player.global_position + offset
	
	rotation = towards.angle()
	
	var destination: Vector2 = global_position + (towards * DISPLACEMENT_TOTAL)
	var tween: Tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(move_to, global_position, destination, 0.5)
	tween.finished.connect(stick_to_ground)


func _ready() -> void:
	visible = false
	monitorable = false
	monitoring = false
	body_entered.connect(handleHitConnect)
	stats = manager.stats


func _process(delta: float) -> void:
	if isTimeToRecall:
		target_pos = player.global_position + offset
		distanceSq_to_target = global_position.distance_squared_to(target_pos)
		move_distance = RECALL_SPEED * delta
		
		if move_distance*move_distance >= distanceSq_to_target:
			global_position = target_pos
			isTimeToRecall = false
			manager.readyAmount += 1
			visible = false
			set_deferred("monitorable", false)
			set_deferred("monitoring", false)
			
		else:
			dir = global_position.direction_to(target_pos)
			global_position += dir * move_distance
			rotation = PI + dir.angle()
