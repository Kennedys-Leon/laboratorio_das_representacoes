extends SceneTree
## Check the rendered silhouette through a full gait, including both foot contacts.
## Requires a graphical renderer; run without --headless.

func _initialize() -> void:
	call_deferred("verify")


func verify() -> void:
	root.size = Vector2i(128, 152)
	root.transparent_bg = true
	var rig: Node2D = load("res://scripts/cat_walk_rig.gd").new()
	root.add_child(rig)
	DirAccess.make_dir_recursive_absolute("/tmp/gauss-connections")
	var failures: Array[int] = []
	for frame in 120:
		rig.set("distance", frame * 62.0 / 120.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		if frame % 15 == 0:
			picture.save_png("/tmp/gauss-connections/pose-%03d.png" % frame)
		var connected := body_component(picture)
		var feet: Array[Vector2] = rig.call("foot_positions")
		for foot in feet:
			var x := roundi(foot.x)
			var y := roundi(foot.y) - 5
			if not connected[y * 128 + x]:
				failures.append(frame)
				picture.save_png("/tmp/gauss-connections/disconnected-%03d.png" % frame)
				break
	print("Rendered gait: %s/120 frames with disconnected paw centers; failures: %s" % [failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func body_component(picture: Image) -> PackedByteArray:
	var visited := PackedByteArray()
	visited.resize(128 * 152)
	var queue: Array[Vector2i] = [Vector2i(73, 70)]
	visited[70 * 128 + 73] = 1
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = point + offset
			if neighbor.x < 0 or neighbor.x >= 128 or neighbor.y < 0 or neighbor.y >= 152:
				continue
			var index := neighbor.y * 128 + neighbor.x
			if not visited[index] and picture.get_pixelv(neighbor).a > 0.4:
				visited[index] = 1
				queue.append(neighbor)
	return visited
