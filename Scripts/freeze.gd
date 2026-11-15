class_name Freeze
extends Timer

## Freezes an enemy: stops it, pauses its keyframed animation (if it has one;
## enemies 1 and 4 bob in their shader, which the freeze material replaces) and
## tints it icy until the time runs out. One per enemy; freezing it again adds
## time (add_duration). Counting down as a Timer replaces a per-frame check, and
## it stops with the enemy (paused game, dying enemy) just like that check did.

var duration: float = 2.0
@onready var parent: CharacterBody2D = get_parent()
@onready var m: Dictionary = parent.marks
@onready var wrapper: Node2D = parent.avatarWrapper
@onready var wrapperChildren: Array[Node] = wrapper.get_children()
var actualSpeed: float = -1.0
var actualAnimSpeedScale: float = -1.0
var ap: AnimationPlayer = null
var freezeMarkCount: int = 1
var wrapperUsedParentMaterial: bool = false
var wrapperMaterial: Material = null


func setup(durationToStayFrozen: float) -> void:
	duration = durationToStayFrozen


func handle_exit() -> void:
	# Put back the wrapper's own material (the enemy shader, or the boss one).
	wrapper.material = wrapperMaterial
	wrapper.use_parent_material = wrapperUsedParentMaterial
	parent.followSpeed = actualSpeed
	if ap:
		ap.speed_scale = actualAnimSpeedScale
	if parent.freezeEffect == self:
		parent.freezeEffect = null
	queue_free()
	
	if m.freeze == freezeMarkCount:
		m.erase('freeze')
		return
	m.freeze -= freezeMarkCount 


func add_duration(amount: float) -> void:
	duration += amount
	start(time_left + amount)
	freezeMarkCount += 1


func _ready() -> void:
	# The wrapper must use its own material, otherwise it inherits its parent's
	# material and the freeze shader assigned below is ignored.
	wrapperUsedParentMaterial = wrapper.use_parent_material
	wrapperMaterial = wrapper.material
	wrapper.use_parent_material = false
	
	for child in wrapperChildren:
		child.use_parent_material = true
	
	wrapper.material = global.FREEZE_SHADER_MATERIAL
	actualSpeed = parent.followSpeed
	parent.followSpeed = 0.0
	
	m = parent.marks
	if m.has("freeze"):
		m.freeze += 1
	else:
		m['freeze'] = 1
	
	ap = parent.get("animationPlayer")
	if ap:
		actualAnimSpeedScale = ap.speed_scale
		ap.speed_scale = 0.0

	AchievementManager.register_frozen_count_changed(1)
	timeout.connect(handle_exit)
	start(duration)


func _exit_tree() -> void:
	AchievementManager.register_frozen_count_changed(-1)
