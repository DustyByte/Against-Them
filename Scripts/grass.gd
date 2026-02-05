extends Node2D

@onready var grassCanvas: CanvasGroup = $Grass
@onready var pointyPlantCanvas: CanvasGroup = $PointyPlants
@onready var rocksCanvas: CanvasGroup = $Rocks

var grassTextures: Array[Texture] = [
	preload("res://Assets/World Objects/LongGrass.png"),
	preload("res://Assets/World Objects/TiltedGrassLeft.png"),
	preload("res://Assets/World Objects/TinyGrassTilted.png"),
	preload("res://Assets/World Objects/TinyLeaf.png"),
	preload("res://Assets/World Objects/InverseTiltedGrass.png")
]
var pointyPlantBluePrints: Array[PackedScene] = [
	preload("res://Scenes/pointy_plant_1_branch_1.tscn"),
	preload("res://Scenes/pointy_plant_1_branch_2.tscn"),
	preload("res://Scenes/pointy_plant_1_branch_3.tscn"),
	preload("res://Scenes/pointy_plant_2_branch.tscn"),
	preload("res://Scenes/pointy_plant_3_branch.tscn")
]
var rockBluePrints: Array[PackedScene] = [
	preload("res://Scenes/rock_1.tscn"),
	preload("res://Scenes/rock_2.tscn"),
	preload("res://Scenes/rock_3.tscn"),
	preload("res://Scenes/rock_4.tscn"),
	preload("res://Scenes/rocks_12.tscn"),
	preload("res://Scenes/rocks_24.tscn"),
	preload("res://Scenes/rocks_123.tscn")
]
var majorCircleRadius: float = 300.0
var majorCirclePadding: float = 60.0
var minorCircleRadius: float = 1.4142 * majorCircleRadius 
var gridWindowAmount: int = 3


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


func spawn_grass(toSpawnAt: Vector2) -> void:
	var grass: Sprite2D = Sprite2D.new()
	
	grass.texture = grassTextures.pick_random()
	grass.position = toSpawnAt
	grass.scale = Vector2.ONE * randf_range(1.0, 1.5)
	grass.flip_h = randi_range(0, 99) <= 50
	grassCanvas.add_child(grass)


func spawn_grass_at_patch(patchLocation: Vector2) -> void:
	var points: PackedVector2Array = PoissonDiscSampling.generate_points_for_circle(patchLocation, 320, 20, 1)
	for point in points:
		spawn_grass(point)


func spawn_pointy_plant(toSpawnAt: Vector2) -> void:
	var plant: StaticBody2D = pointyPlantBluePrints.pick_random().instantiate()
	var randomBrightness: float = randf_range(0.75, 1.0)
	
	plant.position = toSpawnAt
	plant.scale.x *= -1.0 if randi_range(0, 99) <= 50 else 1.0
	plant.modulate = Color(randomBrightness, randomBrightness, randomBrightness)
	pointyPlantCanvas.add_child(plant)


func spawn_pointy_plants_in_circles(circleCenters: Array[Vector2]) -> void:
	for center in circleCenters:
		spawn_pointy_plant(get_random_point_in_circle(center, majorCircleRadius-majorCirclePadding))


func spawn_rock(toSpawnAt: Vector2) -> void:
	var rock = rockBluePrints.pick_random().instantiate()
	var randomBrightness: float = randf_range(0.75, 1.0)
	
	rock.position = toSpawnAt
	rock.modulate = Color(randomBrightness, randomBrightness, randomBrightness)
	rock.scale.x *= -1.0 if randi_range(0, 99) <= 50 else 1.0
	rocksCanvas.add_child(rock)


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
			spawn_grass_at_patch(patchLocation)


func _ready() -> void:
	var t = Time.get_ticks_usec()
	var m = OS.get_static_memory_usage()
	
	var windowDim: Vector2 = get_window().get_size() * 2
	
	generate_world_at(windowDim * Vector2(-1, 1))
	generate_world_at(windowDim * Vector2(0, -1))
	generate_world_at(windowDim * Vector2(1, -1))
	generate_world_at(windowDim * Vector2(-1, 0))
	generate_world_at(Vector2.ZERO)
	generate_world_at(windowDim * Vector2(1, 0))
	generate_world_at(windowDim * Vector2(-1, 1))
	generate_world_at(windowDim * Vector2(0, 1))
	generate_world_at(windowDim * Vector2(1, 1))
	
	print('time ', Time.get_ticks_usec() - t)
	print('memo ', OS.get_static_memory_usage() - m)
