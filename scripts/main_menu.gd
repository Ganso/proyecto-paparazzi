extends Control
# Main menu (docs/futuro/20_INTERFAZ_CLARA.md, modes in docs/futuro/22 §1): clean, light and airy. The live park keeps running
# behind a block of frosted white glass (shaders/frosted_glass.gdshader) while the camera drifts
# slowly. The modes — Arcade, Historia (coming), Tutorial, Sandbox, Academia, Opciones — show one at a time in a
# big card, changed with the arrows (← → keys, D-pad or LB/RB, or the ‹ › buttons) and entered with
# Enter / A or the button; each card holds what its mode needs (scenario and light for the sandbox,
# theme in the options).
const Texts = preload("res://scripts/texts.gd")

const UiStyle = preload("res://scripts/ui_style.gd")
var INK = UiStyle.INK
var SOFT = UiStyle.SOFT
var FAINT = UiStyle.FAINT
var SKY = Color("3aa5f0")
var SKY_SOFT = UiStyle.SKY_SOFT
var CARD = UiStyle.surf(.62)
var LINE = UiStyle.LINE if UiStyle.dark else Color(.62,.78,.92,.55)

var main
var scenario = "clasico"
var time_of_day = "day"
var cards = {}
var chips = {}
var theme_buttons = []
const MODES = ["tutorial","arcade","sandbox","academia","opciones","historia"]
static var current = 0
var card: Control
var dots = []
const Glyphs = preload("res://scripts/input_glyphs.gd")
const GlyphLabel = preload("res://scripts/glyph_label.gd")
var hint: Control
var title_font: Font
var body_font: Font
var body_medium: Font
var light_font: Font
static var web_notice_shown = false
var web_notice_modal: Control

func _init(owner_main) -> void:
	main = owner_main

static func font(name: String) -> Font:
	return UiStyle.font(name)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if main.badges_count(): load_mode()
	scenario = main.scenario
	title_font = font("RussoOne-Regular")   # the name and every title (user, 04-10-2026)
	light_font = font("Roboto-Light")
	body_font = font("Roboto-Regular")
	body_medium = font("Quicksand-Medium")
	var glass = ColorRect.new()
	glass.position = main.full_rect().position
	glass.size = main.full_rect().size
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/frosted_glass.gdshader")
	mat.set_shader_parameter("tint",UiStyle.GLASS_TINT)
	glass.material = mat
	add_child(glass)
	build()
	if OS.has_feature("web") and not web_notice_shown:
		web_notice_shown = true
		call_deferred("show_web_notice")

