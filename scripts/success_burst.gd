extends Control
## Colorful potion smoke; progress is driven at the game's 60 FPS.
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var time := 0.0:
	set(value):
		time = maxf(value, 0.0)
		queue_redraw()
const COLORS := [Color("f58bdd"), Color("a984ff"), Color("85eaaa"), Color("ffe980"), Color("8cd8ff")]
func _draw() -> void:
	if progress <= 0.0 and time <= 0.0:
		return
	var grow := smoothstep(0.0, 0.52, progress)
	var fade := 1.0 - smoothstep(0.43, 0.70, progress)
	var center := Vector2(110, 175 - grow * 53.0)
	for i in 64:
		var angle := float(i) * 2.39996
		var radius := (12.0 + float((i * 17) % 82)) * grow
		var point := center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.72)
		var color: Color = COLORS[i % COLORS.size()]
		color.a = 0.84 * fade
		draw_circle(point, (7.0 + float((i * 7) % 12)) * grow, color, true, -1.0, true)
	for i in 22:
		var angle := float(i) * TAU / 22.0
		var point := center + Vector2(cos(angle) * (48 + 53 * grow), sin(angle) * (34 + 47 * grow))
		var star := Color("ffe477", fade)
		draw_line(point + Vector2(-5, 0), point + Vector2(5, 0), star, 2.4, true)
		draw_line(point + Vector2(0, -5), point + Vector2(0, 5), star, 2.4, true)
	# A lighter ring of stars remains around the cat after the smoke settles.
	var final_alpha := smoothstep(1.20, 1.85, time)
	var positions := [
		Vector2(22, 90), Vector2(48, 65), Vector2(190, 70),
		Vector2(212, 111), Vector2(17, 148), Vector2(39, 175),
		Vector2(199, 165), Vector2(171, 190), Vector2(78, 48),
	]
	for i in positions.size():
		var twinkle := 0.65 + 0.35 * sin(time * 4.8 + float(i) * 1.27)
		var strength := final_alpha * twinkle
		if strength <= 0.0:
			continue
		var point: Vector2 = positions[i]
		var extent := (4.0 + float(i % 3) * 1.8) * (0.8 + 0.2 * twinkle)
		var glow := Color("ffc864", 0.22 * strength)
		var core := Color("fff3ad", 0.9 * strength)
		draw_circle(point, extent * 1.7, glow, true, -1.0, true)
		draw_line(point + Vector2(-extent, 0), point + Vector2(extent, 0), core, 2.4, true)
		draw_line(point + Vector2(0, -extent), point + Vector2(0, extent), core, 2.4, true)
		draw_circle(point, 1.8, Color(1, 1, 1, strength), true, -1.0, true)
