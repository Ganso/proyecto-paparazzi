extends Control
# Paparazzi's reduced interface (docs/futuro/29 §12): the card of who to find and what photo, the
# clock, the stretch's progress and a reticle. Everything else of the camera (body, bars, finder,
# strip, help) is hidden while a run is on. Drawn in main.ui's 1280 × 720 coordinates.
# E5 added the aim's: the brackets on the person locked on and the corners (the traffic light), the
# live shot, the zoom, the traits check on the card, the arrow, the ring, the jokers and the frost
# of the frozen park. (The miniature is main's portrait, turning in the card's corner.)
const Paparazzi = preload("res://scripts/paparazzi.gd")
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Ideal = preload("res://scripts/ideal_equipment.gd")
const PlaneIcon = preload("res://scripts/plane_icon.gd")

const CARD = Rect2(10,10,480,200)          # the portrait (124 × 172) takes its left side
const CLOCK = Rect2(1044,16,220,92)
const GLASS = Color(.03,.05,.08,.62)
const PAPER = Color(.95,.97,1.0)
const DIM = Color(.75,.82,.9)
const GREEN = Color("6fdc8c")
const AMBER = Color("f0c75e")
const ORANGE = Color("f09a4e")
const ZOOM_BAR = Rect2(490,672,300,4)

var run                                    # scripts/paparazzi_run.gd
var swatches = []                           # one Color (or null) per trait shown
var traits = []                             # the traits shown, in the language in use
var plane_text = ""
var mods_text = ""
var flash = {"text":"","time":0.0,"color":Color.WHITE}   # «+28 s» / «−5 s» by the clock
var jokers_label                            # «Congelar ×1 ⟦1⟧ · Otro ×1 ⟦2⟧»
var coach_label                             # the learning line, or the controls when idle
var icon                                    # the shot's pictogram on the card

func _init(owner_run) -> void:
	run = owner_run
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func _ready() -> void:
	jokers_label = run.main.glyph_label(self,"",Rect2(1044,132,230,30),14,PAPER,true)
	coach_label = run.main.glyph_label(self,"",Rect2(190,540,900,40),18,PAPER,true)
	coach_label.align_center = true
	icon = PlaneIcon.new("",PAPER)
	icon.position = Vector2(CARD.end.x-46,CARD.position.y+128)
	icon.size = Vector2(30,64)
	add_child(icon)

func _process(dt: float) -> void:
	visible = run.active and run.main.mode == "SEARCH"
	flash.time = maxf(0.0,flash.time-dt)
	if visible:
		jokers_label.set_rich(jokers_text())
		var key: String = run.coach_key()
		coach_label.set_rich(Texts.get_rich(key) if key != "" else "")
		coach_label.modulate = Color(.7,1,.75) if run.coach_done_time > 0.0 else Color.WHITE
		icon.set_plane(run.current_request().plane if not run.request.is_empty() else "")
		queue_redraw()

func jokers_text() -> String:
	var parts = []
	var jokers: Dictionary = Paparazzi.run.get("jokers",{})
	for kind in ["congelar","otro"]:
		if int(jokers.get(kind,0)) > 0: parts.append(Texts.get_rich("pz_comodin_"+kind) % int(jokers[kind]))
	return " · ".join(parts)

# The card's contents, once per level (and per photo of a reportage).
func set_request() -> void:
	var main = run.main
	traits.clear()
	swatches.clear()
	if is_instance_valid(main.target):
		var desc: PackedStringArray = main.casting.descriptors(main.target.traits)
		for i in run.shown:
			traits.append(desc[i])
			swatches.append(swatch(main.target.traits,i))
	plane_text = Paparazzi.plane_name(run.request.plane)
	var parts = []
	for mod in run.request.get("mods",{}): parts.append(Paparazzi.mod_text(mod,run.request.mods[mod],run.spec.scenario))
	if run.request.has("sequence"): parts.push_front("%d / 3" % (run.step+1))
	mods_text = " · ".join(parts)

