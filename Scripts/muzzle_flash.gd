extends Sprite2D

## Short glow at the barrel when a weapon fires: an additive glow sprite whose
## brightness follows energyCurve. It used to be a PointLight2D, which made
## everything it lit render with lighting (and stop batching) while it was on.

## Peak of energyCurve (the old light's energy); it maps to full brightness.
const PEAK_ENERGY: float = 6.0
const BRIGHTNESS: float = 1.5

@export var energyCurve: Curve = Curve.new()
var isFlashing: bool = false
var activeTween: Tween = null


func flash_method(val: float) -> void:
	self_modulate.a = clampf(energyCurve.sample_baked(val) / PEAK_ENERGY, 0.0, 1.0)


func cleanup() -> void:
	visible = false
	self_modulate.a = 0.0
	isFlashing = false


func flash(flashColor: Color, whereGlob: Vector2) -> void:
	global_position = whereGlob
	
	if isFlashing:
		activeTween.kill()
		activeTween = null
	
	self_modulate = Color(flashColor * BRIGHTNESS, 0.0)
	activeTween = create_tween()
	activeTween.tween_method(flash_method, 0.0, energyCurve.max_domain, 0.05)
	isFlashing = true
	visible = true
	activeTween.finished.connect(cleanup)
