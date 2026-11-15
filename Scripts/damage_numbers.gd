class_name DamageNumbers
extends Node2D

## Draws every floating damage and heal number of a run from this one node.
## Each number fades in while rising for FADE_IN_TIME, holds briefly, then
## disappears. This replaces one Label, one tween and one timer per hit, which
## got expensive once auras, burns and fields hit dozens of enemies at a time.
## Created by world.gd; global.add_damage_text() adds to it.

const RISE: float = 50.0
const FADE_IN_TIME: float = 0.3
const LIFETIME: float = 0.4
const FONT_SIZE: int = 16
const CRIT_FONT_SIZE: int = 32
## The oldest numbers are dropped first when more than this are on screen.
const MAX_NUMBERS: int = 300

var _font: Font = ThemeDB.fallback_font
var _now: float = 0.0
# One entry per number, oldest first (all numbers live equally long).
var _born: PackedFloat32Array = []
var _pos: PackedVector2Array = []
var _text: PackedStringArray = []
var _color: PackedColorArray = []
var _crit: PackedByteArray = []


func _ready() -> void:
	z_index = 1
	set_process(false)


func add(globalPos: Vector2, damage: float, damageType: int, isCrit: bool = false) -> void:
	if _born.size() >= MAX_NUMBERS:
		_drop_oldest(1)
	_born.append(_now)
	_pos.append(globalPos)
	_text.append(str(snapped(damage, 0.1)))
	_color.append(global.DAMAGE_TYPE_COLORS[damageType])
	_crit.append(1 if isCrit else 0)
	set_process(true)


func _process(delta: float) -> void:
	_now += delta
	var expired: int = 0
	var count: int = _born.size()
	while expired < count and _now - _born[expired] >= LIFETIME:
		expired += 1
	if expired:
		_drop_oldest(expired)
	queue_redraw()
	if _born.is_empty():
		set_process(false)   # the redraw above clears the last numbers


func _draw() -> void:
	for i in range(_born.size()):
		var t: float = minf((_now - _born[i]) / FADE_IN_TIME, 1.0)
		var color: Color = _color[i]
		color.a = t
		var fontSize: int = CRIT_FONT_SIZE if _crit[i] else FONT_SIZE
		# Labels placed their top-left corner at the position; draw_string takes the baseline.
		var at: Vector2 = _pos[i] + Vector2(0.0, _font.get_ascent(fontSize) - RISE * t)
		draw_string(_font, at, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, color)


func _drop_oldest(amount: int) -> void:
	_born = _born.slice(amount)
	_pos = _pos.slice(amount)
	_text = _text.slice(amount)
	_color = _color.slice(amount)
	_crit = _crit.slice(amount)
