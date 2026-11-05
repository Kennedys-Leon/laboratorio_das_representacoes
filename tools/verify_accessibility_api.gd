extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	assert(scene.play_button.disabled)
	for i in 600:
		await create_timer(0.02).timeout
		if scene.accessibility.ready_profile: break
	assert(scene.accessibility.profile.textScale==2)
	assert(scene.accessibility.profile.pace=="untimed")
	assert(scene.menu_cat.reduced_motion)
	assert(not scene.play_button.disabled)
	print("PASS: authenticated GET effective profile applied before play")
	quit()
