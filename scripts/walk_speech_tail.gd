@tool
extends Control

func _draw() -> void:
	var fill := Color("fffaf0")
	var edge := Color("b89acc")
	var start := Vector2(0, 0)
	var upper := Vector2(39, 0)
	var tip := Vector2(size.x, size.y)
	var shape := PackedVector2Array([start, upper, tip])
	draw_colored_polygon(shape, fill)
	draw_line(start, tip, edge, 1.5, true)
	draw_line(tip, upper, edge, 1.5, true)
