@tool
extends Node2D
## Keep the exact original toes in front during the brief rise. Upper legs and
## coat remain behind the sprite, so they cannot paint across its white hem.

const RIG = preload("res://scripts/cat_walk_rig.gd")
const TOE_TOP := 138.0

@onready var source_rig: Node2D = get_node_or_null("../CatWalkRig")
var toe_polygons: Array = []


func _ready() -> void:
	var toe_band := PackedVector2Array([
		Vector2(0, TOE_TOP), Vector2(128, TOE_TOP),
		Vector2(128, 152), Vector2(0, 152)])
	for source in [RIG.FAR_LEG, RIG.NEAR_LEG]:
		toe_polygons.append(Geometry2D.intersect_polygons(
			PackedVector2Array(source), toe_band))
	queue_redraw()


func _draw() -> void:
	if source_rig == null:
		return
	var feet: Array[Vector2] = source_rig.call("foot_positions")
	for index in 2:
		draw_set_transform(feet[index] - RIG.BIND_FEET[index])
		for polygon: PackedVector2Array in toe_polygons[index]:
			var uv := PackedVector2Array()
			for point in polygon:
				uv.append(point / Vector2(128, 152))
			draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, RIG.ART)
	draw_set_transform(Vector2.ZERO)
