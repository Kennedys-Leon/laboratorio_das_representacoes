extends SceneTree
## Actual original scene + public lesson envelopes; no HTTP correction is simulated
## as official history. The API suite separately checks all private keys.
func _initialize() -> void:
	call_deferred("verify")


func verify() -> void:
	var fixture := OS.get_environment("GAUSS_PUBLIC_ROUNDS")
	assert(not fixture.is_empty())
	var values: Array = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var bridge: Node = scene.lesson_bridge
	assert(bridge != null)
	for entry in values:
		var envelope := {"contractVersion":1,"gameId":scene.GAME_ID,"lessonId":entry.lesson,"lessonVersion":entry.version,"phaseId":entry.phaseId,"exerciseId":entry.exerciseId,"prompt":entry.prompt,"round":entry.round,"response":entry.response,"practiceMode":"lesson"}
		bridge.configure({"round":envelope})
		await process_frame
		assert(bridge.configured and scene.current_layer == "game", entry.exerciseId)
		assert(bridge.choice() == null, "A question started with a selected answer: " + entry.exerciseId)
		assert(scene.rounds[0].prompt == entry.prompt)
		if entry.round.kind == "laboratorio_representation":
			var node: Control = bridge.current_node()
			var controls: Array = node.official_controls()
			assert(not controls.is_empty(), entry.exerciseId)
			for control in controls:
				if not control.get("disabled", false):
					node.official_action(str(control.id))
					break
			var state: Dictionary = bridge.work_state()
			bridge.configure({"round":envelope,"workState":state})
			assert(bridge.work_state() == state, "State did not restore: " + entry.exerciseId)
		if entry.response.kind == "number":
			bridge.number_answer.text = "999"
		else:
			scene._select(scene.parts_choices.get_child(0))
		bridge.submit_answer()
		assert(bridge.waiting and not scene.result_correct, "The client corrected without the API")
		bridge.receive({"type":"gauss-medidas-error","message":"Connection test"})
		assert(bridge.uncertain and not scene.check_button.disabled)
		bridge.submit_answer()
		assert(bridge.waiting)
		bridge.receive({"type":"gauss-medidas-result","correct":false,"reason":"API test feedback"})
		assert(bridge.feedback_received and scene.status_label.text == "API test feedback")
		bridge.finish_animation()
		bridge.submit_answer()
		assert(not bridge.feedback_received and not scene.submitting)
		print("PUBLIC_SCENE_OK ", entry.exerciseId, " ", bridge.instrument_name())
	scene.queue_free()
	await process_frame
	print("PASS: ", values.size(), " public lesson instruments, original scene, empty choices, state restore and pending locks")
	quit()
