extends Control
const Texts = preload("res://scripts/texts.gd")
var af_mode = "AF matricial"
var mf_coincidence = false
var body = 0
var active = 4
var flash = 0.0
var success = false
var delta_ev = 0.0
var thirds = false
# Where the camera image is shown (ui coordinates; main.gd::view_rect) and whether the classic
# HUD meter/battery are drawn (the realistic finders draw their own data, scripts/camera_body.gd).
var view = Rect2(0,0,1280,720)
var classic = true
var font: Font
var green = Color("a5cc79")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
func points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y in [-1,0,1]:
		for x in [-1,0,1]: out.append(view.position+Vector2(view.size.x*(.5+x*.105),view.size.y*(.50+y*.12)))
	return out
func _process(dt: float) -> void:
	flash = maxf(0,flash-dt)
	queue_redraw()
func _draw() -> void:
	var ink = Color(.92,.95,.84,.48)
	var left = view.position.x+view.size.x*.085
	var right = view.end.x-view.size.x*.085
	var top = view.position.y+view.size.y*(.23 if classic else .08)
	var bottom = view.position.y+view.size.y*(.82 if classic else .92)
	for pair in ([[Vector2(left,top),Vector2(1,1)],[Vector2(right,top),Vector2(-1,1)],[Vector2(left,bottom),Vector2(1,-1)],[Vector2(right,bottom),Vector2(-1,-1)]] if classic else []):
		var p: Vector2 = pair[0]
		var direction: Vector2 = pair[1]
		draw_line(p,p+Vector2(56*direction.x,0),Color(0,0,0,.25),5)
		draw_line(p,p+Vector2(0,40*direction.y),Color(0,0,0,.25),5)
		draw_line(p,p+Vector2(56*direction.x,0),ink,2)
		draw_line(p,p+Vector2(0,40*direction.y),ink,2)
	if thirds:
		for k in [1,2]:
			var gx = view.position.x+view.size.x*k/3
			var gy = view.position.y+view.size.y*k/3
			draw_line(Vector2(gx,view.position.y),Vector2(gx,view.end.y),Color(1,1,1,.22),1)
			draw_line(Vector2(view.position.x,gy),Vector2(view.end.x,gy),Color(1,1,1,.22),1)
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
		var c = view.get_center()
		var patch_color = Color("b8d78c") if mf_coincidence else ink
		var patch_width = 2 if mf_coincidence else 1
		if body == 1:
			draw_rect(Rect2(c-Vector2(view.size.y*.095,view.size.y*.048),Vector2(view.size.y*.19,view.size.y*.096)),patch_color,false,patch_width)
		else:
			draw_arc(c,view.size.y*.078,0,TAU,64,patch_color,patch_width)
		var label_text = Texts.get_text("foco_alineado") if mf_coincidence else Texts.get_text("alinear_imagen")
		var label_color = Color("b8d78c") if mf_coincidence else Color("809276")
		draw_string(font,c+Vector2(-60,85),label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,label_color)
	if not classic: return
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
