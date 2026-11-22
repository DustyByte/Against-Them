extends Control

## Pops up from the Home screen's Echoes notch: watch a rewarded ad for
## MetaProgression.AD_ECHOES_REWARD Echoes, up to DAILY_ECHO_AD_LIMIT times a
## day (resets at local midnight).

## If the ad closes before the reward arrives, keep listening this long.
const REWARD_GRACE: float = 2.0
## After an ad closes, wait this long before the Echoes fly (the game screen
## takes a moment to come back on phones).
const AD_RETURN_DELAY: float = 0.4
const USED_PIP_ALPHA: float = 0.16
const ERROR_COLOR := Color(1.0, 0.55, 0.56)
const REWARD_COLOR := Color(0.62, 0.88, 0.95)
const LABEL_COLOR := Color(0.96, 0.97, 1, 1)   # the watch button's normal text

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Center/Dialog
@onready var _reward: Label = $Center/Dialog/VBox/Offer/Info/Reward
@onready var _owned_value: Label = $Center/Dialog/VBox/OwnedRow/Value
@onready var _limit_value: Label = $Center/Dialog/VBox/LimitRow/Value
@onready var _pips: HBoxContainer = $Center/Dialog/VBox/Pips
@onready var _reset: Label = $Center/Dialog/VBox/Reset
@onready var _close_btn: Panel = $Center/Dialog/VBox/Buttons/CloseButton
@onready var _watch_btn: Panel = $Center/Dialog/VBox/Buttons/WatchButton
@onready var _watch_label: Label = $Center/Dialog/VBox/Buttons/WatchButton/Label

var _on_tap: Callable   # home.gd's tap handler: plays the menu sound, then runs the action
var _awaiting_ad := false   # an ad this card asked for is open or paying out
var _closing := false
var _ad_showing := false     # a real ad covers the screen right now
var _held_echoes := 0        # paid out during the ad; they fly in once it closes
var _message_tween: Tween


func _ready() -> void:
	_on_tap = $"../.."._check_if_touch_then_execute
	_reward.text = tr("+%d ECHOES") % MetaProgression.AD_ECHOES_REWARD
	_build_pips()

	_close_btn.gui_input.connect(_on_tap.bind(_close_btn, _close))
	_watch_btn.gui_input.connect(_on_tap.bind(_watch_btn, _try_watch_ad))
	_dim.gui_input.connect(_on_backdrop_input)

	MetaProgression.echoes_changed.connect(_on_echoes_changed)
	MetaProgression.echo_ads_changed.connect(func(_left: int, _limit: int): _refresh())
	AdMobManager.rewarded_earned.connect(_on_rewarded_earned)
	AdMobManager.rewarded_ad_dismissed.connect(_on_rewarded_ad_dismissed)
	AdMobManager.rewarded_ad_failed_to_show.connect(_on_rewarded_ad_failed_to_show)
	AdMobManager.retry_now()   # the player may want an ad soon: skip any wait between load attempts

	# The reset countdown only needs minutes; one cheap tick a second while open.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)

	_owned_value.text = str(MetaProgression.echoes)
	_refresh()
	_play_entrance()


func _build_pips() -> void:
	var template: Panel = _pips.get_node("Pip")
	for i in MetaProgression.DAILY_ECHO_AD_LIMIT - 1:
		_pips.add_child(template.duplicate())


func _refresh() -> void:
	var left: int = MetaProgression.echo_ads_left_today()   # also rolls over at midnight
	var limit: int = MetaProgression.DAILY_ECHO_AD_LIMIT
	_limit_value.text = "%d / %d" % [left, limit]
	for i in _pips.get_child_count():
		_pips.get_child(i).modulate.a = 1.0 if i < left else USED_PIP_ALPHA

	var seconds: int = MetaProgression.seconds_until_echo_ad_reset()
	_reset.text = tr("RESETS IN %dH %02dM") % [seconds / 3600, (seconds / 60) % 60]
	_update_button()


func _update_button() -> void:
	if _message_tween and _message_tween.is_valid():
		return   # a short message is showing; it restores the label itself
	var available: bool = MetaProgression.can_watch_echo_ad()
	if _awaiting_ad:
		_watch_label.text = "LOADING..."
	elif not available:
		_watch_label.text = "DONE FOR TODAY"
	else:
		_watch_label.text = "WATCH AD"
	_watch_btn.modulate.a = 1.0 if available and not _awaiting_ad else 0.4


