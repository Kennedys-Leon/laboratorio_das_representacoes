extends RefCounted
## Public representation instruments inside Leon's existing FractionDiagram.
## They expose pupil actions and drawings; they never know or correct an answer.

const INK := Color("2a1940")
const PAPER := Color("fffdf1")
const PAINT := Color("a57be2")
const GREEN := Color("d8efb6")
const GOLD := Color("a76518")
const PLATE_COLORS := [Color("9164ca"), Color("3c8a65"), Color("b27328"), Color("a8476b")]

var model := {}
var instrument := ""
var state := {}
var history: Array[Dictionary] = []
var regions: Array[Dictionary] = []


func configure(value: Dictionary, kind: String) -> void:
	model = value.duplicate(true)
	# JSON numbers arrive as floats in Godot. Array.has uses strict element
	# types, so given mark indices must be canonical integers before drawing.
	if model.get("markedParts") is Array:
		model.markedParts = _integer_marks(model.markedParts)
	for figure in model.get("figures", []):
		if figure is Dictionary and figure.get("markedParts") is Array:
			figure.markedParts = _integer_marks(figure.markedParts)
	instrument = kind
	history.clear()
	state = initial_state()


func _integer_marks(values: Array) -> Array:
	var result := []
	for index in values: result.append(int(index))
	return result


func initial_state() -> Dictionary:
	var result := {"observed": [], "factor": 1, "painted": [], "selectedValue": -1, "zoom": false, "cursor": -1, "recipient": 0, "cut": false, "groupView": false}
	var order := []
	var positions := []
	for index in model.get("values", []).size():
		order.append(index)
		positions.append(-1)
	result.order = order
	result.positions = positions
	var assignments := []
	for index in int(model.get("loaves", 0)) * int(model.get("piecesPerLoaf", 0)):
		assignments.append(-1)
	result.assignments = assignments
	return result


func snapshot() -> Dictionary:
	return state.duplicate(true)


func restore(value: Dictionary) -> void:
	var valid := initial_state()
	for key in ["zoom", "cut", "groupView"]:
		if value.get(key) is bool: valid[key] = value[key]
	for key in ["factor", "selectedValue", "cursor", "recipient"]:
		if typeof(value.get(key)) in [TYPE_INT, TYPE_FLOAT]: valid[key] = int(value[key])
	valid.factor = clampi(valid.factor, 1, 5)
	valid.selectedValue = clampi(valid.selectedValue, -1, model.get("values", []).size() - 1)
	valid.cursor = clampi(valid.cursor, -1, int(model.get("intervals", 0)))
	valid.recipient = clampi(valid.recipient, 0, maxi(0, int(model.get("people", 1)) - 1))
	for key in ["observed", "painted"]:
		if value.get(key) is Array:
			for item in value[key].slice(0, 120):
				if typeof(item) in [TYPE_INT, TYPE_FLOAT] and int(item) >= 0 and int(item) < 120 and not valid[key].has(int(item)):
					valid[key].append(int(item))
	if value.get("assignments") is Array and value.assignments.size() == valid.assignments.size():
		for index in valid.assignments.size():
			if typeof(value.assignments[index]) in [TYPE_INT, TYPE_FLOAT]: valid.assignments[index] = clampi(int(value.assignments[index]), -1, int(model.get("people", 1)) - 1)
	if value.get("positions") is Array and value.positions.size() == valid.positions.size():
		for index in valid.positions.size():
			if typeof(value.positions[index]) in [TYPE_INT, TYPE_FLOAT]: valid.positions[index] = clampi(int(value.positions[index]), -1, int(model.get("intervals", 0)))
	if value.get("order") is Array and value.order.size() == valid.order.size():
		var candidate := []
		for index in value.order:
			if typeof(index) in [TYPE_INT, TYPE_FLOAT] and float(index) == int(index): candidate.append(int(index))
		var sorted: Array = candidate.duplicate()
		sorted.sort()
		if sorted == valid.order: valid.order = candidate
	state = valid
	history.clear()


