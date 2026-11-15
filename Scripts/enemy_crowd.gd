class_name EnemyCrowd
extends Node

## Keeps enemies from piling onto each other. They no longer collide with each
## other through the physics engine: with 200 enemies pressing around the
## player, that cost 6 to 9 ms a frame on a desktop, against about 1 ms for
## this. Every physics frame, each pair of enemies that overlaps is pushed apart
## by part of the overlap. Enemies are sorted into a grid first, so each is only
## compared with those in its own and neighbouring cells.
##
## Enemies add themselves when ready and set their crowdRadius to 0 when they
## stop taking up room (dying, shrinking into a black hole); they are dropped
## from the list then, or once freed. Created by world.gd.

const CELL: float = 100.0      # at least the widest enemy (enemy 1: 90 px)
const PUSH: float = 0.5        # share of an overlap removed per frame
const MAX_SHIFT: float = 8.0   # px per frame, so a sudden pile-up eases apart
# Neighbouring cells checked from each cell, so every pair of cells is compared once.
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

var _members: Array = []


func add(enemy: Node2D) -> void:
	_members.append(enemy)


func _ready() -> void:
	process_physics_priority = 100   # after the enemies have moved this frame


func _physics_process(_delta: float) -> void:
	# Drop enemies that are gone or no longer take up room.
	var i: int = 0
	while i < _members.size():
		var e = _members[i]
		if not is_instance_valid(e) or e.crowdRadius <= 0.0:
			_members[i] = _members[_members.size() - 1]
			_members.pop_back()
		else:
			i += 1

	var count: int = _members.size()
	if count < 2:
		return

	var pos := PackedVector2Array()
	var rad := PackedFloat32Array()
	var shift := PackedVector2Array()
	pos.resize(count)
	rad.resize(count)
	shift.resize(count)
	var grid: Dictionary = {}
	for k in range(count):
		var e: Node2D = _members[k]
		var p: Vector2 = e.position
		pos[k] = p
		rad[k] = e.crowdRadius
		var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
		var cell = grid.get(key)
		if cell == null:
			grid[key] = [k]
		else:
			cell.append(k)

	for key: Vector2i in grid:
		var cell: Array = grid[key]
		var size: int = cell.size()
		# Pairs inside this cell...
		for a in range(size - 1):
			var ia: int = cell[a]
			for b in range(a + 1, size):
				var ib: int = cell[b]
				var d: Vector2 = pos[ib] - pos[ia]
				var r: float = rad[ia] + rad[ib]
				var distSq: float = d.length_squared()
				if distSq < r * r:
					if distSq < 0.0001:
						d = Vector2.from_angle(randf() * TAU) * 0.01
						distSq = 0.0001
					var dist: float = sqrt(distSq)
					var s: Vector2 = d * ((r - dist) / dist * 0.5 * PUSH)
					shift[ia] -= s
					shift[ib] += s
		# ...then with the neighbouring cells.
		for offset in NEIGHBOURS:
			var other = grid.get(key + offset)
			if other == null:
				continue
			for ia: int in cell:
				var pa: Vector2 = pos[ia]
				var ra: float = rad[ia]
				for ib: int in other:
					var d: Vector2 = pos[ib] - pa
					var r: float = ra + rad[ib]
					var distSq: float = d.length_squared()
					if distSq < r * r:
						if distSq < 0.0001:
							d = Vector2.from_angle(randf() * TAU) * 0.01
							distSq = 0.0001
						var dist: float = sqrt(distSq)
						var s: Vector2 = d * ((r - dist) / dist * 0.5 * PUSH)
						shift[ia] -= s
						shift[ib] += s

	for k in range(count):
		var s: Vector2 = shift[k]
		if s != Vector2.ZERO:
			_members[k].position += s.limit_length(MAX_SHIFT)
