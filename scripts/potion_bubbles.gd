@tool
extends Control
## Foreground bubbles stay within the liquid before breaking its surface.
@export_range(0.0, 4.8, 0.01) var time := 0.0:
	set(value):
		time = value
		queue_redraw()

func _draw() -> void:
	var strength := smoothstep(0.0, 0.25, time) * (1.0 - smoothstep(3.2, 3.65, time))
	if strength <= 0.0:
		return
	# The bubbling becomes denser and faster while the potion rises.
	var pressure := smoothstep(0.45, 2.2, time)
	var liquid_top := lerpf(178.0, 159.0, smoothstep(0.72, 1.65, time))
	for index in 12:
		var phase := fposmod(time * (0.8 + pressure * 0.9 + index % 4 * 0.12) + index * 0.137, 1.0)
		var point := Vector2(90 + (index * 11) % 49, 205 - phase * (205.0 - liquid_top))
		var radius := (1.1 + index % 4 * 0.48) * (0.7 + pressure * 0.5)
		var alpha := strength * sin(phase * PI)
		draw_circle(point, radius, Color("e5a8ff", alpha * 0.3), true, -1, true)
		draw_arc(point, radius, 0, TAU, 24, Color("ffe3ff", alpha * 0.45), 0.8, true)
