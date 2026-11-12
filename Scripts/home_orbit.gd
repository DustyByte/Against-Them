extends Node2D

## Draws half of the tilted orbit around the Home screen planet, plus Echoe's
## ship when it is on this half. Two instances are used: one behind the planet
## (front = false, the far half) and one in front of it (front = true).

@export var front: bool = true

const SEGMENTS: int = 96
const TRAIL_STEPS: int = 14
const TRAIL_LENGTH: float = 0.55 # radians of orbit the tail covers

var center: Vector2 = Vector2.ZERO
var radii: Vector2 = Vector2(400.0, 100.0)
var tilt: float = -0.18
var ship_angle: float = 0.0
var line_color: Color = Color(0.62, 0.88, 0.95, 0.32)
var ship_color: Color = Color(0.85, 0.97, 1.0, 1.0)


func point_at(angle: float) -> Vector2:
	return center + Vector2(radii.x * cos(angle), radii.y * sin(angle)).rotated(tilt)


## The near half of the orbit is where sin(angle) > 0 (lower half before tilt).
func _is_on_this_half(angle: float) -> bool:
	return (sin(angle) > 0.0) == front


func _draw() -> void:
	# Orbit line: the near half is brighter than the far half.
	var alpha_scale: float = 1.0 if front else 0.45
	var points := PackedVector2Array()
	var start: float = 0.0 if front else PI
	for i in range(SEGMENTS + 1):
		points.append(point_at(start + PI * float(i) / SEGMENTS))
	draw_polyline(points, Color(line_color, line_color.a * alpha_scale), 1.5, true)

	# Ship tail, then the ship itself.
	for i in range(TRAIL_STEPS, 0, -1):
		var a: float = ship_angle - TRAIL_LENGTH * float(i) / TRAIL_STEPS
		if not _is_on_this_half(a):
			continue
		var fade: float = 1.0 - float(i) / TRAIL_STEPS
		draw_circle(point_at(a), 1.2 + 1.3 * fade, Color(ship_color, 0.35 * fade * alpha_scale))

	if _is_on_this_half(ship_angle):
		var p: Vector2 = point_at(ship_angle)
		draw_circle(p, 7.0, Color(ship_color, 0.12 * alpha_scale))
		draw_circle(p, 3.0, Color(ship_color, alpha_scale))
