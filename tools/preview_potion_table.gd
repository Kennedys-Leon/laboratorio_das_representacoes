extends SceneTree
## Capture the actual exercise scene after the pouring intro has ended.

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var requested_width := int(OS.get_environment("GAUSS_PREVIEW_WIDTH"))
	root.size = Vector2i(requested_width if requested_width > 0 else 1100, 720)
	DirAccess.make_dir_recursive_absolute("/tmp/gauss-potion-poses")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	await process_frame
	scene.call("_show_layer", "game")
	for frame in 180:
		await process_frame
		if frame in [70, 90, 110, 130, 150, 170]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/gauss-potion-poses/frame-%03d.png" % frame)
	DirAccess.make_dir_recursive_absolute("/tmp/gauss-potion-motion")
	for frame in 240:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("/tmp/gauss-potion-motion/frame-%04d.jpg" % frame, 0.95)
	await RenderingServer.frame_post_draw
	var output := "res://docs/preview-potion-table-narrow.png" if root.size.x < 900 else "res://docs/preview-potion-table.png"
	root.get_texture().get_image().save_png(output)
	print("Captured potion table with stationary flasks")
	quit()
