extends Node
## The original scene is the activity. The site owns question selection and attempts.
const WEB_SOURCE := """(() => {
 if (window.gaussLabLesson) return;
 const bridge = window.gaussLabLesson = {queue: [], inspect: new URLSearchParams(location.search).get('inspect') === '1'};
 addEventListener('message', e => {
  if (e.origin !== location.origin || e.source !== parent || e.data?.version !== 1) return;
  if (['gauss-medidas-round','gauss-medidas-result','gauss-medidas-error'].includes(e.data.type)) {
   if (JSON.stringify(e.data).length < 100000) bridge.queue.push(e.data);
  }
 });
 parent.postMessage({type:'gauss-medidas-ready',version:1},location.origin);
})();
"""

var game: Control
var configured := false
var waiting := false
var uncertain := false
var feedback_received := false
var feedback_reason := ""
var poll := 0.0
var last_layout := ""
var question_card: Label
var instrument_buttons: HFlowContainer
var number_answer: LineEdit
var button_signature := ""
var restoring := false


func _ready() -> void:
	game = get_parent()
	game.menu_layer.hide()
	game.game_layer.hide()
	game.menu_cat.set_reduced_motion(true)
	game.game_cat.reduced_motion = true
	game.find_child("BackMenuButton", true, false).text = "‹  Voltar à aula"
	var content: VBoxContainer = game.find_child("GameContent", true, false)
	question_card = Label.new()
	question_card.name = "OfficialQuestion"
	question_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_card.add_theme_color_override("font_color", Color("211737"))
	question_card.add_theme_font_size_override("font_size", 18)
	content.add_child(question_card)
	content.move_child(question_card, content.get_children().find(game.find_child("Steps", true, false)) + 1)
	game.accessibility._capture(question_card)
	instrument_buttons = HFlowContainer.new()
	instrument_buttons.name = "InstrumentControls"
	instrument_buttons.add_theme_constant_override("h_separation", 7)
	instrument_buttons.add_theme_constant_override("v_separation", 6)
	content.add_child(instrument_buttons)
	content.move_child(instrument_buttons, content.get_children().find(game.stage_hint) + 1)
	number_answer = LineEdit.new()
	number_answer.name = "OfficialNumberAnswer"
	number_answer.placeholder_text = "Digite sua resposta"
	number_answer.accessibility_name = "Sua resposta"
	number_answer.custom_minimum_size = Vector2(240, 48)
	number_answer.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	number_answer.max_length = 12
	number_answer.text_changed.connect(_number_changed)
	number_answer.text_submitted.connect(func(_text): submit_answer())
	game.parts_choices.get_parent().add_child(number_answer)
	game.accessibility._capture(number_answer)
	game.diagram.official_changed.connect(_instrument_changed)
	game.apples.official_changed.connect(_instrument_changed)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_SOURCE, true)


func post(data: Dictionary) -> void:
	data.version = 1
	if OS.has_feature("web"):
		JavaScriptBridge.eval("parent.postMessage(" + JSON.stringify(data) + ", location.origin)", true)


func receive(data: Dictionary) -> void:
	match data.get("type", ""):
		"gauss-medidas-round": configure(data)
		"gauss-medidas-result":
			if configured: show_result(data)
		"gauss-medidas-error":
			if not configured: return
			waiting = false
			uncertain = true
			game.submitting = true
			lock_controls(true)
			game.check_button.text = "Reenviar tentativa"
			game.check_button.disabled = false
			game.status_label.text = str(data.get("message", "Aguarde a confirmação da API."))


