extends Control

## The 7-day track on the daily reward card: a row of hexagons, one per day,
## each with its Echoes. Days already claimed are filled and ticked, today's
## glows (pulsing while it waits), later days are outlines. Day 7, the big
## one, is larger and lit in the nebula's pink-violet. Days that also give
## Anchor Shards wear a small shard badge (with a count past one). Drawn in
## one _draw.

const ACCENT := Color(0.62, 0.88, 0.95)
const BIG_ACCENT := Color(0.88, 0.48, 0.92)
const TEXT := Color(0.94, 0.97, 1.0)
const HEX_RADIUS: float = 34.0
const BIG_SCALE: float = 1.22
const SHARD_ICON: Texture2D = preload("res://Assets/HUD Elements/anchor_shard_icon.svg")
const SHARD_COLOR := Color(0.8, 0.62, 1.0)
const BADGE_SIZE: float = 26.0

## Track day (0-6) shown as today's, and whether it is still waiting.
var today: int = 0
var waiting: bool = true
## 0-1 pop on today's hexagon when it is claimed.
var pop: float = 0.0
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if waiting:
		queue_redraw()   # only the waiting glow moves


func _draw() -> void:
	var font: Font = get_theme_font(&"font", &"Label")
	var days: int = MetaProgression.DAILY_REWARDS.size()
	var step: float = size.x / days
	var cy: float = HEX_RADIUS * BIG_SCALE + 4.0
	for i in days:
		var big: bool = i == days - 1
		var accent: Color = BIG_ACCENT if big else ACCENT
		var r: float = HEX_RADIUS * (BIG_SCALE if big else 1.0)
		var c := Vector2(step * (i + 0.5), cy)
		var claimed: bool = i < today or (i == today and not waiting)
		var is_today: bool = i == today
		if is_today and pop > 0.0:
			r *= 1.0 + 0.18 * sin(PI * pop)

		var hexagon := PackedVector2Array()
		for k in 7:
			hexagon.append(c + Vector2.from_angle(TAU * k / 6.0 + PI / 6.0) * r)
		var fill_alpha: float = 0.05
		var line_alpha: float = 0.3
		if claimed:
			fill_alpha = 0.22
			line_alpha = 0.55
		if is_today and waiting:
			var breathe: float = 0.5 + 0.5 * sin(TAU * _time / 1.6)
			draw_circle(c, r * 1.35, Color(accent, 0.06 + 0.08 * breathe))
			fill_alpha = 0.14 + 0.1 * breathe
			line_alpha = 0.75 + 0.25 * breathe
		elif big:
			line_alpha = maxf(line_alpha, 0.5)
		hexagon.remove_at(6)
		draw_colored_polygon(hexagon, Color(accent, fill_alpha))
		hexagon.append(hexagon[0])
		draw_polyline(hexagon, Color(accent, line_alpha), 2.0 if is_today else 1.4, true)

		# Its Echoes, or a tick once claimed.
		var amount: String = str(MetaProgression.DAILY_REWARDS[i])
		var font_size: int = 20 if big else 18
		var w: float = font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if not claimed:
			draw_string(font, c + Vector2(-w * 0.5, font_size * 0.36), amount, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT)
		else:
			var tick := PackedVector2Array([c + Vector2(-9, 1) * (r / HEX_RADIUS), c + Vector2(-2, 8) * (r / HEX_RADIUS), c + Vector2(11, -8) * (r / HEX_RADIUS)])
			draw_polyline(tick, Color(accent, 0.95), 3.0, true)

		# Shard badge on the upper right.
		var shards: int = MetaProgression.DAILY_SHARDS[i]
		if shards > 0:
			var badge_alpha: float = 0.4 if claimed else 1.0
			var at: Vector2 = c + Vector2(r * 0.72, -r * 0.62)
			draw_circle(at, BADGE_SIZE * 0.5, Color(0.05, 0.04, 0.09, 0.92 * badge_alpha))
			draw_arc(at, BADGE_SIZE * 0.5, 0.0, TAU, 24, Color(SHARD_COLOR, 0.8 * badge_alpha), 1.2, true)
			draw_texture_rect(SHARD_ICON, Rect2(at - Vector2.ONE * BADGE_SIZE * 0.42, Vector2.ONE * BADGE_SIZE * 0.84), false, Color(1, 1, 1, badge_alpha))
			if shards > 1:
				var count: String = "x%d" % shards
				draw_string(font, at + Vector2(BADGE_SIZE * 0.5 + 2.0, 5.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(SHARD_COLOR, badge_alpha))

		var day: String = tr("DAY %d") % (i + 1)
		var day_alpha: float = 1.0 if is_today else 0.55
		var dw: float = font.get_string_size(day, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(c.x - dw * 0.5, cy + HEX_RADIUS * BIG_SCALE + 24.0), day, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(accent, day_alpha))
