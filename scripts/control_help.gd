extends Control
# On-screen help (docs/futuro/21 §6): which controls this camera has, which ones the player handles
# (MANUAL, highlighted) and which ones the camera does (AUTO), each with its key and current value.
# A switch on screen and F1 show or hide it; the choice is kept in user://interfaz.cfg. With the
# classic interface the keys are also printed on the HUD buttons. Drawn over the scene in its own
# dark glass so it reads the same with the light and the dark theme; it never reaches the photo.
const Photo = preload("res://scripts/photography.gd")
const Texts = preload("res://scripts/texts.gd")

var main
var enabled = true
var font: Font
var bold: Font
var toggle: Button
var raise_button: Button      # classic park: lower the camera to search, raise it to shoot (Y)
const MANUAL = Color("7cc6ff")
const AUTO = Color(.78,.82,.86)
const FIXED = Color(.6,.64,.68)

func _init(owner_main) -> void:
	main = owner_main

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = preload("res://scripts/ui_style.gd").font("Roboto-Regular")
	bold = preload("res://scripts/ui_style.gd").font("Roboto-Medium") if FileAccess.file_exists("res://assets/fuentes/Roboto-Medium.ttf") else font
	var config = ConfigFile.new()
	if config.load("user://interfaz.cfg") == OK: enabled = bool(config.get_value("interfaz","ayuda",true))
	toggle = Button.new()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.size = Vector2(150,30)
	toggle.add_theme_font_size_override("font_size",13)
	toggle.pressed.connect(func(): set_enabled(not enabled))
	add_child(toggle)
	raise_button = Button.new()
	raise_button.focus_mode = Control.FOCUS_NONE
	raise_button.size = Vector2(190,34)
	raise_button.add_theme_font_size_override("font_size",14)
	raise_button.pressed.connect(func(): main.toggle_raise())
	add_child(raise_button)

func set_enabled(value: bool) -> void:
	enabled = value
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","ayuda",value)
	config.save("user://interfaz.cfg")
	queue_redraw()

func _process(_dt: float) -> void:
	var can_lower = main.mode == "SEARCH" and not main.crowd and not (main.academy and main.academy.active)
	raise_button.visible = can_lower
	if can_lower:
		raise_button.text = Texts.get_text("bajar_camara") if main.camera_raised else Texts.get_text("subir_camara")
		var vr: Rect2 = main.view_rect
		raise_button.position = Vector2(vr.end.x-raise_button.size.x-10,vr.end.y-raise_button.size.y-(150 if main.interface_mode == "clasica" and main.eye_ready() else 12))
	var searching = main.mode == "SEARCH" and main.eye_ready()
	toggle.visible = searching
	if searching:
		var r: Rect2 = main.view_rect
		toggle.text = ("✓ " if enabled else "")+Texts.get_text("ayuda_pantalla")+" · F1"
		toggle.position = Vector2(r.end.x-toggle.size.x-10,r.position.y+(96 if main.interface_mode == "clasica" and main.hud_top[0].visible else 10)+(80 if main.interface_mode == "clasica" else 0))
	queue_redraw()

