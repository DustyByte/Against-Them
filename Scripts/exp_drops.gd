class_name ExpDrops
extends MultiMeshInstance2D

## Every EXP drop of the run, kept as plain data and drawn by this one
## MultiMesh: drop slot i is MultiMesh instance i. Before, each drop was its own
## Area2D node, so long runs piled up thousands of physics shapes and nodes.
##
## Enemies call add() when they die (bosses call spray_boss(), which throws a
## burst of drops out around them); the player's ExpManagementSystem calls
## update_pickup() every frame. Drops resting on the ground are indexed in a
## grid of CELL-sized cells, so finding the ones in reach only looks at the
## few cells around the player.
##
## Drops being pulled in draw a short comet tail behind them: a second
## MultiMesh (_trails) with one tapered, fading quad per slot, shown only while
## that drop flies. One extra transform per flying drop per frame, no shader.

const CELL: float = 128.0
const GROW_BY: int = 512
const DROP_ROTATION: float = 0.78539816339   # the square quad is drawn as a diamond
const DROP_RADIUS: float = 5.0               # as the old drop's collision circle
const COLLECT_DISTANCE_SQ: float = 400.0     # collected within 20 px
const HIDDEN := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

var _rid: RID
var _capacity: int = 0
var _used: int = 0                      # slots below this have been handed out
var _free: PackedInt32Array = []        # handed-out slots now empty again
var _pos: PackedVector2Array = []
var _amount: PackedFloat32Array = []
var _color: PackedColorArray = []
var _cells: Dictionary = {}             # Vector2i -> Array of resting slots
var _flying: PackedInt32Array = []      # slots being pulled towards the player
var _flyAge: PackedFloat32Array = []    # seconds each slot has been flying (grows its tail)
var _trails: MultiMeshInstance2D = null
var _trailRid: RID
const TRAIL_LENGTH: float = 40.0        # px, once fully grown (was 30)
const TRAIL_WIDTH: float = 9.0          # (was 6)
const TRAIL_GROW_TIME: float = 0.08     # the tail stretches out instead of popping in
## A drop swells to this size while it's pulled in (over TRAIL_GROW_TIME), so
## the pull reads as a snap of energy, not a dot sliding along.
const FLYING_DROP_SCALE: float = 1.6

## A boss's spray: drops leave its spot one after another over SPRAY_TIME and
## each hops out to a spot inside a circle of SPRAY_RADIUS, landing after
## HOP_TIME (only then can it be picked up).
const SPRAY_TIME: float = 0.7
const SPRAY_RADIUS: float = 170.0
const HOP_TIME: float = 0.35
const HOP_HEIGHT: float = 46.0
## Boss drops: BOSS_DROPS at the first boss wave, BOSS_DROPS_STEP more every
## 5 waves after. About BOSS_TYPE_2_SHARE of them are type 2; from wave
## BOSS_TYPE_3_WAVE, BOSS_TYPE_3_SHARE are type 3 (at least one). The rest type 1.
const BOSS_DROPS: int = 30
const BOSS_DROPS_STEP: int = 5
const BOSS_TYPE_2_SHARE: float = 0.2
const BOSS_TYPE_3_WAVE: int = 20
const BOSS_TYPE_3_SHARE: float = 0.05
var _sprays: Array = []     # [origin, targets (PackedVector2Array), types (Array), next, timer]
var _hops: Array = []       # [slot, from, to, age]


func _ready() -> void:
	_rid = multimesh.get_rid()
	_make_trails()
	_grow()
	set_process(false)   # only while a boss's drops are flying out


## Drops EXP of `type` (one of global.EXP_DROP_TYPES) at `at`.
func add(at: Vector2, type: Dictionary) -> void:
	var slot: int = _take_slot(at, type)
	_rest(slot)


