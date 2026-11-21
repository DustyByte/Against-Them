extends Node2D

## Grass around the player, made one block ("chunk") per window-sized area of
## the world (windows are twice the screen size). Each block is drawn by its own
## MultiMesh, and blocks more than KEEP_DISTANCE windows away are freed, so the
## memory used and the cost of adding a block stay the same however far the
## player travels. (Before, all grass ever made lived in one list that was
## copied, sorted and re-uploaded as a whole whenever a new area was added.)
##
## New blocks are made on a worker thread, one batch at a time (the Poisson
## sampler keeps shared state), and handed to the main thread, which creates
## their MultiMesh. Grass right around the player is swapped for real sprites
## so it can be drawn in front of or behind the player (depth effect).
##
## Each block also gets a few boulders (boulder.gd), in the circles kept free
## of grass. Where they go is decided on the worker thread with a generator
## seeded by the block's coordinate, so a block always gets the same boulders
## when the player comes back. They never overlap: each one's art rect must
## stay clear of the others' (plus BOULDER_GAP) and inside its own block, so
## boulders of neighbouring blocks can't meet either. Grass under a boulder or
## its shadow is left out. Boulder nodes are pooled and reused.

@onready var player: CharacterBody2D = $"../Player"

var grassTextures: Array[Texture] = [
	preload("res://Assets/World Objects/Grass01.png"),
	preload("res://Assets/World Objects/Grass02.png"),
	preload("res://Assets/World Objects/Grass03.png"),
	preload("res://Assets/World Objects/Grass04.png"),
	preload("res://Assets/World Objects/Grass05.png")
]
# Plants and rocks. Placing them is switched off (see _generate_chunk), so their
# scenes are loaded when used instead of being preloaded with every run.
const POINTY_PLANT_SCENES: Array[String] = [
	"res://Scenes/WorldObjects/pointy_plant_1_branch_1.tscn",
	"res://Scenes/WorldObjects/pointy_plant_1_branch_2.tscn",
	"res://Scenes/WorldObjects/pointy_plant_1_branch_3.tscn",
	"res://Scenes/WorldObjects/pointy_plant_2_branch.tscn",
	"res://Scenes/WorldObjects/pointy_plant_3_branch.tscn"
]
const BOULDER_SCENE: PackedScene = preload("res://Scenes/WorldObjects/boulder.tscn")
## Chance that a circle kept free of grass gets a boulder (about 1-2 a screen).
const BOULDER_CHANCE: float = 0.6
const BOULDER_SIZE_MIN: float = 0.85
const BOULDER_SIZE_MAX: float = 1.1
const BOULDER_GAP: float = 40.0        # least space between two boulders' art
const BOULDER_SEED: int = 0x5EEDB01D
## How far a block's grass patches can reach past its edge (circle radius plus
## patch radius, with room to spare).
const GRASS_SPILL: float = 700.0
## Blocks further than this many windows from the player's window are freed.
const KEEP_DISTANCE: int = 2
const GRASS_SIZE: float = 32.0   # quad size, used to pad each block's bounds

var majorCircleRadius: float = 300.0
var majorCirclePadding: float = 60.0
var grassDepthEffectRad: float = 40.0
var tBegin: int = 0
var currentWinGrid := Vector2i.ZERO
var windowDim: Vector2
var twiceWindowDim: Vector2
var _material: Material
var _mesh: Mesh
var _chunks: Dictionary = {}       # Vector2i -> GrassChunk
var _wanted: Dictionary = {}       # Vector2i -> true: still to be made
var _building: bool = false        # a worker batch is running
var _task: int = -1                # its WorkerThreadPool task id
var grassHidden: Dictionary = {}   # Vector3i(chunk x, chunk y, index) -> Sprite2D
var _boulderPool: Array[Boulder] = []
@onready var _crowd: EnemyCrowd = get_parent().enemyCrowd   # made in world.gd's _init


class GrassChunk:
	var mmi: MultiMeshInstance2D
	var rid: RID                   # the MultiMesh, for hiding single blades
	var ys: PackedFloat32Array     # blade y positions, ascending (for bsearch)
	var pos: PackedVector2Array    # blade positions, same order
	var scale: PackedVector2Array
	var type: PackedByteArray      # which of grassTextures
	var bounds: Rect2              # around all blade positions
	var boulders: Array[Boulder] = []


func point_is_inside_circle(point: Vector2, circleCenter: Vector2, rad: float) -> bool:
	return point.distance_squared_to(circleCenter) < rad*rad


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


func spawn_pointy_plant(toSpawnAt: Vector2) -> void:
	var plant: StaticBody2D = load(POINTY_PLANT_SCENES.pick_random()).instantiate()
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


