class_name Boulder
extends StaticBody2D

## One boulder of the world, placed and recycled by grass.gd as world blocks
## are made and freed (it keeps a pool, so walking around allocates nothing).
## There are a few kinds (different rocks); a pooled node takes whichever kind
## it is placed as.
##
## - Solid on physics layer 1: Echo walks around it, and bullets that hit world
##   objects (Rupture, Torcher, icicles) stop on it, sparking in its avgColor.
## - Enemies are steered around its footprint by EnemyCrowd (they don't use
##   physics), registered by grass.gd.
## - Its origin sits between the footprint's front and back edges, so the
##   y-sorted world draws Echo and enemies behind it or in front of it by where
##   they stand, and nobody can stand where that would look wrong.
## - Drawn as one sprite (baked from its SVG in Assets/Source, soft shadow
##   included, by Tools/bake_boulder.gd) plus a few real grass blades at its
##   base, swaying with the field's wind shader and drawn in front of it.
##
## The body itself is never scaled (physics bodies dislike it): size and
## mirroring go on the sprite and blades, and the collision shape is rebuilt.
##
## Per kind, everything below is from its footprint centre, unflipped, at
## size 1, in art units (the texture is baked at 0.8 of the art).

const TEXTURE_SCALE: float = 1.25              # the texture is baked at 0.8 of the art
const TEXTURES: Array[Texture2D] = [
	preload("res://Assets/World Objects/Boulder01.png"),
	preload("res://Assets/World Objects/Boulder02.png"),
	preload("res://Assets/World Objects/Boulder04.png"),
]
## Where the footprint centre is on each texture, in texture px (printed by
## the bake as foot px).
const SPRITE_OFFSETS: Array[Vector2] = [Vector2(-200, -179.4), Vector2(-181, -203), Vector2(-169, -186.6)]
## Where it stands on the ground: one outline around the rock and the small
## stones at its foot together, from the front of the base well back under its
## bulk, so a crowd stands clear of it instead of hugging a flat picture.
## Only its convex hull is used: dips between the rock and its stones are
## filled in, so there is no pocket for enemies to wedge into, and pushing out
## of a convex shape always has one clear way out. (Kind 0's hull at size 1 is
## also saved on the scene's CollisionPolygon2D so it shows in the editor;
## setup() replaces it with the sized, mirrored one. Update both if it changes.)
const FOOT_OUTLINES: Array = [
	[   # Boulder01: wide dome, pebble on the right
		Vector2(-240, 0), Vector2(-229, 32), Vector2(-170, 52), Vector2(-97, 66),
		Vector2(46, 66), Vector2(98, 56), Vector2(190, 72), Vector2(247, 49),
		Vector2(253, 14), Vector2(222, -43), Vector2(213, -60), Vector2(167, -112),
		Vector2(98, -143), Vector2(47, -152), Vector2(-11, -153), Vector2(-68, -138),
		Vector2(-125, -109), Vector2(-177, -72), Vector2(-200, -49),
	],
	[   # Boulder02: craggy mass and shoulder, two stones on the left
		Vector2(-216, 52), Vector2(-194, 10), Vector2(-140, -50), Vector2(-80, -120),
		Vector2(0, -170), Vector2(70, -160), Vector2(130, -120), Vector2(182, -70),
		Vector2(194, -10), Vector2(180, 40), Vector2(140, 72), Vector2(30, 84),
		Vector2(-110, 84), Vector2(-200, 78),
	],
	[   # Boulder04: craggy mass with the nebula glass, shoulder on the left
		Vector2(-206, 8), Vector2(-192, -28), Vector2(-150, -62), Vector2(-90, -98),
		Vector2(-30, -152), Vector2(40, -162), Vector2(100, -152), Vector2(160, -112),
		Vector2(190, -62), Vector2(200, -12), Vector2(186, 28), Vector2(130, 46),
		Vector2(0, 54), Vector2(-130, 50), Vector2(-190, 36),
	],
]
static var _hulls: Array[PackedVector2Array] = []
## Where its art (stones and shadow included) reaches: the texture, x1.25,
## from the anchor (printed by the bake). grass.gd keeps boulders from
## overlapping and clears grass with it.
const ART_RECTS: Array[Rect2] = [Rect2(-250, -224, 511, 293), Rect2(-227, -254, 428, 347), Rect2(-212, -234, 423, 294)]
## Grass blades along its base: offset and blade size.
const BLADE_SPOTS: Array = [
	[
		Vector3(-214, -4, 1.1), Vector3(-166, 30, 1.35), Vector3(-148, 34, 1.15),
		Vector3(24, 42, 1.2), Vector3(96, 38, 1.3), Vector3(118, 36, 1.0),
	],
	[
		Vector3(-150, 76, 1.05), Vector3(-134, 58, 1.2), Vector3(-72, 68, 1.35),
		Vector3(-54, 70, 1.1), Vector3(32, 72, 1.25), Vector3(100, 64, 1.3),
		Vector3(122, 58, 1.0), Vector3(176, 14, 1.1),
	],
	[
		Vector3(-170, 30, 1.1), Vector3(-110, 38, 1.3), Vector3(-90, 39, 1.1),
		Vector3(6, 43, 1.25), Vector3(80, 40, 1.3), Vector3(102, 36, 1.0),
		Vector3(160, 24, 1.15), Vector3(184, 0, 1.0),
	],
]
const MAX_BLADES: int = 8
## Grass is left out of these ovals (its shadow, its body, its stones'
## shadow), so none pokes through the shadow and the cleared patch follows
## the rock's shape instead of a square. Centre (position) and radii (size).
const CLEAR_OVALS: Array = [
	[Rect2(-2, 12, 248, 56), Rect2(8, -98, 216, 126), Rect2(188, 40, 72, 28)],
	[Rect2(10, 48, 190, 44), Rect2(13, -95, 180, 160), Rect2(-166, 66, 60, 26)],
	[Rect2(0, 22, 210, 40), Rect2(-2, -99, 196, 136)],
]

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _blades: MultiMeshInstance2D = $Blades
@onready var _shape: CollisionPolygon2D = $CollisionPolygon2D
var _blade_buffer := PackedFloat32Array()
## EnemyCrowd obstacle ids while placed (grass.gd), empty when pooled.
var obstacle_ids: Array[int] = []


