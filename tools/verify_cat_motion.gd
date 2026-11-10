extends SceneTree
## Regression checks for the requested 60-frame turn and grounded alternating gait.

func _initialize() -> void:
	call_deferred("verify")


func verify() -> void:
	root.size = Vector2i(1100, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	var cat: CatAnimator = scene.find_child("MenuCat", true, false)
	cat.set_process(false)
	await process_frame
	cat._process(1.25)
	assert(cat.breath_amount > 0.95, "Menu cat's breathing is no longer visible")
	cat.start_idle()
	var play: Button = scene.find_child("PlayButton", true, false)
	var walk_speech: TextureRect = scene.find_child("WalkSpeech", true, false)
	var walk_speech_tail: Control = scene.find_child("WalkSpeechTail", true, false)
	assert(walk_speech.get_parent() == cat.walk_rig and walk_speech_tail.get_parent() == cat.walk_rig,
		"Walking bubble does not follow the cat")
	assert(not walk_speech.visible and not walk_speech_tail.visible,
		"Walking bubble appears before the cat walks")
	assert(scene.find_child("WalkSpeechLabel", true, false).text ==
		"Hora de representar!!!", "Walking dialogue changed")
	play.pressed.emit()
	var turn_seen := {}
	var support_samples := 0
	var walk_samples := 0
	var both_down_samples := 0
	var lifted := [0, 0]
	var last_world: Array[Vector2] = []
	var last_grounded := [false, false]
	var last_turn_feet: Array[Vector2] = []
	var last_body_pose := Vector2.ZERO
	var forward_lean_samples := 0
	var backward_lean_samples := 0
	for sample in 720:
		assert(cat.sprite.scale == Vector2.ONE and cat.walk_rig.scale == Vector2.ONE, "Scale changed")
		if cat.state == "turn":
			assert(not walk_speech.visible, "Walking bubble appears during the turn")
			turn_seen[cat.frame_index] = true
			assert(not cat.walk_rig.visible and not cat.paw_overlay.visible,
				"Extra paw artwork appeared during the authored rise")
			var turn_feet: Array[Vector2] = cat.walk_rig.call("foot_positions")
			for paw in 2:
				assert(is_equal_approx(turn_feet[paw].y, 150.0), "Rising paw left the floor")
				if not last_turn_feet.is_empty():
					assert(absf(turn_feet[paw].x - last_turn_feet[paw].x) < 1.0, "Rising paw jumped")
			last_turn_feet = turn_feet
		elif cat.state == "walk":
			walk_samples += 1
			assert(cat.modulate.a > 0.999, "Cat faded out before the scene transition")
			assert(walk_speech.visible and not walk_speech_tail.visible,
				"Walking bubble did not appear with the first step")
			assert(walk_speech.size.y <= 201.0, "Walking bubble grew over the cat")
			if walk_speech.modulate.a > 0.05:
				assert(walk_speech.get_global_rect().end.x <= root.size.x + 3.0,
					"Walking bubble clipped at the screen edge")
			assert(not cat.paw_overlay.visible, "Rising paw layer remained over the walk")
			var body_pose: Vector2 = cat.walk_rig.call("body_pose")
			assert(absf(body_pose.x - last_body_pose.x) < 0.5,
				"Upper body jumped out of step with the paws")
			assert(absf(body_pose.y - last_body_pose.y) < deg_to_rad(0.6),
				"Upper body lean jumped between steps")
			if body_pose.y > deg_to_rad(0.08):
				forward_lean_samples += 1
			elif body_pose.y < -deg_to_rad(0.08):
				backward_lean_samples += 1
			last_body_pose = body_pose
			var feet: Array[Vector2] = cat.walk_rig.call("foot_positions")
			assert(absf(feet[1].x - feet[0].x) <= 31.0 + cat.walk_rig.STEP_LENGTH + 0.1,
				"The paws spread too far apart during a stride")
			if cat.walk_distance > cat.walk_rig.FIRST_STEP + cat.walk_rig.STEP_LENGTH:
				for paw in 2:
					assert(absf(feet[paw].x - cat.walk_rig.GAIT_FEET[paw].x) < cat.walk_rig.STEP_LENGTH * 0.75,
						"One paw trails its hip by more than the balanced stride")
			var ground_y := (cat.get_global_transform() * (cat.home_position + Vector2(0, 150))).y
			var grounded := [false, false]
			var world: Array[Vector2] = []
			for paw in 2:
				world.append(cat.walk_rig.to_global(feet[paw]))
				assert(world[paw].y <= ground_y + 0.001, "Paw penetrated the floor")
				grounded[paw] = absf(world[paw].y - ground_y) < 0.001
				if not grounded[paw]:
					lifted[paw] += 1
				if grounded[paw] and last_grounded[paw] and not last_world.is_empty():
					assert(absf(world[paw].x - last_world[paw].x) < 0.01, "Planted paw slid")
			assert(grounded[0] or grounded[1], "Both paws left the floor")
			if grounded[0] and grounded[1]:
				both_down_samples += 1
				assert(absf(body_pose.x) < 0.15,
					"Torso did not settle when both paws touched the floor")
			support_samples += 1
			last_world = world
			last_grounded = grounded
		elif scene.get("game_layer").visible:
			break
		cat._process(1.0 / 60.0)
	assert(turn_seen.size() == 60, "Turn did not display all 60 frames")
	assert(walk_samples <= 181 and walk_samples >= 179, "Walk takes too long or skips its steps")
	assert(is_equal_approx(cat.walk_distance, cat.walk_route_distance), "Walk ended before the planted final pose")
	assert(both_down_samples > 20, "Missing double support")
	assert(lifted[0] > 20 and lifted[1] > 20, "Both legs must take turns stepping")
	assert(forward_lean_samples > 15 and backward_lean_samples > 15,
		"Upper body did not alternate with the two paw strides")
	assert(scene.get("game_layer").visible, "Round did not open")
	assert(not walk_speech.visible and not walk_speech_tail.visible,
		"Walking bubble remains after the cat leaves")
	# Each leg must have the same reach/lift relative to its own ankle, shifted
	# by one step. This catches the former permanent forward/backward bias.
	for sample in 240:
		var distance: float = cat.walk_rig.FIRST_STEP + 2.0 * cat.walk_rig.STEP_LENGTH + sample * cat.walk_rig.STEP_LENGTH / 120.0
		cat.walk_rig.distance = distance
		var far: Vector2 = cat.walk_rig.foot_positions()[0] - cat.walk_rig.GAIT_FEET[0]
		cat.walk_rig.distance = distance + cat.walk_rig.STEP_LENGTH
		var near: Vector2 = cat.walk_rig.foot_positions()[1] - cat.walk_rig.GAIT_FEET[1]
		assert(far.distance_to(near) < 0.001, "The two legs have unequal stride trajectories")
	scene.call("_show_layer", "menu")
	assert(root.gui_get_focus_owner() == null, "Play button kept the purple focus outline after returning")
	scene.find_child("HowButton", true, false).pressed.emit()
	assert(scene.get("current_layer") == "how" and root.gui_get_focus_owner() == null,
		"Rules button kept a purple focus outline")
	var how_art: Control = scene.find_child("HowArtLayer", true, false)
	how_art._process(1.25)
	assert(float((scene.find_child("HowCat", true, false).material as ShaderMaterial).get_shader_parameter("breath_amount")) > 0.95,
		"The cat on the rules screen is motionless")
	print("PASS: 60 turn frames, %s walking frames, visible cat, %s grounded samples, %s double-support samples, synchronized body and paws, both idle screens breathe" % [walk_samples, support_samples, both_down_samples])
	quit()
