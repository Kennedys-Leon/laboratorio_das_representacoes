extends Control

# A aparência e a hierarquia ficam em main.tscn.
const GAME_ID := "laboratorio-das-representacoes"
const SKILL_ID := "EF03MA09"
const DEMO_CONTENT = preload("res://content/grade3_fractions_preview.json")
const INK := Color("211737")
const PURPLE := Color("2a1450")
const GREEN := Color("a5ea79")
const MENU_SPEECH_SCALE := Vector2.ONE / 1.15
const MENU_GREETINGS := [
	"Vamos lá!!!",
	"Matemática é o código invisível que orgâniza a vida!",
	"Tenha sonhos grandes e a força para conquistá-los maior ainda",
	"Sigam-me os bons!",
]
@onready var game_background: TextureRect = find_child("GameBackground", true, false)
@onready var background_dim: ColorRect = find_child("BackgroundDim", true, false)
@onready var menu_layer: Control = find_child("MenuLayer", true, false)
@onready var game_layer: Control = find_child("GameLayer", true, false)
@onready var feedback_layer: Control = find_child("FeedbackLayer", true, false)
@onready var how_layer: Control = find_child("HowLayer", true, false)
@onready var menu_cat: CatAnimator = find_child("MenuCat", true, false)
@onready var menu_speech: PanelContainer = find_child("MenuSpeech", true, false)
@onready var menu_speech_label: Label = find_child("MenuSpeechLabel", true, false)
@onready var menu_speech_tail: Control = find_child("MenuSpeechTail", true, false)
@onready var menu_speech_pop: SpeechPop = find_child("MenuSpeechPop", true, false)
@onready var walk_speech: PanelContainer = find_child("WalkSpeech", true, false)
@onready var walk_speech_tail: Control = find_child("WalkSpeechTail", true, false)
@onready var game_cat: GameCatIdle = find_child("GameCat", true, false)
@onready var game_row: BoxContainer = find_child("GameRow", true, false)
@onready var game_card: PanelContainer = find_child("GameCard", true, false)
@onready var game_header: PanelContainer = find_child("GameHeader", true, false)
@onready var cat_area: Control = find_child("CatArea", true, false)
@onready var cat_speech: PanelContainer = find_child("CatSpeech", true, false)
@onready var speech_tail: Control = find_child("SpeechTail", true, false)
@onready var speech_pop: SpeechPop = find_child("SpeechPop", true, false)
@onready var cat_platform: Panel = find_child("CatPlatform", true, false)
@onready var play_button: Button = find_child("PlayButton", true, false)
@onready var feedback_cat: TextureRect = find_child("FeedbackCat", true, false)
@onready var menu_content: VBoxContainer = find_child("MenuContent", true, false)
@onready var question_label: Label = find_child("QuestionLabel", true, false)
@onready var round_label: Label = find_child("RoundLabel", true, false)
@onready var progress: ProgressBar = find_child("RoundProgress", true, false)
@onready var diagram: Control = find_child("FractionDiagram", true, false)
@onready var apples: Control = find_child("AppleCollection", true, false)
@onready var stage_hint: Label = find_child("StageHint", true, false)
@onready var parts_choices: HFlowContainer = find_child("PartsChoices", true, false)
@onready var collection_choices: HFlowContainer = find_child("CollectionChoices", true, false)
@onready var status_label: Label = find_child("StatusLabel", true, false)
@onready var check_button: Button = find_child("CheckButton", true, false)
@onready var feedback_title: Label = find_child("FeedbackTitle", true, false)
@onready var feedback_explanation: Label = find_child("FeedbackExplanation", true, false)
@onready var feedback_action: Button = find_child("FeedbackActionButton", true, false)
@onready var demo_tag: Label = find_child("GameDemoTag", true, false)

@onready var step_active_style: StyleBox = find_child("StepDraw", true, false).get_theme_stylebox("panel")
@onready var step_waiting_style: StyleBox = find_child("StepAnswer", true, false).get_theme_stylebox("panel")

var victory_timer := Timer.new()
var retry_timer := Timer.new()

var api: Node = preload("res://scripts/gauss_api.gd").new()
var rounds: Array[Dictionary] = []
var online_rounds := false
var submitting := false
var pending_attempt := {}
var round_index := 0
var selected_button: Button
var result_correct := false
var previous_layer := "menu"
var current_layer := "menu"
var base_styles := {}
var base_font_colors := {}
var transitioning_to_game := false
var stage_complete := false
var configuring_round := false
var speech_generation := 0
var speech_tween: Tween
var menu_speech_tween: Tween
var walk_speech_tween: Tween
var student_name := ""
var greeting_rng := RandomNumberGenerator.new()
var accessibility: Node
var activity_paused := false
var tutorial_pending := false
var tutorial_checked_token := "__unchecked__"
var tutorial_key := "demo"
var tutorial_seen := false
var tutorial_storage_path := "user://tutorial.cfg"
var parchment_card_style: StyleBox
var parchment_header_style: StyleBox
var mobile_card_style: StyleBoxFlat
var mobile_header_style: StyleBoxFlat



