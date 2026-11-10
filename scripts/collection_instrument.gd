extends RefCounted
## Free distribution, proportion and percentage instruments for Leon's tray.
## All counts here describe givens or the child's construction; there is no key.
signal changed

const INK := Color("2a1747")
const PURPLE := Color("9865ce")
const GREEN := Color("76ba89")
const CREAM := Color("fff9e9")
const COLORS := [Color("9865ce"), Color("76ba89"), Color("d9a54c"), Color("d879a0"), Color("659bbf")]

var model := {}
var instrument := "collection"
var total := 0
var allocations: Array[int] = []
var group_count := 2
var active_group := 0
var selected_groups: Array[int] = []
var observed: Array[int] = []
var bundle := 1
var unit_factor := 1
var history: Array[Dictionary] = []


func configure(value: Dictionary, kind: String) -> void:
	model = value.duplicate(true)
	instrument = kind
	total = clampi(int(model.get("total", 0)), 0, 80)
	reset()


func reset() -> void:
	group_count = 1 if model.get("task") == "form_groups" else clampi(int(model.get("groups", 2)), 1, 10)
	active_group = 0
	bundle = 1
	unit_factor = 1
	selected_groups.clear()
	observed.clear()
	allocations.clear()
	for index in total: allocations.append(-1)
	var givens: Variant = model.get("givenGroups")
	if givens is Array:
		var next := 0
		for group in givens.size():
			for unused in maxi(0, int(givens[group])):
				if next < total: allocations[next] = group
				next += 1
	history.clear()
	changed.emit()


func state() -> Dictionary:
	return {"allocations":allocations.duplicate(), "groupCount":group_count, "activeGroup":active_group,
		"selectedGroups":selected_groups.duplicate(), "observed":observed.duplicate(), "bundle":bundle, "unitFactor":unit_factor}


func restore(value: Dictionary) -> void:
	var count: int = clampi(int(value.get("groupCount", group_count)), 1, 10)
	if model.get("task") != "form_groups": count = group_count
	var restored: Variant = value.get("allocations")
	if restored is Array and restored.size() == total and not model.has("givenGroups"):
		var valid := true
		for index in restored:
			if typeof(index) not in [TYPE_INT, TYPE_FLOAT] or int(index) != index or int(index) < -1 or int(index) >= count: valid = false
		if valid:
			allocations.clear()
			for index in restored: allocations.append(int(index))
	group_count = count
	active_group = clampi(int(value.get("activeGroup", 0)), 0, group_count - 1)
	bundle = int(value.get("bundle", 1)) if int(value.get("bundle", 1)) in [1, 5, 10] else 1
	unit_factor = clampi(int(value.get("unitFactor", 1)), 1, 4)
	selected_groups.clear()
	var marked: Variant = value.get("selectedGroups")
	if marked is Array:
		for group in marked:
			if typeof(group) in [TYPE_INT, TYPE_FLOAT] and int(group) == group and group >= 0 and group < group_count and not selected_groups.has(int(group)): selected_groups.append(int(group))
	observed.clear()
	var inspected: Variant = value.get("observed")
	if inspected is Array:
		for index in inspected:
			if typeof(index) in [TYPE_INT, TYPE_FLOAT] and int(index) == index and index >= 0 and index < total and not observed.has(int(index)): observed.append(int(index))
	history.clear()
	changed.emit()


