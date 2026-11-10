class_name CatAnimator
extends Control

signal walk_finished
signal walk_started

const IDLE_OPEN: Texture2D = preload("res://assets/cat_animation/v8/idle.png")
const TURN_ATLAS: Texture2D = preload("res://assets/cat_animation/v8/turn-60.png")
const TURN_FRAME_COUNT := 60
const TURN_FPS := 60.0
const TURN_SECONDS := 1.0
const WALK_SECONDS := 3.0
const WALK_RAMP_SECONDS := 0.24
# Stop on a double-support pose, with the cat still on screen when the scene changes.
var walk_route_distance := 140.0

@onready var sprite: TextureRect = $CatSprite
@onready var shadow: Panel = $CatShadow
@onready var walk_rig: Node2D = $CatWalkRig
@onready var paw_overlay: Node2D = $CatPawOverlay

var state := "idle"
var frame_index := 0
var elapsed := 0.0
var home_position := Vector2(46, 0)
var shadow_home_position := Vector2(55, 140)
var walk_distance := 0.0
var reduced_motion := false
var turn_start_position := Vector2.ZERO
var turn_start_rotation := 0.0
var breath_amount := 0.0
var turn_start_breath := 0.0
var turn_frames: Array[AtlasTexture] = []


func _ready() -> void:
	home_position = sprite.position
	shadow_home_position = shadow.position
	for i in TURN_FRAME_COUNT:
		var frame := AtlasTexture.new()
		frame.atlas = TURN_ATLAS
		frame.region = Rect2((i % 10) * 128, int(i / 10) * 152, 128, 152)
		frame.filter_clip = true
		turn_frames.append(frame)
	start_idle()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or state == "stopped":
		return
	elapsed += delta
	match state:
		"turn":
			_animate_turn()
		"walk":
			_animate_walk()
		_:
			_animate_idle()


func _animate_idle() -> void:
	# A smooth full breathing cycle, with the feet anchored to the floor.
	breath_amount = 0.5 - 0.5 * cos(elapsed * TAU / 2.5)
	(sprite.material as ShaderMaterial).set_shader_parameter("breath_amount", breath_amount)
	sprite.position = home_position
	sprite.rotation = deg_to_rad(sin(elapsed * TAU / 4.4) * 0.48)


func _animate_turn() -> void:
	frame_index = mini(int(floor(elapsed / TURN_SECONDS * TURN_FRAME_COUNT + 0.00001)), TURN_FRAME_COUNT - 1)
	sprite.texture = turn_frames[frame_index]
	# The authored 60-frame rise already carries both paws. Keep the walking rig
	# hidden until its endpoint matches the final standing frame exactly.
	walk_rig.call("set_turn_pose", elapsed / TURN_SECONDS)
	var settle := smoothstep(0.0, 0.35, elapsed)
	sprite.position = turn_start_position.lerp(home_position, settle)
	sprite.rotation = lerpf(turn_start_rotation, 0.0, settle)
	breath_amount = lerpf(turn_start_breath, 0.0, settle)
	(sprite.material as ShaderMaterial).set_shader_parameter("breath_amount", breath_amount)
	if elapsed >= TURN_SECONDS:
		_begin_walk(elapsed - TURN_SECONDS)


func _animate_walk() -> void:
	# Integrate symmetric acceleration and braking. The paws are driven by the
	# distance travelled, so neither foot slides while it supports the body.
	var time := clampf(elapsed, 0.0, WALK_SECONDS)
	var ramp := WALK_RAMP_SECONDS
	var speed := walk_route_distance / (WALK_SECONDS - ramp)
	if time < ramp:
		var u := time / ramp
		walk_distance = speed * ramp * (u * u * u - 0.5 * u * u * u * u)
	elif time > WALK_SECONDS - ramp:
		var u := (WALK_SECONDS - time) / ramp
		walk_distance = walk_route_distance - speed * ramp * (u * u * u - 0.5 * u * u * u * u)
	else:
		walk_distance = speed * (time - ramp * 0.5)
	walk_rig.position = home_position + Vector2(walk_distance, 0)
	walk_rig.set("distance", walk_distance)
	shadow.position.x = shadow_home_position.x + walk_distance
	# Let the bubble follow the first steps, then fade it before its edge reaches
	# the viewport. Moving the bubble independently detached its tail from the cat.
	var bubble: TextureRect = $CatWalkRig/WalkSpeech
	var clearance := get_viewport_rect().end.x - bubble.get_global_rect().end.x
	bubble.modulate.a = smoothstep(0.0, 0.18, elapsed) * smoothstep(2.0, 25.0, clearance)
	if elapsed >= WALK_SECONDS:
		state = "stopped"
		walk_finished.emit()


func start_idle() -> void:
	modulate.a = 1.0
	state = "stopped" if reduced_motion else "idle"
	frame_index = 0
	elapsed = 0.0
	walk_distance = 0.0
	breath_amount = 0.0
	(sprite.material as ShaderMaterial).set_shader_parameter("breath_amount", 0.0)
	sprite.position = home_position
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.texture = IDLE_OPEN
	sprite.show()
	walk_rig.hide()
	walk_rig.call("set_turn_pose", 0.0)
	walk_rig.modulate.a = 0.0
	paw_overlay.hide()
	paw_overlay.position = home_position
	(sprite.material as ShaderMaterial).set_shader_parameter("rise_progress", 0.0)
	walk_rig.position = home_position
	walk_rig.set("distance", 0.0)
	shadow.position = shadow_home_position
	shadow.modulate.a = 1.0


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled and (state == "turn" or state == "walk"):
		state = "stopped"
		walk_finished.emit()
	elif state == "idle" or state == "stopped":
		start_idle()


func walk_out() -> void:
	if state == "walk" or state == "turn":
		return
	state = "turn"
	elapsed = 0.0
	turn_start_position = sprite.position
	turn_start_rotation = sprite.rotation
	turn_start_breath = breath_amount
	sprite.texture = turn_frames[0]
	paw_overlay.hide()


func _begin_walk(carry_time := 0.0) -> void:
	state = "walk"
	# Keep the fraction of a rendered frame left after the final rise pose.
	# This removes a tiny cadence pause when the display delta is not exact.
	elapsed = carry_time
	walk_distance = 0.0
	sprite.position = home_position
	sprite.rotation = 0.0
	sprite.hide()
	walk_rig.position = home_position
	walk_rig.set("distance", 0.0)
	walk_rig.call("begin_walk")
	walk_rig.modulate.a = 1.0
	paw_overlay.hide()
	walk_rig.show()
	var edge := (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect().end).x
	var desired := maxf(40.0, edge - home_position.x - 105.0)
	walk_route_distance = walk_rig.FIRST_STEP + roundf((desired - walk_rig.FIRST_STEP) / walk_rig.STEP_LENGTH) * walk_rig.STEP_LENGTH
	walk_started.emit()
	_animate_walk()
