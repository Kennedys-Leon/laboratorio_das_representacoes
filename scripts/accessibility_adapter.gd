extends Node

const Profile = preload("res://scripts/accessibility_profile.gd")
var profile := Profile.DEFAULTS.duplicate()
var game: Control
var ready_profile := false
var host_revision := 0
var fonts := {}
var styles := {}
var colors := {}
var wrap_modes := {}
var selected_fruits := PackedInt32Array()
var controls: HFlowContainer
var toggle: Button
var instruction: Label
var continue_button: Button
var poll := 0.0
var controls_signature := ""
var last_round := -1
var loading := false

func _ready() -> void:
	game = get_parent()
	if game.lesson_mode:
		var balloon: StyleBox = game.cat_speech.get_theme_stylebox("panel").duplicate()
		balloon.set_content_margin(SIDE_LEFT, 35)
		balloon.set_content_margin(SIDE_RIGHT, 35)
		balloon.set_content_margin(SIDE_BOTTOM, 74)
		game.cat_speech.add_theme_stylebox_override("panel", balloon)
	var content: VBoxContainer = game.find_child("GameContent", true, false)
	instruction = Label.new()
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.name = "AccessibleQuestion"
	content.add_child(instruction)
	content.move_child(instruction, 2)
	toggle = Button.new()
	toggle.text = "Usar botões"
	toggle.toggle_mode = true
	# Internal state follows the effective API profile; pupils do not choose a mode here.
	controls = HFlowContainer.new()
	content.add_child(controls)
	content.move_child(controls, 5)
	toggle.toggled.connect(func(_on): controls_signature = ""; refresh_controls())
	continue_button = Button.new()
	continue_button.text = "Continuar"
	continue_button.custom_minimum_size.y = 48
	content.add_child(continue_button)
	continue_button.hide()
	for button in [continue_button]: style_button(button)
	continue_button.pressed.connect(func():
		if game.result_correct: game._advance_after_victory()
		else: game._restart_after_failure())
	_capture(game)
	if game.lesson_mode:
		# The complete official prompt is longer than the prototype's paint hint.
		fonts[game.question_label] = 18
	if OS.has_feature("web"):
		if game.lesson_mode:
			# The host's React practice is the semantic alternative for official lessons.
			JavaScriptBridge.eval("""(() => {
 window.gaussAccess = {queue:[], actions:[], render:()=>{}};
 addEventListener('message', e => {
  if(e.origin===location.origin && e.source===parent && e.data?.version===1 && e.data.type==='gauss-accessibility-profile') window.gaussAccess.queue.push(JSON.stringify(e.data.profile));
 });
 parent.postMessage({type:'gauss-accessibility-ready'},location.origin);
})();""", true)
		else:
			JavaScriptBridge.eval(preload("res://scripts/accessibility_web_source.gd").SOURCE, true)
	if game.lesson_mode:
		var safe := Profile.DEFAULTS.duplicate()
		safe.reducedMotion = true
		apply_profile(safe)
		return
	if game.api.has_session() or (OS.has_feature("web") and bool(JavaScriptBridge.eval("window.parent !== window", true))):
		loading = true
		game.play_button.disabled = true
		game.menu_cat.set_reduced_motion(true)
		for n in ["MenuDecor", "GameDecor", "HowDecor", "FeedbackDecor"]: game.find_child(n,true,false).hide()
		load_profile()
	else:
		apply_profile(profile)

func _capture(node: Node) -> void:
	if node is Control:
		fonts[node] = node.get_theme_font_size("font_size")
		if node is Label: wrap_modes[node] = node.autowrap_mode
		var saved_styles := {}
		var saved_colors := {}
		for property in node.get_property_list():
			var key: String = property.name
			if key.begins_with("theme_override_styles/") and node.get(key) != null: saved_styles[key] = node.get(key)
			if key.begins_with("theme_override_colors/"): saved_colors[key] = node.get(key)
		styles[node] = saved_styles
		for color_key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
			saved_colors["theme_override_colors/"+color_key] = node.get_theme_color(color_key)
		colors[node] = saved_colors
	for child in node.get_children(): _capture(child)

