extends Control
# The keyboard and the mouse with what each key does (docs/futuro/22 §3), drawn in code for the
# help screen when the player uses keyboard and mouse. The keys the game uses are lit in the colour
# of their group (look, lens, exposure, shoot, camera, help); the legend under it says what each
# group does, with the keys drawn as keycaps. The mouse, on the right, points out its buttons.
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const GlyphLabel = preload("res://scripts/glyph_label.gd")

var font: Font
const U = 40.0          # one key unit in pixels
const ROWS = [
	[["Esc",1],["",.5],["F1",1],["",12.5]],
	[["",1],["1",1],["2",1],["3",1],["4",1],["5",1],["6",1],["7",1],["8",1],["9",1],["",3]],
	[["Tab",1.5],["Q",1],["W",1],["E",1],["R",1],["T",1],["Y",1],["U",1],["I",1],["O",1],["P",1],["[",1],["]",1]],
	[["",1.75],["A",1],["S",1],["D",1],["F",1],["G",1],["H",1],["J",1],["K",1],["L",1],["",1],["",1],["Intro",1.75]],
	[["Mayús",2.25],["Z",1],["X",1],["C",1],["V",1],["B",1],["N",1],["M",1],["",4.25]],
	[["Ctrl",1.5],["",2],["Espacio",6],["",1.5],["←",1],["↓",1],["→",1]],
]
# Group of each key the game uses: colour and legend.
const GROUPS = {
	"mirar": [Color("3a9be8"),["A","D","←","→","↑","↓"]],
	"objetivo": [Color("2fb39a"),["W","S","R","T","F","1","2","3","4","5","6","7","8","9","Mayús"]],
	"exposicion": [Color("e0a030"),["Q","E","Z","X","C","V","[","]"]],
	"disparar": [Color("e05a4a"),["Espacio"]],
	"camara": [Color("8a6ad8"),["Y","G","L","K","Tab"]],
	"ayuda": [Color("7a8a9a"),["H","F1","Esc","Intro"]],
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = UiStyle.font("Roboto-Regular")

func group_of(key: String) -> String:
	for g in GROUPS:
		if key in GROUPS[g][1]: return g
	return ""

func draw_key(rect: Rect2, label: String) -> void:
	var g = group_of(label)
	var base = GROUPS[g][0].darkened(.25) if g != "" else Color(.62,.66,.7,.45)
	var top = GROUPS[g][0] if g != "" else UiStyle.surf(.85)
	var inset = 3.0
	draw_colored_polygon(PackedVector2Array([rect.position+Vector2(0,rect.size.y),rect.end,rect.position+Vector2(rect.size.x-2,0),rect.position+Vector2(2,0)]),base)
	draw_colored_polygon(PackedVector2Array([rect.position+Vector2(inset,rect.size.y-inset*2),rect.end-Vector2(inset,inset*2),rect.position+Vector2(rect.size.x-inset*2,inset),rect.position+Vector2(inset*2,inset)]),top)
	if label != "":
		var size = 13 if label.length() <= 2 else 11
		draw_string(font,rect.position+Vector2(0,rect.size.y*.58),label,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,size,Color.WHITE if g != "" else UiStyle.SOFT)

func _draw() -> void:
	var origin = Vector2(20,10)
	var y = origin.y
	for row in ROWS:
		var x = origin.x
		for key in row:
			var w = key[1]*U
			if key[0] != "": draw_key(Rect2(x+2,y+2,w-4,U-4),key[0])
			x += w
		y += U
	# The up arrow above the down arrow.
	draw_key(Rect2(origin.x+12.0*U+2,y-2*U+2,U-4,U-4),"↑")
	# Mouse on the right.
	var m = Vector2(origin.x+16.5*U,origin.y+2.2*U)
	var body = Rect2(m,Vector2(84,130))
	draw_rect(body,UiStyle.surf(.9))
	draw_rect(Rect2(m,Vector2(42,52)),GROUPS.objetivo[0].lerp(Color.WHITE,.15))
	draw_rect(Rect2(m+Vector2(42,0),Vector2(42,52)),GROUPS.objetivo[0].darkened(.1))
	draw_rect(Rect2(m+Vector2(36,10),Vector2(12,26)),GROUPS.objetivo[0].darkened(.35))
	draw_rect(body,UiStyle.LINE,false,2)
	var notes = [[m+Vector2(20,20),Texts.get_text("raton_clic")],[m+Vector2(42,20),Texts.get_text("raton_rueda")],[m+Vector2(64,26),Texts.get_text("raton_derecho")],[m+Vector2(42,100),Texts.get_text("raton_arrastrar")]]
	for i in notes.size():
		var to = Vector2(m.x+120,m.y-30+i*48)
		draw_line(notes[i][0],to,UiStyle.FAINT,1.2,true)
		draw_circle(notes[i][0],3,UiStyle.SKY)
		GlyphLabel.draw_rich(self,font,to+Vector2(6,-12),notes[i][1],14,UiStyle.INK,size.x-to.x-10)
	# Legend: one line per group.
	var ly = y+18
	var col = 0
	var gi = 0
	for g in GROUPS:
		var pos = Vector2(origin.x+(gi%2)*560,ly+(gi/2)*30)
		draw_rect(Rect2(pos+Vector2(0,4),Vector2(16,16)),GROUPS[g][0])
		GlyphLabel.draw_rich(self,font,pos+Vector2(24,-2),Texts.get_rich("teclado_"+g),14,UiStyle.INK,530)
		gi += 1
