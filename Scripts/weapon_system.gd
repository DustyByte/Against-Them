extends Node2D

@onready var detectionRange: Area2D = $EnemyDetectionRange
@onready var weaponUpdateTimer: Timer = $Timer
var weapon = null
var weaponInPlayerInitPositionX: float
var updateInterval: float = 0.1


func get_nearest_attackable() -> Node2D:
	var bodies: Array = detectionRange.get_overlapping_bodies()
	var nearestDistance: float = INF
	var nearestAttackable = null
	
	for body in bodies:
		if body.is_in_group("attackable"):
			var distance: float = body.global_position.distance_squared_to(global_position)
			if distance <= nearestDistance:
				nearestDistance = distance
				nearestAttackable = body
	
	return nearestAttackable if nearestAttackable else null


func update_weapon_direction(direction: Vector2) -> void:
	if direction.x > 0:
		weapon.scale = Vector2.ONE
		weapon.position.x = weaponInPlayerInitPositionX
	elif direction.x <= 0:
		weapon.scale = Vector2(1, -1)
		weapon.position.x = -weaponInPlayerInitPositionX
	
	var thetaRad: float = Vector2.RIGHT.angle_to(direction)
	weapon.rotation = thetaRad
	weapon.currentlyPointingTowards = direction


func handle_update_timer_timeout() -> void:
	var nearestAttackable := get_nearest_attackable()
	if nearestAttackable:
		var directionToAimAt: Vector2 = global_position.direction_to(nearestAttackable.global_position)
		update_weapon_direction(directionToAimAt)
	weaponUpdateTimer.start(updateInterval)


func _ready() -> void:
	weapon = get_child(0)
	weaponInPlayerInitPositionX = weapon.position.x
	
	weaponUpdateTimer.one_shot = true
	weaponUpdateTimer.start(updateInterval)
	weaponUpdateTimer.timeout.connect(handle_update_timer_timeout)
