extends Control
# On-screen help (docs/futuro/21 §6): which controls this camera has, which ones the player handles
# (MANUAL, highlighted) and which ones the camera does (AUTO), each with its key and current value.
# A switch on screen and F1 show or hide it; the choice is kept in user://interfaz.cfg. With the
# classic interface the keys are also printed on the HUD buttons. Drawn over the scene in its own
# dark glass so it reads the same with the light and the dark theme; it never reaches the photo.
const Photo = preload("res://scripts/photography.gd")
const Texts = preload("res://scripts/texts.gd")
const Glyphs = preload("res://scripts/input_glyphs.gd")
const GlyphLabel = preload("res://scripts/glyph_label.gd")

var main
const UiStyle_SKY = preload("res://scripts/ui_style.gd").SKY
var enabled = true
var panel_rect = Rect2()   # where the list was last drawn (the control strip keeps clear of it)
var font: Font
var bold: Font
var toggle: Button
var raise_button: Button      # classic park: lower the camera to search, raise it to shoot (Y)
var exit_button: Button       # pause / leave the phase (Esc)
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
	exit_button = Button.new()
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.size = Vector2(110,30)
	exit_button.add_theme_font_size_override("font_size",13)
	exit_button.pressed.connect(func(): main.show_pause())
	add_child(exit_button)
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
		var bottom = 617.0 if (not main.hud_bottom.is_empty() and main.hud_bottom[0].visible) else vr.end.y-12   # above the bottom bar when it shows
		# The tutorial's panel sits over the bottom of the finder: the button goes above it.
		if main.tutorial and main.tutorial.visible: bottom = minf(bottom,main.tutorial.panel.position.y-8)
		raise_button.position = Vector2(vr.end.x-raise_button.size.x-10,minf(bottom,vr.end.y-12)-raise_button.size.y)
	exit_button.visible = main.mode == "SEARCH"
	if exit_button.visible:
		var er: Rect2 = main.view_rect
		exit_button.text = "✕ "+Texts.get_text("salir_fase")+" · "+Glyphs.kp("pausa")
		var top = main.hud_clear_top()
		exit_button.position = Vector2(er.end.x-exit_button.size.x-10,top) if not main.eye_ready() else Vector2(er.end.x-toggle.size.x-exit_button.size.x-20,toggle.position.y)
	var searching = main.mode == "SEARCH" and main.eye_ready()
	toggle.visible = searching
	if searching:
		var r: Rect2 = main.view_rect
		toggle.text = ("✓ " if enabled else "")+Texts.get_text("ayuda_pantalla")+" · "+Glyphs.kp("ayuda_pantalla")
		toggle.position = Vector2(r.end.x-toggle.size.x-10,main.hud_clear_top())
	# In a lesson the Academy's panel takes the right side: the two chips move to its left.
	if main.academy and main.academy.active and main.academy.panel.visible and toggle.visible:
		var left = main.academy.panel.position.x-10
		if toggle.position.x+toggle.size.x > left:
			toggle.position.x = left-toggle.size.x
			if exit_button.visible: exit_button.position = Vector2(toggle.position.x-exit_button.size.x-10,toggle.position.y)
	queue_redraw()