func controls() -> Array:
	if _symbolic():
		return [{"id":"subdivide", "text":"Subdividir as unidades", "disabled":unit_factor >= 4}, {"id":"rejoin", "text":"Reunir as unidades", "disabled":unit_factor <= 1}, {"id":"undo", "text":"Desfazer", "disabled":history.is_empty()}]
	if model.has("givenGroups"):
		return [{"id":"bundle-1", "text":"Contar um a um"}, {"id":"bundle-5", "text":"Agrupar de 5"}, {"id":"bundle-10", "text":"Agrupar de 10"}, {"id":"undo", "text":"Desfazer", "disabled":history.is_empty()}]
	var result := [
		{"id":"next-group", "text":"Grupo ativo: %d (trocar)" % (active_group + 1)},
		{"id":"add-1", "text":"Enviar 1", "disabled":_unassigned() == 0},
		{"id":"add-5", "text":"Enviar 5", "disabled":_unassigned() == 0},
		{"id":"add-10", "text":"Enviar 10", "disabled":_unassigned() == 0},
		{"id":"remove-1", "text":"Retirar 1", "disabled":_indices(active_group).is_empty()},
		{"id":"undo", "text":"Desfazer", "disabled":history.is_empty()},
	]
	if model.get("task") == "form_groups": result.insert(1, {"id":"new-group", "text":"Novo grupo", "disabled":group_count >= 10})
	if instrument == "percentage": result.append({"id":"mark-group", "text":"Desmarcar este grupo" if selected_groups.has(active_group) else "Marcar este grupo"})
	return result


func action(id: String) -> void:
	if id == "undo":
		if not history.is_empty():
			var previous: Dictionary = history.pop_back()
			var previous_history := history.duplicate(true)
			restore(previous)
			history = previous_history
		return
	if id == "reset":
		reset()
		return
	if id == "next-group":
		_save()
		active_group = (active_group + 1) % group_count
	elif id == "new-group" and model.get("task") == "form_groups" and group_count < 10:
		_save()
		group_count += 1
		active_group = group_count - 1
	elif id == "mark-group" and instrument == "percentage":
		_save()
		if selected_groups.has(active_group): selected_groups.erase(active_group)
		else: selected_groups.append(active_group)
	elif id.begins_with("add-") and not model.has("givenGroups") and not _symbolic():
		var amount := int(id.trim_prefix("add-"))
		if amount not in [1, 5, 10] or _unassigned() == 0: return
		_save()
		for index in allocations.size():
			if allocations[index] == -1:
				allocations[index] = active_group
				amount -= 1
				if amount == 0: break
	elif id == "remove-1" and not model.has("givenGroups"):
		var indices := _indices(active_group)
		if indices.is_empty(): return
		_save()
		allocations[indices[-1]] = -1
	elif id.begins_with("bundle-") and model.has("givenGroups"):
		var amount := int(id.trim_prefix("bundle-"))
		if amount not in [1, 5, 10]: return
		_save()
		bundle = amount
	elif id == "subdivide" and _symbolic() and unit_factor < 4:
		_save()
		unit_factor += 1
	elif id == "rejoin" and _symbolic() and unit_factor > 1:
		_save()
		unit_factor -= 1
	else:
		return
	changed.emit()


func assign_indices(indices: PackedInt32Array) -> bool:
	if _symbolic() or model.has("givenGroups"): return false
	var valid := PackedInt32Array()
	for index in indices:
		if index >= 0 and index < total and not valid.has(index): valid.append(index)
	if valid.is_empty(): return false
	_save()
	for index in valid: allocations[index] = active_group
	changed.emit()
	return true


func point(owner: Control, position: Vector2) -> void:
	if _symbolic(): return
	if model.has("givenGroups"):
		# The question supplies both quantities. Inspection cannot change a given.
		for group in group_count:
			var rect := _given_rect(owner, group)
			var indices := _indices(group)
			for slot in indices.size():
				if position.distance_to(_given_center(owner, rect, slot, indices.size())) <= 14.0:
					_save()
					var index: int = indices[slot]
					if observed.has(index): observed.erase(index)
					else: observed.append(index)
					changed.emit()
					return
		return
	for group in group_count:
		if _group_rect(owner, group).has_point(position):
			_save()
			active_group = group
			changed.emit()
			return
	var pool := _pool_rect(owner)
	if not pool.has_point(position): return
	for index in total:
		var cell := _pool_cell(owner)
		if position.distance_to(pool_center(owner, index)) < minf(cell.x, cell.y) * 0.45:
			_save()
			allocations[index] = -1 if allocations[index] == active_group else active_group
			changed.emit()
			return


