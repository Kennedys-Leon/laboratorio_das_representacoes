extends SceneTree
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
	var path := "user://tutorial-test-%s.cfg" % Time.get_ticks_usec()
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.tutorial_storage_path = path
	root.add_child(scene)
	await process_frame
	scene.menu_cat.set_reduced_motion(true)
	scene._play()
	assert(scene.current_layer == "how" and scene.tutorial_pending)
	assert(scene.how_layer.get_node("HowArtLayer").visible)
	assert(scene.how_layer.get_node("HowArtLayer/HowArtwork").texture != null)
	assert(scene.menu_cat.state != "walk")
	scene.how_layer.get_node("HowArtLayer/HowArtBackButton").pressed.emit()
	await process_frame
	assert(scene.current_layer == "game" and scene.tutorial_seen)
	scene._show_layer("menu")
	scene._play()
	await process_frame
	assert(scene.current_layer == "game")
	scene.queue_free()
	await process_frame
	var second = load("res://scenes/main.tscn").instantiate()
	second.tutorial_storage_path = path
	root.add_child(second)
	await process_frame
	second.menu_cat.set_reduced_motion(true)
	second._play()
	await process_frame
	assert(second.current_layer == "game", "Completed tutorial was not remembered")
	DirAccess.remove_absolute(path)
	print("PASS: first play shows instructions; Back starts the game; later visits skip instructions")
	quit()
