extends Control
# The pictogram of a shot (docs/futuro/29 §12.3): a mannequin facing us, with the proportions of a
# standard adult (Framing.rest_for()), the band where the bottom edge may fall for that shot and the
# line where the auto-framing cuts. What the shot leaves out is greyed. Any size: the card of
# Paparazzi, its novelty cards and cheat sheet, and the arcade's levels about shots.
const Framing = preload("res://scripts/framing.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

var plane = ""                 # one of Framing.ORDER, or "cualquiera" (the whole figure, no line)
var ink = Color.WHITE
var band_color = UiStyle.BRAND

func _init(shot = "", colour = Color.WHITE) -> void:
	plane = shot
	ink = colour
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_plane(shot: String) -> void:
	if shot == plane: return
	plane = shot
	queue_redraw()

# Heights (metres) of the band where the bottom edge falls for a shot (§4.3); empty for the whole body.
static func band(shot: String, r: Dictionary) -> Vector2:
	match shot:
		"cara": return Vector2(r.shoulders,r.chin)
		"primer_plano": return Vector2(r.chest,r.shoulders)
		"medio": return Vector2(r.hips,r.chest)
		"americano": return Vector2((r.knees+r.ankles)*.5,r.hips)
	return Vector2.ZERO

func _draw() -> void:
	var r = Framing.rest_for(1.75,1.75-1.75/7.0)
	var top = size.y*.04
	var k = size.y*.92/r.crown
	var cx = size.x*.5
	var y = func(m: float) -> float: return top+(r.crown-m)*k
	var cut = -1.0
	if plane in ["cara","primer_plano","medio","americano"]: cut = y.call(Framing.cut_middle(plane,r))
	var dim = Color(ink,.28)
	# A part of the body: bright above the cut, grey below.
	var part = func(rect: Rect2) -> void:
		if cut < 0 or rect.end.y <= cut:
			draw_rect(rect,ink)
		elif rect.position.y >= cut:
			draw_rect(rect,dim)
		else:
			draw_rect(Rect2(rect.position,Vector2(rect.size.x,cut-rect.position.y)),ink)
			draw_rect(Rect2(rect.position.x,cut,rect.size.x,rect.end.y-cut),dim)
	# The band where the edge may go, under the figure.
	var b = band(plane,r)
	if b != Vector2.ZERO:
		draw_rect(Rect2(0,y.call(b.y),size.x,y.call(b.x)-y.call(b.y)),Color(band_color,.22))
	var head_r = (r.crown-r.chin)*.5*k
	var shoulder_w = .40*k
	var hip_w = .30*k
	var arm_w = .085*k
	var leg_w = .12*k
	part.call(Rect2(cx-.05*k,y.call(r.chin),.10*k,y.call(r.shoulders)-y.call(r.chin)))                 # neck
	part.call(Rect2(cx-shoulder_w*.5+arm_w,y.call(r.shoulders),shoulder_w-2*arm_w,y.call(r.waist)-y.call(r.shoulders)))   # chest
	part.call(Rect2(cx-hip_w*.5,y.call(r.waist),hip_w,y.call(r.hips)-y.call(r.waist)))                  # belly
	for side in [-1.0,1.0]:
		part.call(Rect2(cx+side*(shoulder_w*.5-arm_w*.5)-arm_w*.5+side*.012*k,y.call(r.shoulders),arm_w,y.call(r.hips-.05)-y.call(r.shoulders)))   # arm
		part.call(Rect2(cx+side*hip_w*.25-leg_w*.5,y.call(r.hips),leg_w,y.call(0.0)-y.call(r.hips)))   # leg
	draw_circle(Vector2(cx,y.call((r.crown+r.chin)*.5)),head_r,ink)
	# The line of the cut.
	if cut >= 0:
		var x = 0.0
		while x < size.x:
			draw_line(Vector2(x,cut),Vector2(minf(x+5,size.x),cut),band_color,maxf(1.5,size.y/60.0))
			x += 9
	elif plane in ["entero","general"]:
		draw_line(Vector2(0,y.call(0.0)+2),Vector2(size.x,y.call(0.0)+2),band_color,maxf(1.5,size.y/60.0))
