class_name Option

var name: String = ""
var description: String = ""
var modifiers: Dictionary = {}
var isAvailable: bool = false
var isForceDeactivated: bool = false
var children: Array[Option] = []
var iconPath: String = "res://icon.svg"
var hierarchyMark: String = ""


func _init(givenName: String, givenModifiers: Dictionary, givenDescription: String, givenHierarchyMark: String, givenIconPath: String, initAsAvailable = false) -> void:
	name = givenName
	modifiers = givenModifiers
	description = givenDescription
	isAvailable = initAsAvailable
	iconPath = givenIconPath
	hierarchyMark = givenHierarchyMark


func augment_child(childToAugment: Option) -> void:
	children.append(childToAugment)


func augment_children(childrenToAugment: Array[Option]) -> void:
	children += childrenToAugment


func make_immediate_children_available() -> void:
	for child in children:
		child.isAvailable = not isForceDeactivated


func duplicate_deep() -> Option:
	var option: Option = Option.new('', {}, '', '', "")
	var duplicatedChildren : Array[Option] = []
	
	option.name = name
	option.description = description
	option.iconPath = iconPath
	option.hierarchyMark = hierarchyMark
	option.modifiers = modifiers.duplicate(true)
	option.isAvailable = isAvailable
	for child in children:
		duplicatedChildren.append(child.duplicate_deep())
	option.children = duplicatedChildren
	
	return option


func deactivate(force: bool = false) -> void:
	isAvailable = false
	isForceDeactivated = force


func _to_string() -> String:
	return name
