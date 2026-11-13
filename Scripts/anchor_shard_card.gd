extends PanelContainer
## Shop card for Anchor Shards. Shows how many the player owns, the price
## (one rewarded ad) and today's remaining ads, and runs the ad flow itself.

const TAP_MAX_DRAG: float = 24.0
## If the ad closes before the reward arrives, keep listening this long.
const REWARD_GRACE: float = 2.0

@onready var _owned_value: Label = $VBox/Top/Info/OwnedPill/HBox/Value
@onready var _limit_value: Label = $VBox/LimitRow/Value
@onready var _button: Panel = $VBox/WatchButton
@onready var _button_label: Label = $VBox/WatchButton/Label

var _awaiting_ad: bool = false   # an ad this card asked for is open or paying out
var _press_position: Vector2
var _message_tween: Tween


func _ready() -> void:
	_button.gui_input.connect(_on_button_gui_input)
	InventoryManager.anchor_shards_changed.connect(func(_total: int): _refresh())
	InventoryManager.daily_ads_changed.connect(func(_used: int, _limit: int): _refresh())
	AdMobManager.rewarded_earned.connect(_on_rewarded_earned)
	AdMobManager.rewarded_ad_dismissed.connect(_on_rewarded_ad_dismissed)
	AdMobManager.rewarded_ad_failed_to_show.connect(_on_rewarded_ad_failed_to_show)
	_refresh()


func _refresh() -> void:
	_owned_value.text = str(InventoryManager.anchor_shards)
	_limit_value.text = "%d / %d" % [InventoryManager.ads_left_today(), InventoryManager.DAILY_AD_LIMIT]
	_update_button()


func _update_button() -> void:
	var available: bool = InventoryManager.can_watch_ad_today()
	if _awaiting_ad:
		_button_label.text = "LOADING..."
	elif not available:
		_button_label.text = "COME BACK TOMORROW"
	else:
		_button_label.text = "WATCH TO GET"
	_button.modulate.a = 1.0 if available and not _awaiting_ad else 0.4


# --- Tap handling (ignores drags so scrolling the grid doesn't trigger it) ---

func _on_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	if event.is_pressed():
		_press_position = event.position
	elif event.position.distance_to(_press_position) <= TAP_MAX_DRAG:
		_try_watch_ad()


func _try_watch_ad() -> void:
	if _awaiting_ad or not InventoryManager.can_watch_ad_today():
		return
	_play_ui_sfx()
	_awaiting_ad = true
	_update_button()
	AdMobManager.show_rewarded_ad()


# --- Ad results ---------------------------------------------------------------

func _on_rewarded_earned(_reward_type: String, _amount: int) -> void:
	if not _awaiting_ad:
		return   # someone else's ad (e.g. the death screen)
	_awaiting_ad = false
	InventoryManager.register_ad_reward()
	_pulse_owned()


func _on_rewarded_ad_dismissed() -> void:
	if not _awaiting_ad:
		return
	# The reward can arrive just after the ad closes; wait briefly for it.
	await get_tree().create_timer(REWARD_GRACE).timeout
	if _awaiting_ad:
		_awaiting_ad = false   # closed early, no reward
		_update_button()


func _on_rewarded_ad_failed_to_show(_error: String) -> void:
	if not _awaiting_ad:
		return
	_awaiting_ad = false
	_update_button()
	_flash_message("NO AD RIGHT NOW")


# --- Feedback -----------------------------------------------------------------

func _pulse_owned() -> void:
	_owned_value.pivot_offset = _owned_value.size * 0.5
	var tween := create_tween()
	tween.tween_property(_owned_value, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_owned_value, "scale", Vector2.ONE, 0.25)


## Shows a short note on the button, then restores its normal text.
func _flash_message(text: String) -> void:
	if _message_tween:
		_message_tween.kill()
	_button_label.text = text
	_button_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.56))
	_message_tween = create_tween()
	_message_tween.tween_interval(1.8)
	_message_tween.tween_callback(func():
		_button_label.add_theme_color_override("font_color", Color(0.85, 0.96, 1))
		_update_button()
	)


func _play_ui_sfx() -> void:
	if global.SFX_TYPES_PERM["ui"]:
		var asp := AudioStreamPlayer.new()
		asp.stream = preload("res://Assets/SFX/UI.mp3")
		asp.pitch_scale = randf_range(0.7, 1.3)
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
