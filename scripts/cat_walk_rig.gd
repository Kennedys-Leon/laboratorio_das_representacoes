@tool
extends Node2D
## Two independently animated hind paws. The planted paw is fixed in world space.

const ART: Texture2D = preload("res://assets/cat_animation/v8/standing.png")
const GROUND_Y := 150.0
const STEP_LENGTH := 8.0
const FIRST_STEP := STEP_LENGTH
const FIRST_SWING := STEP_LENGTH * 2.0 - 3.0
const DOUBLE_SUPPORT := 0.20
const LIFT := 3.3
const BODY_PIVOT := Vector2(70, 129)
const BODY_BOB := 1.05
const BODY_LEAN := 0.9
const BODY_SWAY := 0.22
const BIND_FEET := [Vector2(54, GROUND_Y), Vector2(85, GROUND_Y)]
const HIPS := [Vector2(53, 130), Vector2(81, 129)]
var fur_colors: Array[Color] = []
# The body keeps the coat hem. The foot polygons start below it, so a white
# coat fragment cannot travel with either paw during a step.
const BODY := [Vector2(0, 0), Vector2(128, 0), Vector2(128, 131),
	Vector2(93, 131), Vector2(86, 133), Vector2(82, 130), Vector2(72, 131),
	Vector2(68, 134), Vector2(64, 135), Vector2(55, 134), Vector2(49, 132),
	Vector2(45, 134), Vector2(45, 152), Vector2(0, 152)]
const FAR_LEG := [Vector2(44, 134), Vector2(68, 134), Vector2(71, 138),
	Vector2(71, 152), Vector2(44, 152)]
const NEAR_LEG := [Vector2(70, 134), Vector2(91, 134), Vector2(105, 142),
	Vector2(106, 152), Vector2(70, 152)]

func _init() -> void:
	var original := ART.get_image()
	for sample in [Vector2i(60, 136), Vector2i(81, 135)]:
		fur_colors.append(original.get_pixelv(sample))

var walking := true
var pose_feet: Array[Vector2] = [Vector2(62, 150), Vector2(92, 150)]

func set_turn_pose(progress: float) -> void:
	walking = false
	var rise := smoothstep(0.22, 0.80, progress)
	pose_feet = [Vector2(62, 150).lerp(BIND_FEET[0], rise),
		Vector2(92, 150).lerp(BIND_FEET[1], rise)]
	queue_redraw()

func begin_walk() -> void:
	walking = true
	distance = 0.0

@export_range(0.0, 620.0, 0.1) var distance := 0.0:
	set(value):
		distance = maxf(0.0, value)
		queue_redraw()


func foot_positions() -> Array[Vector2]:
	if not walking:
		return pose_feet
	# Each paw advances from its own authored ankle. The old first stride
	# used the other ankle as its destination and overextended the far thigh.
	# Start with a half stride. A full first stride left the right paw a
	# whole step behind its hip, while the left paw stayed ahead of its hip.
	var starting := distance < FIRST_STEP
	var travel := maxf(0.0, distance - FIRST_STEP)
	var step := int(floor(travel / STEP_LENGTH))
	var phase := distance / FIRST_STEP if starting else fposmod(travel, STEP_LENGTH) / STEP_LENGTH
	var swing := clampf((phase - DOUBLE_SUPPORT) / (1.0 - DOUBLE_SUPPORT), 0.0, 1.0)
	var ease := swing * swing * (3.0 - 2.0 * swing)
	var moving := 0 if starting else (step + 1) % 2
	var feet: Array[Vector2] = []
	for leg in 2:
		# Each planted paw has a fixed world position. At a step boundary,
		# the next stance starts at precisely the previous swing endpoint.
		var completed := floori(float(step) / 2.0) if leg == 0 else floori(float(step + 1) / 2.0)
		var world_x: float = BIND_FEET[leg].x + completed * 2.0 * STEP_LENGTH
		if leg == 0 and not starting: world_x += FIRST_SWING
		var lift := 0.0
		if leg == moving:
			world_x += ease * (FIRST_SWING if starting else 2.0 * STEP_LENGTH)
			lift = LIFT * (0.75 if starting else 1.0) * pow(sin(swing * PI), 2)
		feet.append(Vector2(world_x - distance, GROUND_Y - lift))
	return feet


func body_pose() -> Vector2:
	# Derive the torso directly from the actual lifted paw. There is no
	# independent rocking cycle that can drift relative to a footfall.
	if not walking:
		return Vector2.ZERO
	var feet := foot_positions()
	var far_lift := (GROUND_Y - feet[0].y) / LIFT
	var near_lift := (GROUND_Y - feet[1].y) / LIFT
	return Vector2(-BODY_BOB * maxf(far_lift, near_lift),
		deg_to_rad(BODY_LEAN) * (far_lift - near_lift))


func _body_point(point: Vector2, pose: Vector2) -> Vector2:
	var feet := foot_positions()
	var feet_center := (feet[0].x + feet[1].x) * 0.5
	var weight_shift := BODY_SWAY * pose.y / deg_to_rad(BODY_LEAN) + clampf((feet_center - 69.5) * 0.15, -0.8, 0.8)
	return BODY_PIVOT + (point - BODY_PIVOT).rotated(pose.y) + Vector2(weight_shift, pose.x)


func _draw() -> void:
	var feet := foot_positions()
	var pose := body_pose()
	for leg in 2:
		_draw_attachment(leg, feet[leg], pose)
		_draw_leg(leg, feet[leg])
	if not walking:
		return
	var body_points := PackedVector2Array()
	var body_uv := PackedVector2Array()
	for point: Vector2 in BODY:
		body_points.append(_body_point(point, pose))
		body_uv.append(point / Vector2(128, 152))
	draw_polygon(body_points, PackedColorArray([Color.WHITE]), body_uv, ART)


func _draw_attachment(index: int, foot: Vector2, pose: Vector2) -> void:
	# A round, articulated connector sits behind the intact source drawing.
	# Only this hidden upper leg bends; no paw pixels are stretched or sheared.
	var hip: Vector2 = _body_point(HIPS[index], pose) + Vector2(0, -3)
	var ankle := foot + Vector2(0, -9)
	var bend := -1.5 if index == 0 else 1.5
	var knee := hip.lerp(ankle, 0.5) + Vector2(bend, 0)
	var outline := Color("171020")
	draw_polyline(PackedVector2Array([hip, knee, ankle]), outline, 13.0, true)
	draw_circle(knee, 6.5, outline, true, -1.0, true)
	draw_polyline(PackedVector2Array([hip, knee, ankle]), fur_colors[index], 9.0, true)
	draw_circle(knee, 4.5, fur_colors[index], true, -1.0, true)


func _draw_leg(index: int, foot: Vector2) -> void:
	# Translate the ENTIRE original leg, including its upper contour, rigidly.
	# Previously a 2–7 px strip carried the full stride deformation and folded.
	var shift: Vector2 = foot - BIND_FEET[index]
	var source: Array = FAR_LEG if index == 0 else NEAR_LEG
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for point: Vector2 in source:
		points.append(point)
		uv.append(point / Vector2(128, 152))
	draw_set_transform(shift)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, ART)
	draw_set_transform(Vector2.ZERO)
