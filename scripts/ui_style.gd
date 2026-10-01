extends RefCounted
# Light interface style (docs/futuro/20_INTERFAZ_CLARA.md): clean, light tones with sky-blue
# highlights, Quicksand for headings and buttons, Roboto for text. One Theme for the whole UI
# and a mapping from the old dark palette, so every screen built with main.gd's helpers follows it.
# Palette as variables: dark=true swaps to the inverse trial (light text on dark glass, --ui=oscuro).
static var dark = false
static var INK = Color("0e1924")
static var SOFT = Color("26394a")
static var FAINT = Color("3b4f62")
static var SKY = Color("2f9be8")
static var SKY_DEEP = Color("155a8c")
static var SKY_SOFT = Color("d6ecfb")
static var WARN = Color("a13a1f")
static var GLASS = Color(1,1,1,.74)
static var LINE = Color(.55,.72,.88,.6)
static var SURFACE = Color(1,1,1)   # base of buttons, cards and panels
static var GLASS_TINT = Color(.965,.98,1.0)

static func set_dark(on: bool) -> void:
	dark = on
	if not on: return
	INK = Color("eef4fa")
	SOFT = Color("c9d6e2")
	FAINT = Color("9fb1c2")
	SKY = Color("3aa5f0")
	SKY_DEEP = Color("7cc6ff")
	SKY_SOFT = Color("1d3b55")
	WARN = Color("ff9a76")
	GLASS = Color(.07,.1,.14,.8)
	LINE = Color(.45,.6,.75,.45)
	SURFACE = Color(.09,.13,.18)
	GLASS_TINT = Color(.05,.075,.1)

# Surface colour with alpha (white in the light style, dark slate in the inverse one).
static func surf(a: float) -> Color:
	return Color(SURFACE.r,SURFACE.g,SURFACE.b,a)

static var fonts = {}
static func font(name: String) -> FontFile:
	if not fonts.has(name):
		var f = FontFile.new()
		f.load_dynamic_font("res://assets/fuentes/%s.ttf" % name)
		fonts[name] = f
	return fonts[name]

static func box(color: Color, radius = 12, border = Color.TRANSPARENT, border_w = 1, shadow = 0) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.border_color = border
	b.set_border_width_all(border_w if border.a > 0 else 0)
	b.shadow_color = Color(.24,.48,.72,.16)
	b.shadow_size = shadow
	b.shadow_offset = Vector2(0,shadow*.35)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	b.anti_aliasing = true
	return b

static func lum(c: Color) -> float:
	return c.r*.299+c.g*.587+c.b*.114

# Old (dark theme) text colour → light theme text colour.
static func text_color(c: Color) -> Color:
	if dark:
		if lum(c) < .45: return INK
		if c.r > c.g+.08 and c.r > c.b+.1: return WARN
		if c.g > c.r+.05 and c.g > c.b+.02: return SKY_DEEP
		return INK if lum(c) > .7 else SOFT
	if lum(c) < .45: return c
	if c.r > c.g+.08 and c.r > c.b+.1: return WARN
	if c.g > c.r+.05 and c.g > c.b+.02: return SKY_DEEP
	return INK if lum(c) > .7 else SOFT

# Old dark panel colour → white glass (keeps translucent panels translucent).
static func panel_color(c: Color) -> Color:
	if lum(c) > .5 and not dark: return c
	return surf(.8*c.a+.06)

static func theme() -> Theme:
	var t = Theme.new()
	t.default_font = font("Roboto-Regular")
	t.default_font_size = 16
	t.set_color("font_color","Label",INK)
	for kind in ["Button","OptionButton"]:
		t.set_font("font",kind,font("Quicksand-Medium"))
		t.set_color("font_color",kind,SOFT)
		t.set_color("font_hover_color",kind,SKY_DEEP)
		t.set_color("font_pressed_color",kind,SKY_DEEP)
		t.set_color("font_disabled_color",kind,Color(.36,.44,.52))
		t.set_stylebox("normal",kind,box(surf(.62),12,LINE))
		t.set_stylebox("hover",kind,box(surf(.92),12,SKY.lightened(.3),1,8))
		t.set_stylebox("pressed",kind,box(SKY_SOFT,12,SKY.lightened(.1)))
		t.set_stylebox("disabled",kind,box(surf(.3),12,LINE))
		t.set_stylebox("focus",kind,StyleBoxEmpty.new())
	t.set_stylebox("panel","PopupMenu",box(surf(.97),10,LINE,1,10))
	t.set_color("font_color","PopupMenu",INK)
	t.set_color("font_hover_color","PopupMenu",SKY_DEEP)
	t.set_stylebox("hover","PopupMenu",box(SKY_SOFT,8))
	t.set_font("font","PopupMenu",font("Roboto-Regular"))
	var track = box(Color(.72,.82,.92,.9) if not dark else Color(.25,.34,.44,.9),4)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider","HSlider",track)
	t.set_stylebox("grabber_area","HSlider",box(SKY,4))
	t.set_stylebox("grabber_area_highlight","HSlider",box(SKY.lightened(.1),4))
	return t

static func primary(b: Button) -> void:
	b.add_theme_color_override("font_color",Color.WHITE)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color.WHITE)
	b.add_theme_stylebox_override("normal",box(SKY,12,Color.TRANSPARENT,0,10))
	b.add_theme_stylebox_override("hover",box(SKY.lightened(.12),12,Color.TRANSPARENT,0,14))
	b.add_theme_stylebox_override("pressed",box(SKY.darkened(.1),12))
