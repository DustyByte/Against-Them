extends VBoxContainer


@export var hangerUV: Vector2 = Vector2(0.8, 0.4)


func set_hanger_on_screen(u: float = -1.0, v: float = -1.0) -> void:
	var screenSize: Vector2 = get_viewport_rect().size
	if u < 0 and v < 0:
		position = hangerUV * screenSize
	else:
		position = Vector2(u, v) * screenSize
	position -= size*0.5


func set_hanger_on_screen_pivot_center_right(u: float, v: float) -> void:
	var screenSize: Vector2 = get_viewport_rect().size
	var marginRight: float = 64
	position = Vector2(u, v) * screenSize - Vector2(size.x, size.y*0.5) + Vector2.LEFT*marginRight


func _ready() -> void:
	set_hanger_on_screen(hangerUV.x, hangerUV.y)
	global.ON_RUN_WEAPON_HANGER = self
