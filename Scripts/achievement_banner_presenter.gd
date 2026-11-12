extends Node

## Shows an "Achievement Unlocked!" banner during a run for every achievement
## completed, one at a time, and never while a wave banner is on screen.
## Created by world.gd as a child of the run's HUD CanvasLayer; banners are
## added next to it.

const BANNER_SCENE: PackedScene = preload("res://Scenes/HUD/achievement_banner.tscn")

# Each entry: { "id": String, "frame": int (process frame it was queued on) }
var _queue: Array[Dictionary] = []
var _current_banner: Node = null


func _ready() -> void:
	AchievementManager.achievement_completed.connect(_on_achievement_completed)


func _on_achievement_completed(achievement_id: String) -> void:
	_queue.append({ "id": achievement_id, "frame": Engine.get_process_frames() })


func _process(_delta: float) -> void:
	if _queue.is_empty() or is_instance_valid(_current_banner):
		return

	# Wait one frame after queueing: a wave banner requested on the same frame is
	# added deferred, so it only shows up in the group on the next frame.
	if Engine.get_process_frames() <= int(_queue[0]["frame"]):
		return

	if get_tree().get_first_node_in_group(WaveHeading.GROUP) != null:
		return

	var achievement: Dictionary = AchievementManager.get_achievement(_queue.pop_front()["id"])
	if achievement.is_empty():
		return

	_current_banner = BANNER_SCENE.instantiate()
	get_parent().add_child(_current_banner)
	_current_banner.setup(achievement["title"], achievement["reward"])
	_current_banner.play()
