class_name Freeze
extends Node

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


func setup(durationToStayFrozen: float) -> void:
	duration = durationToStayFrozen


func handle_exit() -> void:
	wrapper.material = null
	wrapper.use_parent_material = wrapperUsedParentMaterial
	parent.followSpeed = actualSpeed
	ap.speed_scale = actualAnimSpeedScale
	queue_free()
	
	if m.freeze == freezeMarkCount:
		m.erase('freeze')
		return
	m.freeze -= freezeMarkCount 


func add_duration(amount: float) -> void:
	duration += amount
	freezeMarkCount += 1


func _ready() -> void:
	# The wrapper must use its own material, otherwise it inherits its parent's
	# material and the freeze shader assigned below is ignored.
	wrapperUsedParentMaterial = wrapper.use_parent_material
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
	
	ap = parent.animationPlayer
	actualAnimSpeedScale = ap.speed_scale
	ap.speed_scale = 0.0

	AchievementManager.register_frozen_count_changed(1)


func _exit_tree() -> void:
	AchievementManager.register_frozen_count_changed(-1)


var x: float = 0.0
func _process(delta: float) -> void:
	x += delta
	if x >= duration:
		handle_exit()
