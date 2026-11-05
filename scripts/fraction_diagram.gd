@tool
extends Control

signal selection_changed(count: int)

@export_range(2, 12, 1) var equal_parts := 4:
	set(value):
		equal_parts = value
		queue_redraw()
@export var marked_parts: PackedInt32Array = PackedInt32Array([0]):
	set(value):
		marked_parts = value
		queue_redraw()
@export_enum("circle", "square") var diagram_shape := "circle":
	set(value):
		diagram_shape = value
		queue_redraw()
@export var interactive := false:
	set(value):
		interactive = value
		queue_redraw()
@export var marked_color := Color("aa77e8"):
	set(value):
		marked_color = value
		queue_redraw()

var selected_parts := PackedInt32Array()
var selection_history: Array[PackedInt32Array] = []
var hovered_part := -1
var text_scale := 1.0


func reset_selection() -> void:
	selected_parts = PackedInt32Array()
	selection_history.clear()
	hovered_part = -1
	queue_redraw()
	selection_changed.emit(0)


func undo_selection() -> void:
	if selection_history.is_empty():
		return
	selected_parts = selection_history.pop_back()
	queue_redraw()
	selection_changed.emit(selected_parts.size())


func select_part(part: int) -> void:
	if not interactive or part < 0 or part >= equal_parts:
		return
	selection_history.append(selected_parts.duplicate())
	if selected_parts.has(part):
		selected_parts.remove_at(selected_parts.find(part))
	else:
		selected_parts.append(part)
	queue_redraw()
	selection_changed.emit(selected_parts.size())


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseMotion:
		var next_hover := _part_at(event.position)
		if next_hover != hovered_part:
			hovered_part = next_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var part := _part_at(event.position)
		if part >= 0:
			select_part(part)
			accept_event()


func _part_at(point: Vector2) -> int:
	var center := size / 2.0
	var extent := minf(size.x, size.y) * 0.43
	if diagram_shape == "square":
		var bounds := Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2.0)
		if not bounds.has_point(point):
			return -1
		var columns := 2 if equal_parts == 4 else equal_parts
		var rows := ceili(float(equal_parts) / columns)
		var cell := bounds.size / Vector2(columns, rows)
		return mini(equal_parts - 1, int((point.y - bounds.position.y) / cell.y) * columns + int((point.x - bounds.position.x) / cell.x))
	var direction := point - center
	if direction.length() > extent:
		return -1
	var angle := fposmod(direction.angle() + PI / 2.0, TAU)
	return mini(equal_parts - 1, int(floor(angle / TAU * equal_parts)))


func _draw() -> void:
	var center := size / 2.0
	var extent := minf(size.x, size.y) * 0.43
	if extent < 4.0:
		return
	if diagram_shape == "square":
		_draw_square(center, extent)
	else:
		_draw_circle_parts(center, extent)


func _part_color(part: int) -> Color:
	var filled := selected_parts.has(part) if interactive else marked_parts.has(part)
	if filled:
		return marked_color
	return Color("edf8dc") if interactive and hovered_part == part else Color("fffdf1")


func _draw_circle_parts(center: Vector2, radius: float) -> void:
	var outline := Color("241636")
	for part in range(equal_parts):
		var points := PackedVector2Array([center])
		for step in range(25):
			var angle := -PI / 2.0 + TAU * (part + float(step) / 24.0) / equal_parts
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, _part_color(part))
		var middle := -PI / 2.0 + TAU * (part + 0.5) / equal_parts
		var label_position := center + Vector2(cos(middle), sin(middle)) * radius * 0.66
		draw_string(get_theme_default_font(), label_position + Vector2(-6, 6), str(part + 1),
			HORIZONTAL_ALIGNMENT_CENTER, -1, roundi(17 * text_scale), Color.WHITE if selected_parts.has(part) and marked_color.v < 0.7 else outline)
	if equal_parts % 2 == 0:
		for boundary in int(equal_parts / 2):
			var angle := -PI / 2.0 + TAU * boundary / equal_parts
			var direction := Vector2(cos(angle), sin(angle)) * radius
			draw_line(center - direction, center + direction, outline, 2.7, true)
	else:
		for boundary in equal_parts:
			var angle := -PI / 2.0 + TAU * boundary / equal_parts
			draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius,
				outline, 2.7, true)
	draw_arc(center, radius, 0.0, TAU, 128, outline, 3.0, true)


func _draw_square(center: Vector2, half_size: float) -> void:
	var outline := Color("241636")
	var columns := 2 if equal_parts == 4 else equal_parts
	var rows := ceili(float(equal_parts) / columns)
	var bounds := Rect2(center - Vector2.ONE * half_size, Vector2.ONE * half_size * 2.0)
	var cell := bounds.size / Vector2(columns, rows)
	for part in equal_parts:
		var top_left := bounds.position + Vector2(part % columns, int(part / columns)) * cell
		var rect := Rect2(top_left, cell)
		draw_rect(rect, _part_color(part), true)
		draw_rect(rect, outline, false, 2.5, true)
		var label_position := rect.get_center() + Vector2(-6, 6)
		draw_string(get_theme_default_font(), label_position, str(part + 1),
			HORIZONTAL_ALIGNMENT_CENTER, -1, roundi(17 * text_scale), Color.WHITE if selected_parts.has(part) and marked_color.v < 0.7 else outline)
	draw_rect(bounds, outline, false, 3.5, true)
