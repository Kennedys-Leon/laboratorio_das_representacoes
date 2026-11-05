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
	var cat: GameCatIdle = scene.find_child("GameCat", true, false)
	cat.set_process(false)
	scene.find_child("CatSpeech", true, false).hide()
	scene.find_child("SpeechTail", true, false).hide()
	DirAccess.make_dir_recursive_absolute("/tmp/gauss-success")
	cat.celebrate()
	for frame in 240:
		cat._process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_jpg("/tmp/gauss-success/frame-%04d.jpg" % frame, 0.95)
		if frame in [0, 30, 60, 100, 140, 200, 230]:
			picture.save_png("res://docs/preview-success-%03d.png" % frame)
	print("Captured success in exercise scene")
	quit()