func configure(data: Dictionary) -> void:
	var value: Variant = data.get("round")
	if not value is Dictionary: return
	var r: Dictionary = value
	var part: Dictionary = r.get("round", {})
	var response: Dictionary = r.get("response", {})
	if r.get("contractVersion") != 1 or r.get("gameId") != game.GAME_ID: return
	var legacy: bool = part.get("kind") == "fraction_parts" and part.get("originalScene") == "fraction_parts_observe" and part.get("shape") == "strip"
	var expanded: bool = part.get("kind") == "laboratorio_representation" and part.get("originalScene") == "main_instruments" and part.get("instrument") in ["parts", "collection", "equivalence", "comparison", "decimal", "number_line", "bread_share", "ratio", "percentage"] and part.get("model") is Dictionary
	if not legacy and not expanded: return
	if response.get("kind") == "choice":
		if not response.get("choices") is Array or response.choices.size() < 2 or response.choices.size() > 4: return
	elif response.get("kind") != "number": return
	if legacy and (int(part.get("equalParts", 0)) < 2 or int(part.equalParts) > 12 or not part.get("markedParts") is Array): return
	game.rounds.clear()
	game.rounds.append(r)
	game.round_index = 0
	game.online_rounds = true
	configured = true
	show_round()
	restoring = true
	var state: Variant = data.get("workState")
	if not legacy and state is Dictionary and state.get("instrument") == instrument_name() and state.get("state") is Dictionary:
		current_node().call("restore_official_state", state.state)
	elif legacy and state is Dictionary and state.get("observedParts") is Array:
		for index in state.observedParts:
			if typeof(index) in [TYPE_INT, TYPE_FLOAT] and int(index) == index and index >= 0 and index < int(part.equalParts):
				if not game.diagram.selected_parts.has(int(index)):
					game.diagram.selection_history.append(game.diagram.selected_parts.duplicate())
					game.diagram.selected_parts.append(int(index))
	var draft: Variant = data.get("draft")
	if response.kind == "number":
		number_answer.text = str(draft) if typeof(draft) in [TYPE_INT, TYPE_FLOAT] else ""
		game.check_button.disabled = choice() == null
	else:
		for button in game.parts_choices.get_children():
			if button.visible and button.get_meta("choice", null) == draft:
				game._select(button)
	restoring = false
	game.diagram.queue_redraw()
	refresh_instrument_controls()
	post({"type":"gauss-medidas-round-shown", "exerciseId":r.exerciseId, "scene": "fraction_parts_observe" if legacy else instrument_name(), "scenePath":"res://scenes/main.tscn", "prompt":r.prompt})


func show_round() -> void:
	if not configured: return
	waiting = false
	uncertain = false
	feedback_received = false
	feedback_reason = ""
	game.victory_timer.stop()
	game.retry_timer.stop()
	game._cancel_speech_transition()
	game.submitting = false
	game.result_correct = false
	game.stage_complete = true
	game.configuring_round = true
	game._reset_selection()
	var r: Dictionary = game.rounds[0]
	var legacy := is_legacy()
	question_card.visible = not legacy
	question_card.text = r.prompt
	game.question_label.text = r.prompt if legacy else instrument_hint()
	game.round_label.text = "Questão da aula"
	game.find_child("ActivityBadge", true, false).text = "Laboratório • %dº ano" % int(r.get("schoolYear", 3))
	game.progress.max_value = 1
	game.progress.value = 0
	game.diagram.clear_official()
	game.apples.clear_official()
	var collection := instrument_name() in ["collection", "ratio", "percentage"]
	game.diagram.visible = not collection
	game.apples.visible = collection
	if legacy:
		game.diagram.equal_parts = int(r.round.equalParts)
		game.diagram.marked_parts = PackedInt32Array(r.round.markedParts)
		game.diagram.diagram_shape = "strip"
		game.diagram.observe_mode = true
		game.diagram.custom_minimum_size = Vector2(320, 170)
		game.diagram.reset_selection()
	else:
		current_node().call("configure_official", r.round.model, instrument_name())
	var choices: Array = r.response.get("choices", [])
	game.parts_choices.visible = r.response.kind == "choice"
	number_answer.visible = r.response.kind == "number"
	number_answer.text = ""
	game.collection_choices.hide()
	for index in game.parts_choices.get_child_count():
		var button: Button = game.parts_choices.get_child(index)
		button.visible = index < choices.size()
		if button.visible:
			button.set_meta("choice", choices[index])
			game._restore_choice(button)
			button.custom_minimum_size.x = 520 if str(choices[index]).length() > 30 else 145
			button.disabled = false
	game.check_button.show()
	game.check_button.text = "Conferir"
	game.find_child("RepeatButton", true, false).text = "Recomeçar"
	game.find_child("UndoButton", true, false).text = "Voltar uma ação"
	game.check_button.disabled = true
	game.cat_speech.show()
	game.speech_tail.show()
	game.demo_tag.text = "Questão oficial da aula · correção pela API."
	game.stage_hint.text = "Observe a parte marcada. Toque nas partes se quiser acompanhá-las." if legacy else "Use o instrumento para experimentar. Depois responda ao desafio."
	game.status_label.text = "Escolha uma resposta e confira." if r.response.kind == "choice" else "Digite sua resposta e confira."
	game.configuring_round = false
	lock_controls(false)
	game._show_layer("game")
	game.accessibility.continue_button.hide()
	game._update_steps()
	update_layout()
	refresh_instrument_controls()


func work_state() -> Dictionary:
	return {"observedParts": Array(game.diagram.selected_parts)} if is_legacy() else {"instrument": instrument_name(), "state": current_node().call("official_state")}


