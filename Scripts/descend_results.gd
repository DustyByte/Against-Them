extends Control

@onready var enemies_value: Label = $Center/Dialog/VBox/Stats/Row/Kills/Value
@onready var wave_value: Label = $Center/Dialog/VBox/Stats/Row/Wave/Value
@onready var time_value: Label = $Center/Dialog/VBox/Stats/Row/Time/Value
@onready var echoes_value: Label = $Center/Dialog/VBox/Echoes/HBox/Value
@onready var return_button: Panel = $Center/Dialog/VBox/ReturnButton
@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Center/Dialog

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

		var earned: int = MetaProgression.award_run_echoes(completed_waves, bosses_killed, kills)
		_count_up_echoes(earned)
		_echoes_awarded = true
		AchievementManager.register_run_completed()


func _ready() -> void:
	_play_entrance()


## The world behind dims in and the panel rises into place.
func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the panel lay out first
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.35)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.3).set_delay(0.08)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.4).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Echoes earned tick up from zero once the panel is in, then pop.
func _count_up_echoes(earned: int) -> void:
	echoes_value.text = "+0"
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_method(func(v: float): echoes_value.text = "+%d" % int(round(v)),
		0.0, float(earned), clampf(0.4 + earned * 0.03, 0.4, 1.2)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): echoes_value.pivot_offset = echoes_value.size * 0.5)
	tween.tween_property(echoes_value, "scale", Vector2(1.18, 1.18), 0.1)
	tween.tween_property(echoes_value, "scale", Vector2.ONE, 0.2)


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
