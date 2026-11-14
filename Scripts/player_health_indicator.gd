extends Node2D
## Echo's HP readout: a hexagonal glass vessel whose fluid level is the HP.
## The fluid shifts teal -> amber -> crimson as HP drops, sloshes and flashes
## on hits, and the frame pulses when HP runs low.
## Idle vessels cost nothing on the CPU: _process only runs while the slosh,
## flash or warning is changing, and shader values are only sent then. (Waves,
## bubbles and the warning pulse run on the shader's own clock.)

const COLOR_FULL := Color(0.35, 0.95, 0.85)
const COLOR_MID := Color(0.95, 0.75, 0.35)
const COLOR_LOW := Color(0.95, 0.35, 0.42)
const DANGER_BELOW := 0.3        # HP ratio where the warning pulse starts
const FILL_TIME := 0.35

@export_range(0.0, 1.0, 0.001) var screenPositionX: float
@export_range(0.0, 1.0, 0.001) var screenPositionY: float

var playerStats: PlayerStats = null
@onready var _vessel: ColorRect = $Vessel
@onready var _value: Label = $Readout/Value
@onready var _max: Label = $Readout/Max
var _mat: ShaderMaterial

var _fill: float = 1.0           # shown level, eases toward the real ratio
var _lastHP: float = -1.0
var _slosh: float = 0.0
var _flash: float = 0.0
var _danger: float = 0.0
var _fillTween: Tween


func _ready() -> void:
	# Viewport units, so it sits in the same spot on every screen size.
	position = get_viewport_rect().size * Vector2(screenPositionX, screenPositionY)
	_mat = _vessel.material
	
	var player: Player = $"../../Player"
	playerStats = player.stats
	player.hp_changed.connect(update_indicator)
	_lastHP = playerStats.currentHP
	_fill = _ratio(playerStats.currentHP, playerStats.maxHP)
	_apply_level(_fill)
	_update_text(playerStats.currentHP, playerStats.maxHP)
	_danger = _wanted_danger()
	_send_effects()
	set_process(false)


func update_indicator(currentHP: float, maxHP: float) -> void:
	var target: float = _ratio(currentHP, maxHP)
	if currentHP < _lastHP:
		_slosh = 1.0
		_flash = 1.0
		_mat.set_shader_parameter("tilt", randf_range(-0.35, 0.35))
	elif currentHP > _lastHP:
		_slosh = maxf(_slosh, 0.5)
	_lastHP = currentHP
	_update_text(currentHP, maxHP)
	
	if _fillTween:
		_fillTween.kill()
	_fillTween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fillTween.tween_method(_apply_level, _fill, target, FILL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	set_process(true)


func _process(delta: float) -> void:
	_slosh = move_toward(_slosh, 0.0, delta * 0.9)
	_flash = move_toward(_flash, 0.0, delta * 4.0)
	var wantDanger: float = _wanted_danger()
	_danger = move_toward(_danger, wantDanger, delta * 2.0)
	_send_effects()
	
	# Slosh, flash and warning have all arrived and the level has finished
	# draining: nothing left to animate here, so go idle.
	var fillMoving: bool = _fillTween != null and _fillTween.is_running()
	if _slosh == 0.0 and _flash == 0.0 and _danger == wantDanger and not fillMoving:
		set_process(false)


func _wanted_danger() -> float:
	return 1.0 if (_fill < DANGER_BELOW and _lastHP > 0.0) else 0.0


func _send_effects() -> void:
	_mat.set_shader_parameter("slosh", _slosh)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("danger", _danger)


func _apply_level(level: float) -> void:
	_fill = level
	_mat.set_shader_parameter("fill_level", level)
	_mat.set_shader_parameter("fluid_color", _color_for(level))


## Teal when healthy, amber around half, crimson when nearly empty.
func _color_for(ratio: float) -> Color:
	if ratio >= 0.5:
		return COLOR_MID.lerp(COLOR_FULL, (ratio - 0.5) / 0.5)
	return COLOR_LOW.lerp(COLOR_MID, ratio / 0.5)


func _update_text(currentHP: float, maxHP: float) -> void:
	_value.text = str(ceili(currentHP))
	_max.text = "/ %d" % ceili(maxHP)


func _ratio(currentHP: float, maxHP: float) -> float:
	return clampf(currentHP / maxHP, 0.0, 1.0) if maxHP > 0.0 else 0.0
