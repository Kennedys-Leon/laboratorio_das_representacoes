extends SceneTree
## Capture the four visual tasks after their drawing step is complete.

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
		if index < 2:
			var diagram: Control = scene.find_child("FractionDiagram", true, false)
			for part in int(scene.get("rounds")[index].round.markedParts.size()):
				diagram.call("select_part", part)
		else:
			var collection: Control = scene.find_child("AppleCollection", true, false)
			var size: Vector2 = collection.size
			var group_count: int = scene.get("rounds")[index].round.equalGroups
			for group_index in group_count:
				var rect := Rect2(Vector2(5, group_index * size.y / 2.0 + 5),
					Vector2(size.x - 10, size.y / 2.0 - 10)) if index == 2 else Rect2(
					Vector2(group_index * size.x / 4.0 + 5, 5), Vector2(size.x / 4.0 - 10, size.y - 10))
				var path := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
					rect.end, rect.position + Vector2(0, rect.size.y)])
				collection.call("submit_lasso", path)
		await create_timer(0.68).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/grade3-interaction-%d.png" % (index + 1))
	print("Captured four completed visual tasks")
	quit()
