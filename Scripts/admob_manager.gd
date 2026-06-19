extends Node
## AdMob Manager for handling rewarded ads in the game
## Initialize this by calling: AdMobManager.initialize()


# Rewarded ad unit IDs (replace with your actual ad unit IDs)
const REWARDED_AD_UNIT_ID_ANDROID = "ca-app-pub-3940256099942544/5224354917"  # Test ID
const REWARDED_AD_UNIT_ID_IOS = "ca-app-pub-3940256099942544/1712485313"      # Test ID

# Test device IDs (add your device ID for testing)
const TEST_DEVICE_IDS = []

var _rewarded_ad: RewardedAd = null
var _rewarded_ad_loader: RewardedAdLoader = null
var _is_loading = false
var _is_initialized = false

# Signals
signal rewarded_ad_loaded
signal rewarded_ad_failed_to_load(error: String)
signal rewarded_earned(reward_type: String, reward_amount: int)
signal rewarded_ad_shown
signal rewarded_ad_dismissed
signal rewarded_ad_failed_to_show(error: String)

## Initialize AdMob (call this once at game start)
func initialize() -> void:
	if _is_initialized:
		return
	
	_is_initialized = true
	
	# Configure request settings
	var request_config := RequestConfiguration.new()
	request_config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	#request_config.test_device_ids = TEST_DEVICE_IDS
	
	MobileAds.set_request_configuration(request_config)
	
	# Initialize MobileAds
	var on_init_listener := OnInitializationCompleteListener.new()
	on_init_listener.on_initialization_complete = _on_initialization_complete
	
	MobileAds.initialize(on_init_listener)

## Load a rewarded ad
func load_rewarded_ad() -> void:
	if _is_loading or _rewarded_ad != null:
		print("from load_rewarded_ad AdMobManager returned")
		return
	
	print("from load_rewarded_ad AdMobManager loading")
	_is_loading = true
	
	_rewarded_ad_loader = RewardedAdLoader.new()
	var load_callback := RewardedAdLoadCallback.new()
	load_callback.on_ad_loaded = _on_rewarded_ad_loaded
	load_callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load
	
	# Get the correct ad unit ID based on platform
	var ad_unit_id = REWARDED_AD_UNIT_ID_ANDROID if OS.get_name() == "Android" else REWARDED_AD_UNIT_ID_IOS
	
	_rewarded_ad_loader.load(ad_unit_id, AdRequest.new(), load_callback)

## Show the loaded rewarded ad
func show_rewarded_ad() -> void:
	if _rewarded_ad == null:
		push_error("No rewarded ad loaded")
		rewarded_ad_failed_to_show.emit("No ad loaded")
		return
	
	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = _on_user_earned_reward
	
	_rewarded_ad.full_screen_content_callback = _create_content_callback()
	_rewarded_ad.show(reward_listener)

## Check if a rewarded ad is loaded and ready to show
func is_rewarded_ad_ready() -> bool:
	return _rewarded_ad != null

## Destroy the current rewarded ad
func destroy_rewarded_ad() -> void:
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null

# Private functions
func _on_initialization_complete(_status: InitializationStatus) -> void:
	print("AdMob initialized successfully")
	load_rewarded_ad()

func _on_rewarded_ad_loaded(ad: RewardedAd) -> void:
	print("Rewarded ad loaded successfully")
	_rewarded_ad = ad
	_is_loading = false
	rewarded_ad_loaded.emit()

func _on_rewarded_ad_failed_to_load(error: LoadAdError) -> void:
	print("Failed to load rewarded ad: ", error.message)
	_is_loading = false
	rewarded_ad_failed_to_load.emit(error.message)
	get_tree().create_timer(1.0, true, false, true).timeout.connect(load_rewarded_ad)

func _on_user_earned_reward(item: RewardedItem) -> void:
	#print("User earned reward: ", item.amount, " ", item.type)
	rewarded_earned.emit(item.type, item.amount)

func _create_content_callback() -> FullScreenContentCallback:
	var callback := FullScreenContentCallback.new()
	
	callback.on_ad_clicked = func() -> void:
		print("Rewarded ad clicked")
	
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		print("Rewarded ad dismissed")
		rewarded_ad_dismissed.emit()
		_rewarded_ad = null
		# Load next ad for future use
		load_rewarded_ad()
	
	callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		print("Failed to show rewarded ad: ", error.message)
		rewarded_ad_failed_to_show.emit(error.message)
		_rewarded_ad = null
	
	callback.on_ad_impression = func() -> void:
		print("Rewarded ad impression recorded")
		rewarded_ad_shown.emit()
	
	callback.on_ad_showed_full_screen_content = func() -> void:
		print("Rewarded ad showed")
	
	return callback
