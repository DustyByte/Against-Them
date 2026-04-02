class_name Exp
extends Area2D

var expAmount: float = 0
var color: Color
var isPickedUp: bool = false
var id: int = -1
var expDropMMIRID: RID = RID()


func set_exp_type(givenExpType: Dictionary) -> void:
	expAmount = givenExpType.expAmount
	color = givenExpType.color


func handle_mm_to_cpu_migration() -> void:
	var oldId: int = id
	id = global.WORLD.get_exp_latest_id(oldId)
	global.WORLD.remove_exp_id_lifetrack(oldId)
	
	var mmXform: Transform2D = RenderingServer.multimesh_instance_get_transform_2d(expDropMMIRID, id)
	RenderingServer.multimesh_instance_set_transform_2d(expDropMMIRID, id, mmXform.scaled(Vector2.ZERO))
	
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = global.EXP_DROP_POLYGON_ARRAY
	polygon.color = color
	add_child(polygon)


func _ready() -> void: 
	expDropMMIRID = global.WORLD.expDropMMI.multimesh.get_rid()
	
	if RenderingServer.multimesh_get_visible_instances(expDropMMIRID) == RenderingServer.multimesh_get_instance_count(expDropMMIRID):
		global.WORLD.clean_expdropmm()
	
	id = RenderingServer.multimesh_get_visible_instances(expDropMMIRID)
	RenderingServer.multimesh_set_visible_instances(expDropMMIRID, id + 1)
	RenderingServer.multimesh_instance_set_transform_2d(expDropMMIRID, id, Transform2D(0.78539816339, global_position))
	RenderingServer.multimesh_instance_set_color(expDropMMIRID, id, color)
