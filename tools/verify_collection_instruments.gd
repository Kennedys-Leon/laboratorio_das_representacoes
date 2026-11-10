extends SceneTree

func _initialize() -> void:
	call_deferred("verify")


func verify() -> void:
	var node: Control = load("res://scripts/apple_collection.gd").new()
	root.add_child(node)
	node.interactive = true
	var models := [
		["collection", {"total":15,"groups":3,"objectLabel":"fichas","objectStyle":"chip","task":"share"}],
		["collection", {"total":20,"groupSize":4,"objectLabel":"tampas","objectStyle":"cap","task":"form_groups"}],
		["percentage", {"total":60,"groups":4,"objectLabel":"peças","objectStyle":"counter","task":"percent","percentages":[75]}],
		["ratio", {"total":45,"groups":2,"objectLabel":"mudas","objectStyle":"seedling","task":"ratio","ratios":[1,2]}],
		["ratio", {"groups":2,"objectLabel":"partes","objectStyle":"counter","task":"ratio","ratios":[1,2]}],
		["ratio", {"total":50,"groups":2,"objectLabel":"itens","objectStyle":"counter","task":"ratio","givenGroups":[10,40]}],
	]
	for entry in models:
		# Exercise the same numeric types as the JSON bridge.
		node.configure_official(JSON.parse_string(JSON.stringify(entry[1])), entry[0])
		var initial: Dictionary = node.official_state()
		if entry[1].has("givenGroups"):
			node.official_action("bundle-10")
			assert(node.official_state().allocations == initial.allocations)
		elif not entry[1].has("total"):
			node.official_action("subdivide")
			assert(node.official_state().unitFactor == 2)
		else:
			assert(initial.allocations.count(-1) == entry[1].total)
			node.official_action("add-10")
			assert(node.official_state().allocations.count(0) == 10, "Wrong-sized groups must remain constructible")
			if entry[0] == "percentage": node.official_action("mark-group")
			if entry[1].task == "form_groups": node.official_action("new-group")
		var state: Dictionary = node.official_state()
		node.configure_official(entry[1], entry[0])
		node.restore_official_state(JSON.parse_string(JSON.stringify(state)))
		assert(node.official_state() == state)
		node.interactive = false
		node.official_action("reset")
		assert(node.official_state() == state, "Locked state changed")
		node.interactive = true
		print("COLLECTION_INSTRUMENT_OK ", entry[0], " ", entry[1].get("task"))
	node.clear_official()
	assert(not node.official_mode)
	node.queue_free()
	await process_frame
	print("PASS: original tray, free incorrect allocations, groups, percentage, proportions, given quantities and JSON restore")
	quit()