## Makes one block's grass: positions sorted by y plus its MultiMesh buffer.
## Runs on the worker thread (or the main thread for the first blocks), so it
## touches nothing but its own data.
func _generate_chunk(windowCoord: Vector2i) -> Dictionary:
	var blockCenter: Vector2 = Vector2(windowCoord) * twiceWindowDim
	var layout: Array = _block_layout(windowCoord)
	var majorGrid: Array[Vector2] = layout[0]
	var boulders: Array = layout[1]
	# Grass patches spill up to GRASS_SPILL past a block's edge, so the grass
	# must also keep clear of the neighbours' boulders near the shared edges.
	# Their layout is seeded, so it is simply worked out again here.
	var nearby: Array = boulders.duplicate()
	var reach: Rect2 = Rect2(blockCenter - twiceWindowDim * 0.5, twiceWindowDim).grow(GRASS_SPILL)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			for b in _block_layout(windowCoord + Vector2i(dx, dy))[1]:
				if reach.intersects(b[3]):
					nearby.append(b)

	var blades: Array = []   # [y, x, scale x, scale y, type]
	for circleCenter in majorGrid:
		for patchNum in range(randi_range(2, 4)):
			var patchLocation: Vector2 = get_random_point_in_circle(circleCenter, majorCircleRadius)
			for point in PoissonDiscSampling.generate_points_for_circle(patchLocation, 320, 20, 1):
				if not nearby.is_empty() and _under_boulder(point, nearby):
					continue   # under a boulder or its shadow
				var s: float = randf_range(1.0, 1.5)
				blades.append([point.y, point.x, -s if randf() < 0.5 else s, s, randi_range(0, 4)])
	return _pack_chunk(blades, boulders)


## Which of a block's circles get grass, and its boulders: seeded by the block,
## so it comes out the same every time (and for its neighbours, see above).
## Returns [grass circles, boulders]. Worker thread.
func _block_layout(windowCoord: Vector2i) -> Array:
	var blockCenter: Vector2 = Vector2(windowCoord) * twiceWindowDim
	var majorGrid: Array[Vector2] = get_major_circle_grid_for_window_at(blockCenter)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(windowCoord) ^ BOULDER_SEED
	for i in range(majorGrid.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2 = majorGrid[i]
		majorGrid[i] = majorGrid[j]
		majorGrid[j] = swap

	# One sixth of the circles are kept free for plants, one sixth for rocks.
	var sliceIndex := 1 + int(majorGrid.size() / 6.0)
	var slicedParts: Array = slice_array(majorGrid, sliceIndex)
	var circlesForPP: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]
	slicedParts = slice_array(majorGrid, clamp(sliceIndex, 0, majorGrid.size()))
	var circlesForRock: Array[Vector2] = slicedParts[0]
	majorGrid = slicedParts[1]

	#spawn_pointy_plants_in_circles(circlesForPP)   # (those circles now also take boulders)

	return [majorGrid, _place_boulders(circlesForRock + circlesForPP, blockCenter, rng)]


## Sorts a block's blades by y and packs them for its MultiMesh.
func _pack_chunk(blades: Array, boulders: Array) -> Dictionary:
	blades.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var n: int = blades.size()
	var ys := PackedFloat32Array()
	var pos := PackedVector2Array()
	var scale := PackedVector2Array()
	var type := PackedByteArray()
	var buffer := PackedFloat32Array()
	ys.resize(n)
	pos.resize(n)
	scale.resize(n)
	type.resize(n)
	buffer.resize(n * 12)
	var bounds := Rect2()
	for i in range(n):
		var b: Array = blades[i]
		var p := Vector2(b[1], b[0])
		ys[i] = b[0]
		pos[i] = p
		scale[i] = Vector2(b[2], b[3])
		type[i] = b[4]
		bounds = Rect2(p, Vector2.ZERO) if i == 0 else bounds.expand(p)
		# 2x4 transform (scale only, no rotation), then custom data: r = texture index.
		var bi: int = i * 12
		buffer[bi] = b[2]
		buffer[bi + 3] = p.x
		buffer[bi + 5] = b[3]
		buffer[bi + 7] = p.y
		buffer[bi + 8] = b[4]
	return { "ys": ys, "pos": pos, "scale": scale, "type": type, "buffer": buffer, "bounds": bounds, "boulders": boulders }


