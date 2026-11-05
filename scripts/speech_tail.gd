@tool
extends Control

@export var curved := false
@export_range(-1.0, 2.0) var tip_fraction := 0.28:
	set(value):
		tip_fraction = value
		queue_redraw()

func _draw() -> void:
	var fill := Color("fffaf0")
	var edge := Color("b89acc")
	if curved:
		var tip := Vector2(size.x * tip_fraction, size.y)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in 21:
			var t := float(i) / 20.0
			left.append(Vector2.ZERO.bezier_interpolate(Vector2(0, size.y * 0.45), tip + Vector2(1, -5), tip, t))
			right.append(Vector2(size.x, 0).bezier_interpolate(Vector2(size.x * 0.8, size.y * 0.65), tip + Vector2(10, -1), tip, t))
		var shape := left.duplicate()
		for i in range(right.size() - 1, -1, -1):
			shape.append(right[i])
		draw_colored_polygon(shape, fill)
		draw_polyline(left, edge, 1.5, true)
		draw_polyline(right, edge, 1.5, true)
		return
	var triangle := PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x * tip_fraction, size.y)
	])
	draw_colored_polygon(triangle, fill)
	draw_line(triangle[0], triangle[2], edge, 1.5, true)
	draw_line(triangle[2], triangle[1], edge, 1.5, true)
