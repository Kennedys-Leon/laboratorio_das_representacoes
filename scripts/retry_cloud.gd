@tool
extends Control
## Entire scalloped smoke cloud; no atlas crop, mask or clipping rectangle.

@export_range(0.0, 10.0, 0.01) var time := 0.0:
	set(value):
		time = value
		queue_redraw()

const CLOUD = preload("res://assets/cat_animation/potion_mix/failure/retry_cloud.png")

func _ready() -> void:
	$Message.hide() # Lettering is part of the reference artwork.

func _draw() -> void:
	draw_texture_rect(CLOUD, Rect2(12, 0, 256, 155), false)
	# A lively halo of sparks echoes the victory cloud's little stars.
	for index in 18:
		var angle := TAU * float(index) / 18.0 + 0.12
		var center := Vector2(140, 70) + Vector2(cos(angle) * (117 + index % 3 * 5), sin(angle) * (52 + index % 4 * 2))
		var glint := 0.55 + 0.45 * sin(time * 5.2 + index * 1.3)
		var extent := (3.0 + index % 3 * 1.2) * glint
		var color := Color("ffe591", 0.64 + 0.36 * glint) if index % 3 else Color("ffbdea", 0.7 + 0.3 * glint)
		draw_circle(center, extent * 1.8, Color(color.r, color.g, color.b, 0.16), true, -1, true)
		draw_line(center - Vector2(extent, 0), center + Vector2(extent, 0), color, 2.1, true)
		draw_line(center - Vector2(0, extent), center + Vector2(0, extent), color, 2.1, true)
	for index in 8:
		var phase := time * 2.3 + index * 0.8
		var center := Vector2(21 + index * 33, 120 - fposmod(phase * 8.0, 27.0))
		draw_circle(center, 2.0 + index % 3, Color("d6a2fa", 0.55 + 0.25 * sin(phase)), true, -1, true)