func draw(owner: Control) -> void:
	if owner.tray_style != null: owner.draw_style_box(owner.tray_style, Rect2(Vector2(3, 1), owner.size - Vector2(6, 4)))
	if _symbolic():
		_draw_symbolic(owner)
		return
	if model.has("givenGroups"):
		_draw_givens(owner)
		return
	var label := str(model.get("objectLabel", "objetos"))
	_text(owner, Vector2(14, 24), "%d %s · distribua para investigar" % [total, label], 15)
	var pool := _pool_rect(owner)
	_panel(owner, pool, CREAM, Color("d4b985"), 1.5)
	var cell := _pool_cell(owner)
	var radius := minf(cell.x, cell.y) * 0.27
	for index in total:
		var center := pool_center(owner, index)
		if allocations[index] < 0:
			_object(owner, center, radius, str(model.get("objectStyle", "counter")), INK)
		else:
			owner.draw_circle(center, maxf(2.0, radius * 0.22), Color("c8b6aa"))
	for group in group_count:
		var rect := _group_rect(owner, group)
		var is_active := group == active_group
		var is_marked := selected_groups.has(group)
		_panel(owner, rect, Color("eee1f8") if is_marked else Color("fffdf4"), INK if is_active else COLORS[group % COLORS.size()], 3.0 if is_active else 2.0)
		var items := _indices(group)
		var label_group := "%sG%d: %d" % ["* " if is_active and not model.has("ratios") else "", group + 1, items.size()]
		_text(owner, rect.position + Vector2(6, 19 * owner.text_scale), label_group, 13)
		var cols := mini(6, maxi(1, items.size()))
		var rows := ceili(float(items.size()) / cols)
		var available := Vector2(rect.size.x - 12, maxf(0, rect.size.y - 30 * owner.text_scale))
		var icon_cell := Vector2(available.x / cols, available.y / maxi(1, rows))
		if icon_cell.y >= 8:
			for slot in items.size():
				var center := rect.position + Vector2(6 + (slot % cols + 0.5) * icon_cell.x, 26 * owner.text_scale + (int(slot / cols) + 0.5) * icon_cell.y)
				_object(owner, center, minf(icon_cell.x, icon_cell.y) * 0.25, str(model.get("objectStyle", "counter")), COLORS[group % COLORS.size()])
	var footer := "Estoque: %d · escolha um grupo e mova os objetos" % _unassigned()
	if instrument == "percentage":
		var selected := 0
		for group in selected_groups: selected += _indices(group).size()
		footer = "Sua seleção: %d objetos · grupos marcados: %d" % [selected, selected_groups.size()]
	elif model.get("task") == "form_groups":
		footer = "Sua montagem: %d grupos · tamanho pedido: %d" % [group_count, int(model.get("groupSize", 1))]
	elif model.has("ratios"):
		footer = "Relação dada: %d : %d · estoque: %d" % [int(model.ratios[0]), int(model.ratios[1]), _unassigned()]
	_text(owner, Vector2(14, owner.size.y - 10), footer, 14)


func _draw_givens(owner: Control) -> void:
	_text(owner, Vector2(14, 24), "Quantidades dadas · toque nos objetos para acompanhar", 15)
	for group in group_count:
		var rect := _given_rect(owner, group)
		_panel(owner, rect, Color("fffdf4"), COLORS[group % COLORS.size()], 2.0)
		var indices := _indices(group)
		_text(owner, rect.position + Vector2(8, 22 * owner.text_scale), "Grupo %d: %d" % [group + 1, indices.size()], 15)
		for slot in indices.size():
			var center := _given_center(owner, rect, slot, indices.size())
			var columns := mini(10, maxi(1, indices.size()))
			var rows := ceili(float(indices.size()) / columns)
			var radius := minf((rect.size.x - 20) / columns, (rect.size.y - 44 * owner.text_scale) / maxi(1, rows)) * 0.22
			_object(owner, center, radius, str(model.get("objectStyle", "counter")), COLORS[group % COLORS.size()])
			if observed.has(indices[slot]): owner.draw_arc(center, radius * 1.5, 0, TAU, 24, INK, 2, true)
		if bundle > 1:
			for first in range(0, indices.size(), bundle):
				var first_point := _given_center(owner, rect, first, indices.size())
				var last_point := _given_center(owner, rect, mini(first + bundle - 1, indices.size() - 1), indices.size())
				if is_equal_approx(first_point.y, last_point.y):
					owner.draw_line(first_point + Vector2(-7, 11), last_point + Vector2(7, 11), INK, 2.0, true)
	_text(owner, Vector2(14, owner.size.y - 10), "Agrupamento escolhido: de %d em %d" % [bundle, bundle], 14)


