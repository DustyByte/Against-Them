extends Node2D

@onready var grassMMI: MultiMeshInstance2D = $Grass
@onready var grassMMRID: RID = grassMMI.multimesh.get_rid()
@onready var player: CharacterBody2D = $"../Player"

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
var currentWinGrid: Vector2 = Vector2.ZERO
var builtWindows: Dictionary = {}
var windowDim: Vector2
var twiceWindowDim: Vector2


func point_is_inside_circle(point: Vector2, circleCenter: Vector2, rad: float) -> bool:
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


func generate_grass_data_at(at: Vector2) -> Array:
	var grassTypeIdx: int = randi_range(0, 4)
	
	var grassScale = Vector2.ONE * randf_range(1.0, 1.5)
	grassScale.x *= -1.0 if randf() < 0.5 else 1.0
	
	var xForm: Transform2D = Transform2D(0.0, grassScale, 0.0, at)
	
	return [xForm, grassTypeIdx, Time.get_ticks_msec()]


func generate_grass_data_at_patch(patchLocation: Vector2) -> void:
	var points: PackedVector2Array = PoissonDiscSampling.generate_points_for_circle(patchLocation, 320, 20, 1)
	var extraArray: Array = []
	extraArray.resize(points.size())
	
	var i: int = 0
	for point in points:
		extraArray[i] = generate_grass_data_at(point)
		i += 1
	
	grassData.append_array(extraArray)


func worker_thread_generate_grass_data_at_patch(patchLocation: Vector2, tempGrassDataHolder: Array) -> void:
	var points: PackedVector2Array = PoissonDiscSampling.generate_points_for_circle(patchLocation, 320, 20, 1)
	var extraArray: Array = []
	extraArray.resize(points.size())
	
	var i: int = 0
	for point in points:
		extraArray[i] = generate_grass_data_at(point)
		i += 1
	
	tempGrassDataHolder.append_array(extraArray)


func mm_object_sort_logic(A: Array, B: Array) -> bool:
	return A[0].origin.y < B[0].origin.y


func worker_update_grass_mm(dataToAdd: Array) -> void:
	var tempGrassData: Array = grassData.duplicate(true)
	tempGrassData.append_array(dataToAdd)
	tempGrassData.sort_custom(mm_object_sort_logic)
	
	var buffer: PackedFloat32Array = create_buffer(tempGrassData)
	var tgdSize: int = tempGrassData.size()
	
	RenderingServer.multimesh_allocate_data(grassMMRID, tgdSize, RenderingServer.MULTIMESH_TRANSFORM_2D, false, true)
	RenderingServer.multimesh_set_buffer(grassMMRID, buffer)
	RenderingServer.multimesh_set_visible_instances(grassMMRID, tgdSize)
	
	var update_main_thread_data: Callable = func(data: Array):
		grassData = data
	update_main_thread_data.bind(tempGrassData).call_deferred()


func update_grass_mm() -> void:
	grassData.sort_custom(mm_object_sort_logic)
	
	var buffer: PackedFloat32Array = create_buffer(grassData)
	var gdSize: int = grassData.size()
	
	RenderingServer.multimesh_allocate_data(grassMMRID, gdSize, RenderingServer.MULTIMESH_TRANSFORM_2D, false, true)
	RenderingServer.multimesh_set_buffer(grassMMRID, buffer)
	RenderingServer.multimesh_set_visible_instances(grassMMRID, gdSize)


func set_grass_data(newGrassData: Array) -> void:
	grassData = newGrassData


func spawn_pointy_plant(toSpawnAt: Vector2) -> void:
	var plant: StaticBody2D = pointyPlantBluePrints.pick_random().instantiate()
	var randomBrightness: float = randf_range(0.75, 1.0)
	
	plant.position = toSpawnAt
	plant.modulate.b = randomBrightness
	plant.scale.x = -1.0 if randi_range(0, 99) <= 50 else 1.0
	add_child(plant)


