extends SceneTree
## Check the potion default for a ten-second fixed 60 FPS run.

func _initialize() -> void:
	call_deferred("verify")


func verify() -> void:
	root.size = Vector2i(1100, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	await process_frame
	scene.call("_show_layer", "game")
	var cat: GameCatIdle = scene.find_child("GameCat", true, false)
	assert(cat.get_node_or_null("PotionCoatBacking") == null,
		"The coat is being faked with a separate runtime layer")
	var standing_legs: TextureRect = cat.get_node("StandingLegs")
	assert(standing_legs.visible and standing_legs.position.y > 220.0,
		"Standing paws are not visible below the workbench")
	assert(standing_legs.texture != null and standing_legs.size.x / standing_legs.size.y > 2.5,
		"Standing paws are missing or disproportionate")
	cat.set_process(false)
	cat.start_idle()
	assert(ProjectSettings.get_setting("application/run/max_fps") == 60)
	assert(cat.frames.size() == 18)
	var table: Control = cat.get_node("PotionTable")
	assert(table.z_index > cat.sprite.z_index, "Coat draws over the tabletop")
	assert(cat.beaker.z_index > table.z_index, "Table hides the glass vessel")
	assert(cat.beaker_frames.size() == cat.frames.size(), "A glass layer is missing")
	assert(standing_legs.size.x / standing_legs.size.y > 2.5,
		"Standing legs became long and narrow again")
	var fixed: TextureRect = cat.get_node("TableFlasks")
	assert(fixed.texture != null)
	var flask_position := fixed.position
	var fixed_image := fixed.texture.get_image()
	var bottle_base := fixed.position.y + float(fixed_image.get_used_rect().end.y) * fixed.size.y / float(fixed_image.get_height())
	assert(bottle_base >= 193.0 and bottle_base <= 208.0,
		"The empty bottles do not rest on the tabletop")
	for point in [Vector2i(16, 251), Vector2i(16, 253), Vector2i(18, 255), Vector2i(20, 255)]:
		assert(fixed_image.get_pixelv(point).a > 0.9, "Left bottle lost its lower side outline")
		assert(fixed_image.get_pixel(point.x + 195, point.y).a > 0.9,
			"Right bottle lost its lower side outline")
	for y in range(187, 261):
		for x in range(13, 75):
			assert(fixed_image.get_pixel(x, y) == fixed_image.get_pixel(x + 195, y),
				"A side of the right bottle is missing at (%d, %d)" % [x + 195, y])
	for seed in [Vector2i(40, 220), Vector2i(235, 220)]:
		assert(fixed_image.get_pixelv(seed).a > 0.0, "A fixed bottle is missing")
		for index in range(5, 16):
			assert(cat.frames[index].get_image().get_pixelv(seed).a == 0.0,
				"A bottle still moves with the cat in frame %d" % (index + 1))
	for frame in cat.frames:
		assert(frame.get_size() == Vector2(272, 273), "Potion frame changed size")
		assert(frame.get_image().get_pixel(0, 0).a == 0.0, "Black atlas background leaked")
	for index in range(5, 16):
		var chest: Color = cat.frames[index].get_image().get_pixel(155, 150)
		assert(chest.a > 0.95 and chest.r < 0.45,
			"The background shows through the cat's coat in pose %d" % (index + 1))
	var visited: Array[int] = [cat.pose_index]
	var blended := false
	var vessel_moved := false
	var loop_starts := 0
	for tick in 600:
		var previous := cat.pose_index
		cat._process(1.0 / 60.0)
		assert(cat.sprite.texture != null and cat.next_sprite.texture != null)
		assert(cat.beaker.position == cat.next_beaker.position and cat.beaker.position == cat.beaker_rim.position,
			"The animated glass and its complete rim moved apart")
		assert(cat.beaker.position.length() < 1.1 and cat.beaker.size == cat.sprite.size,
			"The central glass moved too far from the spoon")
		assert(cat.next_beaker.modulate.a == cat.next_sprite.modulate.a,
			"Glass and character change poses at different times")
		assert(cat.pose_index >= 0 and cat.pose_index <= 13, "The stirring loop pulled the paw back to the face")
		assert(cat.next_sprite.modulate.a >= 0.0 and cat.next_sprite.modulate.a <= 1.0)
		if cat.stirring:
			assert(fixed.visible and fixed.modulate.a == 1.0 and fixed.position == flask_position,
				"The table bottles moved during stirring")
			assert(cat.beaker_rim.visible, "The complete glass edge disappeared during stirring")
			vessel_moved = vessel_moved or cat.beaker.position.length() > 0.25
		blended = blended or (cat.next_sprite.modulate.a > 0.0 and cat.next_sprite.modulate.a < 1.0)
		if cat.pose_index != previous:
			visited.append(cat.pose_index)
			if previous == 7 and cat.pose_index == 6:
				loop_starts += 1
	assert(visited.slice(0, 14) == range(14), "Pouring sequence skipped or reordered a pose")
	assert(cat.stirring and loop_starts >= 2, "Stirring failed to repeat")
	assert(blended, "The 60 FPS in-between transition did not run")
	assert(vessel_moved, "The central vessel never rocks under the spoon")
	cat.celebrate()
	assert(not cat.beaker_rim.visible, "The mixing glass edge overlaps the original victory scene")
	var glass_position := cat.celebration_beaker.position
	for tick in 240:
		cat._process(1.0 / 60.0)
		assert(cat.beaker.position == Vector2.ZERO,
			"The beaker's lower half follows the cat during celebration")
		if tick >= 70:
			assert(cat.celebration_beaker.visible and cat.celebration_beaker.position == glass_position,
				"The final beaker does not remain fixed on the table")
			assert(cat.beaker.modulate.a == 0.0,
				"An animated glass layer remains over the fixed beaker")
	assert(cat.celebration_done and cat.praise.visible,
		"The complete cloud and final success pose did not finish")
	print("PASS: 18 aligned transparent frames; pour once; stirring repeats with in-between blends at 60 FPS")
	quit()
