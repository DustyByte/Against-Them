extends Panel

const MIN_SCALE := 0.5
const MAX_SCALE := 2.0
const SCALE_MARGIN := 0.95
const COUNTDOWN_FROM := 3
const COUNTDOWN_STEP := 0.8

@onready var title_label: Label = $Title
@onready var understood_button: Panel = $OkayButton
@onready var revive_button: Panel = $ReviveButton

# Revive only happens once the reward was granted AND the ad has been closed,
# whichever of the two arrives last. Until then the world stays paused.
var _ad_open: bool = false
var _reward_earned: bool = false
var _reviving: bool = false

func _ready() -> void:
	understood_button.gui_input.connect(_check_if_touch_then_execute.bind(_on_okay_button_gui_input))
	revive_button.gui_input.connect(_check_if_touch_then_execute.bind(_on_revive_button_gui_input))
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	_update_scale()
	
	AdMobManager.rewarded_ad_failed_to_show.connect(_handle_rewarded_ad_failed_to_show)
	AdMobManager.rewarded_earned.connect(_on_rewarded_earned)
	AdMobManager.rewarded_ad_dismissed.connect(_on_rewarded_ad_dismissed)

func _on_rewarded_earned(_reward_type: String, _amount: int) -> void:
	if _reward_earned:
		return
	_reward_earned = true
	AchievementManager.register_revive()
	_try_revive()

func _on_rewarded_ad_dismissed() -> void:
	_ad_open = false
	# Closed early without the reward: stay on the death screen.
	_try_revive()

func _try_revive() -> void:
	if _reward_earned and not _ad_open and not _reviving:
		_reviving = true
		_start_countdown()

## World stays paused while a 3-2-1 plays, so the player can get ready.
func _start_countdown() -> void:
	visible = false
	
	var settings := LabelSettings.new()
	settings.font = title_label.label_settings.font
	settings.font_size = 120
	settings.font_color = Color(0.85, 0.97, 1.0)
	settings.outline_size = 14
	settings.outline_color = Color(0.02, 0.05, 0.1, 0.85)
	
	var label := Label.new()
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(240, 180)
	get_parent().add_child(label)
	
	var view: Vector2 = get_viewport_rect().size
	# Below the player, clear of the wave banner and the HUD corners.
	label.position = Vector2(view.x * 0.5, view.y * 0.72) - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	
	var tween: Tween = label.create_tween()
	for n in range(COUNTDOWN_FROM, 0, -1):
		tween.tween_callback(func():
			label.text = str(n)
			global.WORLD.audio_play(preload("res://Assets/SFX/UI.mp3"), "ui")
		)
		tween.tween_property(label, "scale", Vector2.ONE, COUNTDOWN_STEP * 0.35).from(Vector2(1.6, 1.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate:a", 1.0, COUNTDOWN_STEP * 0.25).from(0.0)
		tween.tween_interval(COUNTDOWN_STEP * 0.4)
		tween.tween_property(label, "modulate:a", 0.0, COUNTDOWN_STEP * 0.25)
	tween.tween_callback(_finish_revive)

func _finish_revive() -> void:
	get_tree().paused = false
	var player: Player = global.PLAYER
	player.take_heal(player.stats.maxHP * 0.5)
	player.revive_shockwave()
	# Free the whole death screen layer (this script sits on its panel).
	get_parent().queue_free()

func _handle_rewarded_ad_failed_to_show(err: String) -> void:
	_ad_open = false
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
	if _ad_open or _reviving:
		return
	_ad_open = true
	AdMobManager.show_rewarded_ad()
