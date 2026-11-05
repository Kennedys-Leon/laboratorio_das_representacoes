extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	root.size = Vector2i(1100,720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	await process_frame
	var adapter = scene.accessibility
	var p = adapter.profile.duplicate()
	p.textScale=2
	p.contrast="high"
	p.reducedMotion=true
	p.focusMode=true
	p.pace="untimed"
	p.preferredInput="keyboard"
	assert(adapter.apply_profile(JSON.parse_string(JSON.stringify(p))))
	var font_size = scene.check_button.get_theme_font_size("font_size")
	assert(adapter.apply_profile(p))
	assert(scene.check_button.get_theme_font_size("font_size")==font_size)
	var invalid = p.duplicate()
	invalid.reducedMotion="false"
	assert(not adapter.apply_profile(invalid))
	assert(adapter.profile.reducedMotion)
	for index in 4:
		scene.round_index=index
		scene._show_round()
		scene._show_layer("game")
		await process_frame
		var data=scene.rounds[index].round
		if data.kind=="fraction_parts":
			for part in data.markedParts: adapter.action("part",int(part))
		else:
			var count=int(data.objectCount)/int(data.equalGroups)
			for group in int(data.equalGroups):
				for fruit in count: adapter.action("fruit",group*count+fruit)
				adapter.action("group",0)
		assert(scene.stage_complete,"Buttons did not complete the drawing")
		adapter.set_paused(true)
		assert(scene.activity_paused and not scene.diagram.interactive)
		adapter.set_paused(false)
		var choices=scene._active_choices()
		for i in choices.get_child_count():
			var b=choices.get_child(i)
			if scene._demo_correct(data,b.get_meta("choice")):
				adapter.action("choice",i)
				break
		var choice=scene.selected_button
		adapter.apply_profile(p)
		assert(scene.selected_button==choice and scene.stage_complete)
		adapter.action("check",0)
		assert(scene.game_cat.celebration_done)
		assert(scene.victory_timer.is_stopped() and adapter.continue_button.visible)
		adapter.action("continue",0)
	# Error also waits for the pupil, and resets via the same controls.
	scene.round_index=0
	scene._show_round()
	scene._show_layer("game")
	adapter.action("part",0)
	adapter.action("choice",1)
	adapter.action("check",0)
	assert(scene.game_cat.failure_done and scene.retry_timer.is_stopped())
	adapter.action("continue",0)
	assert(not scene.submitting and not scene.stage_complete)
	print("PASS: strict profile validation, idempotent 200% text, live state preservation, four button-only exercises, reduced motion, untimed success/retry")
	quit()
