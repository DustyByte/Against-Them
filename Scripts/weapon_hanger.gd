extends VBoxContainer


@export var hangerUV: Vector2 = Vector2(0.8, 0.4)


func set_hanger_on_screen(u: float, v: float) -> void:
	var screenSize: Vector2 = get_viewport().get_visible_rect().size
	position = Vector2(u, v) * screenSize
	position -= size*0.5


func _ready() -> void:
	set_hanger_on_screen(hangerUV.x, hangerUV.y)
	global.ON_RUN_WEAPON_HANGER = self
