class_name GameCatIdle
extends Control
signal celebration_finished
signal failure_finished

## Potion-mixing default for the exercise scene. The atlas supplies key poses;
## this control blends them on every rendered frame at the project's 60 FPS.

const FRAME_COUNT := 18
const INTRO: Array[int] = [0, 1, 2, 3, 4, 5]
# The final two storyboard poses pull the stirring paw back toward the face.
# Keeping the spoon-down poses together makes a calm, continuous mixing loop.
const STIR_LOOP: Array[int] = [6, 7, 8, 9, 10, 11, 12, 13,
	12, 11, 10, 9, 8, 7]

@onready var sprite: TextureRect = $CatSprite
@onready var next_sprite: TextureRect = $CatSpriteNext
@onready var table_flasks: TextureRect = $TableFlasks
@onready var standing_paws: TextureRect = $StandingLegs
@onready var beaker: TextureRect = $BeakerSprite
@onready var next_beaker: TextureRect = $BeakerSpriteNext
@onready var beaker_rim: TextureRect = $BeakerRim

var frames: Array[Texture2D] = []
var beaker_frames: Array[Texture2D] = []
var elapsed := 0.0
var pose_elapsed := 0.0
var pose_step := 0
var pose_index := 0
var stirring := false
var reduced_motion := false
var celebrating := false
var celebration_elapsed := 0.0
var celebration_done := false
var celebration_start_index := 15
var burst: Control
var praise: TextureRect
var failure_beaker: TextureRect
var celebration_beaker: TextureRect
var fixed_mixing_beaker: TextureRect
@onready var failure_effect: Control = $FailureReaction
@onready var retry_message: Control = $RetryMessage
var failing := false
var failure_done := false
var failure_elapsed := 0.0
@onready var failure_sprite: TextureRect = $FailureSprite
@onready var failure_props: TextureRect = $FailureProps
var failure_frames: Array[Texture2D] = []
var failure_frame_index := 0
const FAILURE_SECONDS := 4.0
const FAILURE_FPS := 60
const FAILURE_FRAME_COUNT := 240
const FAILURE_IDLE_FRAMES := 120
const FAILURE_CLOUD_START := 3.40

@onready var potion_bubbles: Control = $PotionBubbles


func _ready() -> void:
	var glass_shape: Texture2D = preload("res://assets/cat_animation/potion_mix/celebration_beaker.png")
	var bounds := glass_shape.get_image().get_used_rect()
	var dimensions := glass_shape.get_size()
	for layer in [failure_sprite, failure_props]:
		var depth_material := ShaderMaterial.new()
		depth_material.shader = preload("res://shaders/failure_depth.gdshader")
		depth_material.set_shader_parameter("foreground", layer == failure_props)
		depth_material.set_shader_parameter("glass_shape", glass_shape)
		depth_material.set_shader_parameter("glass_bounds", Vector4(bounds.position.x / dimensions.x, bounds.position.y / dimensions.y, bounds.size.x / dimensions.x, bounds.size.y / dimensions.y))
		layer.material = depth_material
	for index in FRAME_COUNT:
		var frame := load("res://assets/cat_animation/potion_mix/frame_%02d.png" % (index + 1)) as Texture2D
		assert(frame != null, "Missing potion animation frame %d" % (index + 1))
		frames.append(frame)
		beaker_frames.append(load("res://assets/cat_animation/potion_mix/beaker_%02d.png" % (index + 1)))
	for layer in [beaker, next_beaker]:
		var liquid_material := ShaderMaterial.new()
		liquid_material.shader = preload("res://shaders/beaker_liquid_mask.gdshader")
		layer.material = liquid_material
	var rim_material := ShaderMaterial.new()
	rim_material.shader = preload("res://shaders/beaker_liquid_mask.gdshader")
	rim_material.set_shader_parameter("glass_only", true)
	beaker_rim.material = rim_material
	fixed_mixing_beaker = TextureRect.new()
	fixed_mixing_beaker.texture = beaker_frames[6]
	fixed_mixing_beaker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fixed_mixing_beaker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fixed_mixing_beaker.size = beaker.size
	fixed_mixing_beaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_mixing_beaker.z_index = 2
	add_child(fixed_mixing_beaker)
	fixed_mixing_beaker.hide()
	burst = load("res://scripts/success_burst.gd").new()
	burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.z_as_relative = false
	burst.z_index = 90
	add_child(burst)
	praise = TextureRect.new()
	praise.texture = preload("res://assets/cat_animation/potion_mix/success_cloud.png")
	praise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	praise.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	praise.size = Vector2(220, 220)
	praise.pivot_offset = Vector2(110, 55)
	praise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	praise.z_as_relative = false
	praise.z_index = 100
	add_child(praise)
	# The final glass is a separate, fixed tabletop prop during the success pose.
	celebration_beaker = TextureRect.new()
	celebration_beaker.texture = preload("res://assets/cat_animation/potion_mix/celebration_beaker.png")
	celebration_beaker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	celebration_beaker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	celebration_beaker.size = Vector2(220, 220)
	celebration_beaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebration_beaker.z_index = 3
	add_child(celebration_beaker)
	celebration_beaker.hide()
	failure_beaker = TextureRect.new()
	var fixed_glass := AtlasTexture.new()
	fixed_glass.atlas = preload("res://assets/cat_animation/potion_mix/celebration_beaker.png")
	fixed_glass.region = Rect2(94, 192, 97, 75)
	failure_beaker.texture = fixed_glass
	failure_beaker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	failure_beaker.size = Vector2(97, 75) * (220.0 / 273.0)
	failure_beaker.position = Vector2(94, 192) * (220.0 / 273.0)
	failure_beaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	failure_beaker.z_index = 3
	add_child(failure_beaker)
	failure_beaker.hide()
	for atlas_index in 15:
		var sheet := load("res://assets/cat_animation/potion_mix/failure/motion_%02d.png" % atlas_index) as Texture2D
		assert(sheet != null, "Missing failure motion atlas %d" % atlas_index)
		for slot in 24:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2((slot % 6) * 279, (slot / 6) * 303, 279, 303)
			failure_frames.append(frame)
	assert(failure_frames.size() == FAILURE_FRAME_COUNT + FAILURE_IDLE_FRAMES)
	start_idle()


