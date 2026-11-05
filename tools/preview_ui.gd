extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	for width in [1100, 390]:
		root.size = Vector2i(width, 720 if width == 1100 else 844)
		var scene: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		scene.tutorial_checked_token = scene.api.token
		scene.tutorial_seen = true
		await process_frame
		scene.call("_update_layout")
		for screen in ["menu", "how", "game", "collection", "feedback"]:
			if screen == "collection":
				scene.set("round_index", 2)
				scene.call("_show_round")
				scene.call("_show_layer", "game")
			else:
				scene.call("_show_layer", screen)
			if screen == "feedback":
				scene.find_child("FeedbackTitle", true, false).text = "Vamos tentar juntos?"
				scene.find_child("FeedbackExplanation", true, false).text = "Observe as partes iguais. Você pode voltar ao desenho e tentar outra vez."
				scene.find_child("FeedbackActionButton", true, false).text = "Tentar novamente"
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/ui-%s-%d.png" % [screen, width])
		scene.queue_free()
		await process_frame
	print("Captured all screens at desktop and phone sizes")
	quit()
