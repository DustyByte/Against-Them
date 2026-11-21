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
##
## Boulders (grass.gd) are fixed convex obstacles. Each enemy looks ahead for
## them every LOOK_EVERY frames (in turn): if a boulder stands on the next
## LOOK_AHEAD px of its way to Echo, it heads for the boulder's corner on the
## shorter way round, turning gradually as it nears, and walks straight at
## Echo again once past it. It keeps the side it picked unless the other gets
## clearly shorter, so it doesn't dither. (This sets the enemy's avoidCorner
## and avoidWeight; the enemy turns by them as it walks.)
## As a backstop (shoves from the crowd, knockback), an enemy inside one is put
## back out through its nearest edge. An enemy walking into a boulder (more
## than HEAD_ON of its speed against the edge) goes round it by the nearer end:
## its sideways motion along the edge is turned that way, kept at its own
## sideways speed or SLIDE_SHARE of its walk, whichever is more, so it is never
## faster than it walks. (Left alone, enemies walk along the edge towards the
## point nearest Echo, all meet in the middle and stall there.) Enemies that
## only graze a boulder keep their own way.
## Each obstacle is filed in every OBSTACLE_CELL it could touch, so an enemy
## costs one lookup; it is stored as edge planes, so testing a point exits on
## the first edge it is outside of.

const CELL: float = 100.0      # at least the widest enemy (enemy 1: 90 px)
const PUSH: float = 0.5        # share of an overlap removed per frame
const MAX_SHIFT: float = 8.0   # px per frame, so a sudden pile-up eases apart
# Neighbouring cells checked from each cell, so every pair of cells is compared once.
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

var _members: Array = []

const OBSTACLE_CELL: float = 256.0
const MAX_ENEMY_RADIUS: float = 50.0   # obstacles are filed this much wider
## An enemy's room around a boulder: its crowdRadius times these. Less on y, as
## the ground is seen at an angle.
const OBSTACLE_REACH: Vector2 = Vector2(0.6, 0.3)
## An enemy counts as walking into a boulder when more than this share of its
## speed goes against the edge (about 60 degrees or closer to head-on).
const HEAD_ON: float = 0.5
## Least sideways speed (share of its walk) it keeps while going round.
const SLIDE_SHARE: float = 0.6
## How far ahead (px) an enemy looks for boulders on its way to Echo.
const LOOK_AHEAD: float = 500.0
## Room (px) it leaves between itself and a boulder while going round.
const AVOID_MARGIN: float = 100.0
## The last stretch (px) before Echo is not looked at, so an enemy closing on
## Echo beside a boulder goes for Echo instead of round the boulder.
const AVOID_SKIP_END: float = 70.0
## How much shorter (px) the other way round must get before an enemy switches.
const SIDE_STICK: float = 80.0
## The way round is only judged from at least this far (px) from the boulder.
const SIDE_JUDGE_FROM: float = 60.0
## A corner this close (px) counts as reached: it heads for the next one.
## More than it walks between two looks.
const CORNER_REACHED: float = 40.0
## Each enemy looks ahead once every this many frames (in turn), which is
## plenty for walking round a rock.
const LOOK_EVERY: int = 3
## Looking ahead uses the outline with edges merged away while that bulges it
## out by no more than this (px), down to AVOID_MIN_EDGES edges.
const AVOID_MAX_BULGE: float = 10.0
const AVOID_MIN_EDGES: int = 6
var _obstacles: Dictionary = {}        # id -> [cells, entry]
# Vector2i -> Array of entries: [bounds (grown by MAX_ENEMY_RADIUS), outward
# edge normals, edge offsets (normal . point on edge), reach factor per edge,
# centre, then the same for looking ahead on a coarser shape: normals,
# offsets (with AVOID_MARGIN), reach factors, corners (at radius 0, and per px
# of radius)]
var _obstacleCells: Dictionary = {}
# The same entries, filed wider (by LOOK_AHEAD) for looking ahead.
var _aheadCells: Dictionary = {}
var _nextObstacleId: int = 0