func start_idle() -> void:
	failing = false
	failure_done = false
	failure_elapsed = 0.0
	failure_frame_index = 0
	failure_effect.time = 0.0
	failure_effect.hide()
	potion_bubbles.time = 0.0
	potion_bubbles.hide()
	retry_message.hide()
	failure_sprite.hide()
	failure_props.hide()
	failure_beaker.hide()
	$CatShadow.show()
	standing_paws.show()
	$PotionTable.show()
	sprite.show()
	next_sprite.show()
	beaker.show()
	next_beaker.show()
	beaker_rim.hide()
	fixed_mixing_beaker.hide()
	for layer in [beaker, next_beaker]:
		layer.material.set_shader_parameter("liquid_only", false)
	elapsed = 0.0
	pose_elapsed = 0.0
	pose_step = 0
	stirring = false
	celebrating = false
	celebration_done = false
	celebration_elapsed = 0.0
	burst.progress = 0.0
	burst.set("time", 0.0)
	praise.hide()
	celebration_beaker.hide()
	pose_index = INTRO[0]
	if sprite != null:
		sprite.texture = frames[pose_index]
		next_sprite.texture = frames[INTRO[1]]
		next_sprite.modulate.a = 0.0
		beaker.texture = beaker_frames[0]
		beaker.modulate.a = 1.0
		next_beaker.texture = beaker_frames[1]
		next_beaker.modulate.a = 0.0
		for layer in [sprite, next_sprite, beaker, next_beaker]:
			layer.position = Vector2.ZERO
			layer.rotation = 0.0
		beaker_rim.position = Vector2.ZERO
		fixed_mixing_beaker.position = Vector2.ZERO
		standing_paws.position.x = 60.0
		table_flasks.hide()