func text(parent: Control, value: String, pos: Vector2, size: int, color: Color, f: Font, width = 0.0) -> Label:
	var l = Label.new()
	l.text = value
	l.position = pos
	if width > 0:
		l.custom_minimum_size = Vector2(width,0)
		l.size = Vector2(width,0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font",f)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	if width > 0: l.set_deferred("size",Vector2(width,0))
	return l

func box(color: Color, radius: int, border = Color.TRANSPARENT, border_w = 1, shadow = 0) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.border_color = border
	b.set_border_width_all(border_w if border.a > 0 else 0)
	b.shadow_color = Color(.24,.48,.72,.16)
	b.shadow_size = shadow
	b.shadow_offset = Vector2(0,shadow*.35)
	b.anti_aliasing = true
	return b

func flat_button(parent: Control, label: String, rect: Rect2, callback: Callable, style = "ghost") -> Button:
	var b = Button.new()
	b.text = label
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font",body_medium)
	match style:
		"primary":
			b.add_theme_font_size_override("font_size",22)
			b.add_theme_color_override("font_color",Color.WHITE)
			b.add_theme_color_override("font_hover_color",Color.WHITE)
			b.add_theme_color_override("font_pressed_color",Color.WHITE)
			b.add_theme_stylebox_override("normal",box(SKY,14,Color.TRANSPARENT,0,14))
			b.add_theme_stylebox_override("hover",box(SKY.lightened(.12),14,Color.TRANSPARENT,0,20))
			b.add_theme_stylebox_override("pressed",box(SKY.darkened(.1),14,Color.TRANSPARENT,0,8))
		_:
			b.add_theme_font_size_override("font_size",16)
			b.add_theme_color_override("font_color",SOFT)
			b.add_theme_color_override("font_hover_color",SKY.darkened(.15))
			b.add_theme_color_override("font_pressed_color",SKY.darkened(.25))
			b.add_theme_stylebox_override("normal",box(UiStyle.surf(.42),12,LINE))
			b.add_theme_stylebox_override("hover",box(UiStyle.surf(.8),12,SKY.lightened(.35),1,10))
			b.add_theme_stylebox_override("pressed",box(SKY_SOFT,12,SKY.lightened(.2)))
			b.add_theme_color_override("font_focus_color",SKY.darkened(.15))
	# Keyboard and gamepad focus: a visible sky-blue ring.
	b.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,14,SKY,3))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build() -> void:
	var x = 96.0
	# The block camera of the logo, the name in its orange.
	var logo = TextureRect.new()
	logo.texture = preload("res://assets/marca/camara.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.position = Vector2(x-14,40)
	logo.size = Vector2(108,108)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	text(self,Texts.get_text("menu_estudio"),Vector2(x+104,58),13,UiStyle.SKY_DEEP,body_medium)
	text(self,Texts.get_text("nombre_juego"),Vector2(x+102,78),54,UiStyle.BRAND,title_font)
	text(self,Texts.get_text("menu_lema"),Vector2(x,150),16,SOFT,light_font,600)
	# ‹ card › with the dots of the five modes under it.
	var left = flat_button(self,"‹",Rect2(x-62,330,48,96),func(): change_mode(-1))
	left.add_theme_font_size_override("font_size",40)
	var right = flat_button(self,"›",Rect2(x+618,330,48,96),func(): change_mode(1))
	right.add_theme_font_size_override("font_size",40)
	for k in MODES.size():
		var dot = Panel.new()
		dot.position = Vector2(x+300-MODES.size()*12+k*24,602)
		dot.size = Vector2(12,12)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		dots.append(dot)
	hint = GlyphLabel.new()
	hint.position = Vector2(x,628)
	hint.size = Vector2(600,24)
	hint.font_size = 13
	hint.color = FAINT
	hint.align_center = true
	add_child(hint)
	build_card()

# The mode on show is kept between sessions (user://interfaz.cfg): the game opens where it was left.
static var mode_loaded = false
static func load_mode() -> void:
	if mode_loaded: return
	mode_loaded = true
	var config = ConfigFile.new()
	if config.load("user://interfaz.cfg") == OK: current = maxi(0,MODES.find(str(config.get_value("interfaz","modo_menu",MODES[0]))))

func remember_mode() -> void:
	if not main.badges_count(): return   # tests and capture tools do not touch the player's file
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","modo_menu",MODES[current])
	config.save("user://interfaz.cfg")

func change_mode(step: int) -> void:
	current = posmod(current+step,MODES.size())
	remember_mode()
	build_card()

func build_card() -> void:
	if is_instance_valid(card): card.queue_free()
	var x = 96.0
	card = Panel.new()
	card.position = Vector2(x,200)
	card.size = Vector2(600,390)
	card.add_theme_stylebox_override("panel",box(UiStyle.surf(.78),20,LINE,1,18))
	add_child(card)
	var mode: String = MODES[current]
	text(card,(Texts.get_text("modo_d_de_d") % [current+1,MODES.size()]).to_upper(),Vector2(32,26),13,UiStyle.SKY_DEEP,body_medium)
	text(card,Texts.get_text("modo_"+mode+"_titulo"),Vector2(30,44),44,UiStyle.BRAND,title_font)
	text(card,Texts.get_text("modo_"+mode+"_texto"),Vector2(32,108),16,SOFT,light_font,536)
	match mode:
		"arcade":
			var progress = preload("res://scripts/arcade.gd").load_progress()
			var stars = 0
			for n in progress: stars += int(progress[n].stars)
			text(card,Texts.get_text("modo_arcade_progreso") % [progress.size(),stars],Vector2(32,190),18,INK,body_medium)
			enter_button(main.show_arcade)
		"historia":
			# Not playable yet: said clearly, with a disabled button (docs/futuro/10).
			var badge = Label.new()
			badge.text = Texts.get_text("modo_proximamente")
			badge.position = Vector2(440,26)
			badge.add_theme_font_override("font",body_medium)
			badge.add_theme_font_size_override("font_size",13)
			badge.add_theme_color_override("font_color",Color.WHITE)
			badge.add_theme_stylebox_override("normal",box(UiStyle.WARN,10,Color.TRANSPARENT,0))
			card.add_child(badge)
			var b = flat_button(card,Texts.get_text("modo_historia_boton"),Rect2(32,306,536,58),func(): pass)
			b.disabled = true
			enter_callback = Callable()
		"tutorial":
			enter_button(main.start_tutorial)
		"sandbox":
			build_sandbox()
			enter_button(func(): main.start_in(scenario,time_of_day,true))
		"academia":
			var done = main.academy.practices_done() if main.academy else 0
			text(card,Texts.get_text("modo_academia_progreso") % done,Vector2(32,190),18,INK,body_medium)
			enter_button(main.open_academy)
		"opciones":
			build_options()
	for k in dots.size():
		dots[k].add_theme_stylebox_override("panel",box(SKY if k == current else UiStyle.surf(.6),6,LINE))
	hint.set_rich(Texts.get_rich("modo_ayuda_menu"))

func enter_button(callback: Callable) -> void:
	var b = flat_button(card,Texts.get_text("modo_entrar"),Rect2(32,306,536,58),callback,"primary")
	b.focus_mode = Control.FOCUS_ALL
	b.call_deferred("grab_focus")
	enter_callback = callback

var enter_callback: Callable
var swipe = 0.0

func build_sandbox() -> void:
	cards = {}
	chips = {}
	for k in 2:
		var which = ["clasico","grande"][k]
		var c = Button.new()
		c.position = Vector2(32+k*276,170)
		c.size = Vector2(260,70)
		c.focus_mode = Control.FOCUS_ALL
		c.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,14,SKY,3))
		c.pressed.connect(func(): select_scenario(which))
		card.add_child(c)
		text(c,Texts.get_text("escenario_"+which).capitalize(),Vector2(16,10),18,INK,body_medium)
		text(c,Texts.get_text("menu_"+which+"_detalle"),Vector2(16,38),12,SOFT,light_font,230)
		cards[which] = c
	var times = [["day","intro_dia"],["golden","intro_dorada"],["blue","intro_azul"],["night","intro_noche"]]
	for k in times.size():
		var chip = Button.new()
		chip.text = Texts.get_text(times[k][1])
		# (Taller under a finger: the row has the room, up to the «Entrar» button.)
		chip.position = Vector2(32+k*136,248 if Glyphs.touch else 252)
		chip.size = Vector2(126,50 if Glyphs.touch else 38)
		chip.focus_mode = Control.FOCUS_ALL
		chip.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,19,SKY,3))
		chip.add_theme_font_override("font",body_medium)
		chip.add_theme_font_size_override("font_size",14)
		var tod = times[k][0]
		chip.pressed.connect(func(): select_time(tod))
		card.add_child(chip)
		chips[tod] = chip
	# Explicit neighbours: Godot's guess jumps from a card to a chip of the row below.
	var rows = [cards.values(),chips.values()]
	for r in rows.size():
		var row: Array = rows[r]
		for k in row.size():
			var b: Control = row[k]
			b.focus_neighbor_left = b.get_path_to(row[posmod(k-1,row.size())])
			b.focus_neighbor_right = b.get_path_to(row[posmod(k+1,row.size())])
			if r == 0: b.focus_neighbor_bottom = b.get_path_to(chips.values()[mini(k*2,chips.size()-1)])
			else: b.focus_neighbor_top = b.get_path_to(cards.values()[mini(k/2,cards.size()-1)])
	refresh()

