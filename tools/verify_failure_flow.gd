extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func select_wrong(scene: Node) -> void:
	var diagram: Control = scene.find_child("FractionDiagram", true, false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = diagram.size / 2.0 + Vector2(45, 0)
	diagram.call("_gui_input", click)
	for choice in scene.call("_active_choices").get_children():
		if choice.get_meta("choice") == "1/3":
			scene.call("_select", choice)
	scene.call("_check")

func verify() -> void:
	root.size = Vector2i(1100, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	await process_frame
	scene.call("_show_layer", "game")
	await process_frame
	var cat: GameCatIdle = scene.find_child("GameCat", true, false)
	cat.set_process(false)
	cat._process(2.0)
	var card_position: Vector2 = scene.find_child("GameCard", true, false).global_position
	var cat_transform: Transform2D = cat.get_global_transform()
	select_wrong(scene)
	await process_frame
	assert(scene.find_child("GameCard", true, false).global_position == card_position,
		"The feedback text moved the exercise and cat")
	assert(cat.get_global_transform() == cat_transform and cat.scale == Vector2(1.12, 1.12),
		"The cat changed position or scale at the start of the error")
	assert(cat.failing and scene.get("current_layer") == "game")
	assert(cat.failure_sprite.visible and not cat.sprite.visible, "Failure still assembles a face over the original body")
	for old_layer in [cat.next_sprite, cat.beaker, cat.next_beaker, cat.beaker_rim, cat.table_flasks, cat.get_node("CatShadow"), cat.retry_message]:
		assert(not old_layer.visible, "An old cat or prop layer overlaps the complete failure frame: %s" % old_layer.name)
	assert(cat.standing_paws.visible and cat.get_node("PotionTable").visible)
	assert(cat.failure_beaker.visible and cat.failure_effect.visible)
	assert(cat.failure_sprite.z_index < cat.get_node("PotionTable").z_index)
	assert(cat.failure_props.z_index > cat.get_node("PotionTable").z_index)
	assert(cat.failure_frames.size() == GameCatIdle.FAILURE_FRAME_COUNT + GameCatIdle.FAILURE_IDLE_FRAMES)
	assert(cat.failure_frame_index == 0 and cat.failure_sprite.texture == cat.failure_frames[0])
	assert(scene.get("submitting") and not scene.find_child("CheckButton", true, false).visible)
	assert(not scene.find_child("FractionDiagram", true, false).get("interactive"))
	var table_position: Vector2 = cat.get_node("PotionTable").position
	var check_timer: Timer = scene.get("retry_timer")
	# Manual 60 Hz samples verify ordering without tying animation to frame rate.
	for tick in int(GameCatIdle.FAILURE_SECONDS * 60) - 1:
		cat._process(1.0 / 60.0)
		assert(cat.failure_frame_index == tick + 1, "Motion skipped or repeated a frame at 60 Hz")
		assert(cat.failure_sprite.texture == cat.failure_frames[cat.failure_frame_index])
		assert(cat.retry_message.visible == (cat.failure_elapsed >= GameCatIdle.FAILURE_CLOUD_START))
		assert(check_timer.is_stopped(), "Retry timer started before the animation ended")
		assert(cat.get_node("PotionTable").position == table_position)
		assert(cat.failure_beaker.position == Vector2(94, 192) * (220.0 / 273.0) and cat.failure_beaker.rotation == 0.0,
			"Glass follows the body instead of staying on the table")
		assert(not cat.table_flasks.visible, "Unbroken bottles overlap the broken props")
	assert(not cat.failure_done)
	cat._process(0.04)
	assert(cat.failure_done and cat.failure_frame_index >= GameCatIdle.FAILURE_FRAME_COUNT)
	assert(not check_timer.is_stopped())
	scene.call("_repeat")
	scene.call("_undo")
	scene.call("_check")
	assert(cat.failing and scene.get("round_index") == 0)
	await create_timer(2.7).timeout
	assert(cat.failing and scene.get("submitting"))
	await create_timer(0.4).timeout
	assert(not cat.failing and not scene.get("submitting"))
	assert(cat.sprite.visible and not cat.failure_sprite.visible, "Complete animation did not reset")
	assert(cat.beaker.visible and cat.standing_paws.visible and cat.get_node("PotionTable").visible)
	assert(scene.get("round_index") == 0 and not scene.get("stage_complete"))
	assert(scene.get("selected_button") == null)
	assert(scene.find_child("FractionDiagram", true, false).get("selected_parts").is_empty())
	assert(scene.find_child("CheckButton", true, false).visible)
	assert(scene.find_child("CatSpeech", true, false).visible)
	# Leaving during the wait must cancel the queued restart.
	select_wrong(scene)
	cat._process(GameCatIdle.FAILURE_SECONDS + 0.1)
	assert(not check_timer.is_stopped())
	scene.call("_show_layer", "menu")
	assert(check_timer.is_stopped())
	await create_timer(3.1).timeout
	assert(scene.get("current_layer") == "menu")
	print("PASS: 60 Hz failure animation; three seconds AFTER completion; same round fully reset; navigation cancels retry")
	quit()