func _process(delta: float) -> void:
	if reduced_motion: return
	if not is_visible_in_tree() or frames.is_empty():
		return
	elapsed += delta
	if failing:
		_animate_failure(delta)
		return
	if celebrating:
		_animate_celebration(delta)
		return
	pose_elapsed += delta
	var duration := _pose_duration()
	while pose_elapsed >= duration:
		pose_elapsed -= duration
		_advance_pose()
		duration = _pose_duration()
	var sequence := STIR_LOOP if stirring else INTRO
	pose_index = sequence[pose_step]
	var next_index := sequence[(pose_step + 1) % sequence.size()]
	if not stirring and pose_step == INTRO.size() - 1:
		next_index = STIR_LOOP[0]
	sprite.texture = frames[pose_index]
	next_sprite.texture = frames[next_index]
	beaker.texture = beaker_frames[pose_index]
	next_beaker.texture = beaker_frames[next_index]
	var progress := pose_elapsed / duration
	var blend := clampf((progress - 0.52) / 0.36, 0.0, 1.0)
	next_sprite.modulate.a = blend * blend * (3.0 - 2.0 * blend)
	next_beaker.modulate.a = next_sprite.modulate.a
	# Keep the complete glass steady while the liquid inside follows both poses.
	# Masking the changing frames prevents their mismatched side outlines from
	# ghosting through the cup's fixed silhouette.
	beaker.visible = true
	next_beaker.visible = true
	beaker_rim.visible = stirring
	fixed_mixing_beaker.visible = stirring
	for layer in [beaker, next_beaker]:
		layer.material.set_shader_parameter("liquid_only", stirring)
	# The bottles settle onto the tabletop with the same in-between blend,
	# then remain fixed while the cat's animated layers continue to sway.
	table_flasks.modulate.a = 1.0 if stirring or pose_index >= 5 else next_sprite.modulate.a if next_index >= 5 else 0.0
	table_flasks.visible = table_flasks.modulate.a > 0.0
	# A restrained shared sway keeps both overlapping poses aligned.
	var sway := sin(elapsed * TAU / 1.8) * 0.6
	standing_paws.position.x = 60.0 + sin(elapsed * TAU / 1.8) * 0.35
	sprite.position.y = sway
	next_sprite.position.y = sway
	# The whole central vessel rocks gently under the spoon. Its complete rim
	# moves with the glass, while the two smaller tabletop flasks stay fixed.
	var vessel_phase := elapsed * TAU / 1.8
	# A vessel supported by the wood sways sideways; its base does not bob
	# through the tabletop. Every glass layer shares the same displacement.
	var vessel_motion := Vector2(sin(vessel_phase) * 0.45, 0.0) if stirring else Vector2.ZERO
	beaker.position = vessel_motion
	next_beaker.position = vessel_motion
	beaker_rim.position = vessel_motion
	fixed_mixing_beaker.position = vessel_motion


func _pose_duration() -> float:
	if stirring:
		return 0.125
	return 0.34 if pose_step == 0 else 0.23


func _advance_pose() -> void:
	pose_step += 1
	if stirring:
		pose_step %= STIR_LOOP.size()
	elif pose_step >= INTRO.size():
		stirring = true
		pose_step = 0


func celebrate() -> void:
	celebrating = true
	celebration_done = false
	celebration_elapsed = 0.0
	celebration_start_index = pose_index
	table_flasks.hide()
	praise.hide()
	celebration_beaker.hide()
	beaker_rim.hide()
	fixed_mixing_beaker.hide()
	for layer in [beaker, next_beaker]:
		layer.material.set_shader_parameter("liquid_only", false)
	beaker.modulate.a = 1.0
	beaker.position = Vector2.ZERO
	next_beaker.position = Vector2.ZERO
	if reduced_motion: _animate_celebration(2.3)


func _animate_celebration(delta: float) -> void:
	celebration_elapsed += delta
	var t := celebration_elapsed
	# The raised-arm pose appears beneath the opaque potion smoke. Blending two
	# full poses made the gloves and their coat cuffs detach from one another.
	var index := celebration_start_index if t < 0.27 else 15 if t < 0.60 else 16 if t < 0.85 else 17
	var next_index := 15 if t < 0.27 else 16 if t < 0.60 else index
	var blend := smoothstep(0.0, 0.27, t) if t < 0.27 else smoothstep(0.27, 0.60, t) if t < 0.60 else 0.0
	sprite.texture = frames[index]
	beaker.texture = beaker_frames[index]
	next_sprite.texture = frames[next_index]
	next_beaker.texture = beaker_frames[next_index]
	next_sprite.modulate.a = blend
	next_beaker.modulate.a = blend
	var settle := smoothstep(1.4, 2.25, t)
	var phase := (t - 1.4) * TAU / 3.2
	var sway := sin(phase) * 0.6 * settle
	for layer in [sprite, next_sprite]:
		layer.pivot_offset = Vector2(110, 170)
		layer.rotation = deg_to_rad(0.35) * sin(phase) * settle
	sprite.position.y = sway
	next_sprite.position.y = sway
	beaker.position.y = 0.0
	next_beaker.position.y = 0.0
	standing_paws.position.x = 60.0 + sin(phase) * 0.2 * settle
	# The prop never follows the cat's bob. As the stick leaves the glass,
	# crossfade to the complete fixed beaker so its upper rim stays still too.
	var settled := smoothstep(0.68, 0.85, t)
	beaker.modulate.a = 1.0 - settled
	next_beaker.modulate.a = blend * (1.0 - settled)
	celebration_beaker.visible = settled > 0.0
	celebration_beaker.modulate.a = settled
	burst.progress = clampf((t - 0.15) / 2.0, 0.0, 1.0)
	burst.set("time", t)
	praise.visible = t >= 0.66
	if praise.visible:
		praise.modulate.a = smoothstep(0.66, 0.91, t)
		var rise := smoothstep(0.61, 1.90, t)
		praise.scale = Vector2.ONE * (1.0 + 0.22 * smoothstep(0.66, 1.35, t))
		praise.position = Vector2(0, 58.0 - 124.0 * rise)
	if t >= 2.25 and not celebration_done:
		celebration_done = true
		celebration_finished.emit()