## Picks boulder spots: one try per free circle. A spot is kept only if its art
## rect stays inside this block and clear of every boulder kept so far, so no
## two boulders ever overlap, in this block or across a block edge. Returns
## [position, size, flipped, art rect, seed, kind] per boulder. Worker thread.
func _place_boulders(circles: Array, blockCenter: Vector2, rng: RandomNumberGenerator) -> Array:
	var inside: Rect2 = Rect2(blockCenter - twiceWindowDim * 0.5, twiceWindowDim).grow(-BOULDER_GAP)
	var innerRad: float = majorCircleRadius - majorCirclePadding
	var placed: Array = []
	for center in circles:
		if rng.randf() >= BOULDER_CHANCE:
			continue
		var at: Vector2 = center + Vector2.from_angle(rng.randf() * TAU) * innerRad * sqrt(rng.randf())
		var size: float = rng.randf_range(BOULDER_SIZE_MIN, BOULDER_SIZE_MAX)
		var flip: bool = rng.randf() < 0.5
		var kind: int = rng.randi() % Boulder.TEXTURES.size()   # which rock
		var art: Rect2 = Boulder.art_rect_at(at, kind, size, flip)
		if not inside.encloses(art):
			continue
		var spaced: Rect2 = art.grow(BOULDER_GAP)
		var spacedOut := true
		for other in placed:
			if spaced.intersects(other[3]):
				spacedOut = false
				break
		if spacedOut:
			placed.append([at, size, flip, art, rng.randi(), kind])
	return placed


## True if a grass blade at `point` would be under one of `boulders` (as made
## by _place_boulders): its art rect first (cheap), then its ovals.
func _under_boulder(point: Vector2, boulders: Array) -> bool:
	for b in boulders:
		if b[3].has_point(point) and Boulder.covers(point, b[0], b[5], b[1], b[2]):
			return true
	return false


func _spawn_boulder(data: Array) -> Boulder:
	var b: Boulder
	if _boulderPool.is_empty():
		b = BOULDER_SCENE.instantiate()
	else:
		b = _boulderPool.pop_back()
	add_child(b)
	b.setup(data[0], data[5], data[1], data[2], data[4], _mesh, _material)
	b.obstacle_ids.append(_crowd.add_obstacle(Boulder.footprint(data[0], data[5], data[1], data[2])))
	return b


func _recycle_boulder(b: Boulder) -> void:
	for id in b.obstacle_ids:
		_crowd.remove_obstacle(id)
	b.obstacle_ids.clear()
	remove_child(b)
	_boulderPool.append(b)


func _add_chunk(coord: Vector2i, data: Dictionary) -> void:
	_wanted.erase(coord)
	if _chunks.has(coord) or not _is_kept(coord):
		return
	var chunk := GrassChunk.new()
	chunk.ys = data.ys
	chunk.pos = data.pos
	chunk.scale = data.scale
	chunk.type = data.type
	chunk.bounds = data.bounds

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = _mesh
	var padded: Rect2 = chunk.bounds.grow(GRASS_SIZE * 2.0)
	mm.custom_aabb = AABB(Vector3(padded.position.x, padded.position.y, 0.0), Vector3(padded.size.x, padded.size.y, 0.0))
	mm.instance_count = chunk.pos.size()
	if chunk.pos.size():
		mm.buffer = data.buffer
	chunk.rid = mm.get_rid()

	chunk.mmi = MultiMeshInstance2D.new()
	chunk.mmi.multimesh = mm
	chunk.mmi.material = _material
	chunk.mmi.z_index = -1
	add_child(chunk.mmi)
	for b in data.boulders:
		chunk.boulders.append(_spawn_boulder(b))
	_chunks[coord] = chunk


func _is_kept(coord: Vector2i) -> bool:
	return maxi(absi(coord.x - currentWinGrid.x), absi(coord.y - currentWinGrid.y)) <= KEEP_DISTANCE


## Queues the 3x3 windows around the player that don't have grass yet.
func _want_around_player() -> void:
	for i in range(-1, 2):
		for j in range(-1, 2):
			var coord := currentWinGrid + Vector2i(i, j)
			if not _chunks.has(coord):
				_wanted[coord] = true
	_start_building()


func _start_building() -> void:
	if _building or _wanted.is_empty():
		return
	_building = true
	_task = WorkerThreadPool.add_task(_build_on_worker.bind(_wanted.keys()))


func _build_on_worker(coords: Array) -> void:   # worker thread
	for coord in coords:
		_add_chunk.call_deferred(coord, _generate_chunk(coord))
	_finish_building.call_deferred()


func _finish_building() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)   # already done; releases the task
	_task = -1
	_building = false
	_start_building()   # anything asked for while that batch ran


func _free_far_chunks() -> void:
	for coord: Vector2i in _chunks.keys():
		if _is_kept(coord):
			continue
		for key: Vector3i in grassHidden.keys():
			if key.x == coord.x and key.y == coord.y:
				grassHidden[key].queue_free()
				grassHidden.erase(key)
		_chunks[coord].mmi.queue_free()
		for b in _chunks[coord].boulders:
			_recycle_boulder(b)
		_chunks.erase(coord)
	for coord: Vector2i in _wanted.keys():
		if not _is_kept(coord):
			_wanted.erase(coord)