func _draw_symbolic(owner: Control) -> void:
	var ratios: Array = model.get("ratios", [1, 2])
	var all_units: int = maxi(1, int(ratios[0]) + int(ratios[1]))
	_text(owner, Vector2(14, 25), "Uma unidade de medida · compare as duas partes", 15)
	var x := 22.0
	var y: float = 72.0 * owner.text_scale
	var unit_width := (owner.size.x - 50) / all_units
	var height := maxf(50, owner.size.y - y - 54)
	for group in 2:
		var units: int = int(ratios[group])
		var rect := Rect2(Vector2(x, y), Vector2(unit_width * units, height))
		_panel(owner, rect, COLORS[group].lightened(0.45), INK, 2)
		for division in units * unit_factor:
			var boundary := x + division * unit_width / unit_factor
			owner.draw_line(Vector2(boundary, y), Vector2(boundary, y + height), INK, 1.5, true)
		_text(owner, Vector2(x + 4, y - 12), "Parte %d" % (group + 1), 16)
		x += rect.size.x + 6
	_text(owner, Vector2(14, owner.size.y - 12), "Subdivisões por unidade: %d" % unit_factor, 14)


func _object(owner: Control, center: Vector2, radius: float, style: String, color: Color) -> void:
	var r := maxf(2.0, radius)
	match style:
		"person":
			owner.draw_circle(center + Vector2(0, -r * 0.55), r * 0.42, color)
			owner.draw_line(center + Vector2(0, -r * 0.1), center + Vector2(0, r * 0.65), color, maxf(1.5, r * 0.3), true)
			owner.draw_line(center + Vector2(-r * 0.6, r * 0.05), center + Vector2(r * 0.6, r * 0.05), color, maxf(1.5, r * 0.24), true)
			owner.draw_line(center + Vector2(0, r * 0.5), center + Vector2(-r * 0.45, r), color, maxf(1.5, r * 0.24), true)
			owner.draw_line(center + Vector2(0, r * 0.5), center + Vector2(r * 0.45, r), color, maxf(1.5, r * 0.24), true)
		"seedling":
			owner.draw_line(center + Vector2(0, r), center + Vector2(0, -r * 0.65), INK, maxf(1.5, r * 0.18), true)
			owner.draw_colored_polygon(PackedVector2Array([center, center + Vector2(-r, -r * 0.8), center + Vector2(-r * 0.3, -r)]), GREEN)
			owner.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r * 0.3), center + Vector2(r, -r), center + Vector2(r * 0.2, -r)]), GREEN.darkened(0.2))
		"sticker":
			var rect := Rect2(center - Vector2(r * 0.85, r), Vector2(r * 1.7, r * 2))
			owner.draw_rect(rect, Color("eee1f8"))
			owner.draw_rect(rect, color, false, maxf(1, r * 0.16))
			owner.draw_circle(center, r * 0.42, GREEN)
		"pencil":
			owner.draw_line(center + Vector2(-r * 0.5, r * 0.75), center + Vector2(r * 0.5, -r * 0.75), Color("d7a951"), maxf(2, r * 0.5), true)
			owner.draw_line(center + Vector2(-r * 0.5, r * 0.75), center + Vector2(-r * 0.65, r), INK, maxf(1, r * 0.18), true)
		"cap":
			owner.draw_circle(center, r, Color("d6ead8"))
			owner.draw_arc(center, r, 0, TAU, 20, color, maxf(1, r * 0.2), true)
			owner.draw_arc(center, r * 0.55, 0, TAU, 16, color, 1, true)
		_:
			owner.draw_circle(center, r, color.lightened(0.25))
			owner.draw_arc(center, r, 0, TAU, 20, INK, maxf(1, r * 0.16), true)
			owner.draw_line(center + Vector2(-r * 0.4, -r * 0.4), center + Vector2(r * 0.4, r * 0.4), INK, 1.0, true)