## Adds a fixed convex obstacle (its outline, either winding); returns its id.
func add_obstacle(outline: PackedVector2Array) -> int:
	var id: int = _nextObstacleId
	_nextObstacleId += 1
	var n: int = outline.size()
	var centre := Vector2.ZERO
	for v in outline:
		centre += v
	centre /= n
	var normals := PackedVector2Array()
	var offsets := PackedFloat32Array()
	var reachK := PackedFloat32Array()
	normals.resize(n)
	offsets.resize(n)
	reachK.resize(n)
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for k in n:
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % n]
		bounds = bounds.expand(a)
		var normal: Vector2 = (b - a).orthogonal().normalized()
		if normal.dot((a + b) * 0.5 - centre) < 0.0:
			normal = -normal   # point it outwards
		normals[k] = normal
		offsets[k] = normal.dot(a)
		# How far an enemy's (flattened) body reaches across this edge, per radius.
		reachK[k] = Vector2(normal.x * OBSTACLE_REACH.x, normal.y * OBSTACLE_REACH.y).length()
	# For looking ahead, a coarser shape: nearly straight-on edges are merged
	# away (their neighbours extended to meet), so it has fewer edges and
	# corners to check yet still holds the whole outline; the margin covers
	# the little it bulges.
	var kept: Array[int] = []
	for k in n:
		kept.append(k)
	while kept.size() > AVOID_MIN_EDGES:
		var best: int = -1
		var bestBulge: float = AVOID_MAX_BULGE
		for i in kept.size():
			var e0: int = kept[(i + kept.size() - 1) % kept.size()]
			var e2: int = kept[(i + 1) % kept.size()]
			var x = _meet(normals[e0], offsets[e0], normals[e2], offsets[e2])
			if x == null:
				continue
			var bulge: float = normals[kept[i]].dot(x) - offsets[kept[i]]
			if bulge < bestBulge:
				best = i
				bestBulge = bulge
		if best < 0:
			break
		kept.remove_at(best)
	var m: int = kept.size()
	var aNormals := PackedVector2Array()
	var aOffsets := PackedFloat32Array()   # with AVOID_MARGIN added
	var aReachK := PackedFloat32Array()
	for k in kept:
		aNormals.append(normals[k])
		aOffsets.append(offsets[k] + AVOID_MARGIN)
		aReachK.append(reachK[k])
	# Its corners, pushed out by AVOID_MARGIN + radius * reachK. That is linear
	# in the radius, so each is kept as corner0 + radius * cornerK.
	var corner0 := PackedVector2Array()
	var cornerK := PackedVector2Array()
	for i in m:
		var before: int = (i + m - 1) % m   # the edge ending at this corner
		var x0 = _meet(aNormals[before], aOffsets[before], aNormals[i], aOffsets[i])
		var x1 = _meet(aNormals[before], aOffsets[before] + aReachK[before], aNormals[i], aOffsets[i] + aReachK[i])
		if x0 == null or x1 == null:   # nearly straight on: its outline point, pushed out
			var mid: Vector2 = (aNormals[before] + aNormals[i]).normalized()
			corner0.append(outline[kept[i]] + mid * AVOID_MARGIN)
			cornerK.append(mid * (aReachK[before] + aReachK[i]) * 0.5)
		else:
			corner0.append(x0)
			cornerK.append(x1 - x0)
	bounds = bounds.grow(MAX_ENEMY_RADIUS)
	var entry: Array = [bounds, normals, offsets, reachK, centre,
			aNormals, aOffsets, aReachK, corner0, cornerK]
	var cells: Array[Vector2i] = _file(_obstacleCells, bounds, entry)
	var aheadCells: Array[Vector2i] = _file(_aheadCells, bounds.grow(LOOK_AHEAD + AVOID_MARGIN), entry)
	_obstacles[id] = [cells, entry, aheadCells]
	return id


## Files `entry` in every cell of `grid` that `bounds` touches; returns them.
func _file(grid: Dictionary, bounds: Rect2, entry: Array) -> Array[Vector2i]:
	var from := Vector2i((bounds.position / OBSTACLE_CELL).floor())
	var to := Vector2i((bounds.end / OBSTACLE_CELL).floor())
	var cells: Array[Vector2i] = []
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var key := Vector2i(x, y)
			var list = grid.get(key)
			if list == null:
				grid[key] = [entry]
			else:
				list.append(entry)
			cells.append(key)
	return cells


## Where the lines n1 . x = c1 and n2 . x = c2 meet, or null if they are
## nearly parallel.
func _meet(n1: Vector2, c1: float, n2: Vector2, c2: float):
	var det: float = n1.x * n2.y - n1.y * n2.x
	if absf(det) < 0.05:
		return null
	return Vector2(c1 * n2.y - c2 * n1.y, n1.x * c2 - n2.x * c1) / det


