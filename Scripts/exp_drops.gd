class_name ExpDrops
extends MultiMeshInstance2D

## Every EXP drop of the run, kept as plain data and drawn by this one
## MultiMesh: drop slot i is MultiMesh instance i. Before, each drop was its own
## Area2D node, so long runs piled up thousands of physics shapes and nodes.
##
## Enemies call add() when they die; the player's ExpManagementSystem calls
## update_pickup() every frame. Drops resting on the ground are indexed in a
## grid of CELL-sized cells, so finding the ones in reach only looks at the
## few cells around the player.

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


func _ready() -> void:
	_rid = multimesh.get_rid()
	_grow()


## Drops EXP of `type` (one of global.EXP_DROP_TYPES) at `at`.
func add(at: Vector2, type: Dictionary) -> void:
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

	var color: Color = type.color
	_pos[slot] = at
	_amount[slot] = type.expAmount
	_color[slot] = color
	var key := Vector2i((at / CELL).floor())
	if _cells.has(key):
		_cells[key].append(slot)
	else:
		_cells[key] = [slot]
	RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(DROP_ROTATION, at))
	RenderingServer.multimesh_instance_set_color(_rid, slot, color)


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
			p += p.direction_to(target) * step
			_pos[slot] = p
			RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, Transform2D(DROP_ROTATION, p))
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
					cell.remove_at(k)
			if cell.is_empty():
				_cells.erase(key)


func _release(slot: int) -> void:
	RenderingServer.multimesh_instance_set_transform_2d(_rid, slot, HIDDEN)
	_free.append(slot)


## Makes room for GROW_BY more drops, keeping the ones already drawn.
func _grow() -> void:
	var oldCapacity: int = _capacity
	_capacity += GROW_BY
	_pos.resize(_capacity)
	_amount.resize(_capacity)
	_color.resize(_capacity)

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