func controls() -> Array:
	var result := []
	match instrument:
		"parts":
			for index in int(model.get("parts", 2)):
				result.append(_button("part-%d" % index, "Parte %d%s" % [index + 1, " [x]" if state.observed.has(index) else ""]))
		"equivalence":
			if model.get("variant", "equivalent") == "pizzas":
				result.append(_button("pizza-0", "Observar pizza pequena"))
				result.append(_button("pizza-1", "Observar pizza grande"))
			else:
				result.append(_button("divide", "Subdividir cada parte", state.factor >= 5))
				result.append(_button("join", "Desfazer subdivisão", state.factor <= 1))
				if int(model.get("targetParts", 0)) > 0:
					for index in int(model.targetParts): result.append(_button("paint-%d" % index, "Marcar parte %d" % (index + 1)))
		"comparison":
			for index in model.get("values", []).size(): result.append(_button("value-%d" % index, "Observar %s" % str(model.values[index])))
			result.append(_button("zoom", "Escala completa" if state.zoom else "Ampliar escala"))
			if model.get("mode", "compare") == "order":
				result.append(_button("left", "Mover cartão à esquerda", state.selectedValue < 0))
				result.append(_button("right", "Mover cartão à direita", state.selectedValue < 0))
		"decimal":
			result.append(_button("groups", "Ver centésimos" if state.groupView else "Agrupar em décimos"))
			result.append(_button("inspect-next", "Acompanhar próximo quadradinho"))
		"number_line":
			result.append(_button("previous", "Marco anterior", state.cursor == 0))
			result.append(_button("next", "Próximo marco", state.cursor >= int(model.get("intervals", 1))))
			if int(model.get("intervals", 1)) >= 50: result.append(_button("zoom", "Ver reta inteira" if state.zoom else "Ampliar marcos"))
			for index in model.get("values", []).size(): result.append(_button("value-%d" % index, "Cartão %s" % str(model.values[index])))
			if not model.get("values", []).is_empty(): result.append(_button("place", "Colocar cartão neste marco", state.cursor < 0 or state.selectedValue < 0))
		"bread_share":
			result.append(_button("cut", "Cortar cada pão em %d partes" % int(model.get("piecesPerLoaf", 4)), state.cut))
			for index in int(model.get("people", 4)): result.append(_button("person-%d" % index, "Pessoa %d%s" % [index + 1, " [x]" if state.recipient == index else ""]))
			result.append(_button("give", "Entregar uma parte", not state.cut or not state.assignments.has(-1)))
			result.append(_button("take", "Recolher uma parte", not state.assignments.has(state.recipient)))
	return result


func _button(id: String, text: String, disabled := false) -> Dictionary:
	return {"id": id, "text": text, "disabled": disabled}


func action(id: String) -> bool:
	if id == "undo":
		if history.is_empty(): return false
		state = history.pop_back()
		return true
	var before := snapshot()
	if id == "reset":
		state = initial_state()
	elif id.begins_with("part-"):
		_toggle("observed", int(id.trim_prefix("part-")))
	elif id.begins_with("paint-"):
		_toggle("painted", int(id.trim_prefix("paint-")))
	elif id.begins_with("value-"):
		state.selectedValue = clampi(int(id.trim_prefix("value-")), 0, model.get("values", []).size() - 1)
	elif id.begins_with("pizza-"):
		_toggle("observed", int(id.trim_prefix("pizza-")))
	elif id.begins_with("person-"):
		state.recipient = clampi(int(id.trim_prefix("person-")), 0, int(model.get("people", 4)) - 1)
	elif id.begins_with("tick-"):
		state.cursor = clampi(int(id.trim_prefix("tick-")), 0, int(model.get("intervals", 1)))
	elif id.begins_with("piece-"):
		var index := int(id.trim_prefix("piece-"))
		if state.cut and index >= 0 and index < state.assignments.size(): state.assignments[index] = -1 if state.assignments[index] == state.recipient else state.recipient
	else:
		match id:
			"divide": state.factor = mini(5, state.factor + 1)
			"join": state.factor = maxi(1, state.factor - 1)
			"zoom": state.zoom = not state.zoom
			"groups": state.groupView = not state.groupView
			"inspect-next": _toggle("observed", state.observed.size() % 100)
			"left", "right":
				var index: int = state.order.find(state.selectedValue)
				var next_index: int = clampi(index + (-1 if id == "left" else 1), 0, state.order.size() - 1)
				if index >= 0:
					var swap: Variant = state.order[next_index]
					state.order[next_index] = state.selectedValue
					state.order[index] = swap
			"previous": state.cursor = maxi(0, state.cursor - 1)
			"next": state.cursor = mini(int(model.get("intervals", 1)), state.cursor + 1)
			"place":
				if state.selectedValue >= 0 and state.cursor >= 0: state.positions[state.selectedValue] = state.cursor
			"cut": state.cut = true
			"give":
				var index: int = state.assignments.find(-1)
				if state.cut and index >= 0: state.assignments[index] = state.recipient
			"take":
				for index in range(state.assignments.size() - 1, -1, -1):
					if state.assignments[index] == state.recipient:
						state.assignments[index] = -1
						break
			_: return false
	if state == before: return false
	history.append(before)
	if history.size() > 100: history.pop_front()
	return true


