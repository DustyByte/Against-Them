extends VBoxContainer
## Example usage of RewardedAdButton in your game
## This demonstrates how to integrate rewarded ads into your UI

class_name RewardedAdExample

@onready var reward_button: RewardedAdButton = $RewardedAdButton
@onready var status_label: Label = $StatusLabel
@onready var reward_count_label: Label = $RewardCountLabel

var total_rewards_earned: int = 0

func _ready() -> void:
	# Configure the reward button
	reward_button.button_text = "Free Reward"
	reward_button.ready_text = "Watch Ad for 100 Gold"
	reward_button.loading_text = "Loading Ad..."
	
	# Set the reward callback
	reward_button.reward_callback = _on_ad_reward_earned
	
	# Connect to AdMobManager signals for monitoring
	AdMobManager.rewarded_ad_loaded.connect(_on_ad_loaded)
	AdMobManager.rewarded_ad_failed_to_load.connect(_on_ad_failed_to_load)
	AdMobManager.rewarded_ad_dismissed.connect(_on_ad_dismissed)
	AdMobManager.rewarded_ad_failed_to_show.connect(_on_ad_failed_to_show)
	
	_update_status("Ready for ads")
	_update_reward_count()

## Called when the user earns a reward
func _on_ad_reward_earned(reward_type: String, reward_amount: int) -> void:
	total_rewards_earned += 1
	_update_status("Reward earned: %d %s" % [reward_amount, reward_type])
	_update_reward_count()
	
	# Here you would add game logic to grant the reward
	# Example: global.player_gold += 100

## Called when ad successfully loads
func _on_ad_loaded() -> void:
	_update_status("Ad loaded and ready!")

## Called when ad fails to load
func _on_ad_failed_to_load(error: String) -> void:
	_update_status("Failed to load ad: %s" % error)

## Called when user closes/dismisses the ad
func _on_ad_dismissed() -> void:
	_update_status("Ad dismissed - watch another!")

## Called when ad fails to show
func _on_ad_failed_to_show(error: String) -> void:
	_update_status("Failed to show ad: %s" % error)

## Update the status display
func _update_status(message: String) -> void:
	status_label.text = message

## Update the reward counter display
func _update_reward_count() -> void:
	reward_count_label.text = "Total Rewards Earned: %d" % total_rewards_earned
