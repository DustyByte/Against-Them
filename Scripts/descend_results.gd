extends Control

@onready var enemies_value: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatsPanel/StatsMargin/StatsVBox/EnemiesKilled/EnemiesValue
@onready var wave_value: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatsPanel/StatsMargin/StatsVBox/WaveReached/WaveValue
@onready var time_value: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatsPanel/StatsMargin/StatsVBox/ElapsedTime/TimeValue
@onready var echoes_value: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/EchoesPanel/EchoesMargin/EchoesEarned/EchoesValue
@onready var return_button: Panel = $CenterContainer/Panel/MarginContainer/VBoxContainer/ReturnButton

var _echoes_awarded: bool = false


func set_stats(kills: int, wave: int, elapsed_seconds: float) -> void:
	enemies_value.text = str(kills)
	wave_value.text = str(wave)
	
	var minutes := int(elapsed_seconds) / 60
	var seconds := int(elapsed_seconds) % 60
	
	time_value.text = "%02d:%02d" % [minutes, seconds]

	if not _echoes_awarded:
		var completed_waves: int = 0
		var bosses_killed: int = 0
		if is_instance_valid(global.WAVE_MANAGER):
			completed_waves = global.WAVE_MANAGER.wavesCompleted
			bosses_killed = global.WAVE_MANAGER.bossesKilled

		var earned: int = MetaProgression.award_run_echoes(completed_waves, bosses_killed)
		echoes_value.text = str(earned)
		_echoes_awarded = true


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