func spawn_pointy_plants_in_circles(circleCenters: Array[Vector2]) -> void:
	var innerCircleRad: float = majorCircleRadius-majorCirclePadding
	for center in circleCenters:
		var randomPoint: Vector2 = get_random_point_in_circle(center, innerCircleRad)
		spawn_pointy_plant.call_deferred(randomPoint)


func spawn_rock(toSpawnAt: Vector2) -> void:
	var rock = rockBluePrints.pick_random().instantiate()
	var randomBrightness: float = randf_range(0.75, 1.0)
	
	rock.position = toSpawnAt
	rock.modulate.b = randomBrightness
	rock.scale.x *= -1.0 if randi_range(0, 99) <= 50 else 1.0
	add_child(rock)


func spawn_rocks_in_circles(circleCenters: Array[Vector2]) -> void:
	var innerCircleRad: float = majorCircleRadius-majorCirclePadding
	for center in circleCenters:
		var randomPoint: Vector2 = get_random_point_in_circle(center, innerCircleRad)
		spawn_rock.call_deferred(randomPoint)


func get_major_circle_grid_for_window_at(windowRectCenter: Vector2) -> Array[Vector2]:
	var windowSize: Vector2 = windowDim
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


func generate_world_at(windowCoord: Vector2) -> void:
	var majorGrid: Array[Vector2] = get_major_circle_grid_for_window_at(windowCoord * twiceWindowDim)
	
	majorGrid.shuffle()
	
	var sliceIndex := 1 + int(majorGrid.size() * 1.0/6.0)
	
	var slicedParts: Array = slice_array(majorGrid, sliceIndex)
	var circlesForPP: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]
	
	slicedParts = slice_array(majorGrid, clamp(sliceIndex, 0, majorGrid.size()))
	var circlesForRock: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]
	
	#spawn_pointy_plants_in_circles(circlesForPP)
	#spawn_rocks_in_circles(circlesForRock)
	
	
	for circleCenter in majorGrid:
		var patchAmount: int = randi_range(2, 4)
		for patchNum in range(patchAmount):
			var patchLocation: Vector2 = get_random_point_in_circle(circleCenter, majorCircleRadius)
			generate_grass_data_at_patch(patchLocation)
	
	builtWindows[windowCoord] = true


func worker_thread_generate_world_at(windowCoord: Vector2, tempGrassDataHolder: Array) -> void:
	if builtWindows.has(windowCoord):
		return
	
	var majorGrid: Array[Vector2] = get_major_circle_grid_for_window_at(windowCoord*twiceWindowDim)
	
	majorGrid.shuffle()
	
	var sliceIndex := 1 + int(majorGrid.size() * 0.1667)
	
	var slicedParts: Array = slice_array(majorGrid, sliceIndex)
	var circlesForPP: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]
	
	slicedParts = slice_array(majorGrid, clamp(sliceIndex, 0, majorGrid.size()))
	var circlesForRock: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]
	
	#spawn_pointy_plants_in_circles(circlesForPP)
	#spawn_rocks_in_circles(circlesForRock)
	
	
	for circleCenter in majorGrid:
		var patchAmount: int = randi_range(2, 4)
		for patchNum in range(patchAmount):
			var patchLocation: Vector2 = get_random_point_in_circle(circleCenter, majorCircleRadius)
			worker_thread_generate_grass_data_at_patch(patchLocation, tempGrassDataHolder)
	
	update_build_window_dic.call_deferred(windowCoord)


func update_build_window_dic(winCoord: Vector2) -> void:
	builtWindows[winCoord] = true


func add_grass_data_to_main_thread_data_array(arrayToAdd: Array) -> void:
	grassData.append_array(arrayToAdd)


