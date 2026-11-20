extends Node
## AdMob Manager for handling rewarded ads in the game
## Initialize this by calling: AdMobManager.initialize()
##
## Consent first: before any ad is requested, Google's User Messaging Platform
## checks whether this player must be asked (EEA and UK players, as set up under
## AdMob > Privacy & messaging) and shows the consent form if so. AdMob then
## follows the player's choice by itself. Players who were asked can change their
## choice later from Settings (has_ad_choices / show_ad_choices).
##
## These are the real IDs. Phones registered as test devices (AdMob > Settings >
## Test devices, or TEST_DEVICE_IDS below) still get only test ads, so never tap
## real ads on your own phones or ask testers to.


const REWARDED_AD_UNIT_ID_ANDROID = "ca-app-pub-3940256099942544/5224354917"  # Test ID
const REWARDED_AD_UNIT_ID_IOS = "ca-app-pub-3940256099942544/1712485313"      # Test ID (no iOS app yet)

# Extra test devices, by the ID AdMob prints in Logcat. Devices registered in
# the AdMob console don't need to be listed here.
const TEST_DEVICE_IDS: Array[String] = []

var _rewarded_ad: RewardedAd = null
var _rewarded_ad_loader: RewardedAdLoader = null
var _is_loading = false
var _is_initialized = false
var _ads_started := false
# Wait before the next load attempt after a failure (offline, no ad to show).
# Grows after each failure so a phone without internet isn't asked to load an
# ad every second for the whole session.
const RETRY_DELAY_MIN := 15.0
const RETRY_DELAY_MAX := 300.0
var _retry_delay := RETRY_DELAY_MIN
var _retry_timer: SceneTreeTimer = null

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
	_request_consent()



## True when this player was asked for ad consent (EEA/UK) and can change it.
func has_ad_choices() -> bool:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	return status == ConsentInformation.ConsentStatus.OBTAINED 		or status == ConsentInformation.ConsentStatus.REQUIRED


## Shows Google's consent form again so the player can change their choice.
func show_ad_choices() -> void:
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm): form.show(func(_error): pass),
		func(error: FormError): push_warning("Consent form failed to load: %s" % error.message))


# --- Consent ------------------------------------------------------------------

func _request_consent() -> void:
	# Without the consent part of the plugin the callbacks below would never come.
	if not Engine.has_singleton("PoingGodotAdMobConsentInformation") \
			or not Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform"):
		push_warning("UMP plugin missing; starting ads without a consent check")
		_start_ads()
		return
	var params := ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(params,
		_on_consent_info_updated,
		func(error: FormError):
			# Offline or similar: carry on. AdMob uses the choice saved last time.
			push_warning("Consent info update failed: %s" % error.message)
			_start_ads())


func _on_consent_info_updated() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() != ConsentInformation.ConsentStatus.REQUIRED 			or not info.get_is_consent_form_available():
		_start_ads()
		return
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm): form.show(func(_error): _start_ads()),
		func(error: FormError):
			push_warning("Consent form failed to load: %s" % error.message)
			_start_ads())


## Starts the Mobile Ads SDK once consent has been dealt with.
func _start_ads() -> void:
	if _ads_started:
		return
	_ads_started = true

	# Configure request settings
	var request_config := RequestConfiguration.new()
	request_config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	if not TEST_DEVICE_IDS.is_empty():
		request_config.test_device_ids = TEST_DEVICE_IDS
	
	MobileAds.set_request_configuration(request_config)
	
	# Initialize MobileAds
	var on_init_listener := OnInitializationCompleteListener.new()
	on_init_listener.on_initialization_complete = _on_initialization_complete
	
	MobileAds.initialize(on_init_listener)

## Load a rewarded ad
func load_rewarded_ad() -> void:
	if _is_loading or _rewarded_ad != null or not _ads_started:
		return
	
	_retry_timer = null
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

## Loads an ad now instead of waiting for the next retry (the player asked for one).
func retry_now() -> void:
	if _retry_timer != null:
		_retry_timer = null
		_retry_delay = RETRY_DELAY_MIN
		load_rewarded_ad()

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
	load_rewarded_ad()

func _on_rewarded_ad_loaded(ad: RewardedAd) -> void:
	_rewarded_ad = ad
	_is_loading = false
	_retry_delay = RETRY_DELAY_MIN
	rewarded_ad_loaded.emit()

func _on_rewarded_ad_failed_to_load(error: LoadAdError) -> void:
	_is_loading = false
	rewarded_ad_failed_to_load.emit(error.message)
	_schedule_retry()


func _schedule_retry() -> void:
	var timer := get_tree().create_timer(_retry_delay, true, false, true)
	_retry_timer = timer
	_retry_delay = minf(_retry_delay * 2.0, RETRY_DELAY_MAX)
	timer.timeout.connect(func():
		if _retry_timer == timer: # not already retried by retry_now()
			load_rewarded_ad())

func _on_user_earned_reward(item: RewardedItem) -> void:
	rewarded_earned.emit(item.type, item.amount)

func _create_content_callback() -> FullScreenContentCallback:
	var callback := FullScreenContentCallback.new()
	
	callback.on_ad_dismissed_full_screen_content = func() -> void:
		rewarded_ad_dismissed.emit()
		_rewarded_ad = null
		# Load next ad for future use
		load_rewarded_ad()
	
	callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		rewarded_ad_failed_to_show.emit(error.message)
		_rewarded_ad = null
		load_rewarded_ad()
	
	callback.on_ad_impression = func() -> void:
		rewarded_ad_shown.emit()

	return callback