# [key, name, value, kind] for every control of the mounted camera; kind is manual, auto or fixed.
func rows() -> Array:
	var e = main.equipment
	var m: String = e.exposure_mode()
	var out = []
	out.append([Texts.get_text("ayuda_tecla_mirar"),Texts.get_text("ayuda_mirar"),"","info"])
	if e.zoom(): out.append([Texts.get_text("ayuda_tecla_zoom"),Texts.get_text("ayuda_zoom"),"%d mm" % roundi(main.focal),"manual"])
	else: out.append(["—",Texts.get_text("ayuda_zoom"),Texts.get_text("ayuda_objetivo_fijo") % roundi(main.focal),"fixed"])
	var dist = Texts.get_text("infinito") if is_inf(main.focus_distance) else "%.1f m" % main.focus_distance
	if e.focus_mode == "MF":
		out.append([Texts.get_text("ayuda_tecla_mf_zoom") if e.zoom() else Texts.get_text("ayuda_tecla_mf"),Texts.get_text("ayuda_enfoque"),dist,"manual"])
	else:
		out.append([Texts.get_text("ayuda_tecla_af"),Texts.get_text("ayuda_enfoque")+" AF",dist,"auto"])
	var n = main.apertures()[main.n_index]
	out.append(["Q · E",Texts.get_text("ayuda_diafragma"),"f/%s" % (("%.1f" % n) if n < 10 else str(int(n))),"manual" if m in ["M","A"] else "auto"])
	out.append(["Z · X",Texts.get_text("ayuda_velocidad"),"1/%d s" % Photo.DENOMINATORS[main.t_index],"manual" if m in ["M","S"] else "auto"])
	if e.film: out.append(["—","ISO",Texts.get_text("ayuda_carrete") % Photo.ISOS[main.iso_index],"fixed"])
	else: out.append(["C · V","ISO",str(Photo.ISOS[main.iso_index]),"manual" if m == "M" else "auto"])
	if m != "M": out.append(["[ · ]",Texts.get_text("ayuda_compensacion"),"%+.1f EV" % e.exposure_compensation(),"manual"])
	else: out.append(["",Texts.get_text("ayuda_exposimetro"),"%+.1f EV" % main.finder.delta_ev,"meter"])
	if e.tlr():
		out.append(["L",Texts.get_text("tlr_lupa"),"3×" if main.tlr_loupe else "","info"])
		if main.sandbox: out.append(["K",Texts.get_text("ayuda_manivela"),"%d / 12" % main.tlr_frames,"info"])
	out.append(["G",Texts.get_text("ayuda_tercios"),"","info"])
	out.append([Texts.get_text("ayuda_tecla_disparar"),Texts.get_text("ayuda_disparar"),"","info"])
	return out

func _draw() -> void:
	if not enabled or main.mode != "SEARCH" or not main.eye_ready(): return
	var r: Rect2 = main.view_rect
	var classic = main.interface_mode == "clasica"
	var list = rows()
	var line = 21.0
	var w = 330.0
	var h = 34.0+list.size()*line
	var pos = Vector2(r.position.x+10,r.position.y+(178 if classic else 10))
	draw_style_box(box(Color(.03,.05,.08,.62)),Rect2(pos,Vector2(w,h)))
	draw_string(bold,pos+Vector2(12,21),Texts.get_text("ayuda_titulo") % main.equipment.CAMERAS[main.equipment.body],HORIZONTAL_ALIGNMENT_LEFT,w-24,13,Color(1,1,1,.92))
	var y = pos.y+30
	for row in list:
		var kind: String = row[3]
		var color = MANUAL if kind == "manual" else (FIXED if kind == "fixed" else AUTO)
		if kind == "meter":
			var off = absf(main.finder.delta_ev) > .5
			color = Color(1,.72,.4) if off else Color(.55,1,.6)
		if row[0] != "":
			var kw = maxf(30.0,font.get_string_size(row[0],HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+12)
			draw_style_box(box(Color(1,1,1,.16) if kind != "manual" else Color(MANUAL.r,MANUAL.g,MANUAL.b,.3),5),Rect2(pos.x+10,y+2,kw,17))
			draw_string(font,Vector2(pos.x+16,y+15),row[0],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(1,1,1,.95))
		draw_string(font,Vector2(pos.x+120,y+15),row[1],HORIZONTAL_ALIGNMENT_LEFT,104,13,color)
		draw_string(font,Vector2(pos.x+228,y+15),row[2],HORIZONTAL_ALIGNMENT_LEFT,66,13,color)
		if kind in ["manual","auto"]:
			draw_string(font,Vector2(pos.x+w-46,y+15),"MAN" if kind == "manual" else "AUTO",HORIZONTAL_ALIGNMENT_RIGHT,36,9,color)
		y += line
	# Classic interface: the key on top of each HUD control too.
	if classic and main.hud_top[0].visible:
		var chips = [[main.shutter_button,"Z·X"],[main.aperture_button,"Q·E"],[main.iso_button,"C·V"],[main.exposure_button,"[ ]"],[main.af_button,"F"],[main.lens_slider,"W·S"],[main.focus_slider,"R·T"]]
		for c in chips:
			var node: Control = c[0]
			if not node.visible: continue
			var gr = node.get_global_rect()
			var kw = font.get_string_size(c[1],HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+10
			var at = Vector2(gr.end.x-kw-2,gr.position.y-9)
			draw_style_box(box(Color(.08,.2,.32,.92),5),Rect2(at,Vector2(kw,16)))
			draw_string(font,at+Vector2(5,12),c[1],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)

func box(color: Color, radius = 8) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b
