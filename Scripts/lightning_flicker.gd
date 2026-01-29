extends Sprite2D

var noiseGenerator: FastNoiseLite = FastNoiseLite.new()
var initFlickerSliderValue: float
var isTurnedOn: bool = false


func adjust_rotation(rotationDegree: float) -> void:
	rotation_degrees = -rotationDegree


func _ready() -> void:
	initFlickerSliderValue = material.get_shader_parameter("flickerSlider")


func _process(_delta: float) -> void:
	if isTurnedOn:
		visible = true
		var newFlickerSliderValue: float = initFlickerSliderValue + noiseGenerator.get_noise_1d(Time.get_ticks_usec())*0.5
		material.set_shader_parameter("flickerSlider", newFlickerSliderValue)
	else:
		visible = false
