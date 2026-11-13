extends RefCounted
## Echo skins sold in the Shop. Each one is a shader in res://Shaders/Skins/
## applied to the avatar's parent material.

const SKINS: Array[Dictionary] = [
	{
		"id": "ember_warden",
		"name": "Ember Warden",
		"shader": "res://Shaders/Skins/skin_ember_warden.gdshader",
		"price": 2500,
	},
	{
		"id": "frostbound",
		"name": "Frostbound",
		"shader": "res://Shaders/Skins/skin_frostbound.gdshader",
		"price": 2500,
	},
	{
		"id": "voidwalker",
		"name": "Voidwalker",
		"shader": "res://Shaders/Skins/skin_voidwalker.gdshader",
		"price": 2500,
	},
]

## Echo's original look. Always owned, not sold, and has no shader.
const DEFAULT_SKIN: Dictionary = {
	"id": "default",
	"name": "Default",
	"shader": "",
	"price": 0,
}


## Any skin by id, including the default. Empty if unknown.
static func get_skin(skin_id: String) -> Dictionary:
	if skin_id == DEFAULT_SKIN["id"]:
		return DEFAULT_SKIN
	for skin: Dictionary in SKINS:
		if skin["id"] == skin_id:
			return skin
	return {}


## The skin's shader, or null for the default look.
static func load_shader(skin_id: String) -> Shader:
	var path: String = get_skin(skin_id).get("shader", "")
	return load(path) if path != "" else null