func style_button(button: Button) -> void:
	var source: Button = game.find_child("BackMenuButton",true,false)
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,source.get_theme_stylebox(state))
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(state,source.get_theme_color(state))
	for state in ["font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state,source.get_theme_color("font_color"))
	button.add_theme_font_size_override("font_size",18)

func load_profile() -> void:
	var revision := host_revision
	var received: Dictionary = await game.api.get_accessibility_profile()
	if revision != host_revision: return
	if received.get("ok", false) and apply_profile(received.data): return
	loading = false
	# No anonymous cache: a failed request must never reuse another pupil's profile.
	var safe := Profile.DEFAULTS.duplicate()
	safe.reducedMotion = true
	safe.focusMode = true
	apply_profile(safe)
	game.find_child("DemoTag",true,false).text = "Não foi possível carregar seus ajustes. Você pode jogar com menos movimento e usar a atividade em texto."

func apply_profile(value: Variant) -> bool:
	var valid := Profile.validate(value)
	if valid.is_empty(): return false
	if ready_profile and profile == valid: return true
	var previous_pace: String = profile.pace
	profile = valid
	ready_profile = true
	loading = false
	game.play_button.disabled = game.transitioning_to_game
	game.menu_cat.set_reduced_motion(profile.reducedMotion or profile.focusMode)
	game.game_cat.reduced_motion = profile.reducedMotion or profile.focusMode
	if game.game_cat.reduced_motion:
		if game.game_cat.failing and not game.game_cat.failure_done: game.game_cat._animate_failure(4.0)
		elif game.game_cat.celebrating and not game.game_cat.celebration_done: game.game_cat._animate_celebration(2.3)
	if profile.reducedMotion:
		game._cancel_speech_transition()
		if game.menu_speech_tween != null: game.menu_speech_tween.kill()
		if game.walk_speech_tween != null: game.walk_speech_tween.kill()
		game.menu_speech_pop.clear()
		game._hide_walk_speech()
	toggle.button_pressed = profile.preferredInput != "auto" or profile.accessibleActivity == "react"
	game._update_layout()
	apply_visuals()
	refresh_controls()
	if previous_pace != profile.pace and (game.game_cat.failure_done or game.game_cat.celebration_done): schedule_continuation()
	return true

func apply_visuals() -> void:
	if not ready_profile: return
	var high: bool = profile.contrast == "high"
	var large: bool = profile.textScale > 1
	var text_instructions: bool = high or large or profile.focusMode or profile.audioAssistance or game.size.x < 700.0
	game.how_layer.get_node("HowArtLayer").visible = not text_instructions
	game.how_layer.get_node("Scroll").visible = text_instructions
	for name in ["GameNavigation", "ProgressRow", "Steps"]:
		game.find_child(name,true,false).vertical = large or (name == "GameNavigation" and game.size.x < 520)
	game.find_child("CatSpace",true,false).visible = not large and game.size.x >= 900
	game.find_child("Eyebrow",true,false).visible = not profile.focusMode
	game.feedback_cat.visible = not large and not profile.focusMode and game.size.x >= 900
	for node in fonts:
		if not is_instance_valid(node): continue
		var base: int = fonts[node]
		if node.name == "MenuTitle" or node.name == "MenuTitleShadow": base = 34 if game.size.x < 900 else 49
		node.add_theme_font_size_override("font_size", roundi(base * profile.textScale))
		for key in styles[node]: node.set(key, styles[node][key])
		for key in colors[node]: node.set(key, colors[node][key])
		if high:
			for key in colors[node]: node.set(key, Color.WHITE)
			for key in styles[node]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color("101526")
				style.border_color = Color("ffffff")
				style.set_border_width_all(2)
				style.set_corner_radius_all(10)
				if styles[node][key] is StyleBox:
					for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side, styles[node][key].get_content_margin(side))
				node.set(key,style)
			for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
				node.add_theme_color_override(key, Color.WHITE)
		if node is Label: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if large else wrap_modes[node]
		if node is Button:
			node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, maxf(48, 32 * profile.textScale))
			node.add_theme_color_override("font_focus_color", Color.WHITE if high else colors[node]["theme_override_colors/font_color"])
			var focus := StyleBoxFlat.new()
			focus.bg_color = Color.TRANSPARENT
			focus.border_color = Color("ffcc33") if high else Color("602ba0")
			focus.set_border_width_all(3 if high else 1)
			node.add_theme_stylebox_override("focus", focus)
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			node.accessibility_name = node.text
	game.find_child("MenuTitleShadow", true, false).visible = not high
	for n in ["MenuDecor", "GameDecor", "HowDecor", "FeedbackDecor"]:
		var decor: Control = game.find_child(n,true,false)
		decor.visible = not profile.focusMode and (n != "HowDecor" or text_instructions)
		decor.set_process(not profile.reducedMotion)
	game.game_background.visible = game.current_layer in ["game","feedback"] and not profile.focusMode
	game.find_child("LaboratorioBackground",true,false).visible = not profile.focusMode
	game.cat_area.visible = not (large or profile.focusMode)
	game.cat_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	instruction.visible = large or profile.focusMode
	instruction.text = game.question_label.text
	if large:
		game.game_row.vertical = true
		game.menu_content.custom_minimum_size.x = 0
		game.menu_cat.hide()
		for group in [game.parts_choices,game.collection_choices]:
			for button in group.get_children(): button.custom_minimum_size.x = minf(260,game.size.x - 80)
	if profile.focusMode: game.menu_cat.hide()
	game.diagram.marked_color = Color("5520a0") if high else Color("aa77e8")
	game.diagram.text_scale = profile.textScale
	game.apples.text_scale = profile.textScale
	game.apples.custom_minimum_size.y = (260 if game.apples.official_mode else 220) * profile.textScale
	game.diagram.queue_redraw()
	game.apples.queue_redraw()
	for timer in [game.victory_timer,game.retry_timer]: timer.wait_time = 6 if profile.pace == "extended" else 3
	if game.lesson_mode and game.lesson_bridge != null:
		game.lesson_bridge.update_layout()

