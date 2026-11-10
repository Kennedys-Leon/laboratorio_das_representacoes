@tool
extends Control

signal groups_changed(formed: int, required: int)
signal group_rejected(message: String)
signal official_changed

const GROUP_COLORS := [Color("47ad72"), Color("9a62db"), Color("e7a72d"), Color("e7698b")]
const APPLE_ART: Texture2D = preload("res://assets/fruta-maca-v2.png")
const BANANA_ART: Texture2D = preload("res://assets/fruta-banana-v2.png")

@export_range(1, 24, 1) var apple_count := 12:
	set(value):
		apple_count = value
		queue_redraw()
@export_range(1, 12, 1) var columns := 4:
	set(value):
		columns = value
		queue_redraw()
@export_range(2, 12, 1) var required_groups := 4:
	set(value):
		required_groups = value
		queue_redraw()
@export_range(1, 12, 1) var group_size := 3:
	set(value):
		group_size = value
		queue_redraw()
@export_enum("apple", "banana") var object_style := "apple":
	set(value):
		object_style = value
		queue_redraw()
@export var interactive := false

var groups: Array[PackedInt32Array] = []
var outlines: Array[PackedVector2Array] = []
var current_path := PackedVector2Array()
var drawing := false
var rejected_path := PackedVector2Array()
var rejected_time := 0.0
var tray_style: StyleBoxFlat
var text_scale := 1.0
var official_mode := false
var _official := preload("res://scripts/collection_instrument.gd").new()


func _ready() -> void:
	tray_style = StyleBoxFlat.new()
	tray_style.bg_color = Color("fff9e9")
	tray_style.border_color = Color("d4b985")
	tray_style.set_border_width_all(2)
	tray_style.set_corner_radius_all(18)
	tray_style.shadow_color = Color(0.13, 0.05, 0.18, 0.16)
	tray_style.shadow_size = 5
	tray_style.shadow_offset = Vector2(0, 3)


func _process(delta: float) -> void:
	if rejected_time > 0.0:
		rejected_time = maxf(0.0, rejected_time - delta)
		queue_redraw()


func reset_groups() -> void:
	if official_mode:
		_official.reset()
		return
	groups.clear()
	outlines.clear()
	current_path.clear()
	drawing = false
	rejected_path.clear()
	rejected_time = 0.0
	queue_redraw()
	groups_changed.emit(0, required_groups)


func undo_last_group() -> void:
	if official_mode:
		_official.action("undo")
		return
	if groups.is_empty():
		return
	groups.pop_back()
	outlines.pop_back()
	queue_redraw()
	groups_changed.emit(groups.size(), required_groups)


func submit_lasso(path: PackedVector2Array) -> bool:
	if official_mode:
		if not interactive or path.size() < 3: return false
		var indices := PackedInt32Array()
		for index in _official.total:
			if Geometry2D.is_point_in_polygon(_official.pool_center(self, index), path): indices.append(index)
		return _official.assign_indices(indices)
	if not interactive or groups.size() >= required_groups or path.size() < 3:
		return false
	var found := PackedInt32Array()
	for index in apple_count:
		if Geometry2D.is_point_in_polygon(_fruit_center(index), path):
			found.append(index)
	if found.size() != group_size:
		_show_rejected(path)
		group_rejected.emit("Esse grupo tem %d frutas. Faça um grupo com %d %s." % [found.size(), group_size,
			"maçãs" if object_style == "apple" else "bananas"])
		return false
	for group in groups:
		for index in found:
			if group.has(index):
				_show_rejected(path)
				group_rejected.emit("Essa fruta já está em um grupo. Contorne as que faltam.")
				return false
	groups.append(found)
	var closed := path.duplicate()
	closed.append(path[0])
	outlines.append(_smooth_closed_path(closed))
	queue_redraw()
	groups_changed.emit(groups.size(), required_groups)
	return true


func _show_rejected(path: PackedVector2Array) -> void:
	rejected_path = path.duplicate()
	rejected_path.append(path[0])
	rejected_time = 0.6
	queue_redraw()


func submit_indices(indices: PackedInt32Array) -> bool:
	if official_mode:
		return _official.assign_indices(indices) if interactive else false
	if not interactive or groups.size() >= required_groups: return false
	if indices.size() != group_size:
		group_rejected.emit("Escolha %d frutas para formar este grupo." % group_size)
		return false
	var seen := {}
	for index in indices:
		if index < 0 or index >= apple_count or seen.has(index) or _group_of(index) >= 0: return false
		seen[index] = true
	groups.append(indices.duplicate())
	outlines.append(PackedVector2Array())
	queue_redraw()
	groups_changed.emit(groups.size(), required_groups)
	return true