func _toggle(key: String, index: int) -> void:
	if index < 0 or index >= 120: return
	if state[key].has(index): state[key].erase(index)
	else: state[key].append(index)


func hit(point: Vector2) -> String:
	if instrument == "number_line":
		for region in regions:
			if region.id == "line-area" and region.rect.has_point(point):
				var window := _line_window()
				var proportion: float = clampf((point.x - region.rect.position.x) / region.rect.size.x, 0, 1)
				return "tick-%d" % (window.x + roundi(proportion * (window.y - window.x)))
	for region in regions:
		if region.id == "line-area": continue
		if region.rect.has_point(point): return region.id
	return ""


func render(owner: Control) -> void:
	regions.clear()
	match instrument:
		"parts": _parts(owner)
		"equivalence": _equivalence(owner)
		"comparison": _comparison(owner)
		"decimal": _decimal(owner)
		"number_line": _number_line(owner)
		"bread_share": _bread(owner)


func _font(owner: Control, small := false) -> int:
	return roundi((14 if small else 17) * minf(float(owner.text_scale), 1.5))


func _text(owner: Control, text: String, position: Vector2, small := false, color := INK) -> void:
	owner.draw_string(owner.get_theme_default_font(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font(owner, small), color)


func _center(owner: Control, text: String, center: Vector2, small := false) -> void:
	var font: Font = owner.get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font(owner, small)).x
	_text(owner, text, center - Vector2(width / 2, 0), small)


func _panel(owner: Control, rect: Rect2, color := PAPER) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("9772b0")
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	owner.draw_style_box(box, rect)


func _strip(owner: Control, bounds: Rect2, parts: int, marked: Array, id_prefix: String, observed: Array = [], factor := 1) -> void:
	parts = maxi(parts, 1)
	for index in parts:
		var cell := Rect2(bounds.position + Vector2(index * bounds.size.x / parts, 0), Vector2(bounds.size.x / parts, bounds.size.y))
		owner.draw_rect(cell, PAINT if marked.has(index) else PAPER)
		if marked.has(index):
			for stripe in 4:
				var y := cell.position.y + (stripe + 1) * cell.size.y / 5
				owner.draw_line(Vector2(cell.position.x + 3, y), Vector2(cell.end.x - 3, y - 3), Color("5b367d"), 1.2, true)
		owner.draw_rect(cell, INK, false, 2, true)
		for sub in range(1, factor):
			var x := cell.position.x + sub * cell.size.x / factor
			owner.draw_line(Vector2(x, cell.position.y), Vector2(x, cell.end.y), Color("74548c"), 1, true)
		if observed.has(index): owner.draw_rect(cell.grow(-4), GOLD, false, 3, true)
		if not id_prefix.is_empty(): regions.append({"id": id_prefix + str(index), "rect": cell})


func _parts(owner: Control) -> void:
	var width := minf(owner.size.x - 24, 500)
	var bounds := Rect2(Vector2((owner.size.x - width) / 2, 50), Vector2(width, 100))
	_strip(owner, bounds, int(model.get("parts", 2)), model.get("markedParts", []), "part-", state.observed)
	for index in int(model.get("parts", 2)):
		_center(owner, str(index + 1), Vector2(bounds.position.x + (index + 0.5) * width / int(model.parts), 176), true)


