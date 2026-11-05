class_name SpeechPop
extends Control

const DURATION := 0.52
const COLORS := [Color("ffd65d"), Color("f299d4"), Color("a5ea79"), Color("c6a4ff")]

var center := Vector2.ZERO
var elapsed := DURATION


func _ready() -> void:
	set_process(false)


func burst(at: Vector2) -> void:
	center = at
	elapsed = 0.0
	set_process(true)
	queue_redraw()


func clear() -> void:
	elapsed = DURATION
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= DURATION:
		clear()


func _draw() -> void:
	if elapsed >= DURATION:
		return
	var progress := elapsed / DURATION
	for index in 10:
		var angle := TAU * index / 10.0 - PI / 2.0
		var travel := Vector2(cos(angle), sin(angle)) * (19.0 + progress * 78.0)
		var position := center + travel + Vector2(0, progress * progress * 13.0)
		var color: Color = COLORS[index % COLORS.size()]
		color.a = 1.0 - progress
		_draw_star(position, 7.0 * (1.0 - progress * 0.48), color)


func _draw_star(position: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in 8:
		var angle := -PI / 2.0 + TAU * point / 8.0
		var distance := radius if point % 2 == 0 else radius * 0.43
		points.append(position + Vector2(cos(angle), sin(angle)) * distance)
	draw_colored_polygon(points, color)