func schedule_continuation() -> void:
	if game.lesson_mode:
		game.victory_timer.stop()
		game.retry_timer.stop()
		continue_button.hide()
		return
	game.victory_timer.stop()
	game.retry_timer.stop()
	continue_button.visible = profile.pace == "untimed"
	if continue_button.visible:
		continue_button.text = "Próxima questão" if game.result_correct else "Tentar novamente"
		continue_button.grab_focus()
	else:
		var timer: Timer = game.victory_timer if game.result_correct else game.retry_timer
		timer.start(6 if profile.pace == "extended" else 3)

func set_paused(value: bool) -> void:
	game.activity_paused = value
	game.game_cat.set_process(not value)
	game.victory_timer.paused = value
	game.retry_timer.paused = value
	game.diagram.interactive = not value and not game.submitting
	game.apples.interactive = not value and not game.submitting
	continue_button.disabled = value
	controls_signature = ""

func descriptors() -> Array:
	var list: Array = []
	if game.lesson_mode:
		# Official lessons use the site's semantic React alternative. Their controls
		# are part of the original Godot scene, owned by the lesson bridge.
		return list
	if game.current_layer != "game":
		return [{"text":"Jogar", "action":"play", "index":0, "disabled":loading or game.transitioning_to_game}]
	var data: Dictionary = game.rounds[game.round_index].round
	if game.activity_paused:
		return [{"text":"Retomar", "action":"pause", "index":0, "disabled":false},{"text":"Início", "action":"menu", "index":0, "disabled":false}]
	if not game.stage_complete:
		var count: int = int(data.equalParts) if data.kind == "fraction_parts" else int(data.objectCount)
		for i in count:
			var selected: bool = game.diagram.selected_parts.has(i) if data.kind == "fraction_parts" else selected_fruits.has(i)
			var used: bool = data.kind != "fraction_parts" and game.apples._group_of(i) >= 0
			list.append({"text":("Parte " if data.kind == "fraction_parts" else "Fruta ") + str(i+1) + (" ✓" if selected else " (no grupo)" if used else ""), "action":"part" if data.kind == "fraction_parts" else "fruit", "index":i, "disabled":game.submitting or used, "toggle":true, "selected":selected})
		if data.kind != "fraction_parts": list.append({"text":"Formar grupo", "action":"group", "index":0, "disabled":game.submitting})
	else:
		for i in game._active_choices().get_child_count():
			var b: Button = game._active_choices().get_child(i)
			if b.visible: list.append({"text":b.text, "action":"choice", "index":i, "disabled":b.disabled or game.submitting, "toggle":true, "selected":game.selected_button == b})
		list.append({"text":"Conferir", "action":"check", "index":0, "disabled":game.check_button.disabled or game.submitting})
	list.append({"text":"Voltar uma ação", "action":"undo", "index":0, "disabled":game.submitting})
	list.append({"text":"Recomeçar", "action":"reset", "index":0, "disabled":game.submitting})
	if continue_button.visible: list.append({"text":continue_button.text, "action":"continue", "index":0, "disabled":false})
	list.append({"text":"Início", "action":"menu", "index":0, "disabled":false})
	list.append({"text":"Pausar", "action":"pause", "index":0, "disabled":false})
	return list