func choice() -> Variant:
	if configured and game.rounds[0].response.kind == "number":
		var text := number_answer.text.strip_edges().replace(",", ".")
		if text.is_empty() or not text.is_valid_float(): return null
		return float(text)
	return game.selected_button.get_meta("choice") if game.selected_button != null else null


func publish_draft() -> void:
	if not configured or game.configuring_round or restoring or waiting or uncertain or feedback_received: return
	post({"type":"gauss-medidas-draft", "choice":choice(), "workState":work_state()})


func lock_controls(locked: bool) -> void:
	game.diagram.interactive = not locked and not game.activity_paused
	game.apples.interactive = not locked and not game.activity_paused
	number_answer.editable = not locked
	for button in game.parts_choices.get_children(): button.disabled = locked
	for name in ["RepeatButton", "UndoButton"]: game.find_child(name, true, false).disabled = locked
	refresh_instrument_controls()


func submit_answer() -> void:
	if not configured or waiting or game.activity_paused: return
	if feedback_received:
		if game.result_correct:
			post({"type":"gauss-medidas-next"})
		else:
			# The feedback remains until the pupil explicitly chooses to try again.
			game.game_cat.start_idle()
			game.submitting = false
			feedback_received = false
			game.check_button.text = "Conferir"
			game.check_button.disabled = choice() == null
			game.status_label.text = feedback_reason
			lock_controls(false)
		return
	if choice() == null: return
	waiting = true
	game.submitting = true
	lock_controls(true)
	game.check_button.disabled = true
	game.status_label.text = "Conferindo sua resposta na API…"
	post({"type":"gauss-medidas-answer", "exerciseId":game.rounds[0].exerciseId, "choice":choice()})


func show_result(data: Dictionary) -> void:
	waiting = false
	uncertain = false
	feedback_received = true
	feedback_reason = str(data.get("reason", "Resposta registrada pela API."))
	game.result_correct = data.get("correct") == true
	game.submitting = true
	lock_controls(true)
	game.status_label.text = feedback_reason
	game.stage_hint.text = "Resposta correta registrada!" if game.result_correct else "Veja a orientação antes de tentar novamente."
	game.check_button.disabled = true
	if game.result_correct:
		game.progress.value = 1
		game.game_cat.celebrate()
	else:
		game.game_cat.fail_attempt()
	post({"type":"gauss-medidas-feedback-shown", "exerciseId":game.rounds[0].exerciseId, "correct":game.result_correct})


func finish_animation() -> void:
	game.victory_timer.stop()
	game.retry_timer.stop()
	game.check_button.text = "Continuar" if game.result_correct else "Tentar novamente"
	game.check_button.disabled = false
	game.check_button.show()
	game.check_button.grab_focus()


func reset() -> void:
	if waiting or uncertain or feedback_received or game.activity_paused: return
	show_round()
	publish_draft()


func undo() -> void:
	if waiting or uncertain or feedback_received or game.activity_paused: return
	if game.selected_button != null:
		game._reset_selection()
	elif number_answer.visible and not number_answer.text.is_empty():
		number_answer.text = ""
		game.check_button.disabled = true
	else:
		if is_legacy(): game.diagram.undo_selection()
		else: current_node().call("official_action", "undo")
	publish_draft()


func exit_to_site() -> void:
	if not waiting and not uncertain: post({"type":"gauss-medidas-exit"})


func _process(delta: float) -> void:
	if not OS.has_feature("web"): return
	poll += delta
	if poll < 0.1: return
	poll = 0
	var messages: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.gaussLabLesson.queue.splice(0))", true)))
	if messages is Array:
		for message in messages:
			if message is Dictionary: receive(message)
	if configured and bool(JavaScriptBridge.eval("window.gaussLabLesson.inspect", true)): publish_layout()


func publish_layout() -> void:
	# Opt-in diagnostics expose only visible public state and control positions.
	var controls := []
	for button in game.parts_choices.get_children():
		if game.parts_choices.visible and button.visible: controls.append(control_rect(button, "choice-" + str(button.get_index())))
	for button in instrument_buttons.get_children():
		controls.append(control_rect(button, "instrument:" + str(button.get_meta("instrument_id"))))
	if number_answer.visible: controls.append(control_rect(number_answer, "number"))
	controls.append(control_rect(game.check_button, "confirm"))
	controls.append(control_rect(game.find_child("UndoButton", true, false), "undo"))
	controls.append(control_rect(game.find_child("RepeatButton", true, false), "reset"))
	var diagram_rect: Rect2 = current_node().get_global_rect()
	var layout := {"type":"gauss-laboratorio-layout", "scene":"fraction_parts_observe" if is_legacy() else instrument_name(), "scenePath":"res://scenes/main.tscn", "exerciseId":game.rounds[0].exerciseId, "viewport":[game.get_viewport_rect().size.x,game.get_viewport_rect().size.y], "controls":controls, "diagram":[diagram_rect.position.x,diagram_rect.position.y,diagram_rect.size.x,diagram_rect.size.y], "markedParts":Array(game.diagram.marked_parts) if is_legacy() else game.rounds[0].round.model.get("markedParts", []), "choice":choice(), "workState":work_state(), "prompt":game.rounds[0].prompt, "status":game.status_label.text, "correct":game.result_correct, "waiting":waiting, "feedbackReceived":feedback_received}
	var signature := JSON.stringify(layout)
	if signature != last_layout:
		last_layout = signature
		post(layout)


