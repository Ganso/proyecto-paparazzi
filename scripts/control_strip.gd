extends Control
# The control in hand (docs/futuro/22 §5): a strip of chips over the bottom of the finder with the
# settings the player drives on the mounted camera (zoom, manual focus, aperture, shutter, ISO,
# compensation), one of them selected. It is the normal way to change them: with the gamepad the
# D-pad ←→ chooses and ↑↓ changes; with the mouse a click (or the wheel's button) chooses and the
# wheel changes; on the keyboard , . choose and Page Up/Down change. The direct shortcuts of each
# setting (Q E, Z X…) stay for those who know them.
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const GlyphLabel = preload("res://scripts/glyph_label.gd")
const Photo = preload("res://scripts/photography.gd")

const CHIP_H = 40.0
var main
var chips: Array = []
var ids: Array = []
var hint: Control
var styled = ""              # the chip the styles were last set for

func _init(owner_main) -> void:
	main = owner_main

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = GlyphLabel.new()
	hint.font_size = 12
	hint.shadow = true
	hint.size = Vector2(420,20)
	add_child(hint)

func name_of(id: String) -> String:
	return {"zoom":Texts.get_text("ayuda_zoom"),"foco":Texts.get_text("ayuda_enfoque"),"n":Texts.get_text("ayuda_diafragma"),"t":Texts.get_text("ayuda_velocidad"),"iso":"ISO","ev_comp":Texts.get_text("ayuda_compensacion")}[id]

func value_of(id: String) -> String:
	match id:
		"zoom": return "%d mm" % roundi(main.focal)
		"foco": return Texts.get_text("infinito") if is_inf(main.focus_distance) else "%.1f m" % main.focus_distance
		"n":
			var n = main.apertures()[main.n_index]
			return "f/%s" % (("%.1f" % n) if n < 10 else str(int(n)))
		"t": return "1/%d s" % Photo.DENOMINATORS[main.t_index]
		"iso": return str(Photo.ISOS[main.iso_index])
		"ev_comp": return "%+.1f EV" % main.equipment.exposure_compensation()
	return ""

# Where a control's chip is (the Academy frames the one it is talking about).
func chip_rect(id: String) -> Rect2:
	var k = ids.find(id)
	return Rect2(chips[k].position,chips[k].size) if visible and k >= 0 else Rect2()

func rebuild(list: Array) -> void:
	for c in chips: c.queue_free()
	chips = []
	ids = list.duplicate()
	styled = ""
	for id in ids:
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size",12)
		b.pressed.connect(func(): main.selected_control = id)
		# The wheel over a chip takes it in hand and changes it.
		b.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				main.selected_control = id
				main.change_control(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1))
		add_child(b)
		chips.append(b)

func _process(_dt: float) -> void:
	var list: Array = main.selectable_controls() if main.mode == "SEARCH" and main.eye_ready() else []
	visible = not list.is_empty()
	if not visible: return
	if list != ids: rebuild(list)
	var vr: Rect2 = main.view_rect
	var bars = not main.hud_bottom.is_empty() and main.hud_bottom[0].visible
	var bottom = minf(617.0 if bars else vr.end.y-12,vr.end.y-12)
	if main.tutorial and main.tutorial.visible: bottom = minf(bottom,main.tutorial.panel.position.y-8)
	if main.academy and main.academy.active and main.academy.subtitle_panel.visible: bottom = minf(bottom,main.academy.subtitle_panel.position.y-8)
	var left = vr.position.x+10
	var y = bottom-CHIP_H
	# The on-screen help may reach down here on the left (classic interface): start beside it.
	var help: Rect2 = main.control_help.panel_rect
	if main.control_help.enabled and help.size.y > 0 and help.end.y > y-22 and help.position.x < left+20: left = help.end.x+10
	var right = vr.end.x-10
	if main.control_help.raise_button.visible: right = main.control_help.raise_button.position.x-10
	var w = clampf((right-left)/ids.size()-6,88,124)
	if (w+6)*ids.size() > right-left+6:
		# No room beside the «lower the camera» button: one row up, the full width.
		y -= CHIP_H+8
		right = vr.end.x-10
		w = clampf((right-left)/ids.size()-6,74,124)
	var current: String = main.current_control()
	for k in ids.size():
		var b: Button = chips[k]
		var on = ids[k] == current
		b.position = Vector2(left+k*(w+6),y)
		b.size = Vector2(w,CHIP_H)
		b.text = name_of(ids[k])+"\n"+value_of(ids[k])
		if styled == current: continue
		b.add_theme_color_override("font_color",Color.WHITE if on else Color(1,1,1,.82))
		b.add_theme_color_override("font_hover_color",Color.WHITE)
		b.add_theme_stylebox_override("normal",UiStyle.box(UiStyle.SKY if on else Color(.03,.05,.08,.62),10,Color.WHITE if on else Color(1,1,1,.25),2 if on else 1))
		b.add_theme_stylebox_override("hover",UiStyle.box(UiStyle.SKY.lightened(.12) if on else Color(.1,.14,.2,.75),10,Color(1,1,1,.6),1))
		b.add_theme_stylebox_override("pressed",UiStyle.box(UiStyle.SKY,10))
	styled = current
	hint.visible = main.control_help.enabled
	hint.position = Vector2(left+2,y-21)
	hint.set_rich(Texts.get_rich("control_en_mano_ayuda"))
	# The game's notices go above the strip.
	if is_instance_valid(main.toast): main.toast.position.y = minf(main.toast.position.y,y-60)
