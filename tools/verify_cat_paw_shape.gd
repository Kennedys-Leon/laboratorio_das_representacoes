extends SceneTree
## Render each complete paw separately, cancelling its travel in camera space.
## Any scale, shear, mesh fold or texture change then differs from the reference.

class PawProbe extends "res://scripts/cat_walk_rig.gd":
	var selected := 0

	func _draw() -> void:
		_draw_leg(selected, foot_positions()[selected])


func _initialize() -> void:
	call_deferred("verify")


func verify() -> void:
	root.size = Vector2i(128, 152)
	root.transparent_bg = true
	var rig := PawProbe.new()
	# Node2D preserves subpixel positions; a Control would round the camera shift.
	var camera := Node2D.new()
	root.add_child(camera)
	camera.add_child(rig)
	var worst := 0.0
	for paw in 2:
		rig.selected = paw
		rig.begin_walk()
		camera.position = Vector2.ZERO
		await process_frame
		await RenderingServer.frame_post_draw
		var reference := root.get_texture().get_image()
		for frame in 180:
			if frame < 60:
				rig.set_turn_pose(frame / 59.0)
			else:
				rig.begin_walk()
				rig.distance = (frame - 60) * 62.0 / 120.0
			camera.position = rig.BIND_FEET[paw] - rig.foot_positions()[paw]
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := root.get_texture().get_image()
			var error := 0.0
			for y in range(129, 152):
				for x in 128:
					var a := reference.get_pixel(x, y)
					var b := rendered.get_pixel(x, y)
					error += absf(a.r * a.a - b.r * b.a)
					error += absf(a.g * a.a - b.g * b.a)
					error += absf(a.b * a.a - b.b * b.a)
					error += absf(a.a - b.a)
			var mean := error / (23.0 * 128.0 * 4.0)
			worst = maxf(worst, mean)
			assert(mean < 0.1 / 255.0, "Complete paw pixels changed during motion")
	print("PASS: 360 rendered paw poses retain shape and size; maximum mean error %.4f / 255" % (worst * 255.0))
	quit()
