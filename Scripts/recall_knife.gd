class_name RecallKnife
extends Area2D

const DISPLACEMENT_TOTAL: float = 500.0
## Throw: leaves fast and slows to a stop (quadratic ease-out over this time).
const THROW_TIME: float = 0.5
## Recall: starts slow and speeds up toward Echo. From the full 500 px away
## it gets back in about 0.36 s (the old flat 1500 px/s took 0.33 s).
const RECALL_START_SPEED: float = 300.0
const RECALL_ACCEL: float = 6000.0       # px/s gained every second
const RECALL_MAX_SPEED: float = 3000.0
var recall_speed: float = RECALL_START_SPEED
## Fading light ribbon through where the dagger was in the last TRAIL_TIME
## seconds: long when fast, short when slow, gone while it sits in the ground.
## Time-based, so it is the same length at any frame rate. Only the points are
## kept here (world positions, oldest first); the manager draws every dagger's
## trail and glow in two batches (recall_knives_manager.gd).
const TRAIL_TIME: float = 0.12
var trail_points: PackedVector2Array = PackedVector2Array()
var _trail_times: PackedFloat32Array = PackedFloat32Array()
var _clock: float = 0.0
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
	recall_speed = RECALL_START_SPEED
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
	_clear_trail()   # don't connect to where it was last time
	
	rotation = towards.angle()
	
	var destination: Vector2 = global_position + (towards * DISPLACEMENT_TOTAL)
	var tween: Tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)   # fast out, fading to a stop
	tween.tween_method(move_to, global_position, destination, THROW_TIME)
	tween.finished.connect(stick_to_ground)


func _ready() -> void:
	visible = false
	monitorable = false
	monitoring = false
	body_entered.connect(handleHitConnect)
	stats = manager.stats


func _process(delta: float) -> void:
	if visible:
		_update_trail(delta)
	if isTimeToRecall:
		target_pos = player.global_position + offset
		distanceSq_to_target = global_position.distance_squared_to(target_pos)
		recall_speed = minf(recall_speed + RECALL_ACCEL * delta, RECALL_MAX_SPEED)
		move_distance = recall_speed * delta
		
		if move_distance*move_distance >= distanceSq_to_target:
			global_position = target_pos
			isTimeToRecall = false
			manager.readyAmount += 1
			visible = false
			_clear_trail()
			set_deferred("monitorable", false)
			set_deferred("monitoring", false)
			
		else:
			dir = global_position.direction_to(target_pos)
			global_position += dir * move_distance
			rotation = PI + dir.angle()


# --- Trail --------------------------------------------------------------------

func _update_trail(delta: float) -> void:
	_clock += delta
	var count: int = trail_points.size()
	if count == 0 or trail_points[count - 1].distance_squared_to(global_position) > 1.0:
		trail_points.append(global_position)
		_trail_times.append(_clock)
	# Drop points older than TRAIL_TIME from the tail end.
	var expired: int = 0
	while expired < _trail_times.size() and _clock - _trail_times[expired] > TRAIL_TIME:
		expired += 1
	if expired:
		trail_points = trail_points.slice(expired)
		_trail_times = _trail_times.slice(expired)


func _clear_trail() -> void:
	trail_points.clear()
	_trail_times.clear()
