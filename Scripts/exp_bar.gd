extends ProgressBar
## Run EXP bar. Still a ProgressBar (the EXP system sets value / max_value),
## but drawn by exp_bar.gdshader: the fill eases toward the real value, the
## leading edge pulses on pickups, and a level-up flashes the bar and badge.
## Idle bars cost nothing on the CPU: _process only runs while something is
## animating, and shader values are only sent while they change. (The energy
## flow itself runs on the shader's own clock.)

const FILL_SPEED := 6.0          # how fast the shown fill catches up
const FLASH_DECAY := 1.6
const PULSE_DECAY := 3.0
const SETTLED := 0.0005           # fill this close to the target counts as done

@onready var _visual: ColorRect = $Visual
@onready var _level_label: Label = $Level
var _mat: ShaderMaterial

var level: int = 1:
	set(val):
		var leveled_up: bool = val > level
		level = val
		if is_node_ready():
			_level_label.text = str(level)
			if leveled_up:
				_on_level_up()

var _shown: float = 0.0          # displayed fill 0..1
var _last_value: float = 0.0
var _pulse: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	_mat = _visual.material
	_mat.set_shader_parameter("rect_size", size)
	resized.connect(func(): _mat.set_shader_parameter("rect_size", size))
	_level_label.text = str(level)
	_shown = _ratio()
	_last_value = value
	value_changed.connect(_on_value_changed)
	changed.connect(_wake)            # max_value changes (new level milestone)
	_send_all()
	set_process(false)


func _on_value_changed(new_value: float) -> void:
	if new_value > _last_value:
		_pulse = 1.0
	_last_value = new_value
	_wake()


## Bar fills to the top and flashes, then drains to the new (empty) level.
func _on_level_up() -> void:
	_shown = 1.0
	_flash = 1.0
	_pulse = 1.0
	var tween := create_tween()
	tween.tween_property(_level_label, "scale", Vector2.ONE, 0.35).from(Vector2(1.6, 1.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wake()


func _wake() -> void:
	set_process(true)


func _process(delta: float) -> void:
	# Hold full briefly during the flash so the level up reads, then ease.
	if _flash < 0.6:
		_shown = lerpf(_shown, _ratio(), 1.0 - exp(-FILL_SPEED * delta))
	_pulse = move_toward(_pulse, 0.0, delta * PULSE_DECAY)
	_flash = move_toward(_flash, 0.0, delta * FLASH_DECAY)
	
	# Everything has arrived: snap, send the final values once and go idle.
	var settled: bool = absf(_shown - _ratio()) < SETTLED and _pulse == 0.0 and _flash == 0.0
	if settled:
		_shown = _ratio()
	_send_all()
	if settled:
		set_process(false)


func _send_all() -> void:
	_mat.set_shader_parameter("fill", _shown)
	_mat.set_shader_parameter("gain_pulse", _pulse)
	_mat.set_shader_parameter("level_flash", _flash)


func _ratio() -> float:
	return clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