func remove_obstacle(id: int) -> void:
	var o = _obstacles.get(id)
	if o == null:
		return
	_obstacles.erase(id)
	_unfile(_obstacleCells, o[0], o[1])
	_unfile(_aheadCells, o[2], o[1])


func _unfile(grid: Dictionary, cells: Array, entry: Array) -> void:
	for key: Vector2i in cells:
		var list: Array = grid[key]
		list.erase(entry)
		if list.is_empty():
			grid.erase(key)


## Looks along the next LOOK_AHEAD px of enemy `e`'s way (from `p`) to `to`
## (Echo). With a boulder there, sets e.avoidCorner to the corner to head for
## on the shorter way round and e.avoidWeight to how much to turn that way
## (0 at LOOK_AHEAD away, 1 at contact); otherwise sets avoidWeight to 0.
## e.avoidSide keeps the way round it picked (0 for none).
func _look_ahead(e, p: Vector2, radius: float, to: Vector2, list: Array) -> void:
	var toward: Vector2 = to - p
	var dist: float = toward.length()
	var reach: float = minf(dist - AVOID_SKIP_END, LOOK_AHEAD)
	if reach <= 0.0:
		_clear_avoid(e)
		return
	var d: Vector2 = toward / dist

	# The first boulder the look-ahead line (p to p + d * reach) runs into,
	# every edge pushed out by the room this enemy needs.
	var hit = null
	var hitAt: float = INF
	var lookFrom: Vector2 = p   # where to look round it from (outside its margin)
	for o in list:
		# Quick miss: the line clipped by the boulder's bounds.
		var b: Rect2 = o[0]
		var t0: float = 0.0
		var t1: float = reach
		if absf(d.x) > 0.000001:
			var ta: float = (b.position.x - p.x) / d.x
			var tb: float = (b.end.x - p.x) / d.x
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
		elif p.x < b.position.x or p.x > b.end.x:
			continue
		if absf(d.y) > 0.000001:
			var ta: float = (b.position.y - p.y) / d.y
			var tb: float = (b.end.y - p.y) / d.y
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
		elif p.y < b.position.y or p.y > b.end.y:
			continue
		if t0 > t1:
			continue
		# The line clipped by each edge's half-plane, keeping the part inside all.
		var normals: PackedVector2Array = o[5]
		var offsets: PackedFloat32Array = o[6]
		var reachK: PackedFloat32Array = o[7]
		var enter: float = -INF
		var leave: float = reach
		var clear := false
		var shallowest: float = -INF   # how far p is out past its nearest edge
		var shallowEdge: int = 0
		for k in normals.size():
			var n: Vector2 = normals[k]
			var outside: float = n.dot(p) - offsets[k] - radius * reachK[k]
			if outside > shallowest:
				shallowest = outside
				shallowEdge = k
			var dn: float = n.dot(d)
			if absf(dn) < 0.000001:
				if outside > 0.0:
					clear = true
					break
				continue
			var t: float = -outside / dn
			if dn < 0.0:
				if t > enter:
					enter = t
			elif t < leave:
				leave = t
			if enter > leave:
				clear = true
				break
		if clear or leave < 0.0:
			continue
		if shallowest <= 0.0 and normals[shallowEdge].dot(d) >= 0.0:
			continue   # in its margin but already heading away from it
		if enter < hitAt:
			hitAt = enter
			hit = o
			# Inside its margin already: look round it from just outside.
			lookFrom = p if shallowest > 0.0 else p + normals[shallowEdge] * (0.5 - shallowest)

	if hit == null:
		_clear_avoid(e)
		return

	# The corners seen furthest to either side from lookFrom (outside it, so
	# the boulder spans under 180 degrees and "further to one side" is a fair
	# order). Corners it has about reached are left out, so it goes on to the
	# next one instead of circling on the spot.
	var corner0: PackedVector2Array = hit[8]
	var cornerK: PackedVector2Array = hit[9]
	var plus := Vector2.INF
	var minus := Vector2.INF
	for k in corner0.size():
		var q: Vector2 = corner0[k] + cornerK[k] * radius
		var rel: Vector2 = q - lookFrom
		if rel.length_squared() < CORNER_REACHED * CORNER_REACHED:
			continue
		if plus == Vector2.INF:
			plus = q
			minus = q
			continue
		if (plus - lookFrom).cross(rel) > 0.0:
			plus = q
		if (minus - lookFrom).cross(rel) < 0.0:
			minus = q
	if plus == Vector2.INF:
		_clear_avoid(e)
		return

	# Which way round: the shorter, judged only from a fair way out (close up,
	# and from inside the margin, the corners seen are just the near ones), and
	# switched only if the other gets clearly shorter.
	var side: int = e.avoidSide
	if side == 0 or (lookFrom == p and hitAt > SIDE_JUDGE_FROM):
		var plusWay: float = p.distance_to(plus) + plus.distance_to(to)
		var minusWay: float = p.distance_to(minus) + minus.distance_to(to)
		if side == 0:
			side = 1 if plusWay <= minusWay else -1
		elif side > 0 and minusWay < plusWay - SIDE_STICK:
			side = -1
		elif side < 0 and plusWay < minusWay - SIDE_STICK:
			side = 1
		if side != e.avoidSide:
			e.avoidSide = side
	e.avoidCorner = plus if side > 0 else minus
	var w: float = clampf(1.0 - hitAt / LOOK_AHEAD, 0.0, 1.0)
	e.avoidWeight = w * w * (3.0 - 2.0 * w)


