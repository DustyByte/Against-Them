class_name WaveHeading
extends Node2D

## Achievement banners wait while any node is in this group.
const GROUP: StringName = &"wave_heading"

@export_range(0.0, 1.0, 0.001) var screenPositionX: float
@export_range(0.0, 1.0, 0.001) var screenPositionY: float


func setup(waveNo: int) -> void:
	$Label.text = "Wave " + str(waveNo)


func animate_exit() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_method(func(val: float):
		modulate.a = val
	, 1.0, 0.0, 0.15)
	
	tween.finished.connect(queue_free)


func animate_entrance() -> void:
	get_tree().create_tween().tween_method(func(val: float):
		modulate.a = val
	, 0.0, 1.0, 0.3)
	
	await get_tree().create_timer(2.15).timeout
	
	animate_exit()


func _ready() -> void:
	add_to_group(GROUP)
	var windowDim: Vector2 = get_viewport_rect().size
	position = windowDim * Vector2(screenPositionX, screenPositionY)
	
	modulate.a = 0.0
	animate_entrance()
