# AdMob Rewarded Ads Integration Guide

This guide explains how to use the AdMob rewarded ads system that has been integrated into your "Against Them" project.

## Overview

The system consists of three main components:

1. **AdMobManager** (`Scripts/admob_manager.gd`) - Handles all AdMob operations
2. **RewardedAdButton** (`Scripts/rewarded_ad_button.gd`) - UI component for rewarded ads
3. **Global Initialization** - Automatic initialization via `global.gd`

## Setup Steps

### 1. Get Your Ad Unit IDs

1. Go to [Google AdMob Console](https://admob.google.com)
2. Create or select your app
3. Create new ad units for rewarded ads on Android and iOS
4. Copy your ad unit IDs

### 2. Update Ad Unit IDs

Open `Scripts/admob_manager.gd` and replace the test ad unit IDs with your real ones:

```gdscript
const REWARDED_AD_UNIT_ID_ANDROID = "YOUR_ANDROID_AD_UNIT_ID"
const REWARDED_AD_UNIT_ID_IOS = "YOUR_IOS_AD_UNIT_ID"
```

### 3. Add Test Device IDs (Optional)

If you want to test with real ads on your device:

```gdscript
const TEST_DEVICE_IDS = ["YOUR_DEVICE_ID_HERE"]
```

To find your device ID, run your app with a test ad and check the console logs.

## Usage

### Option 1: Add Rewarded Ad Button to UI

1. Create a Button node in your UI scene (or any Control node)
2. Attach the `RewardedAdButton` script to it
3. Configure in the Inspector:
   - **Button Text**: Default text shown
   - **Ready Text**: Text when ad is loaded and ready
   - **Loading Text**: Text while loading ad
   - **Reward Callback**: Optional callback function when reward is earned

Example:
```gdscript
# In your scene script
@onready var reward_button: RewardedAdButton = $RewardButton

func _ready() -> void:
	reward_button.reward_callback = _on_reward_earned

func _on_reward_earned(reward_type: String, reward_amount: int) -> void:
	print("Player earned: %d %s" % [reward_amount, reward_type])
	# Add your reward logic here
	player.add_coins(reward_amount)
```

### Option 2: Manual Control via AdMobManager

Use the global `AdMobManager` singleton for full control:

```gdscript
# Load an ad
AdMobManager.load_rewarded_ad()

# Check if ad is ready
if AdMobManager.is_rewarded_ad_ready():
	AdMobManager.show_rewarded_ad()

# Connect to signals
AdMobManager.rewarded_earned.connect(_on_reward_earned)
AdMobManager.rewarded_ad_dismissed.connect(_on_ad_dismissed)
```

## Available Signals

The `AdMobManager` emits the following signals:

- `rewarded_ad_loaded` - Ad successfully loaded
- `rewarded_ad_failed_to_load(error: String)` - Failed to load ad
- `rewarded_earned(reward_type: String, reward_amount: int)` - User earned reward
- `rewarded_ad_shown` - Ad impression recorded
- `rewarded_ad_dismissed` - User closed the ad
- `rewarded_ad_failed_to_show(error: String)` - Failed to show ad

## Available Methods

```gdscript
# Initialize AdMob (called automatically)
AdMobManager.initialize() -> void

# Load a rewarded ad
AdMobManager.load_rewarded_ad() -> void

# Show the loaded ad
AdMobManager.show_rewarded_ad() -> void

# Check if ad is ready
AdMobManager.is_rewarded_ad_ready() -> bool

# Destroy current ad
AdMobManager.destroy_rewarded_ad() -> void
```

## Testing

### Test Ad Unit IDs

Google provides test ad unit IDs for development:

- **Android**: `ca-app-pub-3940256099942544/5224354917`
- **iOS**: `ca-app-pub-3940256099942544/1712485313`

These are already configured in the code for testing.

### Testing Best Practices

1. Use test ad unit IDs during development
2. Add your device ID to `TEST_DEVICE_IDS` for testing
3. Never click ads repeatedly - this can get your account suspended
4. Use real ad unit IDs only when ready for production
5. Test on actual devices, not just the editor

## Implementation Example

Here's an example of adding a rewarded ad system to your main game UI:

```gdscript
# In your on_run_hud.gd or similar
extends Control

@onready var reward_button: Button = Button.new()

func _ready() -> void:
	reward_button.text = "Get Double Rewards"
	reward_button.pressed.connect(_on_reward_button_pressed)
	add_child(reward_button)
	
	AdMobManager.rewarded_earned.connect(_on_reward_earned)

func _on_reward_button_pressed() -> void:
	if AdMobManager.is_rewarded_ad_ready():
		AdMobManager.show_rewarded_ad()
	else:
		print("Ad not ready yet, loading...")
		AdMobManager.load_rewarded_ad()

func _on_reward_earned(reward_type: String, reward_amount: int) -> void:
	print("Double rewards earned!")
	# Apply reward logic
	player.add_experience(player.current_experience * 2)
```

## Platform Requirements

- **Android**: Requires Google Play Services to be properly configured
- **iOS**: Requires proper provisioning and configuration in Xcode

## Troubleshooting

### Ad doesn't load
- Check that ad unit IDs are correct
- Ensure you have internet connection
- Check that the app is built for the correct platform
- Verify AdMob setup in Google Console

### Ad shows but no reward
- Make sure the user completely watches the ad
- Check the `on_user_earned_reward` callback is connected
- Verify reward configuration in AdMob console

### Plugin not loading
- Check that `addons/admob/plugin.cfg` is enabled in project settings
- Verify Android/iOS export templates are installed
- Check console for specific error messages

## Production Checklist

Before going live:

- [ ] Replace test ad unit IDs with production IDs
- [ ] Remove test device IDs from `TEST_DEVICE_IDS`
- [ ] Test on real devices
- [ ] Verify rewards are working correctly
- [ ] Set appropriate ad frequency to avoid user frustration
- [ ] Add analytics to track reward redemption
- [ ] Configure consent for GDPR/CCPA if applicable

## Additional Resources

- [Google AdMob Documentation](https://admob.google.com/help/admob)
- [Godot AdMob Plugin GitHub](https://github.com/Poing-Studios/godot-admob-plugin)
- [Android Build Export Guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [iOS Build Export Guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
