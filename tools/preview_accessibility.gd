extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	for width in [1100,390]:
		root.size=Vector2i(width,844)
		var scene=load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		scene.tutorial_checked_token = scene.api.token
		scene.tutorial_seen = true
		await process_frame
		var p=scene.accessibility.profile.duplicate()
		p.textScale=2
		p.contrast="high"
		p.focusMode=true
		p.reducedMotion=true
		p.preferredInput="keyboard"
		scene.accessibility.apply_profile(p)
		for layer in ["menu","how","game"]:
			scene._show_layer(layer)
			for tick in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/accessibility-%s-%d.png" % [layer,width])
		scene.queue_free()
		await process_frame
	print("Captured 200% high-contrast focus layouts")
	quit()
