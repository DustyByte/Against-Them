extends Panel

const MIN_SCALE := 0.5
const MAX_SCALE := 2.0
const SCALE_MARGIN := 0.95

@onready var title_label: Label = $Title
@onready var understood_button: Panel = $OkayButton
@onready var revive_button: Panel = $ReviveButton

func _ready() -> void:
	understood_button.gui_input.connect(_check_if_touch_then_execute.bind(_on_okay_button_gui_input))
	revive_button.gui_input.connect(_check_if_touch_then_execute.bind(_on_revive_button_gui_input))
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	_update_scale()
	
	AdMobManager.rewarded_ad_failed_to_show.connect(_handle_rewarded_ad_failed_to_show)
	AdMobManager.rewarded_earned.connect(func(rewardType, amount):
		AchievementManager.register_revive()
		queue_free()
		get_tree().paused = false
		var player: Player = global.PLAYER
		player.take_heal(player.stats.maxHP * 0.5)
	)

func _handle_rewarded_ad_failed_to_show(err: String) -> void:
	var message_label: Label = Label.new()
	message_label.text = "Please check your internet and try again a few seconds later"
	message_label.modulate = Color(1.0, 0.55, 0.557, 0.0)
	
	add_child(message_label)
	message_label.position = Vector2(size.x * 0.5, size.y * 0.25) - (message_label.size * 0.5)
	message_label.pivot_offset = message_label.size * 0.5
	message_label.scale = Vector2(1.0/scale.x, 1.0/scale.y)
	
	var tween: Tween = message_label.create_tween()
	tween.tween_property(message_label, "modulate:a", 1.0, 0.25)
	tween.tween_property(message_label, "position:y", message_label.position.y - 40, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.75)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.4)
	tween.finished.connect(message_label.queue_free)

func _check_if_touch_then_execute(event: InputEvent, functionToExecute: Callable):
	if event is InputEventScreenTouch and event.is_pressed():
		global.WORLD.audio_play(preload("res://Assets/SFX/UI.mp3"), "ui")
		functionToExecute.call()

func _on_viewport_size_changed() -> void:
	_update_scale()

func _update_scale() -> void:
	var window_dim: Vector2 = get_viewport_rect().size
	
	var scale_x: float = window_dim.x / size.x * SCALE_MARGIN
	var scale_y: float = window_dim.y / size.y * SCALE_MARGIN
	scale = Vector2(
		clamp(scale_x, MIN_SCALE, MAX_SCALE),
		clamp(scale_y, MIN_SCALE, MAX_SCALE)
	)
	position = (window_dim - size * scale) * 0.5

func _on_okay_button_gui_input() -> void:
	var descendResults: Control = load("res://Scenes/HUD/descend_results.tscn").instantiate()
	add_sibling(descendResults)
	descendResults.set_stats(
		global.TOTAL_ENEMY_KILLS,
		global.WAVE_MANAGER.currentWave-1,
		global.WORLD.elapsedTime
	)
	
	queue_free()

func _on_revive_button_gui_input() -> void:
	AdMobManager.show_rewarded_ad()
