extends Node2D

@onready var grassMMI: MultiMeshInstance2D = $Grass
@onready var grassMMRID: RID = grassMMI.multimesh.get_rid()
var player: CharacterBody2D = null

var grassTextures: Array[Texture] = [
	preload("res://Assets/World Objects/Grass01.png"),
	preload("res://Assets/World Objects/Grass02.png"),
	preload("res://Assets/World Objects/Grass03.png"),
	preload("res://Assets/World Objects/Grass04.png"),
	preload("res://Assets/World Objects/Grass05.png")
]
var pointyPlantBluePrints: Array[PackedScene] = [
	preload("res://Scenes/WorldObjects/pointy_plant_1_branch_1.tscn"),
	preload("res://Scenes/WorldObjects/pointy_plant_1_branch_2.tscn"),
	preload("res://Scenes/WorldObjects/pointy_plant_1_branch_3.tscn"),
	preload("res://Scenes/WorldObjects/pointy_plant_2_branch.tscn"),
	preload("res://Scenes/WorldObjects/pointy_plant_3_branch.tscn")
]
var rockBluePrints: Array[PackedScene] = [
	preload("res://Scenes/WorldObjects/rock_1.tscn"),
	preload("res://Scenes/WorldObjects/rock_2.tscn"),
	preload("res://Scenes/WorldObjects/rock_3.tscn"),
	preload("res://Scenes/WorldObjects/rock_4.tscn"),
	preload("res://Scenes/WorldObjects/rocks_12.tscn"),
	preload("res://Scenes/WorldObjects/rocks_24.tscn"),
	preload("res://Scenes/WorldObjects/rocks_123.tscn")
]
var grassData: Array = []
var majorCircleRadius: float = 300.0
var majorCirclePadding: float = 60.0
var minorCircleRadius: float = 1.4142 * majorCircleRadius 
var gridWindowAmount: int = 3
var grassDepthEffectRad: float = 40.0
var grassDepthEffectRadSq: float = 1600.0
var grassHidden: Dictionary = {}
var tBegin: int = 0


func point_is_inside_circle(point: Vector2, circleCenter: Vector2, rad: float) -> bool:
	#if point.x > circleCenter.x-rad and point.x < circleCenter.x+rad:
	if point.distance_squared_to(circleCenter) < rad*rad:
		return true
	return false


func binary_custom(a: Array, b: Array) -> bool:
	return a[0].origin.y < b[0].origin.y


func create_buffer(arr: Array) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(arr.size() * 12)
	
	for i in range(arr.size()):
		var bi: int = i * 12
		var xform: Transform2D = arr[i][0]
		
		buffer[bi] = xform.x.x
		buffer[bi + 1] = xform.y.x
		buffer[bi + 2] = 0.0
		buffer[bi + 3] = xform.origin.x
		buffer[bi + 4] = xform.x.y
		buffer[bi + 5] = xform.y.y
		buffer[bi + 6] = 0.0
		buffer[bi + 7] = xform.origin.y
		buffer[bi + 8] = arr[i][1]
		buffer[bi + 9] = arr[i][2]
		buffer[bi + 10] = 0.0
		buffer[bi + 11] = 0.0
	return buffer


func slice_array(arr: Array, at: int) -> Array:
	var leftSlice := arr.slice(0, at)
	var rightSlice := arr.slice(at, arr.size())
	
	return [leftSlice, rightSlice]


func get_random_point_in_circle(center: Vector2, radius: float) -> Vector2:
	var x: float = randf_range(center.x-radius, center.x+radius)
	var component: float = sqrt(pow(radius, 2.0) - pow((x - center.x), 2.0))
	var yRangeBegin: float = -component + center.y
	var yRangeEnd: float = component + center.y
	var y: float = randf_range(yRangeBegin, yRangeEnd)
	
	return Vector2(x, y)


func generate_grass_data_at(at: Vector2) -> void:
	var grassTypeIdx: int = randi_range(0, 4)
	
	var grassScale = Vector2.ONE * randf_range(1.0, 1.5)
	grassScale.x *= -1.0 if randf() < 0.5 else 1.0
	
	var xForm: Transform2D = Transform2D(0.0, grassScale, 0.0, at)
	
	grassData.append([xForm, grassTypeIdx, Time.get_ticks_msec()])


func generate_grass_data_at_patch(patchLocation: Vector2) -> void:
	var points: PackedVector2Array = PoissonDiscSampling.generate_points_for_circle(patchLocation, 320, 20, 1)
	for point in points:
		generate_grass_data_at(point)


func mm_object_sort_logic(A: Array, B: Array) -> bool:
	return A[0].origin.y < B[0].origin.y


func update_grass_mm() -> void:
	grassData.sort_custom(mm_object_sort_logic)
	
	var buffer: PackedFloat32Array = create_buffer(grassData)
	
	RenderingServer.multimesh_allocate_data(grassMMRID, grassData.size(), RenderingServer.MULTIMESH_TRANSFORM_2D, false, true)
	RenderingServer.multimesh_set_buffer(grassMMRID, buffer)
	RenderingServer.multimesh_set_visible_instances(grassMMRID, grassData.size())


func spawn_pointy_plant(toSpawnAt: Vector2) -> void:
	var plant: StaticBody2D = pointyPlantBluePrints.pick_random().instantiate()
	var randomBrightness: float = randf_range(0.75, 1.0)
	
	plant.position = toSpawnAt
	plant.modulate.b = randomBrightness
	plant.scale.x = -1.0 if randi_range(0, 99) <= 50 else 1.0
	add_child(plant)