func build_options() -> void:
	enter_callback = Callable()
	var rows = [
		[Texts.get_text("menu_equipo"),main.show_equipment],
		[Texts.get_text("menu_graficos"),main.show_graphics_settings],
		[Texts.get_text("opcion_tema") % Texts.get_text("tema_oscuro" if UiStyle.dark else "tema_claro"),func(): main.set_theme(not UiStyle.dark)],
		[Texts.get_text("opcion_ayuda") % Texts.get_text("si" if main.control_help.enabled else "no"),func(): main.control_help.set_enabled(not main.control_help.enabled); build_card()],
		[Texts.get_text("opcion_vibracion") % Texts.get_text("si" if main.vibration else "no"),func(): main.set_vibration(not main.vibration); build_card()],
		[Texts.get_text("opcion_invertir") % Texts.get_text("invertir_"+main.look_invert),func(): main.set_look_invert(main.INVERT_CHOICES[(main.INVERT_CHOICES.find(main.look_invert)+1)%4]); build_card()],
		[Texts.get_text("menu_insignias"),main.show_badges],
		[Texts.get_text("menu_album"),func(): main.show_album()],
	]
	for k in rows.size():
		var b = flat_button(card,rows[k][0],Rect2(32+(k%2)*272,162+(k/2)*54,260,46),rows[k][1])
		b.focus_mode = Control.FOCUS_ALL
		if k == 0: b.call_deferred("grab_focus")