func control_rect(button: Control, id: String) -> Dictionary:
	var rect := button.get_global_rect()
	return {"id":id, "text":str(button.get("text")), "disabled":button.disabled if button is Button else not number_answer.editable, "rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}


func is_legacy() -> bool:
	return configured and game.rounds[0].round.kind == "fraction_parts"


func instrument_name() -> String:
	return "parts" if is_legacy() else str(game.rounds[0].round.get("instrument", "parts")) if configured else "parts"


func current_node() -> Control:
	return game.apples if instrument_name() in ["collection", "ratio", "percentage"] else game.diagram


func instrument_hint() -> String:
	match instrument_name():
		"parts": return "Observe as partes do todo. Você pode tocar em cada uma para acompanhar."
		"collection": return "Reparta os objetos e observe os grupos. Você pode enviar e devolver."
		"ratio": return "Experimente a partilha e compare as quantidades."
		"percentage": return "Distribua os objetos e compare as partes da coleção."
		"equivalence": return "Compare os inteiros. Experimente dividir as partes."
		"comparison": return "Compare as representações usando a mesma unidade."
		"decimal": return "Observe os inteiros e as partes menores da unidade."
		"number_line": return "Explore os intervalos e as posições na reta."
		"bread_share": return "Corte os pães e reparta os pedaços entre as pessoas."
	return "Experimente o instrumento e responda ao desafio."


func _number_changed(_text: String) -> void:
	if not configured or game.configuring_round or waiting or uncertain or feedback_received: return
	game.check_button.disabled = choice() == null
	publish_draft()


func _instrument_changed() -> void:
	if not configured or game.configuring_round or restoring: return
	refresh_instrument_controls()
	publish_draft()


func refresh_instrument_controls() -> void:
	if instrument_buttons == null: return
	var descriptors: Array = [] if not configured or is_legacy() else current_node().call("official_controls")
	var locked: bool = waiting or uncertain or feedback_received or game.activity_paused
	var scale: float = game.accessibility.profile.textScale
	var signature := JSON.stringify([descriptors, locked, scale, game.accessibility.profile.contrast])
	if signature == button_signature: return
	button_signature = signature
	var focused: Control = game.get_viewport().gui_get_focus_owner()
	var old_id := str(focused.get_meta("instrument_id", "")) if focused != null else ""
	for child in instrument_buttons.get_children():
		instrument_buttons.remove_child(child)
		child.queue_free()
	for item in descriptors:
		var button := Button.new()
		game.accessibility.style_button(button)
		button.text = str(item.text)
		button.custom_minimum_size = Vector2(90, 42 * scale)
		button.add_theme_font_size_override("font_size", roundi(16 * scale))
		button.disabled = locked or item.get("disabled", false)
		button.set_meta("instrument_id", str(item.id))
		if game.accessibility.profile.contrast == "high":
			for state in ["normal", "hover", "pressed", "disabled"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color("101526")
				style.border_color = Color.WHITE
				style.set_border_width_all(2)
				game.accessibility.button_style(button, state, style)
		button.pressed.connect(_instrument_action.bind(str(item.id)))
		instrument_buttons.add_child(button)
		if str(item.id) == old_id and not button.disabled: button.grab_focus()


func _instrument_action(id: String) -> void:
	if waiting or uncertain or feedback_received or game.activity_paused: return
	current_node().call("official_action", id)
	refresh_instrument_controls()


func update_layout() -> void:
	if not configured: return
	var width: float = clampf(game.get_viewport_rect().size.x - 90, 220, 560)
	if not is_legacy():
		current_node().custom_minimum_size.x = width
		if current_node() == game.apples: game.apples.custom_minimum_size.y = 260 * game.accessibility.profile.textScale
	game.find_child("StepAnswerLabel", true, false).text = "2  •  Responda ao desafio"
	game.find_child("StepDrawLabel", true, false).text = "1  •  Explore o instrumento" if not is_legacy() else "1  •  Observe as partes"
	refresh_instrument_controls()
