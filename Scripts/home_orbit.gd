extends Node2D

## Draws half of the tilted orbit around the Home screen planet, plus Echo's
## ship when it is on this half. Two instances are used: one behind the planet
## (front = false, the far half) and one in front of it (front = true).
## The ship also carries the daily transmission from Earth: while one is
## waiting it glows and sends out beacon rings, and it flashes when the reward
## card flies back into it.

@export var front: bool = true

const SEGMENTS: int = 96
const TRAIL_STEPS: int = 14
const TRAIL_LENGTH: float = 0.55 # radians of orbit the tail covers
const BEACON_PERIOD: float = 1.8

var center: Vector2 = Vector2.ZERO
var radii: Vector2 = Vector2(400.0, 100.0)
var tilt: float = -0.18
var ship_angle: float = 0.0
var line_color: Color = Color(0.62, 0.88, 0.95, 0.32)
var ship_color: Color = Color(0.85, 0.97, 1.0, 1.0)
## Daily reward: waiting or not, a clock for the glow, and a 0-1 flash when
## the card flies back in.
var ship_ready: bool = false
var ship_time: float = 0.0
var ship_pop: float = 0.0


func point_at(angle: float) -> Vector2:
	return center + Vector2(radii.x * cos(angle), radii.y * sin(angle)).rotated(tilt)


## The near half of the orbit is where sin(angle) > 0 (lower half before tilt).
static func is_near_side(angle: float) -> bool:
	return sin(angle) > 0.0


func _is_on_this_half(angle: float) -> bool:
	return is_near_side(angle) == front


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
		var swell: float = 1.0 + 0.6 * sin(PI * ship_pop)
		if ship_ready:
			# A breathing glow and a ring going out now and then: something is waiting.
			var breathe: float = 0.5 + 0.5 * sin(TAU * ship_time / 2.4)
			draw_circle(p, 16.0, Color(ship_color, (0.10 + 0.12 * breathe) * alpha_scale))
			var ring: float = fmod(ship_time, BEACON_PERIOD) / BEACON_PERIOD
			draw_arc(p, 6.0 + 26.0 * ring, 0.0, TAU, 32, Color(ship_color, 0.7 * (1.0 - ring) * alpha_scale), 1.8, true)
		if ship_pop > 0.0:
			draw_circle(p, 22.0 * swell, Color(ship_color, 0.3 * sin(PI * ship_pop) * alpha_scale))
		draw_circle(p, 7.0 * swell, Color(ship_color, (0.2 if ship_ready else 0.12) * alpha_scale))
		draw_circle(p, (3.6 if ship_ready else 3.0) * swell, Color(ship_color, alpha_scale))
