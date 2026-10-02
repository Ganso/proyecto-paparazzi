extends Control
# The gamepad and what every button does (docs/futuro/22 §3), drawn in code for the help screen
# when the player uses a pad. Button names follow the pad family (Xbox, PlayStation, Nintendo).
# Callouts on each side go in the order of the controls from top to bottom, so no line crosses.
const Glyphs = preload("res://scripts/input_glyphs.gd")
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const GlyphLabel = preload("res://scripts/glyph_label.gd")

var font: Font
const S = 1.45

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = UiStyle.font("Roboto-Regular")

func names() -> Dictionary:
	match Glyphs.family:
		"ps": return {"a":"✕","b":"◯","x":"▢","y":"△","lb":"L1","rb":"R1","lt":"L2","rt":"R2","view":"Share","menu":"Options"}
		"nintendo": return {"a":"B","b":"A","x":"Y","y":"X","lb":"L","rb":"R","lt":"ZL","rt":"ZR","view":"−","menu":"+"}
	return {"a":"A","b":"B","x":"X","y":"Y","lb":"LB","rb":"RB","lt":"LT","rt":"RT","view":"View","menu":"Menu"}

func _draw() -> void:
	var n = names()
	var c = size*.5+Vector2(0,10)
	var p = func(v: Vector2) -> Vector2: return c+v*S
	var body = UiStyle.surf(.92)
	var edge = UiStyle.LINE
	for side in [-1,1]:
		draw_circle(p.call(Vector2(side*95,35)),82*S,body)
		draw_arc(p.call(Vector2(side*95,35)),82*S,0,TAU,72,edge,2,true)
	draw_rect(Rect2(p.call(Vector2(-95,-47)),Vector2(190,130)*S),body)
	var pads = {}
	pads["lt"] = p.call(Vector2(-115,-92))
	pads["lb"] = p.call(Vector2(-115,-70))
	pads["rt"] = p.call(Vector2(115,-92))
	pads["rb"] = p.call(Vector2(115,-70))
	for key in ["lt","lb","rt","rb"]:
		var r = Rect2(pads[key]-Vector2(34,9)*S,Vector2(68,18)*S)
		draw_rect(r,UiStyle.SKY_SOFT)
		draw_string(font,r.position+Vector2(0,13*S),n[key],HORIZONTAL_ALIGNMENT_CENTER,r.size.x,14,UiStyle.INK)
	var ls = p.call(Vector2(-100,0))
	var dp = p.call(Vector2(-50,48))
	var rs = p.call(Vector2(50,48))
	var fb = p.call(Vector2(100,0))
	var view = p.call(Vector2(-24,-24))
	var menu = p.call(Vector2(24,-24))
	for s in [ls,rs]:
		draw_circle(s,22*S,UiStyle.SKY_SOFT)
		draw_circle(s,13*S,UiStyle.SKY)
	for d in [Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0)]:
		draw_rect(Rect2(dp+d*12*S-Vector2(8,8)*S,Vector2(16,16)*S),UiStyle.SKY_SOFT)
	var faces = {"y":Vector2(0,-19),"x":Vector2(-19,0),"b":Vector2(19,0),"a":Vector2(0,19)}
	var face_pos = {}
	for key in faces:
		face_pos[key] = fb+faces[key]*S
		GlyphLabel.draw_chip(self,font,face_pos[key]+Vector2(-11,8),"b",n[key],17)
	for v in [view,menu]: draw_rect(Rect2(v-Vector2(11,6)*S,Vector2(22,12)*S),UiStyle.SKY_SOFT)
	# Callouts, ordered top to bottom on each side.
	var left = [[pads.lt,"⦅%s⦆ " % n.lt+Texts.get_text("pad_lt")],[pads.lb,"⦅%s⦆ " % n.lb+Texts.get_text("pad_lb")],[view,"⦅%s⦆ " % n.view+Texts.get_text("pad_view")],[ls,Texts.get_text("pad_stick_izq")],[dp,Texts.get_text("pad_cruceta")]]
	var right = [[pads.rt,"⦅%s⦆ " % n.rt+Texts.get_text("pad_rt")],[pads.rb,"⦅%s⦆ " % n.rb+Texts.get_text("pad_rb")],[menu,"⦅%s⦆ " % n.menu+Texts.get_text("pad_menu")],[face_pos.y,"⦅%s⦆ " % n.y+Texts.get_text("pad_y")],[face_pos.x,"⦅%s⦆ " % n.x+Texts.get_text("pad_x")],[face_pos.b,"⦅%s⦆ " % n.b+Texts.get_text("pad_b")],[face_pos.a,"⦅%s⦆ " % n.a+Texts.get_text("pad_a")],[rs,Texts.get_text("pad_stick_der")]]
	var lx = c.x-205*S
	var rx = c.x+205*S
	for i in left.size():
		var y = 20.0+i*(size.y-40)/(left.size()-1)
		draw_line(left[i][0],Vector2(lx,y),UiStyle.FAINT,1.2,true)
		draw_circle(left[i][0],3,UiStyle.SKY)
		GlyphLabel.draw_rich(self,font,Vector2(8,y-16),left[i][1],15,UiStyle.INK,lx-16)
	for i in right.size():
		var y = 20.0+i*(size.y-40)/(right.size()-1)
		draw_line(right[i][0],Vector2(rx,y),UiStyle.FAINT,1.2,true)
		draw_circle(right[i][0],3,UiStyle.SKY)
		GlyphLabel.draw_rich(self,font,Vector2(rx+8,y-16),right[i][1],15,UiStyle.INK,size.x-rx-12)
