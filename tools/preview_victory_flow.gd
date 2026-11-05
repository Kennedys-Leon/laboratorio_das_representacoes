extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1100, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	await process_frame
	scene.call("_show_layer", "game")
	await process_frame
	var diagram: Control = scene.find_child("FractionDiagram", true, false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = diagram.size / 2.0 + Vector2(45, 0)
	diagram.call("_gui_input", click)
	await create_timer(0.8).timeout
	for choice in scene.call("_active_choices").get_children():
		if choice.get_meta("choice") == "1/2":
			scene.call("_select", choice)
	scene.call("_check")
	DirAccess.make_dir_recursive_absolute("/tmp/gauss-victory-flow")
	for frame in 540:
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_jpg("/tmp/gauss-victory-flow/frame-%04d.jpg" % frame, 0.95)
		if frame == 230:
			picture.save_png("res://docs/preview-victory-flow.png")
	assert(scene.get("round_index") == 1, "The preview failed to advance automatically")
	print("Captured correct answer, celebration, five-second wait and automatic next round")
	quit()
