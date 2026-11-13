extends Control

@onready var resume_button: Panel = $Center/Dialog/VBox/ResumeButton
@onready var quit_button: Panel = $Center/Dialog/VBox/QuitButton
@onready var _dim: ColorRect = $ColorRect
@onready var _dialog: PanelContainer = $Center/Dialog
@onready var _wave_value: Label = $Center/Dialog/VBox/Stats/Row/Wave/Value
@onready var _kills_value: Label = $Center/Dialog/VBox/Stats/Row/Kills/Value
@onready var _time_value: Label = $Center/Dialog/VBox/Stats/Row/Time/Value

func _ready() -> void:
	_fill_stats()
	_play_entrance()

## The run so far, using the same figures as the results screen.
func _fill_stats() -> void:
	_wave_value.text = str(global.WAVE_MANAGER.currentWave - 1) if is_instance_valid(global.WAVE_MANAGER) else "-"
	_kills_value.text = str(global.TOTAL_ENEMY_KILLS)
	var seconds: int = int(global.WORLD.elapsedTime) if is_instance_valid(global.WORLD) else 0
	_time_value.text = "%02d:%02d" % [seconds / 60, seconds % 60]

## The game behind dims and the panel pops into place (quick: pausing should feel instant).
func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the panel lay out first
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.95, 0.95)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.18)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