func _equivalence(owner: Control) -> void:
	if model.get("variant", "equivalent") == "pizzas":
		var figures: Array = model.get("figures", [{"label":"Pizza pequena", "parts":2,"markedParts":[0],"scale":0.65},{"label":"Pizza grande", "parts":2,"markedParts":[0],"scale":1.0}])
		for index in figures.size():
			var figure: Dictionary = figures[index]
			var center := Vector2(owner.size.x * (0.28 if index == 0 else 0.72), 108)
			var radius: float = 76.0 * float(figure.get("scale", 1))
			_pizza(owner, center, radius, int(figure.get("parts", 2)), figure.get("markedParts", [0]))
			_center(owner, str(figure.get("label", "Pizza")), Vector2(center.x, 212), true)
			if state.observed.has(index): owner.draw_arc(center, radius + 5, 0, TAU, 80, GOLD, 3, true)
			regions.append({"id":"pizza-%d" % index,"rect":Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)})
		return
	var bounds := Rect2(Vector2(32, 35), Vector2(owner.size.x - 64, 65))
	_strip(owner, bounds, int(model.get("parts", 4)), model.get("markedParts", []), "", [], int(state.factor))
	_center(owner, "Mesmo inteiro; explore suas divisões.", Vector2(owner.size.x / 2, 23), true)
	if int(model.get("targetParts", 0)) > 0:
		bounds.position.y = 139
		_strip(owner, bounds, int(model.targetParts), state.painted, "paint-", state.painted)
		_center(owner, "Marque na segunda faixa para comparar.", Vector2(owner.size.x / 2, 128), true)
	else:
		_center(owner, "Cada parte pode ser repartida novamente.", Vector2(owner.size.x / 2, 148), true)


func _pizza(owner: Control, center: Vector2, radius: float, parts: int, marked: Array) -> void:
	owner.draw_circle(center, radius + 5, Color("b87937"))
	for part in parts:
		var points := PackedVector2Array([center])
		for step in 25:
			var angle := -PI / 2 + TAU * (part + float(step) / 24) / parts
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		owner.draw_colored_polygon(points, PAINT if marked.has(part) else Color("f2d197"))
		var angle := -PI / 2 + TAU * part / parts
		owner.draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius, INK, 2, true)
	owner.draw_arc(center, radius, 0, TAU, 80, INK, 2, true)
	# Toppings retain the food identity instead of becoming anonymous circles.
	for dot in 7:
		var angle := dot * 2.4
		var point := center + Vector2(cos(angle), sin(angle)) * radius * (0.25 if dot < 3 else 0.65)
		owner.draw_circle(point, maxf(2, radius * 0.065), Color("b75d49"))


func _number(value: Variant) -> float:
	var text := str(value).strip_edges().replace(",", ".")
	if text.contains("/"):
		var pieces := text.split("/")
		if pieces.size() == 2 and float(pieces[1]) != 0: return float(pieces[0]) / float(pieces[1])
	return float(text)


