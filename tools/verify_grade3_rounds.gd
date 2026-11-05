extends SceneTree
## Play every API-authored EF03MA09 round in the local Godot preview.

func _initialize() -> void:
	call_deferred("verify")


func click_part(diagram: Control, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	diagram.call("_gui_input", event)


func draw_group(collection: Control, path: PackedVector2Array) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = path[0]
	collection.call("_gui_input", press)
	for point in path.slice(1):
		var drag := InputEventMouseMotion.new()
		drag.position = point
		collection.call("_gui_input", drag)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = path[-1]
	collection.call("_gui_input", release)


func rectangle_path(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])


func verify() -> void:
	root.size = Vector2i(1100, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	await process_frame
	var rounds: Array = scene.get("rounds")
	assert(rounds.size() == 4, "The four third-year rounds are missing")
	var expected := ["uma-de-duas", "uma-de-quatro", "metade-de-oito", "quarta-parte-de-doze"]
	var answers := ["1/2", "3/4", "1/2", "1/4"]
	for index in 4:
		assert(rounds[index].exerciseId == expected[index])
		assert(rounds[index].schoolYear == 3 and rounds[index].skillId == "EF03MA09")
	scene.find_child("MenuCat", true, false).visible = false
	var play: Button = scene.find_child("PlayButton", true, false)
	play.pressed.emit()
	await process_frame
	assert(scene.get("current_layer") == "game")
	assert(scene.find_child("GameBackground", true, false).visible)
	var game_cat: GameCatIdle = scene.find_child("GameCat", true, false)
	assert(game_cat.scale == Vector2.ONE * 1.12)
	var cat_sprite: TextureRect = game_cat.get_node("CatSprite")
	assert(not cat_sprite.flip_h and cat_sprite.texture.resource_path.ends_with("frame_01.png"))
	assert(game_cat.frames.size() == 18)
	assert(ProjectSettings.get_setting("application/run/max_fps") == 60)
	await create_timer(1.9).timeout
	assert(game_cat.stirring and game_cat.pose_index >= 6 and game_cat.pose_index <= 15)
	for index in 4:
		assert(scene.get("round_index") == index)
		await process_frame
		var round_data: Dictionary = rounds[index]
		var is_parts: bool = round_data.round.kind == "fraction_parts"
		var diagram: Control = scene.find_child("FractionDiagram", true, false)
		var objects: Control = scene.find_child("AppleCollection", true, false)
		assert(diagram.visible == is_parts and objects.visible != is_parts)
		if is_parts:
			assert(diagram.get("equal_parts") == round_data.round.equalParts)
			assert(diagram.get("marked_parts") == PackedInt32Array(round_data.round.markedParts))
			assert(diagram.get("diagram_shape") == ("circle" if index == 0 else "square"))
			assert(diagram.get("selected_parts").is_empty())
		else:
			assert(objects.get("apple_count") == round_data.round.objectCount)
			assert(objects.get("object_style") == ("apple" if index == 2 else "banana"))
			assert(objects.get("groups").is_empty())
		var group: HFlowContainer = scene.call("_active_choices")
		var visible_choices := 0
		var right: Button
		var wrong: Button
		for child in group.get_children():
			if child.visible:
				visible_choices += 1
				if child.get_meta("choice") == answers[index]:
					right = child
				else:
					wrong = child
		assert(visible_choices >= 4 and right != null and wrong != null)
		assert(right.disabled and not scene.get("stage_complete"))
		scene.call("_select", right)
		assert(scene.get("selected_button") == null, "Fraction choices must stay locked")
		if is_parts:
			var center: Vector2 = diagram.size / 2.0
			var points := [center + Vector2(45, 0)] if index == 0 else [
				center + Vector2(-45, -45), center + Vector2(45, -45), center + Vector2(-45, 45)]
			for point in points:
				click_part(diagram, point)
		else:
			var size: Vector2 = objects.size
			draw_group(objects, rectangle_path(Rect2(Vector2(3, 3), Vector2(18, 18))))
			assert(objects.get("groups").is_empty(), "An empty contour must be rejected")
			for group_index in int(round_data.round.equalGroups):
				var rect := Rect2(Vector2(5, group_index * size.y / 2.0 + 5),
					Vector2(size.x - 10, size.y / 2.0 - 10)) if index == 2 else Rect2(
					Vector2(group_index * size.x / 4.0 + 5, 5), Vector2(size.x / 4.0 - 10, size.y - 10))
				draw_group(objects, rectangle_path(rect))
		assert(scene.get("stage_complete") and not right.disabled)
		if index == 0:
			await create_timer(0.68).timeout
			assert(scene.find_child("QuestionLabel", true, false).text == scene.call("_answer_instruction", round_data.round))
		if index == 1:
			scene.call("_undo")
			assert(not scene.get("stage_complete") and right.disabled)
			await create_timer(0.28).timeout
			assert(scene.find_child("SpeechPop", true, false).elapsed < 0.2,
				"Removing a drawing did not pop the speech bubble")
			assert(scene.find_child("QuestionLabel", true, false).text == scene.call("_drawing_instruction", round_data.round))
			click_part(diagram, diagram.size / 2.0 + Vector2(-45, 45))
			assert(scene.get("stage_complete"))
		elif index == 3:
			scene.call("_undo")
			assert(not scene.get("stage_complete") and right.disabled)
			var collection_size: Vector2 = objects.size
			var last_group := Rect2(Vector2(3 * collection_size.x / 4.0 + 5, 5), Vector2(collection_size.x / 4.0 - 10, collection_size.y - 10))
			draw_group(objects, rectangle_path(last_group))
			assert(scene.get("stage_complete"))
		if index == 0:
			scene.call("_select", wrong)
			scene.call("_undo")
			await create_timer(0.28).timeout
			assert(scene.find_child("SpeechPop", true, false).elapsed < 0.2,
				"Removing a choice did not pop the speech bubble")
			scene.call("_select", wrong)
			scene.call("_check")
			assert(scene.get("current_layer") == "game" and not scene.get("result_correct"))
			assert(game_cat.failing and not scene.find_child("FeedbackLayer", true, false).visible)
			game_cat._process(GameCatIdle.FAILURE_SECONDS)
			assert(game_cat.failure_done)
			await create_timer(2.8).timeout
			assert(scene.get("submitting"), "Incorrect attempt restarted before three seconds")
			await create_timer(0.4).timeout
			assert(scene.get("round_index") == index and not scene.get("stage_complete"))
			assert(not game_cat.failing and diagram.get("selected_parts").is_empty())
			click_part(diagram, diagram.size / 2.0 + Vector2(45, 0))
		scene.call("_select", right)
		scene.call("_check")
		assert(scene.get("current_layer") == "game" and scene.get("result_correct"))
		assert(game_cat.celebrating and not scene.find_child("FeedbackLayer", true, false).visible)
		game_cat._process(2.30)
		assert(game_cat.celebration_done and not scene.find_child("CheckButton", true, false).visible)
		var before := int(scene.get("round_index"))
		scene.call("_check")
		assert(scene.get("round_index") == before, "Enter skipped the victory delay")
		await create_timer(2.8).timeout
		assert(scene.get("round_index") == before and scene.get("current_layer") == "game",
			"Victory advanced before three seconds")
		await create_timer(0.4).timeout
		if before < 3:
			assert(scene.get("round_index") == before + 1, "Automatic advance failed")
			assert(scene.find_child("CheckButton", true, false).visible, "Confirm did not return")
	assert(scene.get("current_layer") == "menu")
	print("PASS: all four third-year exercises, visuals, choices, retry and completion")
	quit()
