extends Control
# Main menu (docs/futuro/20_INTERFAZ_CLARA.md): clean, light and airy. The live park keeps running
# behind a block of frosted white glass (shaders/frosted_glass.gdshader) while the camera drifts
# slowly; the menu sits on the left: scenario cards, time of day chips, a big start button and the
# secondary entries (sandbox, academy, equipment, graphics).
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
var title_font: FontFile
var body_font: FontFile
var body_medium: FontFile
var light_font: FontFile

func _init(owner_main) -> void:
	main = owner_main

static func font(name: String) -> FontFile:
	var f = FontFile.new()
	f.load_dynamic_font("res://assets/fuentes/%s.ttf" % name)
	return f

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scenario = main.scenario
	title_font = font("Quicksand-Light")
	light_font = font("Roboto-Light")
	body_font = font("Roboto-Regular")
	body_medium = font("Quicksand-Medium")
	var glass = ColorRect.new()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/frosted_glass.gdshader")
	mat.set_shader_parameter("tint",UiStyle.GLASS_TINT)
	glass.material = mat
	add_child(glass)
	build()

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
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func build() -> void:
	var x = 96.0
	text(self,Texts.get_text("menu_estudio"),Vector2(x,70),13,UiStyle.SKY_DEEP,body_medium)
	text(self,"Proyecto Paparazzi",Vector2(x-4,88),62,INK,title_font)
	text(self,Texts.get_text("menu_lema"),Vector2(x,168),17,SOFT,light_font,560)
	# Scenario cards.
	text(self,Texts.get_text("menu_escenario"),Vector2(x,236),12,FAINT,body_medium)
	var y = 258.0
	for k in 2:
		var which = ["clasico","grande"][k]
		var card = Button.new()
		card.position = Vector2(x+k*292,y)
		card.size = Vector2(278,92)
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(func(): select_scenario(which))
		add_child(card)
		text(card,Texts.get_text("escenario_"+which).capitalize(),Vector2(20,16),21,INK,body_medium)
		text(card,Texts.get_text("menu_"+which+"_detalle"),Vector2(20,48),13,SOFT,light_font,238)
		cards[which] = card
	# Time of day chips.
	text(self,Texts.get_text("menu_luz"),Vector2(x,372),12,FAINT,body_medium)
	var times = [["day","intro_dia"],["golden","intro_dorada"],["blue","intro_azul"],["night","intro_noche"]]
	for k in times.size():
		var chip = Button.new()
		chip.text = Texts.get_text(times[k][1])
		chip.position = Vector2(x+k*143,394)
		chip.size = Vector2(133,42)
		chip.focus_mode = Control.FOCUS_NONE
		chip.add_theme_font_override("font",body_medium)
		chip.add_theme_font_size_override("font_size",15)
		var tod = times[k][0]
		chip.pressed.connect(func(): select_time(tod))
		add_child(chip)
		chips[tod] = chip
	flat_button(self,Texts.get_text("menu_empezar"),Rect2(x,468,570,64),func(): main.start_in(scenario,time_of_day,false),"primary")
	# Secondary entries.
	var row = [["menu_sandbox",func(): main.start_in(scenario,time_of_day,true)],["menu_academia",main.open_academy],["menu_equipo",main.show_equipment],["menu_graficos",main.show_graphics_settings]]
	for k in row.size():
		flat_button(self,Texts.get_text(row[k][0]),Rect2(x+k*145,550,135,44),row[k][1])
	text(self,Texts.get_text("menu_pie"),Vector2(x,624),13,FAINT,light_font,570)
	refresh()

func select_scenario(which: String) -> void:
	scenario = which
	refresh()

func select_time(tod: String) -> void:
	time_of_day = tod
	main.preview_time(tod)
	refresh()

func refresh() -> void:
	for which in cards:
		var on = which == scenario
		var card: Button = cards[which]
		card.add_theme_stylebox_override("normal",box(UiStyle.surf(.86) if on else CARD,16,SKY if on else LINE,2 if on else 1,16 if on else 0))
		card.add_theme_stylebox_override("hover",box(UiStyle.surf(.92),16,SKY.lightened(.2) if not on else SKY,2 if on else 1,14))
		card.add_theme_stylebox_override("pressed",box(SKY_SOFT,16,SKY,2))
	for tod in chips:
		var on = tod == time_of_day
		var chip: Button = chips[tod]
		chip.add_theme_color_override("font_color",Color.WHITE if on else SOFT)
		chip.add_theme_color_override("font_hover_color",Color.WHITE if on else SKY.darkened(.15))
		chip.add_theme_stylebox_override("normal",box(SKY.lightened(.1) if on else UiStyle.surf(.5),21,Color.TRANSPARENT if on else LINE,1,10 if on else 0))
		chip.add_theme_stylebox_override("hover",box(SKY.lightened(.18) if on else UiStyle.surf(.85),21,SKY.lightened(.35),1,8))
		chip.add_theme_stylebox_override("pressed",box(SKY,21))