## A boss died at `at` in `wave`: sprays its drops out around the spot (see
## the BOSS_ constants), mostly type 1, some type 2, and type 3 from wave 20.
func spray_boss(at: Vector2, wave: int) -> void:
	var count: int = BOSS_DROPS + BOSS_DROPS_STEP * maxi(wave / 5 - 1, 0)
	var type3: int = maxi(1, roundi(count * BOSS_TYPE_3_SHARE)) if wave >= BOSS_TYPE_3_WAVE else 0
	var type2: int = roundi(count * BOSS_TYPE_2_SHARE)
	var types: Array = []
	for i in count:
		if i < type3:
			types.append(global.EXP_DROP_TYPES.TYPE_3)
		elif i < type3 + type2:
			types.append(global.EXP_DROP_TYPES.TYPE_2)
		else:
			types.append(global.EXP_DROP_TYPES.TYPE_1)
	types.shuffle()
	# Where each lands: spread evenly over the circle (sqrt keeps the middle
	# from crowding), and never inside a boulder.
	var crowd: EnemyCrowd = global.WORLD.enemyCrowd
	var targets := PackedVector2Array()
	targets.resize(count)
	for i in count:
		var spot: Vector2 = at + Vector2.from_angle(randf() * TAU) * SPRAY_RADIUS * sqrt(randf())
		targets[i] = crowd.out_of_obstacles(spot, DROP_RADIUS * 2.0)
	_sprays.append([at, targets, types, 0, 0.0])
	set_process(true)


func _process(delta: float) -> void:
	# Let the next drops of each spray go.
	for i in range(_sprays.size() - 1, -1, -1):
		var spray: Array = _sprays[i]
		var targets: PackedVector2Array = spray[1]
		var interval: float = SPRAY_TIME / targets.size()
		spray[4] += delta
		while spray[3] < targets.size() and spray[4] >= spray[3] * interval:
			var n: int = spray[3]
			_hops.append([_take_slot(spray[0], spray[2][n]), spray[0], targets[n], 0.0])
			spray[3] = n + 1
		if spray[3] >= targets.size():
			_sprays.remove_at(i)
	# Move the hopping ones: out along the ground, easing in to land, up and
	# down in an arc on the way.
	for i in range(_hops.size() - 1, -1, -1):
		var hop: Array = _hops[i]
		hop[3] += delta
		var t: float = minf(hop[3] / HOP_TIME, 1.0)
		var slot: int = hop[0]
		if t >= 1.0:
			_pos[slot] = hop[2]
			RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(DROP_ROTATION, hop[2]))
			_rest(slot)
			_hops.remove_at(i)
			continue
		var along: float = 1.0 - (1.0 - t) * (1.0 - t)
		var p: Vector2 = hop[1].lerp(hop[2], along)
		_pos[slot] = p
		p.y -= HOP_HEIGHT * 4.0 * t * (1.0 - t)
		RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(DROP_ROTATION, p))
	if _sprays.is_empty() and _hops.is_empty():
		set_process(false)


## Hands out a slot for a drop of `type`, drawn at `at` (not yet resting, so
## not yet picked up).
func _take_slot(at: Vector2, type: Dictionary) -> int:
	var slot: int
	if not _free.is_empty():
		slot = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
	else:
		if _used == _capacity:
			_grow()
		slot = _used
		_used += 1
		RenderingServer.multimesh_set_visible_instances(_rid, _used)
		RenderingServer.multimesh_set_visible_instances(_trailRid, _used)

	var color: Color = type.color
	_pos[slot] = at
	_amount[slot] = type.expAmount
	_color[slot] = color
	RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(DROP_ROTATION, at))
	RenderingServer.multimesh_instance_set_color(_rid, slot, color)
	return slot


## Puts `slot` on the ground at its position, where the player can pick it up.
func _rest(slot: int) -> void:
	var key := Vector2i((_pos[slot] / CELL).floor())
	if _cells.has(key):
		_cells[key].append(slot)
	else:
		_cells[key] = [slot]


## Starts pulling in every resting drop within `reach` of `target`, moves the
## pulled ones `speed` px/s closer and returns the EXP amounts of those that
## arrived this frame (one entry per drop).
func update_pickup(target: Vector2, reach: float, speed: float, delta: float) -> PackedFloat32Array:
	_start_pulling(target, reach + DROP_RADIUS)
	var collected := PackedFloat32Array()
	if _flying.is_empty():
		return collected

	var step: float = speed * delta
	for i in range(_flying.size() - 1, -1, -1):
		var slot: int = _flying[i]
		var p: Vector2 = _pos[slot]
		if p.distance_squared_to(target) <= COLLECT_DISTANCE_SQ:
			collected.append(_amount[slot])
			_release(slot)
			_flying.remove_at(i)
		else:
			var dir: Vector2 = p.direction_to(target)
			p += dir * step
			_pos[slot] = p
			var age: float = _flyAge[slot] + delta
			_flyAge[slot] = age
			var grown: float = minf(age / TRAIL_GROW_TIME, 1.0)
			var size: float = lerpf(1.0, FLYING_DROP_SCALE, grown)
			RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(DROP_ROTATION, Vector2(size, size), 0.0, p))
			# Tail: from the drop back along where it came from, growing in.
			var length: float = TRAIL_LENGTH * grown
			var tail := Transform2D(dir.angle(), Vector2(length, TRAIL_WIDTH), 0.0, p - dir * length * 0.5)
			RenderingServer.multimesh_instance_set_transform_2d(_trailRid, slot, tail)
	return collected


