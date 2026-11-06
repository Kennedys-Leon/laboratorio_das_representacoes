@tool
extends Control

const ART_SIZE := Vector2(1671.0, 941.0)

func _ready() -> void:
	resized.connect(_layout_art)
	_layout_art()

func _layout_art() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit: float = maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var origin := (size - ART_SIZE * fit) * 0.5
	_place($HowArtwork, origin, ART_SIZE, fit)
	$HowFloorBlur.position = Vector2(0.0, maxf(0.0, size.y - 57.0 * fit))
	$HowFloorBlur.size = Vector2(size.x, minf(size.y, 57.0 * fit))
	_place($HowCat, origin + Vector2(1315, 558) * fit, Vector2(180, 214), fit)
	$HowSpeech.position = origin + Vector2(1235, 365) * fit
	$HowSpeech.size = Vector2(300, 215)
	$HowSpeech.scale = Vector2.ONE * fit
	_place($HowSpeechTail, origin + Vector2(1383, 506) * fit, Vector2(44, 52), fit)
	_place($HowArtBackButton, origin + Vector2(650, 735) * fit, Vector2(365, 94), fit)

func _place(node: Control, at: Vector2, art_size: Vector2, fit: float) -> void:
	node.position = at
	node.size = art_size * fit
