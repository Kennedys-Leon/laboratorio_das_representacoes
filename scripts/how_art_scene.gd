@tool
extends Control

const ART_SIZE := Vector2(1671.0, 941.0)
var cat_idle_time := 0.0

func _ready() -> void:
	resized.connect(_layout_art)
	_layout_art()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	cat_idle_time += delta
	var breath := 0.5 - 0.5 * cos(cat_idle_time * TAU / 2.5)
	($HowCat.material as ShaderMaterial).set_shader_parameter("breath_amount", breath)
	$HowCat.rotation = deg_to_rad(sin(cat_idle_time * TAU / 4.4) * 0.36)

func _layout_art() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit: float = maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var origin := (size - ART_SIZE * fit) * 0.5
	# Em telas mais altas, preserve o balão e o gatinho sem cortar o quadro de instruções.
	var speech_right := origin.x + (1235.0 + 300.0) * fit
	var speech_overflow := maxf(0.0, speech_right - size.x + 16.0)
	var parchment_margin := maxf(0.0, origin.x + 400.0 * fit - 20.0)
	origin.x -= minf(speech_overflow, parchment_margin)
	_place($HowArtwork, origin, ART_SIZE, fit)
	$HowFloorBlur.position = Vector2(0.0, maxf(0.0, size.y - 57.0 * fit))
	$HowFloorBlur.size = Vector2(size.x, minf(size.y, 57.0 * fit))
	_place($HowCat, origin + Vector2(1315, 558) * fit, Vector2(180, 214), fit)
	$HowCat.pivot_offset = Vector2($HowCat.size.x * 0.5, $HowCat.size.y * 0.97)
	($HowCat.material as ShaderMaterial).set_shader_parameter("sprite_width", $HowCat.size.x)
	($HowCat.material as ShaderMaterial).set_shader_parameter("sprite_height", $HowCat.size.y)
	($HowCat.material as ShaderMaterial).set_shader_parameter("art_scale", fit)
	$HowSpeech.position = origin + Vector2(1235, 365) * fit
	$HowSpeech.size = Vector2(300, 215)
	$HowSpeech.scale = Vector2.ONE * fit
	_place($HowSpeechTail, origin + Vector2(1383, 506) * fit, Vector2(44, 52), fit)
	_place($HowArtBackButton, origin + Vector2(650, 735) * fit, Vector2(365, 94), fit)

func _place(node: Control, at: Vector2, art_size: Vector2, fit: float) -> void:
	node.position = at
	node.size = art_size * fit
