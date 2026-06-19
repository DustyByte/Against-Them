extends Control

@onready var resume_button = $Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_button = $Panel/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	var aspect_ratio: float = $Panel.size.x / $Panel.size.y
	var window_dim: Vector2 = get_viewport_rect().size
	var panel_y: float = window_dim.y * 0.5
	var panel_x: float = panel_y * aspect_ratio
	$Panel.size = Vector2(panel_x, panel_y)
	$Panel.position = (window_dim - $Panel.size) * 0.5

func _on_resume_button_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		resume_game()

func _on_quit_button_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		quit_game()

func resume_game() -> void:
	get_tree().paused = false
	queue_free()

func quit_game() -> void:
	get_tree().paused = false
	
	queue_free()
	
	var descendResults: Control = load("res://Scenes/HUD/descend_results.tscn").instantiate()
	var canvasLayer: CanvasLayer = CanvasLayer.new()
	canvasLayer.layer = 2
	canvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	global.WORLD.add_child(canvasLayer)
	canvasLayer.add_child(descendResults)
	descendResults.set_stats(
		global.TOTAL_ENEMY_KILLS,
		global.WAVE_MANAGER.currentWave-1,
		global.WORLD.elapsedTime
	)
	
	get_tree().paused = true


func _on_color_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		var pauseButtonPanel: MarginContainer = get_parent().pauseButtonPanel.get_parent()
		var pauseButtonRect := pauseButtonPanel.get_rect()
		if pauseButtonRect.position.x + pauseButtonRect.size.x > event.position.x and pauseButtonRect.position.x < event.position.x:
			if pauseButtonRect.position.y + pauseButtonRect.size.y > event.position.y and pauseButtonRect.position.y < event.position.y:
				resume_game()
