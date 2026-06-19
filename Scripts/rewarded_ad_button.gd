extends Panel
## Rewarded Ad Button - Shows a button to watch rewarded ads
## Add this to your UI scene to enable rewarded ad functionality

@export var button_text: String = "Watch for Reward"
@export var ready_text: String = "Watch Ad"
@export var loading_text: String = "Loading..."
@export var reward_callback: Callable = func(reward_type: String, reward_amount: int):
	var options: Array[Option] = global.PROGRESSION_CHOICE_SYSTEM.give_selectable_options(6)
	$"../../..".present_options(options)
@export var disabled: bool = false
var _is_ready: bool = true

func _ready() -> void:
	gui_input.connect(_on_button_pressed)
	
	AdMobManager.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	AdMobManager.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
	AdMobManager.rewarded_earned.connect(_on_rewarded_earned)
	AdMobManager.rewarded_ad_shown.connect(_on_rewarded_ad_shown)
	AdMobManager.rewarded_ad_dismissed.connect(_on_rewarded_ad_dismissed)
	AdMobManager.rewarded_ad_failed_to_show.connect(_on_rewarded_ad_failed_to_show)
	
	_update_button_state()

func _on_button_pressed(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not _is_ready:
			print("Ad not ready yet")
			_throw_ad_error_label()
			return
		
		disabled = true
		AdMobManager.show_rewarded_ad()

func _on_rewarded_ad_loaded() -> void:
	print("Fropm reqarded ad button _on_rewarded_ad_loaded ")
	_is_ready = true
	_update_button_state()

func _on_rewarded_ad_failed_to_load(error: String) -> void:
	print("Failed to load rewarded ad: ", error)
	_is_ready = false
	_update_button_state()

func _on_rewarded_earned(reward_type: String, reward_amount: int) -> void:
	print("Reward earned: ", reward_amount, " ", reward_type)
	if reward_callback:
		reward_callback.call(reward_type, reward_amount)

func _on_rewarded_ad_shown() -> void:
	print("Rewarded ad shown")

func _on_rewarded_ad_dismissed() -> void:
	disabled = false
	_update_button_state()

func _on_rewarded_ad_failed_to_show(error: String) -> void:
	print(error)
	disabled = false
	_update_button_state()
	
	_throw_ad_error_label()

func _throw_ad_error_label() -> void:
	var message_label: Label = Label.new()
	message_label.text = "Please check your internet and try again a few seconds later"
	message_label.modulate = Color(1.0, 0.55, 0.557, 0.0)
	
	$"../../..".add_child(message_label)
	message_label.position -= message_label.size * 0.5
	
	var tween: Tween = message_label.create_tween()
	tween.tween_property(message_label, "modulate:a", 1.0, 0.25)
	tween.tween_property(message_label, "position:y", message_label.position.y - 40, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.75)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.4)
	tween.finished.connect(message_label.queue_free)

func _update_button_state() -> void:
	if _is_ready:
		disabled = false
	else:
		disabled = true
