extends SceneTree
## Compare the rendered rig at rest to the original standing artwork.
## Run with a rendering display, not --headless.

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.size = Vector2i(128, 152)
	root.transparent_bg = true
	var rig: Node2D = load("res://scripts/cat_walk_rig.gd").new()
	root.add_child(rig)
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	var source: Image = load("res://assets/cat_animation/v8/standing.png").get_image()
	var error := 0.0
	var samples := 0
	for y in range(137, 152):
		for x in 128:
			var actual := rendered.get_pixel(x, y)
			var original := source.get_pixel(x, y)
			error += absf(actual.r * actual.a - original.r * original.a)
			error += absf(actual.g * actual.a - original.g * original.a)
			error += absf(actual.b * actual.a - original.b * original.a)
			error += absf(actual.a - original.a)
			samples += 4
	assert(error / samples < 1.0 / 255.0, "The rig changed the original paws")
	rendered.save_png("res://assets/cat_animation/v8/walk-rest.png")
	print("PASS: original paw artwork preserved; mean render difference = %.3f / 255" % (error / samples * 255.0))
	quit()