func _start_pulling(center: Vector2, radius: float) -> void:
	var radiusSq: float = radius * radius
	var from := Vector2i(((center - Vector2(radius, radius)) / CELL).floor())
	var to := Vector2i(((center + Vector2(radius, radius)) / CELL).floor())
	for cx in range(from.x, to.x + 1):
		for cy in range(from.y, to.y + 1):
			var key := Vector2i(cx, cy)
			var cell = _cells.get(key)
			if cell == null:
				continue
			for k in range(cell.size() - 1, -1, -1):
				var slot: int = cell[k]
				if _pos[slot].distance_squared_to(center) <= radiusSq:
					_flying.append(slot)
					_flyAge[slot] = 0.0
					RenderingServer.multimesh_instance_set_color(_trailRid, slot, _color[slot])
					cell.remove_at(k)
			if cell.is_empty():
				_cells.erase(key)


func _release(slot: int) -> void:
	RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, HIDDEN)
	RenderingServer.multimesh_instance_set_transform_2d(_trailRid, slot, HIDDEN)
	_free.append(slot)


## The tails' MultiMesh, drawn behind the drops. Its texture is a comet made
## once here: bright and full width at the head (right), thin and clear at the
## end (left); the instance color tints it to the drop's color.
func _make_trails() -> void:
	var w: int = 64
	var h: int = 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var along: float = float(x) / (w - 1)          # 0 at the end, 1 at the head
		var half: float = 0.5 * (0.25 + 0.75 * along)  # tapers towards the end
		for y in h:
			var across: float = absf((y + 0.5) / h - 0.5)
			var edge: float = clampf((half - across) / 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(along, 1.6) * edge * 0.75))
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.custom_aabb = multimesh.custom_aabb
	mm.mesh = quad
	_trails = MultiMeshInstance2D.new()
	_trails.name = "Trails"
	_trails.multimesh = mm
	_trails.texture = ImageTexture.create_from_image(img)
	_trails.show_behind_parent = true
	add_child(_trails)
	_trailRid = mm.get_rid()


## Makes room for GROW_BY more drops, keeping the ones already drawn.
func _grow() -> void:
	var oldCapacity: int = _capacity
	_capacity += GROW_BY
	_pos.resize(_capacity)
	_amount.resize(_capacity)
	_color.resize(_capacity)
	_flyAge.resize(_capacity)

	# Reallocating clears the MultiMesh, so rebuild it from the data. Empty
	# slots are left zero-sized. Layout per instance: a 2x4 transform, then the color.
	var buffer := PackedFloat32Array()
	buffer.resize(_capacity * 12)
	var isFree: Dictionary = {}
	for slot in _free:
		isFree[slot] = true
	var c: float = cos(DROP_ROTATION)
	var s: float = sin(DROP_ROTATION)
	for slot in range(mini(_used, oldCapacity)):
		if isFree.has(slot):
			continue
		var b: int = slot * 12
		var p: Vector2 = _pos[slot]
		var color: Color = _color[slot]
		buffer[b] = c
		buffer[b + 1] = -s
		buffer[b + 3] = p.x
		buffer[b + 4] = s
		buffer[b + 5] = c
		buffer[b + 7] = p.y
		buffer[b + 8] = color.r
		buffer[b + 9] = color.g
		buffer[b + 10] = color.b
		buffer[b + 11] = color.a
	RenderingServer.multimesh_allocate_data(_rid, _capacity, RenderingServer.MULTIMESH_TRANSFORM_2D, true, false)
	RenderingServer.multimesh_set_buffer(_rid, buffer)
	RenderingServer.multimesh_set_visible_instances(_rid, _used)
	# Tails start hidden (zero-sized); flying drops redraw theirs next frame.
	var hidden := PackedFloat32Array()
	hidden.resize(_capacity * 12)
	RenderingServer.multimesh_allocate_data(_trailRid, _capacity, RenderingServer.MULTIMESH_TRANSFORM_2D, true, false)
	RenderingServer.multimesh_set_buffer(_trailRid, hidden)
	RenderingServer.multimesh_set_visible_instances(_trailRid, _used)