func fail_attempt() -> void:
	if failing or celebrating:
		return
	failing = true
	failure_done = false
	failure_elapsed = 0.0
	failure_frame_index = 0
	table_flasks.hide()
	# The reaction uses the same perspective table and feet as the idle and
	# victory scenes. Only the complete upper-body reaction replaces the cat.
	$CatShadow.hide()
	standing_paws.show()
	$PotionTable.show()
	beaker.hide()
	next_beaker.hide()
	beaker_rim.hide()
	fixed_mixing_beaker.hide()
	celebration_beaker.hide()
	failure_effect.hide()
	potion_bubbles.hide()
	retry_message.hide()
	praise.hide()
	sprite.hide()
	next_sprite.hide()
	failure_sprite.texture = failure_frames[0]
	failure_props.texture = failure_frames[0]
	for layer in [failure_sprite, failure_props]:
		layer.material.set_shader_parameter("frame_origin", Vector2.ZERO)
		layer.material.set_shader_parameter("reaction_time", 0.0)
	failure_sprite.rotation = 0.0
	for layer in [failure_sprite, failure_props]:
		layer.position = Vector2(-30, -11)
	failure_sprite.pivot_offset = Vector2(140, 203)
	failure_sprite.show()
	failure_props.hide()
	failure_beaker.show()
	failure_effect.time = 0.001
	failure_effect.show()
	potion_bubbles.time = 0.0
	potion_bubbles.show()
	burst.progress = 0.0
	burst.time = 0.0
	if reduced_motion: _animate_failure(4.01)


func _animate_failure(delta: float) -> void:
	failure_elapsed += delta
	var t := failure_elapsed
	failure_effect.time = t
	potion_bubbles.time = minf(t, 4.0)
	failure_frame_index = clampi(roundi(t * FAILURE_FPS), 0, FAILURE_FRAME_COUNT - 1)
	if t >= FAILURE_SECONDS:
		failure_frame_index = FAILURE_FRAME_COUNT + (roundi((t - FAILURE_SECONDS) * FAILURE_FPS) % FAILURE_IDLE_FRAMES)
	failure_sprite.texture = failure_frames[failure_frame_index]
	failure_props.texture = failure_frames[failure_frame_index]
	var slot := failure_frame_index % 24
	var origin := Vector2((slot % 6) * 279, (slot / 6) * 303)
	for layer in [failure_sprite, failure_props]:
		layer.material.set_shader_parameter("frame_origin", origin)
		layer.material.set_shader_parameter("reaction_time", t)
	# Settle with the same small body sway as the success pose. Props remain
	# attached to the workbench while the upper body and feet share the rhythm.
	var settle := smoothstep(FAILURE_SECONDS, FAILURE_SECONDS + 0.8, t)
	var phase := (t - FAILURE_SECONDS) * TAU / 3.2
	failure_sprite.rotation = deg_to_rad(0.25) * sin(phase) * settle
	failure_sprite.position.y = -11.0 + sin(phase) * 0.3 * settle
	standing_paws.position.x = 60.0 + sin(phase) * 0.2 * settle
	# Same independent, whole cloud treatment as the victory effect: its text
	# never morphs with the character, and its particles continue during the wait.
	retry_message.visible = t >= FAILURE_CLOUD_START
	if retry_message.visible:
		var progress := clampf((t - FAILURE_CLOUD_START) / 0.58, 0.0, 1.0)
		var u := progress - 1.0
		var pop := 1.0 + 2.2 * u * u * u + 1.2 * u * u
		retry_message.scale = Vector2.ONE * maxf(0.03, pop)
		retry_message.position = Vector2(-30, lerpf(117.0, 85.0, smoothstep(0.0, 1.0, progress)))
		retry_message.modulate.a = smoothstep(0.0, 0.18, progress)
		retry_message.set("time", t - FAILURE_CLOUD_START)
	if t >= FAILURE_SECONDS and not failure_done:
		failure_done = true
		failure_finished.emit()
