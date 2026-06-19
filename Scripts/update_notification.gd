extends Control

var setAsMustUpdate: bool = true

func _ready() -> void:
	var panel: Panel = $Panel
	var maybeLaterBtn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/MaybeLaterButton
	var updateBtn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/UpdateButton
	var aspectRatio: float = panel.size.x / panel.size.y
	var windowDim: Vector2 = get_viewport_rect().size
	panel.size.y = windowDim.y * 0.5
	panel.size.x = panel.size.y * aspectRatio
	panel.position = (windowDim - panel.size) * 0.5
	
	updateBtn.gui_input.connect(_check_if_touch.bind(_on_update_pressed))
	if setAsMustUpdate:
		maybeLaterBtn.visible = false
		return
	maybeLaterBtn.gui_input.connect(_check_if_touch.bind(_on_maybe_later_pressed))


func _check_if_touch(event: InputEvent, funcToCall: Callable) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		funcToCall.call()


func _on_update_pressed() -> void:
	get_tree().quit()


func _on_maybe_later_pressed() -> void:
	get_tree().paused = false
	queue_free()
