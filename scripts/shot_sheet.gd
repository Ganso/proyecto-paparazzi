extends RefCounted
# The shots' cheat sheet (docs/futuro/29 §11.3): the six shots with their pictograms and where each
# one cuts, and the clean cut. Shared by Paparazzi's PZ_HELP and the help of the other modes (the
# arcade's levels about shots open it with the help key).
const Framing = preload("res://scripts/framing.gd")
const Paparazzi = preload("res://scripts/paparazzi.gd")
const PlaneIcon = preload("res://scripts/plane_icon.gd")
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

# In `box` (1180 px wide), from y 76 to 466: two rows of three shots and the line of the clean cut.
# `asked` (a shot of Framing.ORDER, or "") stands out with the brand's colour.
static func build(main, box: Control, asked = "") -> void:
	for i in Framing.ORDER.size():
		var plane: String = Framing.ORDER[i]
		var at = Vector2(32+(i%3)*376,76+(i/3)*178)
		if plane == asked:
			var mark = Panel.new()
			mark.position = at-Vector2(10,8)
			mark.size = Vector2(366,172)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.add_theme_stylebox_override("panel",UiStyle.box(Color(UiStyle.BRAND,.10),12,UiStyle.BRAND,2))
			box.add_child(mark)
		var icon = PlaneIcon.new(plane,UiStyle.INK)
		icon.position = at
		icon.size = Vector2(70,160)
		box.add_child(icon)
		main.label(box,Paparazzi.plane_name(plane),Rect2(at.x+84,at.y+8,280,28),20,UiStyle.BRAND)
		main.label(box,Texts.get_text("pz_chuleta_"+plane),Rect2(at.x+84,at.y+42,270,110),16,UiStyle.INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.label(box,Texts.get_text("pz_chuleta_corte"),Rect2(32,440,1116,26),17,UiStyle.SOFT)
