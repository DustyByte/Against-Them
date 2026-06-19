class_name OptionDisplay
extends Node2D

@export_range(0.0, 1.0, 0.001) var entireDisplaySizeRatioX: float = 0.6
@export_range(0.0, 1.0, 0.001) var entireDisplaySizeRatioY: float = 0.75
var iconHolder: HBoxContainer = null
var buttonHolder: HBoxContainer = null
var cardDisplay: Panel = null
var nameLabel: Label = null
var descriptionLabel: Label = null
var unlocksHeaderLabel: Label = null
var wouldGetUnlockedGrid: GridContainer = null
var optionIconBP: PackedScene = preload("res://Scenes/HUD/option_icon.tscn")
var currentlySelectedOption: Option = null
var on_select: Callable = func():
	pass


func _set_card_display_internals() -> void:
	var cardDisplaySize: Vector2 = cardDisplay.size
	var topMargin: float = cardDisplaySize.y*0.2
	var leftMargin: float = topMargin
	
	nameLabel.position = Vector2(leftMargin, topMargin)
	nameLabel.size.x = (cardDisplaySize.x-leftMargin*2.0)*0.55
	
	var textInbetweenMargin: float = 64.0
	
	descriptionLabel.position = Vector2(leftMargin, topMargin + nameLabel.size.y + textInbetweenMargin)
	descriptionLabel.size.x = (cardDisplaySize.x-leftMargin*2.0)*0.55
	
	unlocksHeaderLabel.position = Vector2(leftMargin + (cardDisplaySize.x-leftMargin*2.0)*0.65, nameLabel.position.y)
	
	wouldGetUnlockedGrid.position = Vector2(unlocksHeaderLabel.position.x, descriptionLabel.position.y)


func present_options(options: Array[Option]) -> void:
	for oIcon in iconHolder.get_children():
		oIcon.queue_free()
		
	for option in options:
		var oIcon: OptionIcon = optionIconBP.instantiate()
		
		oIcon.set_option(option)
		iconHolder.add_child(oIcon)
		oIcon.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.is_pressed():
				into_display_inject_option(option)
				
				global.WORLD.audio_play(preload("res://Assets/SFX/UI.mp3"), "ui", randf_range(0.8, 1.2))
		)
	
	into_display_inject_option(options[0])


func into_display_inject_option(option: Option) -> void:
	currentlySelectedOption = option
	nameLabel.text = option.name
	descriptionLabel.text = option.description
	
	var existingPreviewNodes: Array[Node] = wouldGetUnlockedGrid.get_children()
	for node in existingPreviewNodes:
		node.queue_free()
	
	for child in option.children:
		var oIconChildPrev: OptionIcon = optionIconBP.instantiate()
		oIconChildPrev.set_option(child)
		wouldGetUnlockedGrid.add_child(oIconChildPrev)


func into_display_inject_child_preview(childOption: Option) -> void:
	nameLabel.text = childOption.name
	descriptionLabel.text = childOption.description


func into_display_remove_child_preview() -> void:
	nameLabel.text = currentlySelectedOption.name
	descriptionLabel.text = currentlySelectedOption.description


func _handle_select_button_tap(event: InputEvent) ->  void:
	if event is InputEventScreenTouch and event.is_pressed():
		global.WORLD.audio_play(preload("res://Assets/SFX/UIReturn.wav"), "ui")
		
		on_select.call(currentlySelectedOption)
		queue_free()


func _ready() -> void:
	iconHolder = $OptionIconHolder
	buttonHolder = $Buttons
	cardDisplay = $CardDisplay
	nameLabel = $CardDisplay/Name
	descriptionLabel = $CardDisplay/Description
	unlocksHeaderLabel = $CardDisplay/UnlocksHeader
	wouldGetUnlockedGrid = $CardDisplay/GridContainer
	
	var screenWindowDim: Vector2 = get_viewport_rect().size
	var entireDisplaySize: Vector2 = screenWindowDim * Vector2(entireDisplaySizeRatioX, entireDisplaySizeRatioY)
	
	position = screenWindowDim*0.5
	
	var iconHolderSize: Vector2 = Vector2(entireDisplaySize.x, 132.0) #132.0 might change it to scalable.
	var iconHolderPos: Vector2 = Vector2(-iconHolderSize.x*0.5, -entireDisplaySize.y*0.5)
	iconHolder.size = iconHolderSize
	iconHolder.position = iconHolderPos
	
	var buttonHolderSize: Vector2 = Vector2(entireDisplaySize.x, 96.0) # 96.0 might change it to scalable.
	var buttonHolderPos: Vector2 = Vector2(-buttonHolderSize.x*0.5, entireDisplaySize.y*0.5 - buttonHolderSize.y)
	buttonHolder.size = buttonHolderSize 
	buttonHolder.position = buttonHolderPos
	
	var cardDisplayPos: Vector2 = iconHolderPos + Vector2(0.0, iconHolderSize.y + 50.0)
	var cardDisplaySize: Vector2 = Vector2(entireDisplaySize.x, buttonHolderPos.y - cardDisplayPos.y - 50.0)
	cardDisplay.size = cardDisplaySize
	cardDisplay.position = cardDisplayPos
	
	_set_card_display_internals()


var fingerInside: int = 0
var prevFrameFingerInside: int = 0
var fingerIndex: int = 0
func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or event is InputEventScreenTouch:
		prevFrameFingerInside = fingerInside
		
		if event is InputEventScreenTouch and not event.pressed and event.index == fingerIndex:
			fingerInside = 0
			into_display_remove_child_preview()
			return
		
		var nodes: Array[Node] = wouldGetUnlockedGrid.get_children()
		for i in range(nodes.size()):
			var node: OptionIcon = nodes[i]
			var nodeRect: Rect2 = Rect2(node.global_position, node.get_rect().size * Vector2(0.65, 0.65))
			var isEventInsideNode: bool = nodeRect.has_point(event.position)
			
			if isEventInsideNode:
				fingerInside = i+1
				break
			else:
				fingerInside = 0
		
		if prevFrameFingerInside != fingerInside:
			if fingerInside == 0:
				into_display_remove_child_preview()
			else:
				into_display_inject_child_preview(nodes[fingerInside - 1].holdingOption)