func spawn_pointy_plants_in_circles(circleCenters: Array[Vector2]) -> void:
	for center in circleCenters:
		spawn_pointy_plant(get_random_point_in_circle(center, majorCircleRadius-majorCirclePadding))


func spawn_rock(toSpawnAt: Vector2) -> void:
	var rock = rockBluePrints.pick_random().instantiate()
	var randomBrightness: float = randf_range(0.75, 1.0)
	
	rock.position = toSpawnAt
	rock.modulate.b = randomBrightness
	rock.scale.x *= -1.0 if randi_range(0, 99) <= 50 else 1.0
	add_child(rock)


func spawn_rocks_in_circles(circleCenters: Array[Vector2]) -> void:
	for center in circleCenters:
		spawn_rock(get_random_point_in_circle(center, majorCircleRadius-majorCirclePadding))


func get_major_circle_grid_for_window_at(windowRectCenter: Vector2) -> Array[Vector2]:
	var windowSize: Vector2 = get_window().get_size()
	var grid: Array[Vector2] = []
	var edgeLength := majorCircleRadius * 2
	
	var xDirPointAmount := int(windowSize.x / edgeLength)
	var yDirPointAmount := int(windowSize.y / edgeLength)
	
	grid.resize((2*xDirPointAmount + 1) * (2*yDirPointAmount + 1))
	var index := 0
	
	for i in range(-xDirPointAmount, xDirPointAmount + 1):
		var xValue := windowRectCenter.x + edgeLength * i
		for j in range(-yDirPointAmount, yDirPointAmount +1):
			grid[index] = (Vector2(xValue, windowRectCenter.y + edgeLength * j))
			index += 1
	
	return grid


func generate_world_at(location: Vector2) -> void:
	var majorGrid: Array[Vector2] = get_major_circle_grid_for_window_at(location)
	
	majorGrid.shuffle()
	
	var sliceIndex := 1 + int(majorGrid.size() * (1.0/6.0))
	
	var slicedParts: Array = slice_array(majorGrid, sliceIndex)
	var circlesForPP: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]
	
	slicedParts = slice_array(majorGrid, clamp(sliceIndex, 0, majorGrid.size()))
	var circlesForRock: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]
	
	
	spawn_pointy_plants_in_circles(circlesForPP)
	spawn_rocks_in_circles(circlesForRock)
	
	for circleCenter in majorGrid:
		var patchAmount: int = randi_range(2, 4)
		for patchNum in range(patchAmount):
			var patchLocation: Vector2 = get_random_point_in_circle(circleCenter, majorCircleRadius)
			generate_grass_data_at_patch(patchLocation)


func _ready() -> void:
	var windowDim: Vector2 = get_window().get_size() * 2
	
	generate_world_at(windowDim * Vector2(-1, -1))
	generate_world_at(windowDim * Vector2(0, -1))
	generate_world_at(windowDim * Vector2(1, -1))
	generate_world_at(windowDim * Vector2(-1, 0))
	generate_world_at(Vector2.ZERO)
	generate_world_at(windowDim * Vector2(1, 0))
	generate_world_at(windowDim * Vector2(-1, 1))
	generate_world_at(windowDim * Vector2(0, 1))
	generate_world_at(windowDim * Vector2(1, 1))
	update_grass_mm()
	
	tBegin = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not player:
		player = global.PLAYER
		return
	
	if player.velocity:
		var playerLegPos: Vector2 = player.global_position
		var circleUpBorder: Array = [Transform2D(0.0, playerLegPos - Vector2(0, grassDepthEffectRad))]
		var circleBottomBorder: float = playerLegPos.y + grassDepthEffectRad
		
		var i: int = grassData.bsearch_custom(circleUpBorder, binary_custom)
		while grassData[i][0].origin.y < circleBottomBorder:
			var xform: Transform2D = grassData[i][0]
			var key: Vector2 = Vector2(i, 0)
			if point_is_inside_circle(xform.origin, playerLegPos, grassDepthEffectRad):
				if not grassHidden.has(key):
					var cpuGrass: Sprite2D = Sprite2D.new()
					cpuGrass.texture = grassTextures[grassData[i][1]]
					cpuGrass.transform = xform
					cpuGrass.offset.y = -9.0
					cpuGrass.position.y += 9
					
					add_child(cpuGrass)
					grassHidden[key] = cpuGrass
					
					RenderingServer.multimesh_instance_set_transform_2d(grassMMRID, i, xform.scaled(Vector2.ZERO))
			i += 1
	
	for grassKey in grassHidden:
		var cpuGrass: Sprite2D = grassHidden[grassKey]
		var t: float = (Time.get_ticks_msec() - tBegin)/1000.0
		
		if not point_is_inside_circle(cpuGrass.global_position, player.global_position, grassDepthEffectRad+7):
			RenderingServer.multimesh_instance_set_transform_2d(grassMMRID, grassKey.x, grassData[grassKey.x][0])
			cpuGrass.queue_free()
			grassHidden.erase(grassKey)
		
		else:
			var waves: float = sin(PI + t * 4.0 + (cpuGrass.global_position.x * 0.5))

			var skewedAmount: float = waves * atan(5.0/32.0)
			var scaleAdjust: float = 1 + waves * 1.0/32.0

			cpuGrass.scale.y = scaleAdjust * grassData[grassKey.x][0].get_scale().y
			cpuGrass.skew = skewedAmount
	
