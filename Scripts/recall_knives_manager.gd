class_name RecallKnivesManager
extends Node2D

## Daggers fan out this far apart (10 degrees)...
const FAN_SPACING: float = 0.174533
## ...unless the fan would get wider than this; then the spacing shrinks so
## every dagger still fits, evenly spread, without two sharing a direction.
## 120 degrees keeps the volley aimed at enemies: up to 13 daggers keep the
## full 10 degrees, then it tightens (20 daggers: about 6.3 degrees).
## TAU would mean at most an evenly spaced full ring around Echo.
const FAN_MAX_SPREAD: float = 2.094395

## Every dagger's trail and glow is drawn here, not by nodes on each dagger:
## this node draws beneath its daggers, so all trails go out as one triangle
## batch and all glows as a second, with one additive material. As 40 separate
## Line2D and glow sprites, switching blend mode per dagger, they cost 2-3 ms a
## frame on a desktop. Same look: a tapering ribbon fading tail to head, and a
## soft oval glow following each blade (even tilted in the ground).
const TRAIL_WIDTH: float = 9.0
const TRAIL_TAIL_COLOR := Color(0.85, 0.12, 0.18, 0.0)
const TRAIL_HEAD_COLOR := Color(1.0, 0.35, 0.3, 0.6)
const GLOW_COLOR := Color(0.7, 0.9, 1.0, 0.4)
const GLOW_SCALE := Vector2(1.5, 0.45)   # along the blade, across it
static var _glow_texture: GradientTexture2D = null
var _trail_points := PackedVector2Array()
var _trail_colors := PackedColorArray()
var _trail_indices := PackedInt32Array()
var _drew_last_frame: bool = false

@onready var recallKnifeBP: PackedScene = preload("res://Scenes/Allies&Summons/recall_knife.tscn")
@onready var player: Player = global.PLAYER
var towards: Vector2 = Vector2.RIGHT
var readyAmount: int = 0
var expectedReadyAmount = -1
var s: int = 1
var offset: Vector2 = Vector2.UP * 64.0
var hasNotThrown: bool = true
var stats: Dictionary = {}
var stackAmount: int = 0


func setup(givenStats: Dictionary) -> void:
	stats = givenStats


func throw() -> void:
	stackAmount = 0
	var children: Array[Node] = get_children()
	var size: int = children.size()
	for i in range(stats.amount - size):
		var recallKnife: RecallKnife = recallKnifeBP.instantiate()
		add_child(recallKnife)
		children.append(recallKnife)
		expectedReadyAmount += 1
		readyAmount += 1
	
	var enemy: Node2D = player.get_nearest_attackable_or_null()
	if enemy:
		towards = (player.global_position + offset).direction_to(enemy.global_position)
	
	# Fan around the aim: 0, -1, +1, -2, +2 ... steps of fan_spacing().
	var spacing: float = fan_spacing(children.size())
	for i in range(children.size()):
		var step: int = (i + 1) / 2
		var side: int = -1 if i % 2 == 1 else 1
		children[i].throw(towards.rotated(step * side * spacing * s))
	s *= -1   # the odd dagger out lands on alternating sides, throw to throw
	
	readyAmount = 0
	hasNotThrown = true


## The angle between neighbouring daggers for `count` daggers: FAN_SPACING
## while the fan fits in FAN_MAX_SPREAD, smaller once it would not.
static func fan_spacing(count: int) -> float:
	if count <= 1:
		return FAN_SPACING
	# n daggers in a full ring need n gaps (the first and last are neighbours too).
	var gaps: int = count if FAN_MAX_SPREAD >= TAU else count - 1
	return minf(FAN_SPACING, FAN_MAX_SPREAD / gaps)


func _ready() -> void:
	expectedReadyAmount = get_child_count()
	readyAmount = expectedReadyAmount
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive   # this node's own drawing only; the daggers keep theirs
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.width = 64
		_glow_texture.height = 64
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)


func _process(_delta: float) -> void:
	if hasNotThrown and readyAmount == expectedReadyAmount:
		get_tree().create_timer(stats.cd).timeout.connect(throw)
		hasNotThrown = false
	# Redraw while any dagger is out, and once more after to clear the last frame.
	var any_out: bool = readyAmount < expectedReadyAmount
	if any_out or _drew_last_frame:
		queue_redraw()
	_drew_last_frame = any_out


func _draw() -> void:
	_trail_points.clear()
	_trail_colors.clear()
	_trail_indices.clear()
	var to_local: Transform2D = get_global_transform().affine_inverse()
	for dagger: RecallKnife in get_children():
		if dagger.visible:
			_add_trail(dagger.trail_points, to_local)
	if not _trail_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _trail_indices, _trail_points, _trail_colors)

	var half: Vector2 = _glow_texture.get_size() * -0.5
	for dagger: RecallKnife in get_children():
		if dagger.visible:
			draw_set_transform_matrix(to_local * dagger.spriteWrapper.global_transform.scaled_local(GLOW_SCALE))
			draw_texture(_glow_texture, half, GLOW_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Appends one dagger's trail as a triangle strip: zero width and fully faded
## at the oldest point, TRAIL_WIDTH and TRAIL_HEAD_COLOR at the newest.
func _add_trail(points: PackedVector2Array, to_local: Transform2D) -> void:
	var n: int = points.size()
	if n < 2:
		return
	var base: int = _trail_points.size()
	for j in range(n):
		var t: float = float(j) / float(n - 1)
		var tangent: Vector2 = points[mini(j + 1, n - 1)] - points[maxi(j - 1, 0)]
		var side: Vector2 = tangent.normalized().orthogonal() * (TRAIL_WIDTH * 0.5 * t)
		var p: Vector2 = to_local * points[j]
		var color: Color = TRAIL_TAIL_COLOR.lerp(TRAIL_HEAD_COLOR, t)
		_trail_points.append(p + side)
		_trail_points.append(p - side)
		_trail_colors.append(color)
		_trail_colors.append(color)
	for j in range(n - 1):
		var b: int = base + j * 2
		_trail_indices.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