func get_current_win_grid_coord(playerPos: Vector2) -> Vector2i:
	var newWinGridCoord := Vector2i.ZERO

	var xyPosQuad: Vector2 = playerPos - twiceWindowDim * 0.5
	if xyPosQuad.x >= 0:
		newWinGridCoord.x += 1 + floori(xyPosQuad.x / twiceWindowDim.x)

	if xyPosQuad.y >= 0:
		newWinGridCoord.y += 1 + floori(xyPosQuad.y / twiceWindowDim.y)

	var xyNegQuad: Vector2 = playerPos + twiceWindowDim * 0.5
	if xyNegQuad.x < 0:
		newWinGridCoord.x -= 1 + floori(-xyNegQuad.x / twiceWindowDim.x)

	if xyNegQuad.y < 0:
		newWinGridCoord.y -= 1 + floori(-xyNegQuad.y / twiceWindowDim.y)

	return newWinGridCoord


func _blade_transform(chunk: GrassChunk, i: int) -> Transform2D:
	return Transform2D(0.0, chunk.scale[i], 0.0, chunk.pos[i])


func _exit_tree() -> void:
	# The worker reads this node's settings: let it finish before the run is freed.
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for b in _boulderPool:   # pooled boulders are out of the tree: free them by hand
		b.free()
	_boulderPool.clear()


func _ready() -> void:
	windowDim = get_window().get_size()
	twiceWindowDim = windowDim * 2.0

	# The Grass node in the scene only holds the shared material and quad.
	var template: MultiMeshInstance2D = $Grass
	_material = template.material
	_mesh = template.multimesh.mesh
	template.queue_free()

	for i in range(-1, 2):
		for j in range(-1, 2):
			var coord := Vector2i(i, j)
			_add_chunk(coord, _generate_chunk(coord))
	tBegin = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	var playerLegPos: Vector2 = player.global_position
	if player.velocity:
		var winGrid: Vector2i = get_current_win_grid_coord(playerLegPos)
		if winGrid != currentWinGrid:
			currentWinGrid = winGrid
			_free_far_chunks()
			_want_around_player()

		# Swap the blades the player stands in for sprites (drawn y-sorted with the player).
		var rad: float = grassDepthEffectRad
		for coord: Vector2i in _chunks:
			var chunk: GrassChunk = _chunks[coord]
			if not chunk.bounds.grow(rad).has_point(playerLegPos):
				continue
			var count: int = chunk.ys.size()
			var i: int = chunk.ys.bsearch(playerLegPos.y - rad)
			while i < count and chunk.ys[i] < playerLegPos.y + rad:
				if point_is_inside_circle(chunk.pos[i], playerLegPos, rad):
					var key := Vector3i(coord.x, coord.y, i)
					if not grassHidden.has(key):
						var cpuGrass: Sprite2D = Sprite2D.new()
						cpuGrass.texture = grassTextures[chunk.type[i]]
						cpuGrass.transform = _blade_transform(chunk, i)
						cpuGrass.offset.y = -9.0
						cpuGrass.position.y += 9.0
						add_child(cpuGrass)
						grassHidden[key] = cpuGrass
						RenderingServer.multimesh_instance_set_transform_2d(chunk.rid, i, Transform2D(0.0, Vector2.ZERO, 0.0, chunk.pos[i]))
				i += 1

	if grassHidden.is_empty():
		return
	var t: float = (Time.get_ticks_msec() - tBegin) * 0.004 # 0.001 * 4
	var toRestore: Array[Vector3i] = []
	for key: Vector3i in grassHidden:
		var cpuGrass: Sprite2D = grassHidden[key]
		if not point_is_inside_circle(cpuGrass.global_position, playerLegPos, grassDepthEffectRad+7):
			toRestore.append(key)
		else:
			var waves: float = sin(PI + t + (cpuGrass.global_position.x * 0.5))
			var chunk: GrassChunk = _chunks[Vector2i(key.x, key.y)]
			cpuGrass.scale.y = (1 + waves * 0.03125) * chunk.scale[key.z].y # 1/32
			cpuGrass.skew = waves * 0.155 # atan(5/32)
	for key in toRestore:
		var chunk: GrassChunk = _chunks[Vector2i(key.x, key.y)]
		RenderingServer.multimesh_instance_set_transform_2d(chunk.rid, key.z, _blade_transform(chunk, key.z))
		grassHidden[key].queue_free()
		grassHidden.erase(key)
