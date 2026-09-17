extends Control
var af_mode = "AF matricial"
var body = 0
var active = 4
var flash = 0.0
var success = false
var delta_ev = 0.0
var thirds = false
var font: Font
var green = Color("a5cc79")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
func points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y in [-1,0,1]:
		for x in [-1,0,1]: out.append(Vector2(size.x*(.5+x*.105),size.y*(.50+y*.12)))
	return out
func _process(dt: float) -> void:
	flash = maxf(0,flash-dt)
	queue_redraw()
func _draw() -> void:
	var ink = Color(.92,.95,.84,.48)
	var left = size.x*.085
	var right = size.x-left
	var top = size.y*.23
	var bottom = size.y*.82
	for pair in [[Vector2(left,top),Vector2(1,1)],[Vector2(right,top),Vector2(-1,1)],[Vector2(left,bottom),Vector2(1,-1)],[Vector2(right,bottom),Vector2(-1,-1)]]:
		var p: Vector2 = pair[0]
		var direction: Vector2 = pair[1]
		draw_line(p,p+Vector2(56*direction.x,0),Color(0,0,0,.25),5)
		draw_line(p,p+Vector2(0,40*direction.y),Color(0,0,0,.25),5)
		draw_line(p,p+Vector2(56*direction.x,0),ink,2)
		draw_line(p,p+Vector2(0,40*direction.y),ink,2)
	if thirds:
		for k in [1,2]:
			draw_line(Vector2(size.x*k/3,top),Vector2(size.x*k/3,bottom),Color(1,1,1,.2),1)
			draw_line(Vector2(left,size.y*k/3),Vector2(right,size.y*k/3),Color(1,1,1,.2),1)
	var pts = points()
	for i in pts.size():
		if af_mode == "MF": continue
		if af_mode == "AF puntual" and i != active: continue
		var color = green if i == active else Color(.12,.18,.15,.7)
		if i == active and flash > 0: color = Color.WHITE if success else Color("ed8465")
		var rect = Rect2(pts[i]-Vector2(12,12),Vector2(24,24))
		draw_rect(rect.grow(1.5),Color(1,1,1,.22),false,1)
		draw_rect(rect,color,false,2)
		if i == active: draw_circle(pts[i],2,color)
	if af_mode == "MF":
		var c = size*.5
		if body == 1: draw_rect(Rect2(c-Vector2(size.y*.095,size.y*.048),Vector2(size.y*.19,size.y*.096)),ink,false,1)
		else: draw_arc(c,size.y*.078,0,TAU,64,ink,1)
		draw_string(font,c+Vector2(-60,85),"MF · alinear imagen",HORIZONTAL_ALIGNMENT_LEFT,-1,14,green)
	var center = Vector2(size.x*.505,46)
	for i in range(-8,9):
		var x = center.x+i*12
		draw_line(Vector2(x,center.y),Vector2(x,center.y+(7 if i%4 == 0 else 3)),Color("809276"),1)
	for i in range(-2,3): draw_string(font,Vector2(center.x+i*48-6,37),str(i) if i <= 0 else "+"+str(i),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c5cdbb"))
	var needle = center.x+clampf(delta_ev,-2,2)*48
	draw_colored_polygon(PackedVector2Array([Vector2(needle-4,58),Vector2(needle+4,58),Vector2(needle,51)]),green if abs(delta_ev) <= .5 else Color("e3ac6a"))
	# Battery, purely cosmetic: there is no battery economy in the prototype.
	draw_rect(Rect2(size.x-61,28,32,16),Color("b9c5af"),false,2)
	draw_rect(Rect2(size.x-57,32,24,8),green)
	draw_rect(Rect2(size.x-28,33,3,6),Color("b9c5af"))
