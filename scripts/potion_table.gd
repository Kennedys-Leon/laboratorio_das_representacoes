@tool
extends Control
## Perspective workbench: broad top, inset rear supports, no lower crossbar.

@export var short_legs := false:
	set(value):
		short_legs = value
		queue_redraw()


func _draw() -> void:
	var ink := Color("291525")
	var rear_floor := 242.0 if short_legs else 258.0
	var front_floor := 249.0 if short_legs else 269.0
	# Rear supports stand farther inward and end higher in the perspective.
	for x in [35.0, 179.0]:
		draw_style_box(_wood_box(ink, Color("643622"), 3), Rect2(x, 210, 16, rear_floor - 210))
		draw_rect(Rect2(x + 3, 216, 8, rear_floor - 219), Color("7e4428"))
		draw_line(Vector2(x + 11, 216), Vector2(x + 11, rear_floor - 3), Color("47262a"), 2.0)
	# Front supports have a lit front face and a shaded inner face.
	for x in [0.0, 207.0]:
		draw_style_box(_wood_box(ink, Color("9b542e"), 3), Rect2(x, 225, 23, front_floor - 225))
		draw_rect(Rect2(x + 4, 230, 4, front_floor - 234), Color("c58048"))
		draw_rect(Rect2(x + 17, 230, 3, front_floor - 233), Color("623421"))
	# A real top plane separates the back row of bottles from the front edge.
	var top := PackedVector2Array([Vector2(0, 176), Vector2(216, 176), Vector2(239, 215), Vector2(-23, 215)])
	draw_colored_polygon(top, Color("c57b48"))
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), ink, 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(3, 178), Vector2(213, 178), Vector2(231, 211), Vector2(-15, 211)]), Color("d68d54"))
	draw_line(Vector2(-15, 212), Vector2(231, 212), Color("f0b77c"), 2.0, true)
	for grain in [Vector4(11, 183, 78, 183), Vector4(147, 183, 211, 183), Vector4(-6, 208, 54, 208), Vector4(170, 209, 227, 209)]:
		draw_line(Vector2(grain.x, grain.y), Vector2(grain.z, grain.w), Color("bb7040"), 1.0, true)
	# Soft contact marks lie on the surface under the fixed bottles.
	for center in [37.0, 191.0]:
		var ellipse := PackedVector2Array()
		for i in 32:
			var angle := TAU * float(i) / 32.0
			ellipse.append(Vector2(center + cos(angle) * 23.0, 201.5 + sin(angle) * 2.7))
		draw_colored_polygon(ellipse, Color(0.22, 0.09, 0.10, 0.24))
	# Rounded front apron, closer and lighter than the rear supports.
	draw_style_box(_wood_box(ink, Color("a85c35"), 3), Rect2(-23, 214, 262, 18))
	draw_line(Vector2(-19, 217), Vector2(235, 217), Color("d99157"), 2.0, true)
	draw_line(Vector2(-18, 228), Vector2(234, 228), Color("7e402b"), 1.0, true)


func _wood_box(edge: Color, fill: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
