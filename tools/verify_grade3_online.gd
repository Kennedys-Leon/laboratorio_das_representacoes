extends SceneTree
## Exercise the real HTTP adapter against the local contract fixture.

func _initialize() -> void:
	call_deferred("verify")


func wait_for_layer(scene: Node, expected: String) -> void:
	for tick in 100:
		if scene.get("current_layer") == expected:
			return
		await create_timer(0.05).timeout
	assert(false, "Timed out waiting for " + expected)


func verify() -> void:
	root.size = Vector2i(1100, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	await process_frame
	assert(scene.get("api").call("has_session"))
	var play: Button = scene.find_child("PlayButton", true, false)
	scene.find_child("MenuCat", true, false).visible = false
	play.pressed.emit()
	await wait_for_layer(scene, "game")
	assert(scene.get("online_rounds") and scene.get("rounds").size() == 4)
	for index in 4:
		var round_data: Dictionary = scene.get("rounds")[index]
		assert(not round_data.has("demoAnswer"), "The server leaked an answer key")
		var answer: Variant = "1/2" if index == 0 or index == 2 else "3/4" if index == 1 else "1/4"
		if index < 2:
			var diagram: Control = scene.find_child("FractionDiagram", true, false)
			for part in int(round_data.round.markedParts.size()):
				diagram.call("select_part", part)
		else:
			var collection: Control = scene.find_child("AppleCollection", true, false)
			await process_frame
			var size: Vector2 = collection.size
			for part in int(round_data.round.equalGroups):
				var rect := Rect2(Vector2(5, part * size.y / 2.0 + 5), Vector2(size.x - 10, size.y / 2.0 - 10)) if index == 2 else Rect2(
					Vector2(part * size.x / 4.0 + 5, 5), Vector2(size.x / 4.0 - 10, size.y - 10))
				var path := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
					rect.end, rect.position + Vector2(0, rect.size.y)])
				assert(collection.call("submit_lasso", path))
		assert(scene.get("stage_complete"))
		var group: HFlowContainer = scene.call("_active_choices")
		var visible_choices := 0
		var chosen: Button
		var wrong: Button
		for button in group.get_children():
			if button.visible:
				visible_choices += 1
			if button.visible and button.get_meta("choice") == answer:
				chosen = button
			elif button.visible:
				wrong = button
		assert(visible_choices >= 4 and chosen != null)
		if index == 0:
			scene.call("_select", wrong)
			scene.call("_check")
			await wait_for_layer(scene, "feedback")
			assert(not scene.get("result_correct"))
			assert(scene.find_child("FeedbackExplanation", true, false).text.length() > 10)
			scene.call("_after_feedback")
		scene.call("_select", chosen)
		scene.call("_check")
		await wait_for_layer(scene, "feedback")
		assert(scene.get("result_correct"))
		scene.call("_after_feedback")
	assert(scene.get("current_layer") == "menu")
	print("PASS: four published grade-three exercises loaded; five authenticated attempts corrected by API")
	quit()
