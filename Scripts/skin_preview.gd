extends SubViewportContainer
## Live preview of Echo wearing a skin shader: a real avatar playing its idle
## animation inside a transparent SubViewport. Scales to fit whatever size
## the container is given.

const AVATAR_SCENE: PackedScene = preload("res://Scenes/Players/spriteand_player_animations.tscn")
## Avatar height in its own units (head top to feet) and where its origin sits.
const AVATAR_HEIGHT: float = 150.0
const AVATAR_ORIGIN_FROM_TOP: float = 0.8
## Fraction of the preview's height the avatar fills.
const FILL: float = 0.78

var _viewport: SubViewport
var _avatar: Node2D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.handle_input_locally = false
	add_child(_viewport)


func setup(shader: Shader, animation: String = "idle") -> void:
	_avatar = AVATAR_SCENE.instantiate()
	# The in-game script needs the World scene; the preview only needs the art.
	_avatar.set_script(null)
	# A fresh material: the scene's own material is shared between instances.
	var material := ShaderMaterial.new()
	material.shader = shader
	_avatar.material = material
	_viewport.add_child(_avatar)
	_avatar.get_node("AnimationPlayer").play(animation)
	resized.connect(_fit_avatar)
	_fit_avatar()


func _fit_avatar() -> void:
	if _avatar == null or size.y <= 0.0:
		return
	var s: float = size.y * FILL / AVATAR_HEIGHT
	_avatar.scale = Vector2(s, s)
	var top_gap: float = size.y * (1.0 - FILL) * 0.5
	_avatar.position = Vector2(size.x * 0.5, top_gap + AVATAR_HEIGHT * AVATAR_ORIGIN_FROM_TOP * s)