func _ready() -> void:
	parchment_card_style = game_card.get_theme_stylebox("panel")
	parchment_header_style = game_header.get_theme_stylebox("panel")
	mobile_card_style = StyleBoxFlat.new()
	mobile_card_style.bg_color = Color("fffaf0")
	mobile_card_style.border_color = Color("d6bce5")
	mobile_card_style.set_border_width_all(2)
	mobile_card_style.set_corner_radius_all(24)
	mobile_card_style.set_content_margin_all(20)
	mobile_header_style = StyleBoxFlat.new()
	mobile_header_style.bg_color = Color("39205f")
	mobile_header_style.set_corner_radius_all(16)
	mobile_header_style.set_content_margin_all(12)
	retry_timer.one_shot = true
	retry_timer.wait_time = 3.0
	add_child(retry_timer)
	retry_timer.timeout.connect(_restart_after_failure)
	victory_timer.one_shot = true
	victory_timer.wait_time = 3.0
	add_child(victory_timer)
	victory_timer.timeout.connect(_advance_after_victory)
	add_child(api)
	greeting_rng.randomize()
	student_name = OS.get_environment("GAUSS_STUDENT_NAME").strip_edges()
	_show_menu_greeting()
	if api.call("has_session"):
		_load_student_name()
	_load_demo_rounds()
	for group in [parts_choices, collection_choices]:
		for child in group.get_children():
			if child is Button:
				base_styles[child] = child.get_theme_stylebox("normal").duplicate()
				base_font_colors[child] = child.get_theme_color("font_color")
				child.pressed.connect(_select.bind(child))
	play_button.pressed.connect(_play)
	menu_cat.walk_started.connect(_show_walk_speech)
	menu_cat.walk_finished.connect(_hide_walk_speech)
	find_child("HowButton", true, false).pressed.connect(func(): _open_modal("how"))
	find_child("ExitButton", true, false).pressed.connect(_exit_game)
	find_child("HowBackButton", true, false).pressed.connect(_return_from_modal)
	find_child("HowArtBackButton", true, false).pressed.connect(_return_from_modal)
	find_child("BackMenuButton", true, false).pressed.connect(func(): _show_layer("menu"))
	find_child("RepeatButton", true, false).pressed.connect(_repeat)
	find_child("UndoButton", true, false).pressed.connect(_undo)
	check_button.pressed.connect(_check)
	feedback_action.pressed.connect(_after_feedback)
	game_cat.celebration_finished.connect(_on_celebration_finished)
	game_cat.failure_finished.connect(_on_failure_finished)
	diagram.selection_changed.connect(_on_diagram_selection_changed)
	apples.groups_changed.connect(_on_groups_changed)
	apples.group_rejected.connect(_on_group_rejected)
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)
	_show_round()
	accessibility = preload("res://scripts/accessibility_adapter.gd").new()
	add_child(accessibility)


func _load_student_name() -> void:
	var received: Dictionary = await api.call("get_student_profile")
	if not received.get("ok", false):
		return
	var profile: Dictionary = received.data
	if profile.get("role", "") != "student":
		return
	student_name = str(profile.get("displayName", "")).strip_edges()
	if current_layer == "menu" and not transitioning_to_game:
		_show_menu_greeting()


func _show_menu_greeting() -> void:
	if menu_speech_tween != null and menu_speech_tween.is_running():
		menu_speech_tween.kill()
	var phrases := MENU_GREETINGS.duplicate()
	if not student_name.is_empty():
		phrases.append("Olá %s vamos aprender hoje?" % student_name)
	menu_speech_label.size.x = 274.0
	menu_speech_label.text = phrases[greeting_rng.randi_range(0, phrases.size() - 1)]
	menu_speech.scale = MENU_SPEECH_SCALE
	menu_speech.pivot_offset = Vector2.ZERO
	menu_speech.modulate.a = 1.0
	menu_speech.show()
	menu_speech_tail.hide()
	menu_speech_pop.clear()
	call_deferred("_align_menu_greeting")


func _align_menu_greeting() -> void:
	await get_tree().process_frame
	var center := 120.0
	menu_speech.size = Vector2(360, maxf(230, menu_speech.get_combined_minimum_size().y))
	menu_speech.position = Vector2(center - menu_speech.size.x * MENU_SPEECH_SCALE.x * 0.5, -24.0 - menu_speech.size.y * MENU_SPEECH_SCALE.y)
	menu_speech_tail.size = Vector2(48, 32)
	menu_speech_tail.position = Vector2(center + 8, menu_speech.position.y + menu_speech.size.y * MENU_SPEECH_SCALE.y - 1.5)
	menu_speech_tail.set("curved", true)
	menu_speech_tail.set("tip_fraction", -8.0 / 48.0)