func _text(owner: Control, position: Vector2, text: String, font_size: int) -> void:
	owner.draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * owner.text_scale), INK)


func _panel(owner: Control, rect: Rect2, background: Color, border: Color, width: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(roundi(width))
	box.set_corner_radius_all(10)
	owner.draw_style_box(box, rect)


func _save() -> void:
	history.append(state())
	if history.size() > 32: history.pop_front()


func _symbolic() -> bool:
	return instrument == "ratio" and not model.has("total")


func _unassigned() -> int:
	var amount := 0
	for group in allocations:
		if group < 0: amount += 1
	return amount


func _indices(group: int) -> Array[int]:
	var result: Array[int] = []
	for index in allocations.size():
		if allocations[index] == group: result.append(index)
	return result


func _pool_rect(owner: Control) -> Rect2:
	return Rect2(Vector2(12, 36 * owner.text_scale), Vector2(owner.size.x * 0.59 - 14, owner.size.y - 68 * owner.text_scale))


func _pool_cell(owner: Control) -> Vector2:
	var rect := _pool_rect(owner)
	var cols := mini(8, maxi(1, total))
	var rows := ceili(float(total) / cols)
	return Vector2(rect.size.x / cols, rect.size.y / maxi(1, rows))


func pool_center(owner: Control, index: int) -> Vector2:
	var rect := _pool_rect(owner)
	var cols := mini(8, maxi(1, total))
	var cell := _pool_cell(owner)
	return rect.position + Vector2((index % cols + 0.5) * cell.x, (int(index / cols) + 0.5) * cell.y)


func _group_rect(owner: Control, group: int) -> Rect2:
	var cols := mini(2, group_count)
	var rows := ceili(float(group_count) / cols)
	var space := Vector2(owner.size.x * 0.41 - 16, owner.size.y - 68 * owner.text_scale)
	var cell := Vector2(space.x / cols, space.y / rows)
	if group_count == 2 and model.has("ratios"):
		var ratios: Array = model.ratios
		var unit: float = space.x / maxf(1, float(ratios[0]) + float(ratios[1]))
		var offset := 0.0 if group == 0 else unit * int(ratios[0])
		return Rect2(Vector2(owner.size.x * 0.59 + offset, 36 * owner.text_scale), Vector2(unit * int(ratios[group]) - 4, space.y - 4))
	return Rect2(Vector2(owner.size.x * 0.59 + (group % cols) * cell.x, 36 * owner.text_scale + int(group / cols) * cell.y), cell - Vector2(4, 4))


func _given_rect(owner: Control, group: int) -> Rect2:
	var width := (owner.size.x - 32) / group_count
	return Rect2(Vector2(12 + group * (width + 6), 38 * owner.text_scale), Vector2(width, owner.size.y - 70 * owner.text_scale))


func _given_center(owner: Control, rect: Rect2, slot: int, count: int) -> Vector2:
	var cols := mini(10, maxi(1, count))
	var rows := ceili(float(count) / cols)
	var cell := Vector2((rect.size.x - 20) / cols, maxf(0, rect.size.y - 44 * owner.text_scale) / maxi(1, rows))
	return rect.position + Vector2(10 + (slot % cols + 0.5) * cell.x, 32 * owner.text_scale + (int(slot / cols) + 0.5) * cell.y)