func _comparison(owner: Control) -> void:
	var values: Array = model.get("values", [])
	if values.is_empty(): return
	var maximum := 1.0
	var minimum := 1000000.0
	for value in values:
		maximum = maxf(maximum, _number(value))
		minimum = minf(minimum, _number(value))
	var base := 0.0
	var top := ceilf(maximum)
	if state.zoom:
		base = floorf(minimum * 10) / 10
		top = maxf(base + 0.1, ceilf(maximum * 10) / 10)
	var rows: Array = state.order if model.get("mode", "compare") == "order" else range(values.size())
	var height := minf(52.0, (owner.size.y - 55.0) / values.size())
	var left := 108.0
	var width := owner.size.x - left - 26.0
	for row in rows.size():
		var index: int = int(rows[row])
		var y := 22 + row * height
		var value := _number(values[index])
		var bounds := Rect2(Vector2(left, y), Vector2(width, height - 12))
		owner.draw_rect(bounds, PAPER)
		var filled := bounds
		filled.size.x = clampf((value - base) / maxf(0.01, top - base), 0, 1) * width
		owner.draw_rect(filled, PAINT)
		owner.draw_rect(bounds, INK, false, 1.5, true)
		# Unit boundaries make improper fractions visibly cross whole units.
		for unit in range(int(ceilf(base)), int(top)):
			if unit <= base: continue
			var x := left + (unit - base) / (top - base) * width
			owner.draw_line(Vector2(x, y), Vector2(x, y + height - 12), INK, 2, true)
		_text(owner, str(values[index]), Vector2(8, y + 23))
		if state.selectedValue == index: owner.draw_rect(Rect2(Vector2(2, y - 3), Vector2(owner.size.x - 4, height - 5)), GOLD, false, 2.5, true)
		regions.append({"id":"value-%d" % index,"rect":Rect2(Vector2(0,y),Vector2(owner.size.x,height - 5))})
	if model.get("mode", "compare") == "between":
		for bound in model.get("bounds", []):
			var x := left + (_number(bound) - base) / maxf(0.01, top - base) * width
			if x >= left and x <= left + width:
				owner.draw_dashed_line(Vector2(x, 10), Vector2(x, rows.size() * height + 12), GOLD, 2, 5)
	var caption := "Mesmo inteiro de referência"
	if top > 1 and not state.zoom: caption = "Cada trecho entre divisórias vale um inteiro."
	if state.zoom: caption = "Escala ampliada: %s a %s" % [str(base).replace(".", ","), str(top).replace(".", ",")]
	_center(owner, caption, Vector2(owner.size.x / 2, owner.size.y - 10), true)
	if model.get("mode", "compare") == "between" and model.get("bounds") is Array:
		_center(owner, "Referências: " + " e ".join(model.bounds), Vector2(owner.size.x / 2, owner.size.y - 32), true)


func _decimal(owner: Control) -> void:
	var wholes := int(model.get("wholeUnits", 0))
	var block := minf(36, (owner.size.x - 32) / maxi(1, wholes))
	for index in wholes:
		var rect := Rect2(Vector2(16 + index * (block + 5), 25), Vector2(block, 35))
		owner.draw_rect(rect, PAINT)
		owner.draw_rect(rect, INK, false, 2, true)
	var fraction := Rect2(Vector2(16 + wholes * (block + 5), 25), Vector2(block, 35))
	owner.draw_rect(fraction, PAPER)
	var partial := fraction
	partial.size.x *= float(model.get("hundredths", 0)) / 100
	owner.draw_rect(partial, PAINT)
	owner.draw_rect(fraction, INK, false, 2, true)
	_center(owner, "Quadros inteiros", Vector2(owner.size.x / 2, 85), true)
	var side := minf(136, owner.size.y - 110)
	var origin := Vector2(owner.size.x / 2 - side / 2, 100)
	var cell := side / 10
	for index in 100:
		var rect := Rect2(origin + Vector2(index % 10, int(index / 10)) * cell, Vector2.ONE * cell)
		owner.draw_rect(rect, PAINT if index < int(model.get("hundredths", 0)) else PAPER)
		owner.draw_rect(rect, INK, false, 0.7, true)
		if state.observed.has(index): owner.draw_rect(rect.grow(-1), GOLD, false, 2, true)
		regions.append({"id":"part-%d" % index,"rect":rect})
	if state.groupView:
		for index in 11: owner.draw_line(origin + Vector2(0,index * cell),origin + Vector2(side,index * cell),INK,2.2,true)
	_text(owner, "Ampliação do quadro", Vector2(12, 131), true)
	_text(owner, "fracionado: 100 partes.", Vector2(12, 154), true)
	if model.has("notation"): _text(owner, "Número dado: " + str(model.notation), Vector2(12, 198), true)


func _line_window() -> Vector2i:
	var total := int(model.get("intervals", 10))
	if not state.zoom: return Vector2i(0, total)
	var focus: int = state.cursor if state.cursor >= 0 else int(model.get("targetTick", 0))
	var first := clampi(focus - 5, 0, maxi(0, total - 10))
	return Vector2i(first, mini(total, first + 10))


