@tool
extends Control

## Painted props share the background palette; small glints only provide motion.
@export_enum("menu", "game", "how", "feedback") var kind := "menu"

const DISPLAY: Texture2D = preload("res://assets/ui_decor/menu-display.png")
const PINK_POTION: Texture2D = preload("res://assets/ui_decor/potion-pink.png")
const BLUE_POTION: Texture2D = preload("res://assets/ui_decor/potion-blue.png")
const SHELF: Texture2D = preload("res://assets/ui_decor/lab-shelf.png")
const GOLD := Color("ffdd75")
var elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta
	queue_redraw()


func _rect_of(name: String) -> Rect2:
	var target := get_parent().find_child(name, true, false) as Control
	if target == null:
		return Rect2()
	return Rect2(target.global_position - global_position, target.size)


func _prop(texture: Texture2D, rect: Rect2, alpha := 1.0) -> void:
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))


func _mounted_shelf(rect: Rect2, card_edge_y := -1.0) -> void:
	# A painted shelf gives the props a shared surface and a cast shadow.
	rect.position.y = minf(rect.position.y, size.y - rect.size.y - 6.0)
	var plank_y := rect.position.y + rect.size.y * 0.70
	draw_set_transform(Vector2(rect.get_center().x, plank_y + 7), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, rect.size.x * 0.52, Color(0.10, 0.05, 0.15, 0.24))
	draw_set_transform(Vector2.ZERO)
	if card_edge_y >= 0.0 and card_edge_y < plank_y:
		for offset in [rect.size.x * 0.19, rect.size.x * 0.82]:
			var x: float = rect.position.x + float(offset)
			draw_line(Vector2(x, card_edge_y - 2), Vector2(x, plank_y + 1),
				Color("5e3b22"), 5.0, true)
			draw_line(Vector2(x - 0.7, card_edge_y - 2), Vector2(x - 0.7, plank_y),
				Color("d9a85b"), 1.2, true)
			draw_circle(Vector2(x, card_edge_y - 1), 2.7, Color("efc776"))
	_prop(SHELF, rect)


func _potion_badge(texture: Texture2D, rect: Rect2) -> void:
	var center := rect.get_center()
	var radius := rect.size.x * 0.69
	draw_circle(center + Vector2(1.5, 3.5), radius + 2, Color(0.10, 0.04, 0.16, 0.28))
	draw_circle(center, radius + 1, Color("bb8a53"))
	draw_circle(center, radius - 1.5, Color("36224d"))
	draw_arc(center, radius - 0.5, 0.18, PI - 0.18, 16,
		Color("f5d49b"), 1.2, true)
	_prop(texture, rect)


func _glint(center: Vector2, radius: float, phase: float = 0.0) -> void:
	var glow := 0.82 + 0.16 * sin(elapsed * 1.8 + phase)
	draw_circle(center, radius * 1.65, Color(1.0, 0.68, 0.23, 0.06 * glow))
	draw_circle(center, radius * 1.35, Color(1.0, 0.89, 0.42, 0.08 * glow))
	var points := PackedVector2Array()
	for i in 8:
		var angle := -PI * 0.5 + float(i) * PI * 0.25
		var length := radius if i % 2 == 0 else radius * 0.25
		points.append(center + Vector2(cos(angle), sin(angle)) * length)
	draw_colored_polygon(points, Color(GOLD.r, GOLD.g, GOLD.b, glow))
	draw_circle(center, 1.1, Color(1, 0.97, 0.83, glow))


func _button_glints(name: String, phase: float) -> void:
	var button := _rect_of(name)
	if button.size == Vector2.ZERO or not get_parent().find_child(name, true, false).visible:
		return
	_glint(button.position + Vector2(button.size.x - 10, 7), 4.5, phase)
	_glint(button.position + Vector2(7, button.size.y - 8), 3.0, phase + 1.9)


func _draw() -> void:
	match kind:
		"menu":
			_draw_menu()
		"game":
			_draw_game()
		"how":
			_draw_card("HowCard", "HowBackButton")
		"feedback":
			_draw_card("FeedbackCard", "FeedbackActionButton")


func _draw_menu() -> void:
	var play := _rect_of("PlayButton")
	if play.size == Vector2.ZERO:
		return
	if size.x >= 850:
		var display := Rect2(Vector2(size.x * 0.50, size.y * 0.055), Vector2(250, 273))
		draw_rect(Rect2(display.position + Vector2(13, 20), display.size - Vector2(9, 19)),
			Color(0.07, 0.03, 0.12, 0.18))
		_prop(DISPLAY, display)
		_mounted_shelf(Rect2(Vector2(size.x * 0.47, size.y * 0.50), Vector2(210, 124)))
		_glint(Vector2(size.x * 0.65, size.y * 0.51), 8, 1.0)
		_glint(Vector2(size.x * 0.48, size.y * 0.33), 6, 2.2)
	else:
		var top := maxf(play.end.y + 195, size.y - 220)
		_prop(DISPLAY, Rect2(Vector2((size.x - 205) * 0.5, top), Vector2(205, 224)))
	_button_glints("PlayButton", 0.4)
	_button_glints("HowButton", 1.5)
	_button_glints("ExitButton", 2.7)


func _draw_game() -> void:
	var card := _rect_of("GameCard")
	if card.size == Vector2.ZERO:
		return
	if size.x >= 900:
		# The parchment artwork already has its own bottles, books and stars.
		_button_glints("RepeatButton", 1.3)
		_button_glints("UndoButton", 2.2)
		_button_glints("CheckButton", 3.1)
		return
	var right := card.end.x
	var header_glint := Vector2(right - 28, card.position.y + 36) if size.x >= 900 else Vector2(right - 16, card.position.y - 9)
	_glint(header_glint, 11 if size.x >= 900 else 8, 0.7)
	_potion_badge(PINK_POTION, Rect2(card.position + Vector2(3, 286), Vector2(34, 48)))
	if size.x >= 900:
		_potion_badge(PINK_POTION, Rect2(Vector2(right - 76, card.position.y + 7), Vector2(34, 48)))
		_mounted_shelf(Rect2(Vector2(right - 129, card.end.y - 34), Vector2(126, 76)), card.end.y)
		_glint(Vector2(right + 10, card.position.y + 160), 7, 2.1)
		_glint(Vector2(right - 117, card.end.y - 65), 6, 1.0)
	var speech := _rect_of("CatSpeech")
	if speech.size != Vector2.ZERO and size.x >= 900:
		_glint(speech.position + Vector2(speech.size.x - 16, -8), 8, 3.0)
	_button_glints("RepeatButton", 1.3)
	_button_glints("UndoButton", 2.2)
	_button_glints("CheckButton", 3.1)


func _draw_card(card_name: String, button_name: String) -> void:
	var card := _rect_of(card_name)
	if card.size == Vector2.ZERO:
		return
	_glint(card.position + Vector2(-8, 35), 9, 0.8)
	_glint(Vector2(card.end.x + 8, card.position.y + 85), 8, 2.1)
	if size.x >= 900:
		_mounted_shelf(Rect2(Vector2(card.end.x - 133, card.end.y - 15), Vector2(128, 75)), card.end.y)
	else:
		_potion_badge(BLUE_POTION, Rect2(Vector2(card.end.x - 42, card.end.y - 36), Vector2(28, 39)))
	if size.x >= 900:
		_potion_badge(PINK_POTION, Rect2(Vector2(card.end.x - 64, card.position.y + 10), Vector2(38, 53)))
	_button_glints(button_name, 3.2)
