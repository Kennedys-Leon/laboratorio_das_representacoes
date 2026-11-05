extends SceneTree
## Save each third-year round from the actual Godot renderer.

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
	for index in 4:
		scene.set("round_index", index)
		scene.call("_show_round")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/grade3-round-%d.png" % (index + 1))
	print("Captured four grade-three rounds")
	quit()