func _on_echoes_changed(total: int) -> void:
	_owned_value.text = str(total)


# --- Ad flow ------------------------------------------------------------------

func _try_watch_ad() -> void:
	if _awaiting_ad or not MetaProgression.can_watch_echo_ad():
		return
	_awaiting_ad = true
	_update_button()
	if OS.has_feature("editor") and not AdMobManager.is_rewarded_ad_ready():
		# No ads on desktop: pretend one was watched so the flow can be tested
		# from the editor. Exported builds never take this path.
		await get_tree().create_timer(0.6).timeout
		_on_rewarded_earned("editor", MetaProgression.AD_ECHOES_REWARD)
		return
	_ad_showing = true
	AdMobManager.show_rewarded_ad()


func _on_rewarded_earned(_reward_type: String, _amount: int) -> void:
	if not _awaiting_ad:
		return   # someone else's ad (e.g. the shop's Anchor Shard card)
	_awaiting_ad = false
	if MetaProgression.register_echo_ad_reward():
		var home: Node = get_tree().get_first_node_in_group(&"home_screen")
		if home:
			if _ad_showing:
				# The ad still covers the screen: keep them off the counter and
				# fly them in once the player is back (_on_rewarded_ad_dismissed).
				home.hold_echoes(MetaProgression.AD_ECHOES_REWARD)
				_held_echoes += MetaProgression.AD_ECHOES_REWARD
			else:
				home.collect_echoes(_reward.get_global_rect().get_center(), MetaProgression.AD_ECHOES_REWARD)
		_pulse(_owned_value)
		_flash_message("+%d ECHOES" % MetaProgression.AD_ECHOES_REWARD, REWARD_COLOR)
	_refresh()


func _on_rewarded_ad_dismissed() -> void:
	_ad_showing = false
	_release_held_echoes(AD_RETURN_DELAY)
	if not _awaiting_ad:
		return
	# The reward can arrive just after the ad closes; wait briefly for it.
	await get_tree().create_timer(REWARD_GRACE).timeout
	if _awaiting_ad:
		_awaiting_ad = false   # closed early, no reward
		_update_button()


## Flies the Echoes paid out during the ad into the counter, a moment after
## the game is back on screen. (Also when the card goes away, so none stay held.)
func _release_held_echoes(delay: float) -> void:
	if _held_echoes <= 0:
		return
	var home: Node = get_tree().get_first_node_in_group(&"home_screen")
	if home:
		home.fly_echoes(_reward.get_global_rect().get_center(), _held_echoes, delay)
	_held_echoes = 0


func _exit_tree() -> void:
	_release_held_echoes(0.0)


func _on_rewarded_ad_failed_to_show(_error: String) -> void:
	_ad_showing = false
	if not _awaiting_ad:
		return
	_awaiting_ad = false
	AdMobManager.retry_now()
	_flash_message("NO AD RIGHT NOW", ERROR_COLOR)


# --- Feedback -----------------------------------------------------------------

func _pulse(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.25)


## Shows a short note on the watch button, then restores its normal text.
func _flash_message(text: String, color: Color) -> void:
	if _message_tween:
		_message_tween.kill()
	_watch_label.text = text
	_watch_label.add_theme_color_override("font_color", color)
	_watch_btn.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(1.6)
	_message_tween.tween_callback(func():
		_message_tween = null
		_watch_label.add_theme_color_override("font_color", LABEL_COLOR)
		_update_button())


# --- Closing -----------------------------------------------------------------

## The backdrop swallows every touch (so nothing behind reacts) and closes on a tap.
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
	_on_tap.call(event, _dim, _close)


func _close() -> void:
	if _closing or _awaiting_ad:
		return   # stay open until a running ad has paid out (or not)
	_closing = true
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.tween_property(_dialog, "scale", Vector2(0.97, 0.97), 0.14)
	await tween.finished
	queue_free()


func _play_entrance() -> void:
	_dim.modulate.a = 0.0
	_dialog.modulate.a = 0.0
	await get_tree().process_frame   # let the panel lay out first
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tween.tween_property(_dialog, "modulate:a", 1.0, 0.18)
	tween.tween_property(_dialog, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
