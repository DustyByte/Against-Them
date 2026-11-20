class_name DamageNumbers
extends Node2D

## Draws every floating damage and heal number of a run from this one node.
## Each number fades in while rising for FADE_IN_TIME, holds briefly, then
## disappears. This replaces one Label, one tween and one timer per hit, which
## got expensive once auras, burns and fields hit dozens of enemies at a time.
## Created by world.gd; global.add_damage_text() adds to it.
##
## Numbers live in fixed ring buffers (oldest at _head), so adding one and
## dropping the oldest are both constant time. Before, a full screen of
## numbers re-copied all five arrays on every new hit.

const RISE: float = 50.0
const FADE_IN_TIME: float = 0.3
const LIFETIME: float = 0.4
## Sizes are in world pixels; the run camera's 0.6 zoom shows them at about
## 22 px (normal) and 34 px (crit) on screen.
const FONT_SIZE: int = 36
const CRIT_FONT_SIZE: int = 56
## A dark rim under every number so it reads over the ground and enemies alike.
const OUTLINE_SIZE: int = 8
const OUTLINE_COLOR := Color(0.02, 0.03, 0.06, 0.85)
## The oldest numbers are dropped first when more than this are on screen.
const MAX_NUMBERS: int = 300

var _font: Font = ThemeDB.fallback_font
var _ascent: float = _font.get_ascent(FONT_SIZE)
var _crit_ascent: float = _font.get_ascent(CRIT_FONT_SIZE)
var _now: float = 0.0
var _head: int = 0    # oldest number
var _count: int = 0
var _born: PackedFloat32Array = []
var _pos: PackedVector2Array = []
var _text: PackedStringArray = []
var _color: PackedColorArray = []
var _crit: PackedByteArray = []


func _init() -> void:
	_born.resize(MAX_NUMBERS)
	_pos.resize(MAX_NUMBERS)
	_text.resize(MAX_NUMBERS)
	_color.resize(MAX_NUMBERS)
	_crit.resize(MAX_NUMBERS)


func _ready() -> void:
	z_index = 1
	set_process(false)


func add(globalPos: Vector2, damage: float, damageType: int, isCrit: bool = false) -> void:
	if _count == MAX_NUMBERS:   # full: the new number replaces the oldest
		_head = (_head + 1) % MAX_NUMBERS
		_count -= 1
	var i: int = (_head + _count) % MAX_NUMBERS
	_count += 1
	_born[i] = _now
	_pos[i] = globalPos
	_text[i] = str(snapped(damage, 0.1))
	_color[i] = global.DAMAGE_TYPE_COLORS[damageType]
	_crit[i] = 1 if isCrit else 0
	set_process(true)


func _process(delta: float) -> void:
	_now += delta
	while _count > 0 and _now - _born[_head] >= LIFETIME:
		_head = (_head + 1) % MAX_NUMBERS
		_count -= 1
	queue_redraw()
	if _count == 0:
		set_process(false)   # the redraw above clears the last numbers


func _draw() -> void:
	for n in range(_count):
		var i: int = (_head + n) % MAX_NUMBERS
		var t: float = minf((_now - _born[i]) / FADE_IN_TIME, 1.0)
		var color: Color = _color[i]
		color.a = t
		var outline: Color = OUTLINE_COLOR
		outline.a *= t
		var crit: bool = _crit[i] == 1
		var fontSize: int = CRIT_FONT_SIZE if crit else FONT_SIZE
		# Labels placed their top-left corner at the position; draw_string takes the baseline.
		var at: Vector2 = _pos[i] + Vector2(0.0, (_crit_ascent if crit else _ascent) - RISE * t)
		draw_string_outline(_font, at, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, OUTLINE_SIZE, outline)
		draw_string(_font, at, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, color)
