extends Camera2D

var isActive: bool = true
var noiseGenerator: FastNoiseLite = FastNoiseLite.new()
var shakeDuration: float = 0.3

func activate() -> void:
	global.activeCamera = self
	isActive = true


func _ready() -> void:
	activate()


func shake(trauma: float) -> void:
	var shakeOneFrame = func(intensity):
		offset.x = noiseGenerator.get_noise_1d(Time.get_ticks_usec()) * intensity
		offset.y = noiseGenerator.get_noise_1d((Time.get_ticks_usec())*1.1) * intensity
	
	get_tree().create_tween().tween_method(shakeOneFrame, trauma, 0.0, shakeDuration)
