extends PointLight2D

@export var energyCurve: Curve = Curve.new()
var isFlashing: bool = false
var activeTween: Tween = null


func flash_method(val: float) -> void:
	energy = energyCurve.sample_baked(val)


func cleanup() -> void:
	visible = false
	energy = 0.0
	isFlashing = false


func flash(flashColor: Color, whereGlob: Vector2) -> void:
	global_position = whereGlob
	
	if isFlashing:
		activeTween.kill()
		activeTween = null
		energy = 0.0
	
	color = flashColor
	activeTween = get_tree().create_tween()
	activeTween.tween_method(flash_method, 0.0, energyCurve.max_domain, 0.05)
	isFlashing = true
	visible = true
	activeTween.finished.connect(cleanup)