# ← → (keys, D-pad, LB/RB) change the mode; Enter / A enters it. In _input: the focused «Entrar»
# button would take the arrows for focus navigation before _unhandled_input ever saw them.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or main.mode != "INTRO": return
	if is_instance_valid(web_notice_modal) and web_notice_modal.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_ESCAPE]:
				get_viewport().set_input_as_handled()
				dismiss_web_notice()
				return
		elif event is InputEventJoypadButton and event.pressed:
			if event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_START]:
				get_viewport().set_input_as_handled()
				dismiss_web_notice()
				return
		return
	var step = 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_LEFT,KEY_A]: step = -1
		elif event.physical_keycode in [KEY_RIGHT,KEY_D]: step = 1
		elif event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER] and enter_callback.is_valid():
			get_viewport().set_input_as_handled()
			enter_callback.call()
			return
	# A swipe across the screen changes the mode too.
	if event is InputEventScreenTouch:
		if event.pressed: swipe = 0.0
		elif absf(swipe) > 140.0: step = -1 if swipe > 0 else 1
	if event is InputEventScreenDrag: swipe += event.relative.x
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_LEFT_SHOULDER]: step = -1
		elif event.button_index in [JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_RIGHT_SHOULDER]: step = 1
	# On a scenario card or a time chip, ← → move along that row (↑ ↓ reach them from «Entrar»).
	if step != 0 and in_rows(get_viewport().gui_get_focus_owner()) and (event is InputEventKey and event.physical_keycode in [KEY_LEFT,KEY_RIGHT] or event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]):
		return
	if step != 0:
		get_viewport().set_input_as_handled()
		change_mode(step)

func in_rows(c: Control) -> bool:
	return c != null and (c in cards.values() or c in chips.values())

func select_scenario(which: String) -> void:
	scenario = which
	refresh()

func select_time(tod: String) -> void:
	time_of_day = tod
	main.preview_time(tod)
	refresh()

func refresh() -> void:
	for which in cards:
		if not is_instance_valid(cards[which]): continue
		var on = which == scenario
		var c: Button = cards[which]
		c.add_theme_stylebox_override("normal",box(UiStyle.surf(.9) if on else CARD,14,SKY if on else LINE,2 if on else 1,12 if on else 0))
		c.add_theme_stylebox_override("hover",box(UiStyle.surf(.95),14,SKY.lightened(.2) if not on else SKY,2 if on else 1,10))
		c.add_theme_stylebox_override("pressed",box(SKY_SOFT,14,SKY,2))
	for tod in chips:
		if not is_instance_valid(chips[tod]): continue
		var on = tod == time_of_day
		var chip: Button = chips[tod]
		chip.add_theme_color_override("font_color",Color.WHITE if on else SOFT)
		chip.add_theme_color_override("font_hover_color",Color.WHITE if on else SKY.darkened(.15))
		chip.add_theme_stylebox_override("normal",box(SKY.lightened(.1) if on else UiStyle.surf(.5),19,Color.TRANSPARENT if on else LINE,1,8 if on else 0))
		chip.add_theme_stylebox_override("hover",box(SKY.lightened(.18) if on else UiStyle.surf(.85),19,SKY.lightened(.35),1,8))
		chip.add_theme_stylebox_override("pressed",box(SKY,19))

func show_web_notice() -> void:
	if is_instance_valid(web_notice_modal):
		web_notice_modal.queue_free()
	var overlay = Control.new()
	overlay.name = "WebNoticeModal"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop = ColorRect.new()
	backdrop.position = main.full_rect().position      # (the bands of a wider screen too)
	backdrop.size = main.full_rect().size
	backdrop.color = Color(0, 0, 0, 0.55)
	overlay.add_child(backdrop)

	var panel = Panel.new()
	var pw = 740.0
	var ph = 280.0
	panel.custom_minimum_size = Vector2(pw, ph)
	panel.size = Vector2(pw, ph)
	panel.position = Vector2((1280.0 - pw) * 0.5, (720.0 - ph) * 0.5)
	panel.add_theme_stylebox_override("panel", box(UiStyle.surf(0.96), 18, UiStyle.SKY, 2, 24))
	overlay.add_child(panel)

	text(panel, Texts.get_text("menu_aviso_web_titulo"), Vector2(36, 24), 28, UiStyle.BRAND, title_font)
	text(panel, Texts.get_text("menu_aviso_web_cuerpo"), Vector2(36, 76), 16, SOFT, body_font, pw - 72.0)

	var btn = flat_button(panel, Texts.get_text("menu_aviso_web_entendido"), Rect2((pw - 220.0) * 0.5, 200.0, 220.0, 48.0), dismiss_web_notice, "primary")
	btn.focus_mode = Control.FOCUS_ALL
	btn.call_deferred("grab_focus")

	add_child(overlay)
	web_notice_modal = overlay

func dismiss_web_notice() -> void:
	if is_instance_valid(web_notice_modal):
		web_notice_modal.queue_free()
		web_notice_modal = null
	# Return focus to mode card button
	change_mode(0)