func _pop_menu_greeting() -> void:
	if accessibility != null and accessibility.profile.reducedMotion:
		menu_speech.hide()
		menu_speech_tail.hide()
		return
	menu_speech.pivot_offset = menu_speech.size * Vector2(0.5, 0.65)
	menu_speech_tail.hide()
	menu_speech_tween = create_tween()
	menu_speech_tween.tween_property(menu_speech, "scale", MENU_SPEECH_SCALE * Vector2(1.08, 0.88), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	menu_speech_tween.tween_property(menu_speech, "scale", MENU_SPEECH_SCALE * Vector2(0.04, 0.04), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	menu_speech_tween.tween_callback(func():
		menu_speech_pop.burst(menu_speech.position + menu_speech.size * Vector2(0.5, 0.6) - menu_speech_pop.position)
		menu_speech.hide()
	)


func _show_walk_speech() -> void:
	if walk_speech_tween != null and walk_speech_tween.is_running():
		walk_speech_tween.kill()
	walk_speech.show()
	walk_speech_tail.hide()
	walk_speech.modulate.a = 0.0
	walk_speech_tail.modulate.a = 0.0
	walk_speech.scale = Vector2(0.92, 0.92)
	walk_speech_tween = create_tween().set_parallel(true)
	walk_speech_tween.tween_property(walk_speech, "modulate:a", 1.0, 0.22)
	walk_speech_tween.tween_property(walk_speech, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	walk_speech_tween.tween_property(walk_speech_tail, "modulate:a", 1.0, 0.22)


func _hide_walk_speech() -> void:
	if walk_speech_tween != null and walk_speech_tween.is_running():
		walk_speech_tween.kill()
	walk_speech.hide()
	walk_speech_tail.hide()


func _update_layout() -> void:
	var width := get_viewport_rect().size.x
	for layer in [menu_layer, game_layer, feedback_layer, how_layer]:
		var page: VBoxContainer = layer.find_child("Page", true, false)
		var max_width := 1050.0 if layer == game_layer or layer == feedback_layer else 960.0 if layer == menu_layer else 750.0
		page.custom_minimum_size.x = maxf(300.0, minf(width - 24.0, max_width))
	var narrow := width < 900.0
	var compact := width < 520.0
	game_card.add_theme_stylebox_override("panel", mobile_card_style if narrow else parchment_card_style)
	game_header.add_theme_stylebox_override("panel", mobile_header_style if narrow else parchment_header_style)
	menu_cat.visible = width >= 850.0
	var cat_shift := maxf(0.0, (1000.0 - width) * 0.7)
	menu_cat.offset_left = -360.0 + cat_shift
	menu_cat.offset_right = -140.0 + cat_shift
	feedback_cat.visible = not narrow
	menu_content.custom_minimum_size.x = 0.0 if narrow else 615.0
	var menu_art_width := maxf(280.0, minf(width - 24.0, 430.0))
	var eyebrow: Label = find_child("Eyebrow", true, false)
	eyebrow.offset_left = 0.0 if narrow else -20.0
	eyebrow.offset_right = eyebrow.offset_left + menu_art_width
	eyebrow.add_theme_font_size_override("font_size", 11 if narrow else 15)
	var eyebrow_ribbon: TextureRect = eyebrow.get_node("EyebrowRibbon")
	eyebrow_ribbon.offset_top = -32.0 if narrow else -40.0
	eyebrow_ribbon.offset_bottom = 32.0 if narrow else 40.0
	var title_divider: TextureRect = find_child("TitleDivider", true, false)
	title_divider.offset_left = 25.0 if narrow else 60.0
	title_divider.offset_right = title_divider.offset_left + (minf(240.0, width - 40.0) if narrow else 265.0)
	find_child("DemoTag", true, false).custom_minimum_size.x = minf(448.0, width - 24.0)
	var title: Label = find_child("MenuTitle", true, false)
	var title_size := 34 if narrow else 49
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_constant_override("line_spacing", -8 if narrow else -18)
	var title_shadow: Label = title.get_node("MenuTitleShadow")
	title_shadow.text = title.text
	title_shadow.add_theme_font_size_override("font_size", title_size)
	title_shadow.add_theme_constant_override("line_spacing", -8 if narrow else -18)
	for menu_button in [play_button, find_child("HowButton", true, false), find_child("ExitButton", true, false)]:
		menu_button.custom_minimum_size.x = minf(370.0, width - 40.0)
	game_row.vertical = narrow
	game_row.move_child(cat_area, 0 if narrow else 1)
	cat_area.custom_minimum_size = Vector2(0, 230 if compact else 245) if narrow else Vector2(330, 540)
	cat_platform.visible = false
	cat_platform.anchor_left = 0.5 if compact else 1.0
	cat_platform.anchor_right = cat_platform.anchor_left
	cat_platform.offset_left = -72.0 if compact else -176.0
	cat_platform.offset_right = 72.0 if compact else -18.0
	cat_platform.offset_top = -5.0 if compact else -7.0
	cat_platform.offset_bottom = 7.0 if compact else 5.0
	cat_speech.anchor_right = 0.62 if compact else 1.0 if not narrow else 0.66
	question_label.add_theme_font_size_override("font_size", 16 if compact else 20)
	find_child("HowText", true, false).add_theme_font_size_override("font_size", 19 if compact else 21)
	cat_speech.offset_top = 10.0 if narrow else 85.0
	cat_speech.offset_bottom = 250.0 if compact else 255.0 if narrow else 330.0
	speech_tail.anchor_left = 0.58 if compact else 0.62 if narrow else 0.42
	speech_tail.anchor_right = speech_tail.anchor_left
	speech_tail.offset_left = -19.0 if not narrow else 0.0
	speech_tail.offset_right = 19.0 if not narrow else 38.0
	speech_tail.offset_top = cat_speech.offset_bottom - 1.0
	speech_tail.offset_bottom = cat_speech.offset_bottom + 34.0
	game_cat.anchor_left = 0.5 if not narrow else 1.0
	game_cat.anchor_right = game_cat.anchor_left
	game_cat.offset_left = -185.0 if compact else -220.0 if narrow else -137.0
	game_cat.offset_right = 35.0 if compact else 0.0 if narrow else 83.0
	game_cat.offset_top = -228.0 if narrow else -207.0
	game_cat.offset_bottom = -28.0 if narrow else -7.0
	game_cat.scale = Vector2.ONE * (0.55 if compact else 0.9 if narrow else 1.12)
	game_cat.get_node("PotionTable").set("short_legs", narrow)
	var standing_legs: TextureRect = game_cat.get_node("StandingLegs")
	standing_legs.offset_top = 220.0 if narrow else 225.0
	standing_legs.offset_bottom = 248.0 if narrow else 263.0
	apples.custom_minimum_size.x = clampf(width - 80.0, 220.0, 560.0)
	for group in [parts_choices, collection_choices]:
		for item in group.get_children():
			if item is Button:
				item.custom_minimum_size.x = maxf(100.0, (width - 78.0) / 2.0) if width < 520.0 else 145.0
	for button_name in ["RepeatButton", "UndoButton", "CheckButton"]:
		var button: Button = find_child(button_name, true, false)
		button.custom_minimum_size.x = 145.0 if not narrow else minf(150.0, (width - 78.0) / 2.0)
	_update_steps()
	if accessibility != null and accessibility.ready_profile: accessibility.apply_visuals()


func _show_layer(name: String) -> void:
	if name != "game":
		victory_timer.stop()
		retry_timer.stop()
	current_layer = name
	game_background.visible = name == "game" or name == "feedback"
	find_child("MenuBackground", true, false).visible = name == "menu"
	background_dim.color = Color(0.09, 0.03, 0.17, 0.18 if game_background.visible else 0.38)
	menu_layer.visible = name == "menu"
	game_layer.visible = name == "game"
	feedback_layer.visible = name == "feedback"
	how_layer.visible = name == "how"
	var layer: Control = {"menu": menu_layer, "game": game_layer, "feedback": feedback_layer, "how": how_layer}[name]
	var scroll: ScrollContainer = layer.find_child("Scroll", true, false)
	scroll.scroll_vertical = 0
	if name == "menu":
		_hide_walk_speech()
		menu_cat.start_idle()
		_show_menu_greeting()
		play_button.disabled = false
		transitioning_to_game = false
	elif name == "game":
		game_cat.start_idle()
	if accessibility != null:
		accessibility.apply_visuals()
		if name == "menu" or name == "how":
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null: focused.release_focus()
		elif name == "game": find_child("BackMenuButton",true,false).grab_focus()


func _play() -> void:
	if transitioning_to_game:
		return
	transitioning_to_game = true
	var account_token: String = api.token
	play_button.disabled = true
	if tutorial_checked_token != account_token:
		tutorial_key = "demo"
		if api.has_session():
			var identity: Dictionary = await api.get_student_profile()
			if account_token != api.token:
				transitioning_to_game = false
				play_button.disabled = false
				return
			if identity.get("ok", false) and identity.data.has("id"):
				tutorial_key = (api.base_url + str(identity.data.get("institutionId", "")) + str(identity.data.id)).sha256_text()
			else:
				tutorial_key = "unresolved"
		var saved := ConfigFile.new()
		saved.load(tutorial_storage_path)
		tutorial_seen = bool(saved.get_value("completed", tutorial_key, false)) if tutorial_key != "unresolved" else false
		tutorial_checked_token = account_token
	if not tutorial_seen:
		tutorial_pending = true
		transitioning_to_game = false
		play_button.disabled = false
		_open_modal("how")
		return
	_pop_menu_greeting()
	if menu_cat.visible and not menu_cat.reduced_motion:
		menu_cat.walk_out()
		await menu_cat.walk_finished
	if account_token != api.token or not transitioning_to_game: return
	round_index = 0
	await _load_session_rounds()
	if account_token != api.token or not transitioning_to_game: return
	if rounds.is_empty():
		_show_layer("menu")
		return
	_show_round()
	_show_layer("game")
	transitioning_to_game = false


func _open_modal(name: String) -> void:
	previous_layer = current_layer
	_show_layer(name)


func _return_from_modal() -> void:
	if tutorial_pending:
		tutorial_pending = false
		if tutorial_checked_token != api.token:
			_show_layer("menu")
			return
		tutorial_seen = true
		if tutorial_key != "unresolved":
			var saved := ConfigFile.new()
			saved.load(tutorial_storage_path)
			saved.set_value("completed", tutorial_key, true)
			saved.save(tutorial_storage_path)
		_show_layer("menu")
		_play()
		return
	_show_layer(previous_layer)


func _exit_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({type:'gauss-laboratorio-exit'}, window.location.origin)")
	else:
		get_tree().quit()


func _load_demo_rounds() -> void:
	var parsed: Variant = DEMO_CONTENT.data
	rounds.clear()
	if parsed is Dictionary and parsed.has("rounds"):
		for item in parsed.rounds:
			rounds.append(item)
	online_rounds = false


func _load_session_rounds() -> void:
	var account_token: String = api.token
	_load_demo_rounds()
	if not api.call("has_session"):
		return
	var received: Dictionary = await api.call("get_grade_three_lessons")
	if api.token != account_token: return
	if not received.get("ok", false):
		return # The local preview remains clearly labeled as unrecorded.
	var catalog: Dictionary = received.data
	if int(catalog.get("schoolYear", 0)) != 3:
		rounds.clear()
		var notice := AcceptDialog.new()
		notice.title = "Atividade do 3º ano"
		notice.dialog_text = "Este jogo está disponível somente para alunos do 3º ano."
		add_child(notice)
		notice.popup_centered()
		notice.confirmed.connect(notice.queue_free)
		return
	var published: Array[Dictionary] = []
	for lesson in catalog.get("lessons", []):
		if not lesson is Dictionary or lesson.get("skillId") != SKILL_ID:
			continue
		var supports_third_year := false
		for year in lesson.get("schoolYears", []):
			if int(year) == 3:
				supports_third_year = true
		if not lesson.get("gameIds", []).has(GAME_ID) or not supports_third_year:
			continue
		for exercise in lesson.get("exercises", []):
			if not exercise is Dictionary or not exercise.has("round") or not exercise.round is Dictionary:
				continue
			if not ["fraction_parts", "fraction_collection"].has(exercise.round.get("kind")):
				continue
			# Earlier published content lacks the drawing step and fraction answers.
			# Keep the complete local activity until the revised lesson is available.
			if exercise.answerMode != "choice" or exercise.get("choices", []).size() < 4:
				return
			if not exercise.round.has("answerPrompt"):
				return
			if exercise.round.kind == "fraction_parts" and not exercise.round.has("shape"):
				return
			if exercise.round.kind == "fraction_collection" and not exercise.round.has("objectStyle"):
				return
			var phase_id := _phase_for_exercise(lesson, str(exercise.id))
			if phase_id.is_empty():
				continue
			published.append({
				"contractVersion": 1, "gameId": GAME_ID,
				"lessonId": lesson.id, "lessonVersion": lesson.version,
				"phaseId": phase_id, "exerciseId": exercise.id,
				"schoolYear": 3, "skillId": SKILL_ID,
				"bnccCodes": lesson.bnccCodes, "practiceMode": "free_practice",
				"prompt": exercise.prompt,
				"accessibleDescription": exercise.accessibleDescription,
				"response": {"kind": "choice", "choices": exercise.choices}
					if exercise.answerMode == "choice" else {"kind": "number"},
				"round": exercise.round,
			})
	if published.is_empty():
		return
	rounds = published
	online_rounds = true


func _phase_for_exercise(lesson: Dictionary, exercise_id: String) -> String:
	for phase in lesson.get("phases", []):
		if phase.get("exerciseIds", []).has(exercise_id):
			return str(phase.id)
		for step in phase.get("teachingSteps", []):
			if step.get("checkExerciseId", "") == exercise_id:
				return str(phase.id)
	return ""


func _active_choices() -> HFlowContainer:
	return parts_choices if rounds[round_index].round.kind == "fraction_parts" else collection_choices


func _fruit_name(round_data: Dictionary) -> String:
	return "maçãs" if round_data.get("objectStyle", "apple") == "apple" else "bananas"


func _drawing_instruction(round_data: Dictionary) -> String:
	if round_data.kind == "fraction_parts":
		var amount: int = round_data.markedParts.size()
		var shape := "círculo" if round_data.get("shape", "circle") == "circle" else "quadrado"
		return "Toque em %d %s do %s para pintar." % [amount,
			"parte" if amount == 1 else "partes", shape]
	var each: int = int(round_data.objectCount) / int(round_data.equalGroups)
	return "Contorne %d %s para formar um grupo. Faça %d grupos." % [
		each, _fruit_name(round_data), int(round_data.equalGroups)]


func _answer_instruction(round_data: Dictionary) -> String:
	if round_data.kind == "fraction_parts":
		return "Você pintou %d de %d partes. Qual fração mostra isso?" % [
			round_data.markedParts.size(), int(round_data.equalParts)]
	return "Um grupo é qual fração de todas as %s?" % _fruit_name(round_data)


func _show_round() -> void:
	if accessibility != null:
		accessibility.selected_fruits.clear()
		accessibility.set_paused(false)
	victory_timer.stop()
	retry_timer.stop()
	for name in ["RepeatButton", "UndoButton"]:
		find_child(name, true, false).disabled = false
	check_button.show()
	cat_speech.show()
	result_correct = false
	submitting = false
	check_button.text = "✓  Conferir"
	configuring_round = true
	stage_complete = false
	_cancel_speech_transition()
	var data: Dictionary = rounds[round_index]
	var round_data: Dictionary = data.round
	var is_parts: bool = round_data.kind == "fraction_parts"
	round_label.text = "Desafio %d de %d" % [round_index + 1, rounds.size()]
	progress.max_value = rounds.size()
	progress.value = round_index
	question_label.text = _drawing_instruction(round_data)
	diagram.visible = is_parts
	apples.visible = not is_parts
	parts_choices.visible = is_parts
	collection_choices.visible = not is_parts
	if is_parts:
		diagram.set("equal_parts", int(round_data.equalParts))
		diagram.set("marked_parts", PackedInt32Array(round_data.markedParts))
		diagram.set("diagram_shape", str(round_data.get("shape", "circle")))
		diagram.set("interactive", true)
		diagram.call("reset_selection")
		stage_hint.text = "Pinte as partes pedidas na figura."
	else:
		apples.set("apple_count", int(round_data.objectCount))
		apples.set("columns", 4)
		apples.set("required_groups", int(round_data.equalGroups))
		apples.set("group_size", int(round_data.objectCount) / int(round_data.equalGroups))
		apples.set("object_style", str(round_data.get("objectStyle", "apple")))
		apples.set("interactive", true)
		apples.call("reset_groups")
		stage_hint.text = "Arraste uma linha fechada em volta de cada grupo."
	var choices: Array = data.response.choices
	var group := _active_choices()
	for index in group.get_child_count():
		var button: Button = group.get_child(index)
		button.visible = index < choices.size()
		if button.visible:
			button.text = str(choices[index])
			button.set_meta("choice", choices[index])
			button.disabled = true
			button.modulate.a = 1.0
	demo_tag.text = "Seu progresso está sendo salvo." if online_rounds else "Modo de teste · progresso não salvo."
	pending_attempt.clear()
	_reset_selection()
	configuring_round = false
	_update_steps()


func _update_steps() -> void:
	var draw_step: PanelContainer = find_child("StepDraw", true, false)
	var answer_step: PanelContainer = find_child("StepAnswer", true, false)
	var compact := get_viewport_rect().size.x < 520.0
	draw_step.add_theme_stylebox_override("panel", step_waiting_style if stage_complete else step_active_style)
	answer_step.add_theme_stylebox_override("panel", step_active_style if stage_complete else step_waiting_style)
	if accessibility != null and accessibility.profile.contrast == "high":
		for step in [draw_step,answer_step]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("101526")
			style.border_color = Color.WHITE
			style.set_border_width_all(2)
			step.add_theme_stylebox_override("panel",style)
	find_child("StepDrawLabel", true, false).text = "✓  Pronto" if stage_complete else "1  Desenhe" if compact else "1  •  Pinte ou contorne"
	find_child("StepAnswerLabel", true, false).text = "2  Responda" if compact else "2  •  Escolha a fração"



func _set_stage_complete(completed: bool) -> void:
	if stage_complete == completed:
		return
	stage_complete = completed
	_update_steps()
	if not completed and selected_button != null:
		_reset_selection()
	for button in _active_choices().get_children():
		if button is Button and button.visible:
			button.disabled = not completed
			button.modulate.a = 1.0
	stage_hint.text = "Agora toque na fração certa." if completed else "Termine o desenho para continuar."
	status_label.text = "Ótimo! Agora escolha uma resposta." if completed else "Termine o desenho para liberar as respostas."
	if completed:
		_animate_speech_to_answer()
	else:
		_animate_speech_rewind(true)


func _cancel_speech_transition() -> void:
	speech_generation += 1
	if speech_tween != null and speech_tween.is_running():
		speech_tween.kill()
	cat_speech.scale = Vector2.ONE
	cat_speech.modulate.a = 1.0
	speech_tail.visible = false
	speech_tail.modulate.a = 1.0
	speech_pop.clear()


func _restore_drawing_speech() -> void:
	_cancel_speech_transition()
	question_label.text = _drawing_instruction(rounds[round_index].round)


func _animate_speech_to_answer() -> void:
	_cancel_speech_transition()
	if accessibility != null and accessibility.profile.reducedMotion:
		question_label.text = _answer_instruction(rounds[round_index].round)
		return
	var generation := speech_generation
	cat_speech.pivot_offset = cat_speech.size * Vector2(0.5, 0.65)
	speech_tail.visible = false
	speech_tween = create_tween()
	speech_tween.tween_property(cat_speech, "scale", Vector2(1.08, 0.88), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	speech_tween.tween_property(cat_speech, "scale", Vector2(0.04, 0.04), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	speech_tween.tween_callback(func(): _finish_speech_pop(generation))


func _animate_speech_rewind(to_drawing: bool) -> void:
	_cancel_speech_transition()
	if accessibility != null and accessibility.profile.reducedMotion:
		question_label.text = _drawing_instruction(rounds[round_index].round) if to_drawing else _answer_instruction(rounds[round_index].round)
		return
	var generation := speech_generation
	cat_speech.pivot_offset = cat_speech.size * Vector2(0.5, 0.65)
	speech_tail.hide()
	speech_tween = create_tween()
	speech_tween.tween_property(cat_speech, "scale", Vector2(1.08, 0.88), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	speech_tween.tween_property(cat_speech, "scale", Vector2(0.04, 0.04), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	speech_tween.tween_callback(func(): _finish_rewind_pop(generation, to_drawing))


func _finish_rewind_pop(generation: int, to_drawing: bool) -> void:
	if generation != speech_generation:
		return
	speech_pop.burst(cat_speech.position + cat_speech.size * Vector2(0.5, 0.6))
	question_label.text = _drawing_instruction(rounds[round_index].round) if to_drawing else _answer_instruction(rounds[round_index].round)
	cat_speech.scale = Vector2(0.42, 0.42)
	speech_tween = create_tween()
	speech_tween.tween_property(cat_speech, "scale", Vector2(1.08, 1.08), 0.19).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	speech_tween.tween_property(cat_speech, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	speech_tween.tween_callback(func():
		if generation == speech_generation:
			speech_tail.hide())


func _finish_speech_pop(generation: int) -> void:
	if generation != speech_generation or not stage_complete:
		return
	speech_pop.burst(cat_speech.position + cat_speech.size * Vector2(0.5, 0.6))
	question_label.text = _answer_instruction(rounds[round_index].round)
	cat_speech.scale = Vector2(0.42, 0.42)
	speech_tween = create_tween()
	speech_tween.tween_property(cat_speech, "scale", Vector2(1.08, 1.08), 0.19).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	speech_tween.tween_property(cat_speech, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	speech_tween.tween_callback(func(): _finish_speech_open(generation))


func _finish_speech_open(generation: int) -> void:
	if generation == speech_generation and stage_complete:
		speech_tail.visible = false


func _on_diagram_selection_changed(count: int) -> void:
	if configuring_round or not diagram.visible:
		return
	var required: int = rounds[round_index].round.markedParts.size()
	_set_stage_complete(count == required)
	if count != required:
		status_label.text = "Você pintou %d de %d partes. Toque na figura para continuar." % [count, required]


func _on_groups_changed(formed: int, required: int) -> void:
	if configuring_round or not apples.visible:
		return
	_set_stage_complete(formed == required)
	if formed != required:
		status_label.text = "%d de %d grupos prontos. Contorne as frutas que faltam." % [formed, required]


func _on_group_rejected(message: String) -> void:
	status_label.text = message


func _select(button: Button) -> void:
	if activity_paused or submitting or not stage_complete or button.disabled:
		return
	var old_choice: Variant = selected_button.get_meta("choice") if selected_button != null else null
	if selected_button != null:
		_restore_choice(selected_button)
	selected_button = button
	button.text = "✓ " + str(button.get_meta("choice"))
	if old_choice != button.get_meta("choice"):
		pending_attempt.clear()
	var highlighted: StyleBoxFlat = base_styles[button].duplicate()
	highlighted.bg_color = Color("e5f7bd")
	highlighted.border_color = Color("246e4d")
	highlighted.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", highlighted)
	button.add_theme_color_override("font_color", INK)
	check_button.disabled = false
	status_label.text = "Você escolheu %s. Toque em Conferir." % button.text


func _restore_choice(button: Button) -> void:
	button.text = str(button.get_meta("choice",button.text))
	button.add_theme_stylebox_override("normal", base_styles[button])
	button.add_theme_color_override("font_color", base_font_colors[button])


func _reset_selection() -> void:
	if submitting:
		return
	if selected_button != null:
		_restore_choice(selected_button)
	selected_button = null
	pending_attempt.clear()
	check_button.disabled = true
	status_label.text = "Toque em uma fração para continuar." if stage_complete else "Termine o desenho para liberar as respostas."


func _repeat() -> void:
	if activity_paused: return
	if accessibility != null: accessibility.selected_fruits.clear()
	if not submitting:
		_show_round()


func _undo() -> void:
	if activity_paused: return
	if submitting:
		return
	if selected_button != null:
		_reset_selection()
		_animate_speech_rewind(false)
	elif diagram.visible:
		diagram.call("undo_selection")
	else:
		apples.call("undo_last_group")


func _check() -> void:
	if activity_paused or selected_button == null or submitting or not stage_complete:
		return
	var data: Dictionary = rounds[round_index]
	var choice: Variant = selected_button.get_meta("choice")
	var feedback_reason := ""
	if online_rounds:
		var account_token: String = api.token
		submitting = true
		check_button.disabled = true
		status_label.text = "Conferindo sua resposta..."
		if pending_attempt.is_empty():
			pending_attempt = {
				"eventId": _new_event_id(),
				"occurredAt": Time.get_datetime_string_from_system(true, false) + ".000Z",
			}
		var result: Dictionary = await api.call("submit_attempt", data, choice,
			pending_attempt.eventId, pending_attempt.occurredAt)
		if account_token != api.token: return
		submitting = false
		if not result.get("ok", false):
			check_button.disabled = false
			status_label.text = "Não conseguimos conferir agora. Toque em Conferir de novo."
			return
		result_correct = bool(result.data.get("correct", false))
		if result.data.get("feedback") is Dictionary:
			feedback_reason = str(result.data.feedback.get("reason", ""))
	else:
		result_correct = _demo_correct(data.round, choice)
		var details: Dictionary = data.get("demoFeedback", {})
		var wrong: Variant = details.get(str(choice), details.get("*", {}))
		if wrong is Dictionary:
			feedback_reason = str(wrong.get("reason", ""))
	pending_attempt.clear()
	if result_correct:
		submitting = true
		check_button.disabled = true
		status_label.text = "Muito bem! Veja a poção do gatinho."
		stage_hint.text = "Experimento concluído!"
		progress.value = round_index + 1
		cat_speech.hide()
		speech_tail.hide()
		check_button.hide()
		game_cat.celebrate()
		return
	# Keep an incorrect attempt in the exercise scene, just like a success.
	submitting = true
	for name in ["RepeatButton", "UndoButton"]:
		find_child(name, true, false).disabled = true
	_cancel_speech_transition()
	cat_speech.hide()
	speech_tail.hide()
	check_button.hide()
	check_button.disabled = true
	diagram.set("interactive", false)
	apples.set("interactive", false)
	for button in _active_choices().get_children():
		button.disabled = true
	stage_hint.text = "Tudo bem! Vamos tentar outra vez."
	status_label.text = feedback_reason if not feedback_reason.is_empty() else "Observe as partes: você terá uma nova tentativa."
	game_cat.fail_attempt()


func _success_explanation(data: Dictionary, choice: Variant) -> String:
	var part: Dictionary = data.round
	if part.kind == "fraction_parts":
		return "Muito bem! %s representa %d de %d partes iguais pintadas." % [str(choice), part.markedParts.size(), int(part.equalParts)]
	var per_group := int(float(part.objectCount) / float(part.equalGroups))
	return "Muito bem! Você formou %d grupos iguais com %d %s em cada um. Um grupo representa %s da coleção." % [
		int(part.equalGroups), per_group, "maçãs" if part.get("objectStyle") == "apple" else "bananas", str(choice)]


func _demo_correct(round_data: Dictionary, choice: Variant) -> bool:
	var components := str(choice).split("/")
	if components.size() != 2 or not components[0].is_valid_int() or not components[1].is_valid_int():
		return false
	if round_data.kind == "fraction_collection":
		return int(components[1]) > 0 and int(components[0]) * int(round_data.equalGroups) == int(round_data.requestedGroups) * int(components[1])
	return int(components[1]) > 0 and int(components[0]) * int(round_data.equalParts) == round_data.markedParts.size() * int(components[1])


func _new_event_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for index in 16:
		bytes[index] = rng.randi_range(0, 255)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := ""
	for item in bytes:
		hex += "%02x" % item
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


func _on_celebration_finished() -> void:
	if not result_correct or current_layer != "game":
		return
	check_button.hide()
	check_button.disabled = true
	victory_timer.start()
	if accessibility != null: accessibility.schedule_continuation()
	status_label.text = _success_explanation(rounds[round_index], selected_button.get_meta("choice"))


func _advance_after_victory() -> void:
	if current_layer == "game" and result_correct and game_cat.celebration_done:
		_after_feedback()


func _on_failure_finished() -> void:
	if current_layer != "game" or result_correct or not game_cat.failing:
		return
	retry_timer.start()
	if accessibility != null: accessibility.schedule_continuation()


func _restart_after_failure() -> void:
	if current_layer != "game" or result_correct or not game_cat.failure_done:
		return
	_show_round()
	game_cat.start_idle()


func _after_feedback() -> void:
	if result_correct:
		if round_index == rounds.size() - 1:
			_show_layer("menu")
		else:
			round_index += 1
			_show_round()
			_show_layer("game")
	else:
		_reset_selection()
		_show_layer("game")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if current_layer == "game":
		var number := -1
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			number = event.keycode - KEY_1
		if number >= 0:
			var choices := _active_choices()
			if number < choices.get_child_count() and choices.get_child(number).visible:
				_select(choices.get_child(number))
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_check()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_show_layer("menu")
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and current_layer == "how":
		_return_from_modal()
		get_viewport().set_input_as_handled()