func _clear_avoid(e) -> void:
	if e.avoidWeight != 0.0:
		e.avoidWeight = 0.0
		e.avoidSide = 0


## Puts enemy `e` (at `p`) back out of any obstacle it is inside, through the
## nearest edge, and if it was walking into it, turns its sideways motion
## towards the nearer end (see the top of this file).
func _out_of_obstacles(e, p: Vector2, radius: float, list: Array, delta: float) -> Vector2:
	for o in list:
		if not o[0].has_point(p):
			continue
		var normals: PackedVector2Array = o[1]
		var offsets: PackedFloat32Array = o[2]
		var reachK: PackedFloat32Array = o[3]
		var deepest: float = -INF   # the edge it is least far inside of
		var edge: int = -1
		var inside := true
		for k in normals.size():
			var d: float = normals[k].dot(p) - offsets[k] - radius * reachK[k]
			if d >= 0.0:
				inside = false
				break
			if d > deepest:
				deepest = d
				edge = k
		if not inside:
			continue
		var n: Vector2 = normals[edge]
		p -= n * deepest
		var v: Vector2 = e.velocity
		var speed: float = v.length()
		if speed > 0.0 and -v.dot(n) > speed * HEAD_ON:
			var t := Vector2(-n.y, n.x)
			var along: float = v.dot(t)   # how it is already moving along the edge
			var way: float = t.dot(p - o[4])
			if absf(way) < 1.0:   # dead in the middle: pick a side per enemy
				way = 1.0 if e.get_instance_id() & 1 else -1.0
			var target: float = signf(way) * maxf(absf(along), speed * SLIDE_SHARE)
			p += t * (target - along) * delta
	return p


func add(enemy: Node2D) -> void:
	_members.append(enemy)


func _ready() -> void:
	process_physics_priority = 100   # after the enemies have moved this frame


func _physics_process(delta: float) -> void:
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
	if count == 0:
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

	var hasObstacles: bool = not _obstacleCells.is_empty()
	var lookTurn: int = -1   # whose turn it is to look ahead (k % LOOK_EVERY)
	var echo: Vector2 = Vector2.ZERO
	if not _aheadCells.is_empty() and is_instance_valid(global.PLAYER):
		lookTurn = Engine.get_physics_frames() % LOOK_EVERY
		echo = global.PLAYER.position
	for k in range(count):
		var s: Vector2 = shift[k]
		var p: Vector2 = pos[k]
		var moved: Vector2 = p
		if s != Vector2.ZERO:
			moved += s.limit_length(MAX_SHIFT)
		if hasObstacles:
			var list = _obstacleCells.get(Vector2i(floori(moved.x / OBSTACLE_CELL), floori(moved.y / OBSTACLE_CELL)))
			if list != null:
				moved = _out_of_obstacles(_members[k], moved, rad[k], list, delta)
		if k % LOOK_EVERY == lookTurn:
			var ahead = _aheadCells.get(Vector2i(floori(moved.x / OBSTACLE_CELL), floori(moved.y / OBSTACLE_CELL)))
			if ahead != null:
				_look_ahead(_members[k], moved, rad[k], echo, ahead)
			else:
				_clear_avoid(_members[k])
		if moved != p:
			_members[k].position = moved