# The colour sample of a trait (§10.4), never the skin's.
func swatch(t: Dictionary, i: int):
	var catalog = run.main.casting.catalog
	match i:
		0: return Color(catalog.tonos_ropa[t.upper_color].rgb)
		1: return Color(catalog.tonos_ropa[t.lower_color].rgb)
		2:
			var head: Dictionary = catalog.piezas.cabeza[t.hair]
			if head.style == "bald": return null
			if head.zona_color == "tela_b": return Color(catalog.tonos_ropa[t.lower_color].rgb)
			return Color(catalog.tonos_pelo[t.hair_color].rgb)
		3:
			if int(t.get("accessory",0)) > 0: return Color(catalog.tonos_ropa[t.get("accessory_color","rojo")].rgb)
	return null

# The biggest size up to `size` at which a line fits in `width` (long traits: «adulto robusto · con
# bandolera azul marino»), never below 11.
func fitting(font: Font, text: String, width: float, size: int) -> int:
	while size > 11 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width: size -= 1
	return size

func show_flash(text: String, good: bool) -> void:
	flash = {"text":text,"time":1.4,"color":GREEN if good else AMBER}

func _draw() -> void:
	var font = UiStyle.font("Roboto-Regular")
	var bold = UiStyle.font("Roboto-Medium")
	corners()
	# The card: who and what.
	draw_style_box(UiStyle.box(GLASS,12),CARD)
	var x = CARD.position.x+136
	draw_string(bold,Vector2(x,CARD.position.y+22),Texts.get_text("pz_ficha_busca"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,DIM)
	var marks: Array = run.trait_marks()
	for i in traits.size():
		var y = CARD.position.y+44+i*22
		if swatches[i] != null:
			draw_circle(Vector2(x+7,y-5),7,swatches[i])
			draw_arc(Vector2(x+7,y-5),7,0,TAU,24,Color(1,1,1,.5),1.0,true)
		draw_string(font,Vector2(x+20,y),traits[i],HORIZONTAL_ALIGNMENT_LEFT,-1,fitting(font,traits[i],CARD.end.x-x-50,15),PAPER)
		if i < marks.size(): mark(Vector2(CARD.end.x-20,y-5),marks[i] > 0)
	var line_y = CARD.position.y+44+traits.size()*22-8
	draw_line(Vector2(x,line_y),Vector2(CARD.end.x-12,line_y),Color(1,1,1,.18),1)
	draw_string(bold,Vector2(x,line_y+18),Texts.get_text("pz_ficha_foto"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,DIM)
	draw_string(bold,Vector2(x,line_y+40),plane_text,HORIZONTAL_ALIGNMENT_LEFT,CARD.end.x-x-60,17,UiStyle.BRAND)
	if mods_text != "": draw_string(font,Vector2(x,line_y+60),mods_text,HORIZONTAL_ALIGNMENT_LEFT,-1,fitting(font,mods_text,CARD.end.x-x-60,13),PAPER)
	# Where she is (big park): near which landmark, and how far.
	var zone: String = run.zone_text()
	if zone != "": shadowed(bold,Vector2(CARD.position.x+6,CARD.end.y+22),zone,15,UiStyle.SKY)
	# The clock: level, stretch, time left and its bar.
	draw_style_box(UiStyle.box(GLASS,12),CLOCK)
	draw_string(bold,CLOCK.position+Vector2(14,22),Texts.get_text("pz_nivel") % run.spec.n,HORIZONTAL_ALIGNMENT_LEFT,-1,13,DIM)
	draw_string(font,CLOCK.position+Vector2(14,22),Texts.get_text("pz_tramo") % run.spec.tramo,HORIZONTAL_ALIGNMENT_RIGHT,CLOCK.size.x-28,13,DIM)
	if run.spec.clock:
		var t = ceili(run.bank)
		var low = run.bank <= 20.0
		var blink = run.bank <= 10.0 and fmod(Time.get_ticks_msec()/1000.0,.6) < .3
		draw_string(bold,CLOCK.position+Vector2(14,64),"%d:%02d" % [t/60,t%60],HORIZONTAL_ALIGNMENT_LEFT,-1,34,AMBER if low else PAPER)
		var bar = Rect2(CLOCK.position+Vector2(14,74),Vector2(192,8))
		draw_rect(bar,Color(1,1,1,.15))
		if not blink: draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(run.bank/Paparazzi.MAX_BANK,0,1),bar.size.y)),UiStyle.WARN if low else UiStyle.SKY)
	else:
		draw_string(bold,CLOCK.position+Vector2(14,60),Texts.get_text("pz_sin_reloj"),HORIZONTAL_ALIGNMENT_LEFT,CLOCK.size.x-28,20,PAPER)
	if flash.time > 0.0:
		var c: Color = flash.color
		c.a = minf(1.0,flash.time/.4)
		draw_string(bold,CLOCK.position+Vector2(120,64-(1.4-flash.time)*14),flash.text,HORIZONTAL_ALIGNMENT_LEFT,-1,22,c)
	# The stretch's ten levels: the ones passed, filled; the milestone, bigger.
	for i in 10:
		var centre = Vector2(1056+i*20,CLOCK.end.y+10)
		var done = i < run.spec.k-1
		var r = 6.0 if i == 9 else 4.0
		if done: draw_circle(centre,r,PAPER)
		else: draw_arc(centre,r,0,TAU,20,Color(1,1,1,.55) if i != run.spec.k-1 else UiStyle.BRAND,2.0,true)
	draw_aim(font,bold)

