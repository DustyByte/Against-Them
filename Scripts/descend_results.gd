extends Control

@onready var enemies_value: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatsPanel/StatsMargin/StatsVBox/EnemiesKilled/EnemiesValue
@onready var wave_value: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatsPanel/StatsMargin/StatsVBox/WaveReached/WaveValue
@onready var time_value: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatsPanel/StatsMargin/StatsVBox/ElapsedTime/TimeValue
@onready var return_button: Panel = $CenterContainer/Panel/MarginContainer/VBoxContainer/ReturnButton


func set_stats(kills: int, wave: int, elapsed_seconds: float) -> void:
	enemies_value.text = str(kills)
	wave_value.text = str(wave)
	
	var minutes := int(elapsed_seconds) / 60
	var seconds := int(elapsed_seconds) % 60
	
	time_value.text = "%02d:%02d" % [minutes, seconds]


func _on_return_button_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if global.SFX_TYPES_PERM["ui"]:
			var ASP: AudioStreamPlayer = AudioStreamPlayer.new()
			ASP.stream = preload("res://Assets/SFX/SomeUITurnedOff_On.mp3")
			ASP.volume_db = -8.0
			global.add_child(ASP)
			ASP.play()
			ASP.finished.connect(ASP.queue_free)
		
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/home.tscn")