## Placed at `at` (its footprint centre) as rock `kind`, `size` times as big,
## mirrored or not. The same `seed` gives the same blades, so a boulder looks
## the same when the player comes back. `grass_mesh` and `grass_material` are
## the field's own.
func setup(at: Vector2, kind: int, size: float, flip: bool, seed: int, grass_mesh: Mesh, grass_material: Material) -> void:
	position = at
	var mirror: float = -1.0 if flip else 1.0
	_sprite.texture = TEXTURES[kind]
	_sprite.offset = SPRITE_OFFSETS[kind]
	_sprite.scale = Vector2(mirror * TEXTURE_SCALE * size, TEXTURE_SCALE * size)
	_blades.scale = Vector2(mirror * size, size)

	_shape.polygon = footprint(Vector2.ZERO, kind, size, flip)

	if _blades.multimesh == null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.mesh = grass_mesh
		mm.instance_count = MAX_BLADES
		_blades.multimesh = mm
		_blades.material = grass_material
		_blade_buffer.resize(MAX_BLADES * 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var shown: int = 0
	for spot: Vector3 in BLADE_SPOTS[kind]:
		if rng.randf() < 0.25:
			continue   # leave some out, so no two boulders look the same
		var s: float = spot.z * rng.randf_range(0.9, 1.1)
		var bi: int = shown * 12
		# 2x4 transform (scale only), then custom data: r = which grass texture.
		_blade_buffer[bi] = -s if rng.randf() < 0.5 else s
		_blade_buffer[bi + 3] = spot.x + rng.randf_range(-6.0, 6.0)
		_blade_buffer[bi + 5] = s
		_blade_buffer[bi + 7] = spot.y
		_blade_buffer[bi + 8] = rng.randi_range(0, 4)
		shown += 1
	_blades.multimesh.buffer = _blade_buffer
	_blades.multimesh.visible_instance_count = shown


## True if grass at `point` would sit under boulder `kind` placed at `at`.
## Static, for the worker thread that makes a block's grass.
static func covers(point: Vector2, at: Vector2, kind: int, size: float, flip: bool) -> bool:
	var local: Vector2 = (point - at) / size
	if flip:
		local.x = -local.x
	for oval: Rect2 in CLEAR_OVALS[kind]:
		var d: Vector2 = (local - oval.position) / oval.size
		if d.x * d.x + d.y * d.y < 1.0:
			return true
	return false


## Its footprint (the convex hull of its FOOT_OUTLINES row) placed at `at`,
## for its collision and EnemyCrowd. Main thread.
static func footprint(at: Vector2, kind: int, size: float, flip: bool) -> PackedVector2Array:
	if _hulls.is_empty():
		for outline in FOOT_OUTLINES:
			var hull: PackedVector2Array = Geometry2D.convex_hull(PackedVector2Array(outline))
			hull.resize(hull.size() - 1)   # convex_hull repeats the first point last
			_hulls.append(hull)
	var hull: PackedVector2Array = _hulls[kind]
	var out := PackedVector2Array()
	out.resize(hull.size())
	var mirror: float = -1.0 if flip else 1.0
	for i in hull.size():
		out[i] = at + Vector2(hull[i].x * mirror, hull[i].y) * size
	return out


## Its art rect in the world, for spacing boulders (static: used off the main
## thread while a block is generated, before any node exists).
static func art_rect_at(at: Vector2, kind: int, size: float, flip: bool) -> Rect2:
	var art: Rect2 = ART_RECTS[kind]
	var r: Rect2 = Rect2(art.position * size, art.size * size)
	if flip:
		r.position.x = -r.end.x
	r.position += at
	return r