# [key, name, value, kind] for every control of the mounted camera; kind is manual, auto or fixed.
func rows() -> Array:
	var e = main.equipment
	var m: String = e.exposure_mode()
	var out = []
	out.append([Glyphs.k("mirar"),Texts.get_text("ayuda_mirar"),"","info"])
	if e.zoom(): out.append([Glyphs.k("zoom"),Texts.get_text("ayuda_zoom"),"%d mm" % roundi(main.focal),"manual","zoom"])
	else: out.append(["—",Texts.get_text("ayuda_zoom"),Texts.get_text("ayuda_objetivo_fijo") % roundi(main.focal),"fixed"])
	var dist = Texts.get_text("infinito") if is_inf(main.focus_distance) else "%.1f m" % main.focus_distance
	if e.focus_mode == "MF":
		out.append([Glyphs.k("enfoque_mf_zoom") if e.zoom() else Glyphs.k("enfoque_mf"),Texts.get_text("ayuda_enfoque"),dist,"manual","foco"])
	else:
		out.append([Glyphs.k("af"),Texts.get_text("ayuda_enfoque")+" AF",dist,"auto"])
	var n = main.apertures()[main.n_index]
	out.append([pad_key("diafragma","n"),Texts.get_text("ayuda_diafragma"),"f/%s" % (("%.1f" % n) if n < 10 else str(int(n))),"manual" if m in ["M","A"] else "auto","n"])
	out.append([pad_key("velocidad","t"),Texts.get_text("ayuda_velocidad"),"1/%d s" % Photo.DENOMINATORS[main.t_index],"manual" if m in ["M","S"] else "auto","t"])
	if e.film: out.append(["—","ISO",Texts.get_text("ayuda_carrete") % Photo.ISOS[main.iso_index],"fixed"])
	else: out.append([pad_key("iso","iso"),"ISO",str(Photo.ISOS[main.iso_index]),"manual" if m == "M" else "auto","iso"])
	if m != "M": out.append([pad_key("compensacion","ev_comp"),Texts.get_text("ayuda_compensacion"),"%+.1f EV" % e.exposure_compensation(),"manual","ev_comp"])
	else: out.append(["",Texts.get_text("ayuda_exposimetro"),"%+.1f EV" % main.finder.delta_ev,"meter"])
	out.append([Glyphs.k("fotometria"),Texts.get_text("ayuda_fotometria"),Texts.get_text("fotometria_"+e.metering),"manual"])
	out.append([Glyphs.k("bloqueo"),Texts.get_text("ayuda_bloqueo"),Texts.get_text("bloqueo_activo") if main.exposure_locked or main.focus_locked else "","manual" if main.exposure_locked or main.focus_locked else "info"])
	if e.tlr():
		out.append([Glyphs.k("lupa"),Texts.get_text("tlr_lupa"),"3×" if main.tlr_loupe else "","info"])
		if main.sandbox: out.append([Glyphs.k("manivela"),Texts.get_text("ayuda_manivela"),"%d / 12" % main.tlr_frames,"info"])
	out.append([Glyphs.k("tercios"),Texts.get_text("ayuda_tercios"),"","info"])
	out.append([Glyphs.k("disparar"),Texts.get_text("ayuda_disparar"),"","info"])
	return out

# With a gamepad the D-pad changes the selected exposure setting: mark which one.
func pad_key(control: String, param: String) -> String:
	if not Glyphs.pad(): return Glyphs.k(control)
	return "Cruceta ↑↓" if main.current_control() == param else ""   # only the control in hand names the D-pad

func _draw() -> void:
	# In the recorded videos (Godot's Movie Maker) the list would cover half of every scene.
	panel_rect = Rect2()
	if OS.has_feature("movie") and not main.demo.has("strip-demo"): return
	if not enabled or main.mode != "SEARCH" or not main.eye_ready(): return
	var r: Rect2 = main.view_rect
	var classic = main.interface_mode == "clasica"
	var list = rows()
	var line = 22.0
	var w = 360.0
	var h = 34.0+list.size()*line
	var pos = Vector2(r.position.x+10,main.hud_clear_top())
	if is_instance_valid(main.portrait) and main.portrait.visible: pos.y = main.portrait.position.y+main.portrait.size.y+10   # under the subject
	draw_style_box(box(Color(.03,.05,.08,.62)),Rect2(pos,Vector2(w,h)))
	panel_rect = Rect2(pos,Vector2(w,h))
	draw_string(bold,pos+Vector2(12,21),Texts.get_text("ayuda_titulo") % main.equipment.CAMERAS[main.equipment.body],HORIZONTAL_ALIGNMENT_LEFT,w-24,13,Color(1,1,1,.92))
	var y = pos.y+30
	for row in list:
		var kind: String = row[3]
		var color = MANUAL if kind == "manual" else (FIXED if kind == "fixed" else AUTO)
		if kind == "meter":
			var off = absf(main.finder.delta_ev) > .5
			color = Color(1,.72,.4) if off else Color(.55,1,.6)
		# The control in hand (the one the wheel or the D-pad ↑↓ changes) is marked.
		if row.size() > 4 and row[4] == main.current_control(): draw_style_box(box(Color(UiStyle_SKY.r,UiStyle_SKY.g,UiStyle_SKY.b,.45),5),Rect2(pos.x+4,y-1,w-8,line))
		if row[0] != "":
			GlyphLabel.draw_rich(self,font,Vector2(pos.x+10,y+1),row[0],12,Color(1,1,1,.9))
		draw_string(font,Vector2(pos.x+150,y+15),row[1],HORIZONTAL_ALIGNMENT_LEFT,104,13,color)
		draw_string(font,Vector2(pos.x+258,y+15),row[2],HORIZONTAL_ALIGNMENT_LEFT,66,13,color)
		if kind in ["manual","auto"]:
			draw_string(font,Vector2(pos.x+w-46,y+15),Texts.get_text("ayuda_man") if kind == "manual" else Texts.get_text("ayuda_auto"),HORIZONTAL_ALIGNMENT_RIGHT,36,9,color)
		y += line
	# Classic interface: the key on top of each HUD control too.
	if classic and main.hud_top[0].visible and not Glyphs.pad():
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
