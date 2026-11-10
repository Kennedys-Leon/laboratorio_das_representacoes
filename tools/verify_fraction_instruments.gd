extends SceneTree
## Focused tests of public givens, exploration, free distributions and resume.

func _initialize() -> void:
	call_deferred("verify")


func verify() -> void:
	var script = load("res://scripts/fraction_diagram.gd")
	var original: Control = script.new()
	root.add_child(original)
	original.interactive = true
	original.equal_parts = 4
	original.select_part(2)
	assert(original.selected_parts == PackedInt32Array([2]))
	original.undo_selection()
	assert(original.selected_parts.is_empty())
	original.queue_free()
	var examples := [
		["parts", {"parts":5,"markedParts":[0,1,2,3],"shape":"strip"}],
		["equivalence", {"parts":5,"markedParts":[0,1],"targetParts":10,"variant":"equivalent"}],
		["comparison", {"values":["3/4","0,5","1/4"],"mode":"order"}],
		["decimal", {"wholeUnits":7,"hundredths":26}],
		["number_line", {"start":0,"end":1,"intervals":100,"targetTick":1,"majorStep":10}],
		["bread_share", {"loaves":7,"people":4,"piecesPerLoaf":4}],
	]
	var board := Control.new()
	root.add_child(board)
	var paper := ColorRect.new()
	paper.color = Color("fffaf0")
	paper.size = Vector2(1180, 840)
	board.add_child(paper)
	var diagrams := []
	for index in examples.size():
		var diagram: Control = script.new()
		diagram.position = Vector2((index % 2) * 590, int(index / 2) * 275)
		diagram.size = Vector2(570, 250)
		diagram.interactive = true
		board.add_child(diagram)
		diagram.configure_official(examples[index][1], examples[index][0])
		diagrams.append(diagram)
	var parts: Control = diagrams[0]
	# Test the actual JSON transport, not only GDScript integer literals.
	parts.configure_official(JSON.parse_string('{"parts":5,"markedParts":[0,1,2,3],"shape":"strip"}'), "parts")
	assert(parts.official_instrument.model.markedParts.has(3), "JSON given marks disappeared from the figure")
	parts.official_action("part-4")
	assert(parts.official_state().observed == [4])
	assert(parts.official_instrument.model.markedParts == [0,1,2,3], "Exploration changed the question's marks")
	parts.official_action("undo")
	assert(parts.official_state().observed == [])
	var equivalent: Control = diagrams[1]
	equivalent.official_action("divide")
	assert(equivalent.official_state().factor == 2)
	equivalent.official_action("paint-9")
	assert(equivalent.official_state().painted == [9], "A mathematically unmatched construction must remain possible")
	var comparison: Control = diagrams[2]
	assert(comparison.official_state().order == [0,1,2], "Ordering cannot be pre-solved")
	comparison.official_action("value-0")
	comparison.official_action("right")
	assert(comparison.official_state().order == [1,0,2])
	var saved_order: Dictionary = comparison.official_state()
	comparison.official_action("reset")
	comparison.restore_official_state(JSON.parse_string(JSON.stringify(saved_order)))
	assert(comparison.official_state().order == [1,0,2])
	comparison.official_action("right")
	assert(comparison.official_state().order == [1,2,0], "Reloaded numeric card IDs stopped responding")
	var decimal: Control = diagrams[3]
	decimal.official_action("groups")
	decimal.official_action("inspect-next")
	assert(decimal.official_state().groupView and decimal.official_state().observed == [0])
	assert(not decimal.official_instrument.model.has("notation"), "The writing task cannot be given its numeral")
	var line: Control = diagrams[4]
	assert(line.official_state().cursor == -1)
	line.official_action("next")
	line.official_action("next")
	line.official_action("zoom")
	assert(line.official_state().cursor == 1 and line.official_state().zoom)
	var bread: Control = diagrams[5]
	bread.official_action("give")
	assert(bread.official_state().assignments.count(-1) == 28)
	bread.official_action("cut")
	for index in 7: bread.official_action("give")
	assert(bread.official_state().assignments.count(0) == 7)
	bread.official_action("person-3")
	bread.official_action("give")
	assert(bread.official_state().assignments.count(3) == 1)
	var saved: Dictionary = bread.official_state()
	bread.official_action("reset")
	bread.restore_official_state(saved)
	assert(bread.official_state() == saved, "Resume changed the pupil's construction")
	bread.restore_official_state({"factor":999,"recipient":999,"assignments":[99],"positions":[99],"order":[99]})
	assert(bread.official_state().recipient == 3 and bread.official_state().assignments.count(-1) == 28)
	bread.restore_official_state(saved)
	await process_frame
	await process_frame
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/laboratorio-fracoes-instruments.png")
	print("PASS: six original-scene fraction instruments; givens, unsolved ordering, free painting/distribution, resume and legacy paint")
	board.queue_free()
	await process_frame
	quit()
