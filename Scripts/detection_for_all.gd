class_name BodyDetect
extends CollisionShape2D

@onready var spaceState: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
#@onready var selfRID: RID = get_rid()
var query: PhysicsShapeQueryParameters2D = null
## Most enemies one query returns (the engine's default is only 32).
const MAX_RESULTS: int = 256


func get_nearest_enemy_or_null_from(globalPosition: Vector2, toExclude: Array[RID] = [], detectionRange: float = 100.0) -> CharacterBody2D:
	global_position = globalPosition
	shape.radius = detectionRange
	
	query.transform = global_transform
	query.exclude = toExclude
	
	var bodiesData: Array[Dictionary] = spaceState.intersect_shape(query, MAX_RESULTS)
	if bodiesData.is_empty():
		return null
	
	# Keeps the closest so far (it used to keep the last one in range instead).
	var minDistSq: float = detectionRange*detectionRange
	var returnableBody: CharacterBody2D = null
	for bodyData in bodiesData:
		var body: CharacterBody2D = bodyData.collider
		var distSq: float = body.global_position.distance_squared_to(global_position)
		if distSq < minDistSq:
			minDistSq = distSq
			returnableBody = body
	
	return returnableBody


func get_all_enemies_from(globalPosition: Vector2, toExclude: Array[RID], range: float = 100.0) -> Array[CharacterBody2D]:
	global_position = globalPosition
	shape.radius = range
	
	query.transform = global_transform
	query.exclude = toExclude
	
	var result: Array[Dictionary] = spaceState.intersect_shape(query, MAX_RESULTS)
	var resultSize: int = result.size()
	var enemies: Array[CharacterBody2D] = []
	enemies.resize(resultSize)
	for i in range(resultSize):
		enemies[i] = result[i].collider
	
	return enemies


func _ready() -> void:
	query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4
	query.collide_with_areas = false
	
	global.DETECTOR = self
