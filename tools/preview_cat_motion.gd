extends SceneTree
## Capture at a deterministic 60 FPS; encode the JPEG frames with ffmpeg afterwards.

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.size = Vector2i(1100, 720)
	DirAccess.make_dir_recursive_absolute("/tmp/gauss-motion-v15")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	var cat: CatAnimator = scene.find_child("MenuCat", true, false)
	cat.set_process(false)
	await process_frame
	var frame := 0
	for sample in 720:
		if sample == 180:
			scene.get("play_button").pressed.emit()
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_jpg("/tmp/gauss-motion-v15/frame-%04d.jpg" % frame, 0.96)
		if sample == 0:
			picture.save_png("res://docs/preview-menu-idle-v15.png")
		elif sample == 210:
			picture.save_png("res://docs/preview-menu-turn-v15.png")
		elif sample == 285:
			picture.save_png("res://docs/preview-menu-walk-v15.png")
		cat._process(1.0 / 60.0)
		frame += 1
		await process_frame
	print("Captured %s frames at 60 FPS" % frame)
	quit()
