extends Control
# Paparazzi's reduced interface (docs/futuro/29 §12): the card of who to find and what photo, the
# clock, the stretch's progress and a reticle. Everything else of the camera (body, bars, finder,
# strip, help) is hidden while a run is on. Drawn in main.ui's 1280 × 720 coordinates.
# (E4: the card and the clock. The lock-on's brackets, the traffic light, the shot label, the zoom
# bar, the arrow and the jokers come with E5; the miniature is main's portrait, which shows the
# person turning in the card's corner.)
const Paparazzi = preload("res://scripts/paparazzi.gd")
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

const CARD = Rect2(10,10,420,172)          # the portrait (124 × 172) takes its left side
const CLOCK = Rect2(1044,16,220,92)
const GLASS = Color(.03,.05,.08,.62)
const PAPER = Color(.95,.97,1.0)
const DIM = Color(.75,.82,.9)
const GREEN = Color("6fdc8c")
const AMBER = Color("f0c75e")

var run                                    # scripts/paparazzi_run.gd
var swatches = []                           # one Color (or null) per trait shown
var traits = []                             # the traits shown, in the language in use
var plane_text = ""
var mods_text = ""
var flash = {"text":"","time":0.0,"color":Color.WHITE}   # «+28 s» / «−5 s» by the clock

func _init(owner_run) -> void:
	run = owner_run
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func _process(dt: float) -> void:
	visible = run.active and run.main.mode == "SEARCH"
	flash.time = maxf(0.0,flash.time-dt)
	if visible: queue_redraw()

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
	# The card: who and what.
	draw_style_box(UiStyle.box(GLASS,12),CARD)
	var x = CARD.position.x+136
	draw_string(bold,Vector2(x,CARD.position.y+22),Texts.get_text("pz_ficha_busca"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,DIM)
	for i in traits.size():
		var y = CARD.position.y+44+i*22
		if swatches[i] != null:
			draw_circle(Vector2(x+7,y-5),7,swatches[i])
			draw_arc(Vector2(x+7,y-5),7,0,TAU,24,Color(1,1,1,.5),1.0,true)
		draw_string(font,Vector2(x+20,y),traits[i],HORIZONTAL_ALIGNMENT_LEFT,-1,fitting(font,traits[i],CARD.end.x-x-28,15),PAPER)
	var line_y = CARD.position.y+44+traits.size()*22-8
	draw_line(Vector2(x,line_y),Vector2(CARD.end.x-12,line_y),Color(1,1,1,.18),1)
	draw_string(bold,Vector2(x,line_y+18),Texts.get_text("pz_ficha_foto"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,DIM)
	draw_string(bold,Vector2(x,line_y+40),plane_text,HORIZONTAL_ALIGNMENT_LEFT,CARD.end.x-x-12,17,UiStyle.BRAND)
	if mods_text != "": draw_string(font,Vector2(x,line_y+60),mods_text,HORIZONTAL_ALIGNMENT_LEFT,-1,fitting(font,mods_text,CARD.end.x-x-12,13),PAPER)
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
	# The reticle.
	draw_arc(Vector2(640,360),10,0,TAU,32,Color(1,1,1,.6),2.0,true)