func action(kind: String, index: int) -> void:
	match kind:
		"open": toggle.button_pressed = true
		"play":
			if not loading and not game.transitioning_to_game: game._play()
		"menu": game._show_layer("menu")
		"pause": set_paused(not game.activity_paused)
		"continue":
			if game.lesson_mode:
				game._check()
				return
			if continue_button.visible: continue_button.pressed.emit()
		_:
			if game.current_layer != "game" or game.submitting or game.activity_paused: return
			match kind:
				"part": game.diagram.select_part(index)
				"fruit":
					if index < 0 or index >= game.apples.apple_count or game.apples._group_of(index) >= 0: return
					if selected_fruits.has(index): selected_fruits.remove_at(selected_fruits.find(index))
					else: selected_fruits.append(index)
				"group":
					if game.apples.submit_indices(selected_fruits): selected_fruits.clear()
				"choice":
					if index >= 0 and index < game._active_choices().get_child_count(): game._select(game._active_choices().get_child(index))
				"check": game._check()
				"undo":
					if not selected_fruits.is_empty(): selected_fruits.remove_at(selected_fruits.size()-1)
					else: game._undo()
				"reset":
					selected_fruits.clear()
					game._repeat()
	refresh_controls()
	if game.stage_complete and kind in ["part","group"]:
		game._active_choices().get_child(0).grab_focus()

func refresh_controls() -> void:
	if not ready_profile: return
	controls.visible = toggle.button_pressed and not game.stage_complete and not game.submitting
	instruction.text = game.question_label.text
	if last_round != game.round_index:
		selected_fruits.clear()
		last_round = game.round_index
	if not game.submitting: continue_button.hide()
	var list := descriptors()
	var signature := JSON.stringify(list)
	if signature == controls_signature: return
	controls_signature = signature
	var focused := game.get_viewport().gui_get_focus_owner()
	var old_key: String = focused.get_meta("access_key", "") if focused != null else ""
	for child in controls.get_children():
		controls.remove_child(child)
		child.queue_free()
	for item in list:
		if item.action not in ["part","fruit","group"]: continue
		var b := Button.new()
		style_button(b)
		b.text = item.text
		b.disabled = item.disabled
		b.custom_minimum_size = Vector2(110,48)
		b.add_theme_font_size_override("font_size",roundi(18*profile.textScale))
		if profile.contrast == "high":
			for state in ["normal","hover","pressed","disabled"]:
				var box := StyleBoxFlat.new()
				box.bg_color = Color("101526")
				box.border_color = Color.WHITE
				box.set_border_width_all(2)
				button_style(b,state,box)
		b.set_meta("access_key",item.action+str(item.index))
		b.pressed.connect(action.bind(item.action,item.index))
		controls.add_child(b)
		if b.get_meta("access_key") == old_key and not b.disabled: b.grab_focus()

func button_style(button: Button, state: String, box: StyleBox) -> void:
	button.add_theme_stylebox_override(state,box)
	for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]: button.add_theme_color_override(key,Color.WHITE)

func _process(delta: float) -> void:
	poll += delta
	if poll < 0.15: return
	poll = 0
	if not game.submitting: continue_button.hide()
	refresh_controls()
	if OS.has_feature("web"):
		var active_token := "" if game.lesson_mode else str(JavaScriptBridge.eval("window.localStorage.getItem('gauss.student.session') || ''",true))
		if not game.lesson_mode and active_token != game.api.token:
			host_revision += 1
			game.api.token = active_token
			game.submitting = false
			game.pending_attempt.clear()
			selected_fruits.clear()
			game._show_layer("menu")
			game._load_demo_rounds()
			var safe := Profile.DEFAULTS.duplicate()
			safe.reducedMotion = true
			apply_profile(safe)
			JavaScriptBridge.eval("window.gaussAccess.queue.length=0; window.gaussAccess.actions.length=0; window.gaussAccess.signature='';",true)
			if not active_token.is_empty(): load_profile()
		var queued: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.gaussAccess?.queue.splice(0) || [])",true)))
		if queued is Array:
			for raw in queued:
				if apply_profile(JSON.parse_string(raw)): host_revision += 1
		var actions: Variant = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.gaussAccess?.actions.splice(0) || [])",true)))
		if actions is Array:
			for item in actions:
				if item is Array and item.size()==2: action(str(item[0]),int(item[1]))
		var state := {"title":"Laboratório das Representações", "question":game.question_label.text if game.current_layer == "game" else "Vamos representar frações!", "status":game.status_label.text if game.current_layer == "game" else "", "controls":descriptors(), "scale":profile.textScale, "high":profile.contrast=="high", "preferText":profile.accessibleActivity=="react"}
		JavaScriptBridge.eval("window.gaussAccess?.render("+JSON.stringify(state)+")",true)
