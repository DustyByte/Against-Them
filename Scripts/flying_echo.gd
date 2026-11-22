extends Node2D

## One claimed-Echoes icon on its way to the Home screen's counter (home.gd
## moves it). Drawn with a short fading trail of where it just was, so it
## reads as one smooth streak even when a phone drops frames.

const TRAIL_LENGTH: int = 5
const TRAIL_ALPHA: float = 0.4

var texture: Texture2D
var icon_size: float = 60.0
## Where it is and how big (1 = icon_size).
var centre: Vector2 = Vector2.ZERO
var icon_scale: float = 0.0
## Only leaves a trail while flying (not while popping into being).
var trailing: bool = false
var _trail: PackedVector2Array = []
var _trail_scale: PackedFloat32Array = []


func move_to(at: Vector2, size_scale: float) -> void:
	if trailing:
		_trail.append(centre)
		_trail_scale.append(icon_scale)
		if _trail.size() > TRAIL_LENGTH:
			_trail.remove_at(0)
			_trail_scale.remove_at(0)
	centre = at
	icon_scale = size_scale
	queue_redraw()


func _draw() -> void:
	var n: int = _trail.size()
	for i in n:   # oldest (faintest) first
		var s: float = _trail_scale[i] * icon_size
		var alpha: float = TRAIL_ALPHA * float(i + 1) / float(n + 1)
		draw_texture_rect(texture, Rect2(_trail[i] - Vector2.ONE * s * 0.5, Vector2.ONE * s), false, Color(1, 1, 1, alpha))
	var size: float = icon_scale * icon_size
	draw_texture_rect(texture, Rect2(centre - Vector2.ONE * size * 0.5, Vector2.ONE * size), false)
