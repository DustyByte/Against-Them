class_name OptionIcon
extends TextureRect

var holdingOption: Option = null


func set_option(option: Option) -> void:
	holdingOption = option
	texture = load(option.iconPath)
	$Label.text = option.hierarchyMark
