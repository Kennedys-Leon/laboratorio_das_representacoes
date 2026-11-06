extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	root.size = Vector2i(1100, 720)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.tutorial_checked_token = scene.api.token
	scene.tutorial_seen = true
	var menu_decor: Control = scene.find_child("MenuDecor", true, false)
	var menu_cat: Control = scene.find_child("MenuCat", true, false)
	assert(menu_decor.get_parent() == menu_cat.get_parent() and menu_decor.get_index() < menu_cat.get_index(),
		"Menu decorations draw over the cat's speech bubble")
	for phrase in scene.MENU_GREETINGS:
		scene.call("_show_menu_greeting")
		scene.menu_speech_label.text = phrase
		for settle in 4:
			await process_frame
		var bubble: Control = scene.menu_speech
		var tail: Control = scene.menu_speech_tail
		assert(bubble.size.y < 320, "Greeting grew beyond the space above the cat")
		assert(bubble.size.y + 1.0 >= bubble.get_combined_minimum_size().y,
			"Greeting text does not fit inside the ornate bubble")
		assert(absf(bubble.position.x + bubble.size.x * bubble.scale.x * 0.5 - 120.0) < 0.1)
		assert(not tail.visible, "Old triangle is visible over the integrated bubble tail")
	print("PASS: all greetings fit in the ornate bubble without duplicate tails")
	quit()
