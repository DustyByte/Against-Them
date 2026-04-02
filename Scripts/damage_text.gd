class_name DamageText
extends Label

var beginPos: Vector2 = Vector2.ZERO


func setup(globalPos: Vector2, damage: float, damageType: int, isCrit: bool = false) -> void:
	global_position = globalPos
	beginPos = globalPos
	text = str(snapped(damage, 0.1))
	modulate = global.DAMAGE_TYPE_COLORS[damageType]
	
	label_settings.font_size = 32 if isCrit else 16


func _ready() -> void:
	var method: Callable = func(val: float):
		modulate.a = val
		global_position = beginPos + Vector2(0.0, -50.0) * val
	var tween: Tween = get_tree().create_tween()
	
	tween.tween_method(method, 0.0, 1.0, 0.3)
	tween.finished.connect(die)


func die() -> void:
	await get_tree().create_timer(0.1).timeout
	queue_free()