func _number_line(owner: Control) -> void:
	var total := int(model.get("intervals", 10))
	var window := _line_window()
	var left := 27.0
	var width := owner.size.x - 54
	var y := 103.0
	owner.draw_line(Vector2(left, y), Vector2(left + width, y), INK, 3, true)
	regions.append({"id":"line-area","rect":Rect2(Vector2(left,y-35),Vector2(width,70))})
	for tick in range(window.x, window.y + 1):
		var x := left + float(tick - window.x) / maxi(1, window.y - window.x) * width
		var major: bool = tick % int(model.get("majorStep", maxi(1, int(total / 10)))) == 0
		owner.draw_line(Vector2(x, y - (14 if major else 7)), Vector2(x, y + (14 if major else 7)), INK, 2 if major else 1, true)
	if window.x == 0: _center(owner, str(model.get("start", 0)).replace(".", ","), Vector2(left, 146))
	if window.y == total: _center(owner, str(model.get("end", 1)).replace(".", ","), Vector2(left + width, 146))
	var target: int = int(model.get("targetTick", -1))
	if target >= window.x and target <= window.y:
		var x := left + float(target - window.x) / maxi(1, window.y - window.x) * width
		owner.draw_circle(Vector2(x, y), 7, Color("6b428e"))
		_center(owner, "Marco do enunciado", Vector2(clampf(x,110,owner.size.x-110), 44), true)
	if state.cursor >= window.x and state.cursor <= window.y:
		var x := left + float(state.cursor - window.x) / maxi(1, window.y - window.x) * width
		owner.draw_line(Vector2(x,y - 28),Vector2(x,y + 28),GOLD,3,true)
	var values: Array = model.get("values", [])
	for index in values.size():
		var x := 20.0 + index * (owner.size.x - 40) / values.size()
		var rect := Rect2(Vector2(x,174),Vector2((owner.size.x-50)/values.size(),33))
		_panel(owner, rect, GREEN if state.selectedValue == index else PAPER)
		_center(owner, str(values[index]),rect.get_center()+Vector2(0,5),true)
		regions.append({"id":"value-%d"%index,"rect":rect})
		var position: int = int(state.positions[index])
		if position >= window.x and position <= window.y:
			var marker_x := left + float(position-window.x)/maxi(1,window.y-window.x)*width
			owner.draw_circle(Vector2(marker_x,y+22+index*12),5,PLATE_COLORS[index%4])
	if values.is_empty(): _center(owner, "Explore os marcos sem mudar a escala da pergunta.",Vector2(owner.size.x/2,193),true)
	if state.zoom: _center(owner,"Ampliação de dez intervalos da mesma reta",Vector2(owner.size.x/2,22),true)


func _bread(owner: Control) -> void:
	var loaves := int(model.get("loaves", 7))
	var pieces := int(model.get("piecesPerLoaf", 4))
	var columns := 4
	var width := minf(104,(owner.size.x-30)/columns-10)
	var height := 45.0
	for loaf in loaves:
		var origin := Vector2(15 + (loaf % columns) * (width + 12), 15 + int(loaf / columns) * 68)
		var rect := Rect2(origin,Vector2(width,height))
		_panel(owner,rect,Color("e8bd7c"))
		if not state.cut:
			for slash in 3: owner.draw_line(origin+Vector2(16+slash*26,14),origin+Vector2(25+slash*26,29),Color("a7733d"),2,true)
		else:
			for piece in pieces:
				var part := Rect2(origin+Vector2(piece%2,int(piece/2))*Vector2(width/2,height/2),Vector2(width/2,height/2))
				var person: int = int(state.assignments[loaf*pieces+piece])
				if person >= 0:
					owner.draw_rect(part.grow(-2),PLATE_COLORS[person%4])
					_center(owner,str(person+1),part.get_center()+Vector2(0,5),true)
				owner.draw_rect(part,INK,false,1.5,true)
				regions.append({"id":"piece-%d"%(loaf*pieces+piece),"rect":part})
		_center(owner,"Pão %d"%(loaf+1),origin+Vector2(width/2,height+18),true)
	var people := int(model.get("people",4))
	var slot_width := (owner.size.x - 26) / people
	for person in people:
		var rect := Rect2(Vector2(13+person*slot_width,170),Vector2(slot_width-8,64))
		_panel(owner,rect,GREEN if state.recipient==person else PAPER)
		_center(owner,"Pessoa %d"%(person+1),rect.get_center()+Vector2(0,-7),true)
		var amount: int = state.assignments.count(person)
		_center(owner,"%d %s"%[amount,"parte" if amount == 1 else "partes"],rect.get_center()+Vector2(0,16),true)
		regions.append({"id":"person-%d"%person,"rect":rect})