func get_current_win_grid_coord(playerPos: Vector2) -> Vector2:
	var newWinGridCoord: Vector2 = Vector2.ZERO
	
	var xyPosQuad: Vector2 = playerPos - twiceWindowDim * 0.5
	if xyPosQuad.x >= 0:
		newWinGridCoord.x += 1 + floor(xyPosQuad.x / twiceWindowDim.x)
	
	if xyPosQuad.y >= 0:
		newWinGridCoord.y += 1 + floor(xyPosQuad.y / twiceWindowDim.y)
	
	var xyNegQuad: Vector2 = playerPos + twiceWindowDim * 0.5
	if xyNegQuad.x < 0:
		newWinGridCoord.x -= 1 + floor(-xyNegQuad.x / twiceWindowDim.x)
	
	if xyNegQuad.y < 0:
		newWinGridCoord.y -= 1 + floor(-xyNegQuad.y / twiceWindowDim.y)
	
	return newWinGridCoord


func get_unbuilt_win_grid_coord_from(winGridCoord: Vector2) -> PackedVector2Array:
	var unbuiltWinCoord: PackedVector2Array = PackedVector2Array([])
	unbuiltWinCoord.resize(8)
	
	var xLoopFrom: int = winGridCoord.x-1
	var xLoopTo: int = winGridCoord.x+2
	var yLoopFrom: int = winGridCoord.y-1
	var yLoopTo: int = winGridCoord.y+2
	
	var k: int = 0
	for i in range(xLoopFrom, xLoopTo):
		for j in range(yLoopFrom, yLoopTo):
			if i == winGridCoord.x and j == winGridCoord.y:
				continue
			
			var coord: Vector2 = Vector2(i, j)
			if not builtWindows.has(coord):
				unbuiltWinCoord[k] = coord
				k += 1
	
	unbuiltWinCoord.resize(k)
	
	return unbuiltWinCoord


func _build_world_at_coords(coords: PackedVector2Array) -> void: # NEVER call from main thread
	var tempGrassDataHolder: Array = []
	for coord in coords:
		worker_thread_generate_world_at(coord, tempGrassDataHolder)
	worker_update_grass_mm(tempGrassDataHolder)


func _ready() -> void:
	windowDim = get_window().get_size()
	twiceWindowDim = get_window().get_size() * 2.0
	
	grassData.append([Transform2D(0.0, Vector2.DOWN * 20000.0), 1, 100])
	
	for i in range(-1, 2):
		for j in range(-1, 2):
			generate_world_at(Vector2(i, j))
	
	update_grass_mm()
	tBegin = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if player.velocity:
		var playerLegPos: Vector2 = player.global_position
		var half_dim: Vector2 = twiceWindowDim * 0.5
		var diff: Vector2 = (playerLegPos - currentWinGrid * twiceWindowDim).abs()
		if diff.x > half_dim.x or diff.y > half_dim.y:
			currentWinGrid = get_current_win_grid_coord(playerLegPos)
			var unbuiltGridCoords: PackedVector2Array = get_unbuilt_win_grid_coord_from(currentWinGrid)
			if not unbuiltGridCoords.is_empty():
				WorkerThreadPool.add_task(_build_world_at_coords.bind(unbuiltGridCoords))
		
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
					cpuGrass.position.y += 9.0
					
					add_child(cpuGrass)
					grassHidden[key] = cpuGrass
					
					RenderingServer.multimesh_instance_set_transform_2d(grassMMRID, i, xform.scaled(Vector2.ZERO))
			i += 1
	
	for grassKey in grassHidden:
		var cpuGrass: Sprite2D = grassHidden[grassKey]
		
		if not point_is_inside_circle(cpuGrass.global_position, player.global_position, grassDepthEffectRad+7):
			RenderingServer.multimesh_instance_set_transform_2d(grassMMRID, grassKey.x, grassData[grassKey.x][0])
			cpuGrass.queue_free()
			grassHidden.erase(grassKey)
		
		else:
			var t: float = (Time.get_ticks_msec() - tBegin) * 0.004 # 0.001 * 4
			var waves: float = sin(PI + t + (cpuGrass.global_position.x * 0.5))
			var skewedAmount: float = waves * 0.155 # atan(5/32)
			var scaleAdjust: float = 1 + waves * 0.03125 # 1/32
		
			cpuGrass.scale.y = scaleAdjust * grassData[grassKey.x][0].get_scale().y
			cpuGrass.skew = skewedAmount
