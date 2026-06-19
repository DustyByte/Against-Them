# AdMob Rewarded Ads - Quick Reference

## Quick Start

### 1. Basic Setup (Already Done)
- ✅ AdMobManager autoload registered in project.godot
- ✅ AdMob initialization in global.gd
- ✅ RewardedAdButton component available
- ✅ Test ad unit IDs configured

### 2. Add to Your Game (Next Steps)

#### Add Button to UI Scene
```gdscript
# Simple way - add button to your scene and attach RewardedAdButton script
extends Control

func _ready():
	# The button will automatically:
	# - Load ads on startup
	# - Show "Loading..." while ads load
	# - Show "Watch Ad" when ready
	# - Emit signals when rewards are earned
	pass
```

#### Listen for Rewards
```gdscript
extends Node

func _ready():
	AdMobManager.rewarded_earned.connect(_on_reward)

func _on_reward(reward_type: String, reward_amount: int):
	print("Got reward: %d %s" % [reward_amount, reward_type])
	# Add your game logic here
```

## Common Use Cases

### Use Case 1: Double Rewards Button

```gdscript
extends Button

func _ready():
	pressed.connect(_on_pressed)
	AdMobManager.rewarded_earned.connect(_on_reward_earned)

func _on_pressed():
	AdMobManager.show_rewarded_ad()

func _on_reward_earned(reward_type: String, reward_amount: int):
	# Double current round rewards
	global.current_round_rewards *= 2
```

### Use Case 2: Revive System

```gdscript
extends Node

func player_died():
	if AdMobManager.is_rewarded_ad_ready():
		print("Ad ready - offer revive!")
		AdMobManager.show_rewarded_ad()
		AdMobManager.rewarded_earned.connect(_on_revive_reward)

func _on_revive_reward(reward_type: String, reward_amount: int):
	player.revive()
	player.health = player.max_health
```

### Use Case 3: Extra Lives Button

```gdscript
extends Button

var extra_lives: int = 0

func _ready():
	pressed.connect(_on_extra_lives_requested)
	AdMobManager.rewarded_earned.connect(_on_lives_earned)

func _on_extra_lives_requested():
	if AdMobManager.is_rewarded_ad_ready():
		AdMobManager.show_rewarded_ad()

func _on_lives_earned(reward_type: String, reward_amount: int):
	extra_lives += 1
	update_ui()
```

### Use Case 4: In-Game Shop

```gdscript
extends Control

func _ready():
	AdMobManager.rewarded_earned.connect(_on_premium_currency_earned)

func _on_premium_currency_earned(reward_type: String, reward_amount: int):
	# Give premium currency for watching ads
	global.premium_currency += 50
	update_shop_display()
```

## Configuration by Reward Type

The reward system can use different reward types. Check your AdMob console settings.

```gdscript
func _on_reward_earned(reward_type: String, reward_amount: int):
	match reward_type:
		"gold":
			player.add_gold(reward_amount)
		"gems":
			player.add_gems(reward_amount)
		"xp":
			player.add_xp(reward_amount)
		_:
			print("Unknown reward type: %s" % reward_type)
```

## Managing Ad Load State

```gdscript
# Check if ad is ready before showing
if AdMobManager.is_rewarded_ad_ready():
	AdMobManager.show_rewarded_ad()
else:
	print("Ad not ready yet")
	# Optional: preload ad
	AdMobManager.load_rewarded_ad()

# Wait for ad to load before showing
func show_ad_when_ready():
	while not AdMobManager.is_rewarded_ad_ready():
		await get_tree().process_frame
	
	AdMobManager.show_rewarded_ad()
```

## Ad Lifecycle

```gdscript
# Typical ad lifecycle:

# 1. Ad loads
AdMobManager.rewarded_ad_loaded  # ← Signal fired

# 2. User clicks button
AdMobManager.show_rewarded_ad()

# 3. Ad shows
AdMobManager.rewarded_ad_shown  # ← Signal fired

# 4. User watches and completes
AdMobManager.rewarded_earned  # ← Signal fired with reward

# 5. User dismisses or completes
AdMobManager.rewarded_ad_dismissed  # ← Signal fired

# 6. Next ad loads automatically
# Repeat from step 1
```

## Debugging

```gdscript
# Check initialization status
var status = MobileAds.get_initialization_status()
print("AdMob initialized: ", status)

# Manual loading with error tracking
var loader = RewardedAdLoader.new()
var callback = RewardedAdLoadCallback.new()

callback.on_ad_loaded = func(ad: RewardedAd):
	print("Ad loaded successfully!")

callback.on_ad_failed_to_load = func(error: LoadAdError):
	print("Ad failed to load: ", error.message)
	print("Error code: ", error.code)

loader.load("YOUR_AD_UNIT_ID", AdRequest.new(), callback)
```

## Testing Checklist

- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test ad loading
- [ ] Test ad showing
- [ ] Test reward earning
- [ ] Test with poor network
- [ ] Test quick successive clicks
- [ ] Verify rewards are properly applied

## Platform-Specific Notes

### Android
- Requires Google Play Services
- Test ads available via Google's test app
- Device ID can be found in Logcat

### iOS
- Requires proper provisioning
- Test ads available on test devices
- Device ID from console logs

## Next Steps

1. **Get Production Ad IDs** from AdMob Console
2. **Replace Test IDs** in `Scripts/admob_manager.gd`
3. **Add UI Elements** using RewardedAdButton
4. **Test on Real Devices** with test IDs
5. **Deploy** with production IDs

## Support

For issues:
1. Check console logs
2. Verify ad unit IDs
3. Check AdMob console for account status
4. Review the full setup guide in ADMOB_SETUP_GUIDE.md
