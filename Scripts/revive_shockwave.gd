extends Node2D
## Expanding ring drawn once when the player revives. Purely visual: the
## knockback itself is applied by Player.revive_shockwave().

const COLOR := Color(0.62, 0.92, 1.0)
const DURATION := 0.45

var maxRadius: float = 450.0
var radius: float = 0.0
var alpha: float = 1.0


func _ready() -> void:
	z_index = 5
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "radius", maxRadius, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "alpha", 0.0, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c: Color = COLOR
	# Soft fill, a bright leading edge and a faint inner echo ring.
	c.a = alpha * 0.08
	draw_circle(Vector2.ZERO, radius, c)
	c.a = alpha * 0.9
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, c, 10.0, true)
	c.a = alpha * 0.35
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 96, c, 4.0, true)
