@tool
extends Control

@export_range(0.0, 10.0, 0.01) var time := 0.0:
	set(value):
		time = value
		queue_redraw()
const FLASKS = preload("res://assets/cat_animation/potion_mix/table_flasks.png")
const INK := Color("38224c")
const PURPLE := Color("b149ee")
const IMPACTS := [1.50, 1.58]
const GLASS_WIDTH := 48.6
const GLASS_HEIGHT := 58.1
const CONTACT_ANGLE := PI * 0.5
const BREAK_HOLD := 0.05

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	if radius.x < 0.05 or radius.y < 0.05: return
	draw_set_transform(center, 0.0, radius / 32.0)
	draw_circle(Vector2.ZERO,32,color,true,-1,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if time <= 0: return
	# Liquid reaches the wood before the connected pool begins spreading.
	var spread := smoothstep(2.62,3.65,time)
	if spread > 0:
		for i in 9:
			var direction := float(i-4)/4.0
			var center := Vector2(115 + direction * 66 * spread, 201 + sin(i*2.1)*3)
			var radius := Vector2(18,5.5) * sqrt(spread)
			_ellipse(center+Vector2(0,1),radius+Vector2(1,0.8),INK)
			_ellipse(center,radius,PURPLE)
			_ellipse(center+Vector2(-3,-1.8),radius*Vector2(0.48,0.15),Color("edb9ff"))
	var front := smoothstep(2.25,2.83,time)
	var flow := smoothstep(2.20,2.50,time)*(1-smoothstep(3.3,3.9,time))
	if flow > 0.02 and front > 0.02:
		for side in [-1.0,1.0]:
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			var shine := PackedVector2Array()
			for i in 28:
				var u := float(i)/27*front
				# Both streams begin at the fixed rim and reach the table gradually.
				var p := Vector2(115+side*(34+6*u*u),157+44*u)
				p.x += sin(u*8-time*4)*0.35*u
				var width := (3.6-1.7*u)*flow
				left.append(p-Vector2(width,0))
				right.append(p+Vector2(width,0))
				shine.append(p-Vector2(width*0.35,0))
			var shape := left.duplicate()
			right.reverse()
			shape.append_array(right)
			draw_colored_polygon(shape,Color("c969f3"))
			shape.append(shape[0])
			draw_polyline(shape,INK,1.3,true)
			draw_polyline(shine,Color("f2beff"),1,true)
			_ellipse(left[-1]+Vector2(1.5,0),Vector2(2.7,3.4)*flow,Color("ce7bf6"))
	# The liquid climbs inside the fixed glass before the rounded foam crests
	# over its mouth. Keep the fill inside the transparent inner wall so the
	# rim and side highlights remain connected to the original cup artwork.
	_draw_rising_liquid()
	# Keep the rounded, cartoon foam. Its lobes share the glass's fixed rim,
	# so the cup, foam and streams cannot drift apart as the cat reacts.
	var foam := smoothstep(1.02, 1.92, time) * (1.0 - 0.22 * smoothstep(3.55, 4.0, time))
	if foam > 0.01:
		_draw_foam(foam)
	# A few drops bounce at the two contact points, without a radial explosion.
	for i in 8:
		var u := (time-(2.64+i*0.055))/0.43
		if u <= 0 or u >= 1: continue
		var side := -1.0 if i%2==0 else 1.0
		var p := Vector2(115+side*(40+13*u),201-sin(u*PI)*(6+i%3*2))
		_ellipse(p,Vector2(1.8,2.5),Color("d784ff"))
	for side in 2:
		var impact: float = IMPACTS[side]
		var direction := -1.0 if side==0 else 1.0
		var center_x := 37.0 if side==0 else 191.0
		var pivot := Vector2(center_x-direction*GLASS_WIDTH*0.5,201.5)
		var fall := smoothstep(impact-0.52, impact, time)
		var angle := direction*CONTACT_ANGLE*fall
		# Raise the rolling flask by the projection of its base. Its lowest
		# point stays on the tabletop instead of passing through the wood.
		var rolling_pivot := pivot - Vector2(0, GLASS_WIDTH * sin(absf(angle)))
		if time < impact + BREAK_HOLD:
			# At 90 degrees the mouth and base both rest on the tabletop.
			# Hold the complete flask there briefly before revealing shards.
			draw_set_transform(rolling_pivot,angle,Vector2.ONE)
			var x := -GLASS_WIDTH if side==0 else 0.0
			draw_texture_rect_region(FLASKS,Rect2(x,-GLASS_HEIGHT,GLASS_WIDTH,GLASS_HEIGHT),Rect2(13+side*195,187,62,74))
			draw_set_transform(Vector2.ZERO)
		else:
			var u := clampf((time-impact-BREAK_HOLD)/0.62,0,1)
			for shard in 8:
				var start := Vector2(center_x+(shard-3.5)*5.7+sin(shard*2.1)*1.8,
					198.0+(shard%3)*1.5)
				var end := Vector2(center_x+(shard-3.5)*5.7,197+(shard%3)*3)
				var p := start.lerp(end,u)
				p.y -= 4*u*(1-u)*(4+shard%3*2)
				var bounce := sin(clampf((u-0.7)/0.3,0,1)*PI)*1.3
				p.y -= bounce
				var rotation_angle := direction*(0.3+shard*0.53)*smoothstep(0,1,u)
				draw_set_transform(p,rotation_angle,Vector2.ONE)
				var width := 3.0+shard%3
				var polygon := PackedVector2Array([Vector2(-width,2),Vector2(-1,-4-shard%2*2),Vector2(width,0),Vector2(width*0.4,3)])
				draw_colored_polygon(polygon,Color("a99bc7"))
				polygon.append(polygon[0])
				draw_polyline(polygon,INK,1.3,true)
				draw_line(Vector2(-1,-3),Vector2(width-1,0),Color("f7eaff"),1.1,true)
				draw_set_transform(Vector2.ZERO)
			var ring := clampf((time-impact-BREAK_HOLD)/0.23,0,1)
			if ring < 1:
				for ray in 3:
					var v := Vector2.from_angle(-PI*0.8+ray*0.3*PI)
					draw_line(Vector2(center_x,198)+v*(9+ring*8),Vector2(center_x,198)+v*(13+ring*10),Color(1,0.9,0.65,(1-ring)*0.8),1.5,true)

func _draw_rising_liquid() -> void:
	if time < 0.72: return
	var rise := smoothstep(0.72, 2.43, time)
	var surface := lerpf(178.0, 158.5, rise)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var crest := PackedVector2Array()
	for i in 13:
		var x := 93.0 + i * (44.0 / 12.0)
		var y := surface + sin(i * 0.85 - time * 4.1) * 0.85 * rise
		points.append(Vector2(x, y))
		colors.append(Color("d280f5"))
		crest.append(Vector2(x, y + 0.6))
	points.append(Vector2(137, 182))
	points.append(Vector2(93, 182))
	colors.append(Color("982be3"))
	colors.append(Color("982be3"))
	draw_polygon(points, colors)
	draw_polyline(crest, Color("f0b9ff"), 1.2, true)

func _draw_foam(growth: float) -> void:
	var lobes: Array[Vector3] = [
		Vector3(82, 157, 6), Vector3(91, 153, 8), Vector3(101, 149, 8),
		Vector3(112, 148, 9), Vector3(123, 149, 8), Vector3(134, 153, 8),
		Vector3(146, 157, 6), Vector3(96, 159, 8), Vector3(111, 158, 10),
		Vector3(127, 159, 9), Vector3(139, 160, 7)
	]
	var centers: Array[Vector2] = []
	var radii: Array[Vector2] = []
	for i in lobes.size():
		var lobe: Vector3 = lobes[i]
		var breath := sin(time * 4.2 + i * 0.9) * 0.45 * growth
		var center := Vector2(lobe.x, lerpf(162.0, lobe.y + breath, growth))
		var radius := Vector2(lobe.z, lobe.z * growth)
		centers.append(center)
		radii.append(radius)
	# A continuous, glossy lower edge and two slow drips make this the same
	# thick potion as the liquid inside the beaker, while keeping its round top.
	var base_center := Vector2(115, 159)
	var base_radius := Vector2(34, 5.5 * growth)
	_ellipse(base_center, base_radius + Vector2(1.25, 1.1), INK)
	for side in [-1.0, 1.0]:
		_ellipse(Vector2(115 + side * 33, 159 + 2.4 * growth), Vector2(3.6, 6.2 * growth), INK)
	# Draw all outlines before all fills to make one connected surface.
	for i in centers.size():
		_ellipse(centers[i], radii[i] + Vector2(1.25, 1.1), INK)
	_ellipse(base_center, base_radius, PURPLE)
	for side in [-1.0, 1.0]:
		_ellipse(Vector2(115 + side * 33, 159 + 2.4 * growth), Vector2(2.8, 5.4 * growth), PURPLE)
	for i in centers.size():
		_ellipse(centers[i], radii[i], PURPLE)
	for i in 7:
		var center := centers[1 + i] + Vector2(-1.5, -2.0 * growth)
		_ellipse(center, Vector2(2.0, 0.85) * growth, Color("e8a4ff"))