# ✓ (green) or ✗ (orange), drawn: the fonts have no such signs.
func mark(at: Vector2, good: bool) -> void:
	if good: draw_polyline(PackedVector2Array([at+Vector2(-6,0),at+Vector2(-2,5),at+Vector2(7,-6)]),GREEN,3.0,true)
	else:
		draw_line(at+Vector2(-5,-5),at+Vector2(5,5),ORANGE,3.0,true)
		draw_line(at+Vector2(-5,5),at+Vector2(5,-5),ORANGE,3.0,true)

func shadowed(font: Font, at: Vector2, text: String, size: int, color: Color, width = -1.0, align = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font,at+Vector2(1.5,1.5),text,align,width,size,Color(0,0,0,.7))
	draw_string(font,at,text,align,width,size,color)

# The aim: the corners, the brackets with their advice, the live shot, the zoom, the arrow, the ring,
# the reticle and the frost.
func draw_aim(font: Font, bold: Font) -> void:
	var main = run.main
	var live: Dictionary = run.live
	if run.locked != null and is_instance_valid(run.locked):
		# (Close up the body runs off the screen: the brackets stay on it.)
		var box: Rect2 = run.body_box(run.locked).intersection(Rect2(36,36,1208,560))
		var color = Color.WHITE if live.is_empty() else (GREEN if live.ok else AMBER)
		if box.has_area(): brackets(box,color)
		if not live.is_empty() and not live.ok and live.tip != "":
			var at = Vector2(box.get_center().x-150,box.end.y+24) if box.has_area() and box.end.y < 540 else Vector2(490,604)
			shadowed(bold,at,Texts.get_text("pz_consejo_"+live.tip),15,AMBER,300,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		draw_arc(Vector2(640,360),10,0,TAU,32,Color(1,1,1,.6),2.0,true)
		# Without a lock the light still judges whoever the photo would be of.
		if not live.is_empty() and not live.ok and live.tip != "" and live.tip != "apunta":
			shadowed(bold,Vector2(490,604),Texts.get_text("pz_consejo_"+live.tip),15,AMBER,300,HORIZONTAL_ALIGNMENT_CENTER)
	# The live shot, with ✓ if it is the one asked for (any shot: any but a wide one).
	if not live.is_empty() and live.plane != "":
		var name = Paparazzi.plane_name(live.plane)
		var width = bold.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		var right: bool = run.on_plane
		shadowed(bold,Vector2(640-width*.5,632),name,20,GREEN if right else PAPER)
		if right: mark(Vector2(640+width*.5+18,625),true)
	# The zoom: where it is from 24 to 600 mm, and how much it enlarges.
	draw_rect(ZOOM_BAR,Color(1,1,1,.3))
	var at = clampf(log(main.focal/Ideal.IDEAL.min)/log(Ideal.IDEAL.max/Ideal.IDEAL.min),0,1)
	draw_rect(Rect2(ZOOM_BAR.position,Vector2(ZOOM_BAR.size.x*at,ZOOM_BAR.size.y)),Color(1,1,1,.8))
	draw_rect(Rect2(ZOOM_BAR.position+Vector2(ZOOM_BAR.size.x*at-2,-6),Vector2(4,16)),PAPER)
	var times = "×%.1f" % (main.focal/Ideal.IDEAL.min)
	if Texts.current() == "es": times = times.replace(".",",")
	shadowed(font,Vector2(ZOOM_BAR.end.x+14,ZOOM_BAR.position.y+7),times,14,PAPER)
	var pulse = .55+.45*sin(Time.get_ticks_msec()/1000.0*TAU*1.2)
	if run.arrow_on():
		var tip = arrow(run.arrow_direction(),pulse)
		# (In the big park, how far.)
		if main.crowd:
			var metres = "%d m" % roundi(main.camera.global_position.distance_to(main.target.global_position))
			shadowed(bold,tip-run.arrow_direction()*58+Vector2(-40,6),metres,15,PAPER,80,HORIZONTAL_ALIGNMENT_CENTER)
	if run.ring_on():
		var box: Rect2 = run.body_box(main.target).grow(10+6*pulse)
		draw_set_transform(box.get_center(),0,Vector2(box.size.x/box.size.y,1))
		draw_arc(Vector2.ZERO,box.size.y*.5,0,TAU,48,Color(UiStyle.SKY,.5+.4*pulse),3.0/(box.size.x/box.size.y),true)
		draw_set_transform(Vector2.ZERO)
	if run.frozen > 0.0:
		draw_rect(Rect2(0,0,1280,720),Color(.6,.8,1,.08))
		var text = Texts.get_text("pz_congelado") % ceili(run.frozen)
		shadowed(bold,Vector2(440,140),text,24,Color(.8,.92,1),400,HORIZONTAL_ALIGNMENT_CENTER)

# The corners of the frame: green when the photo would do (under the card and the clock).
func corners() -> void:
	var good = not run.live.is_empty() and run.live.ok
	var corner = GREEN if good else Color(1,1,1,.35)
	for c in [Vector2(24,24),Vector2(1256,24),Vector2(24,696),Vector2(1256,696)]:
		var sx = 1.0 if c.x < 640 else -1.0
		var sy = 1.0 if c.y < 360 else -1.0
		draw_polyline(PackedVector2Array([c+Vector2(0,40*sy),c,c+Vector2(40*sx,0)]),corner,4.0)

# The four brackets of a box, corners of 18 px.
func brackets(box: Rect2, color: Color) -> void:
	var arm = minf(18.0,minf(box.size.x,box.size.y)*.4)
	for c in [box.position,Vector2(box.end.x,box.position.y),Vector2(box.position.x,box.end.y),box.end]:
		var sx = 1.0 if c.x <= box.get_center().x else -1.0
		var sy = 1.0 if c.y <= box.get_center().y else -1.0
		draw_polyline(PackedVector2Array([c+Vector2(0,arm*sy),c,c+Vector2(arm*sx,0)]),color,3.0)

# A triangle at the edge of the screen pointing where the person is.
func arrow(direction: Vector2, pulse: float) -> Vector2:
	var half = Vector2(600,320)
	var t = minf(half.x/maxf(absf(direction.x),.001),half.y/maxf(absf(direction.y),.001))
	var tip = Vector2(640,360)+direction*t
	var back = tip-direction*28
	var side = Vector2(-direction.y,direction.x)*13
	draw_colored_polygon(PackedVector2Array([tip,back+side,back-side]),Color(UiStyle.SKY,.55+.45*pulse))
	return tip
