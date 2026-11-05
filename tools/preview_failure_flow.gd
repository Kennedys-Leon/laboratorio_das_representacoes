extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1100, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	for settle in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/preview-menu-closer.png")
	scene.call("_show_layer", "game")
	await process_frame
	var diagram: Control = scene.find_child("FractionDiagram", true, false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = diagram.size / 2.0 + Vector2(45, 0)
	diagram.call("_gui_input", click)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/preview-before-failure.png")
	for choice in scene.call("_active_choices").get_children():
		if choice.get_meta("choice") == "1/3":
			scene.call("_select", choice)
	scene.call("_check")
	DirAccess.make_dir_recursive_absolute("/tmp/gauss-failure-flow")
	for frame in 720:
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_jpg("/tmp/gauss-failure-flow/frame-%04d.jpg" % frame, 0.95)
		if frame in [36, 90, 150, 200, 280, 630]:
			picture.save_png("res://docs/preview-failure-%03d.png" % frame)
	assert(scene.get("round_index") == 0 and not scene.get("stage_complete"))
	assert(not scene.find_child("GameCat", true, false).failing)
	# Inspect a narrow viewport as well: the message must remain fully visible.
	root.size = Vector2i(390, 844)
	scene.call("_update_layout")
	await process_frame
	var cat: GameCatIdle = scene.find_child("GameCat", true, false)
	cat.fail_attempt()
	cat._process(GameCatIdle.FAILURE_SECONDS + 0.1)
	scene.find_child("CatSpeech", true, false).hide()
	scene.find_child("SpeechTail", true, false).hide()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/preview-failure-phone.png")
	print("Captured failure, full three-second wait, same question restarting and mobile preview")
	quit()