func _smooth_closed_path(path: PackedVector2Array) -> PackedVector2Array:
	var points := path.duplicate()
	if points.size() < 5:
		return points
	points.resize(points.size() - 1)
	for pass_index in 2:
		var next := PackedVector2Array()
		for index in points.size():
			var a: Vector2 = points[index]
			var b: Vector2 = points[(index + 1) % points.size()]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		points = next
	points.append(points[0])
	return points


func _gui_input(event: InputEvent) -> void:
	if official_mode:
		if interactive and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_official.point(self, event.position)
			accept_event()
		return
	if not interactive or groups.size() >= required_groups:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drawing = true
			current_path = PackedVector2Array([event.position])
		else:
			if drawing:
				drawing = false
				submit_lasso(current_path)
				current_path.clear()
				queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		if current_path.is_empty() or current_path[-1].distance_to(event.position) > 3.0:
			current_path.append(event.position)
			queue_redraw()
		accept_event()


func _fruit_center(index: int) -> Vector2:
	var rows := ceili(float(apple_count) / columns)
	var cell := Vector2(size.x / columns, size.y / max(1, rows))
	return Vector2((index % columns + 0.5) * cell.x, (int(index / columns) + 0.5) * cell.y)


func _draw() -> void:
	if official_mode:
		_official.draw(self)
		return
	if columns < 1 or apple_count < 1:
		return
	if tray_style != null:
		draw_style_box(tray_style, Rect2(Vector2(3, 1), size - Vector2(6, 4)))
	var rows := ceili(float(apple_count) / columns)
	var cell := Vector2(size.x / columns, size.y / max(1, rows))
	var radius := minf(cell.x * 0.27, cell.y * 0.29)
	for index in apple_count:
		var center := _fruit_center(index)
		var group_index := _group_of(index)
		draw_circle(center + Vector2(0, 3), radius * 1.18, Color(0.39, 0.21, 0.13, 0.12))
		draw_circle(center, radius * 1.18, Color("fffdf4"))
		draw_arc(center, radius * 1.18, 0.0, TAU, 30, Color("e6d5b2"), 1.2, true)
		if group_index >= 0:
			var glow: Color = GROUP_COLORS[group_index % GROUP_COLORS.size()]
			glow.a = 0.22
			draw_circle(center, radius * 1.05, glow)
		var icon_size := minf(cell.x * 0.55, cell.y * 0.72) if object_style == "apple" else minf(cell.x * 0.64, cell.y * 0.88)
		var icon := APPLE_ART if object_style == "apple" else BANANA_ART
		draw_texture_rect(icon, Rect2(center - Vector2.ONE * icon_size * 0.5,
			Vector2.ONE * icon_size), false)
		var tag := str(index + 1) + (" · G%d" % (group_index + 1) if group_index >= 0 else "")
		draw_string(ThemeDB.fallback_font, center + Vector2(-18, icon_size * 0.5 + 15 * text_scale), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14 * text_scale), Color("211737"))
	for index in outlines.size():
		if outlines[index].size() < 2: continue
		var stroke: Color = GROUP_COLORS[index % GROUP_COLORS.size()]
		draw_polyline(outlines[index], Color("382343"), 8.0, true)
		draw_polyline(outlines[index], stroke, 5.0, true)
		var end: Vector2 = outlines[index][0]
		draw_circle(end, 5.0, Color("382343"))
		draw_circle(end, 3.2, stroke.lightened(0.35))
	if rejected_time > 0.0 and rejected_path.size() > 1:
		var alpha := rejected_time / 0.6
		draw_polyline(rejected_path, Color(0.9, 0.25, 0.36, alpha), 5.0, true)
	if current_path.size() > 1:
		draw_line(current_path[-1], current_path[0], Color(0.18, 0.48, 0.33, 0.32), 2.0, true)
		draw_polyline(current_path, Color("382343"), 8.0, true)
		draw_polyline(current_path, Color("48c882"), 5.0, true)
		draw_circle(current_path[0], 5.0, Color("382343"))
		draw_circle(current_path[0], 3.0, Color("fff8d6"))
		draw_circle(current_path[-1], 4.0, Color("fff8d6"))


func _group_of(fruit_index: int) -> int:
	for index in groups.size():
		if groups[index].has(fruit_index):
			return index
	return -1


## Official lesson exploration uses the original tray. It never decides correctness.
func clear_official() -> void:
	official_mode = false
	queue_redraw()


func configure_official(model: Dictionary, instrument: String) -> void:
	if not _official.changed.is_connected(_on_official_changed): _official.changed.connect(_on_official_changed)
	official_mode = true
	custom_minimum_size.y = 260 * text_scale
	_official.configure(model, instrument)
	queue_redraw()


func official_state() -> Dictionary:
	return _official.state()


func restore_official_state(value: Dictionary) -> void:
	_official.restore(value)


func official_controls() -> Array:
	return _official.controls()


func official_action(id: String) -> void:
	if interactive: _official.action(id)


func _on_official_changed() -> void:
	queue_redraw()
	official_changed.emit()
