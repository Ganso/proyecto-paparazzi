extends Control
# Text with keys and gamepad buttons drawn as glyphs (docs/futuro/22 §3): a key marked ⟦Q⟧ is a
# keycap, a slightly trapezoidal light square with its letter; a pad button ⦅A⦆ is a round blue
# button. So in any help text a control stands out from the words around it. Wraps to the width.
# Use set_rich(Texts.get_rich(key)) — Texts fills {controls} for the device in use.
const UiStyle = preload("res://scripts/ui_style.gd")

var rich = ""
var font_size = 16
var color = Color.WHITE
var shadow = false
var font: Font
var align_center = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null: font = UiStyle.font("Roboto-Regular")

func set_rich(value: String) -> void:
	if value == rich: return
	rich = value
	queue_redraw()

func _draw() -> void:
	draw_rich(self,font,Vector2.ZERO,rich,font_size,color,size.x,shadow,align_center)

# Pieces of the text: [kind, text] with kind "t" (words), "k" (key) or "b" (pad button).
static func tokens(text_value: String) -> Array:
	var out = []
	var buf = ""
	var i = 0
	while i < text_value.length():
		var ch = text_value[i]
		if ch == "⟦" or ch == "⦅":
			var close = "⟧" if ch == "⟦" else "⦆"
			var end = text_value.find(close,i+1)
			if end < 0: break
			if buf != "": out.append(["t",buf])
			buf = ""
			out.append(["k" if ch == "⟦" else "b",text_value.substr(i+1,end-i-1)])
			i = end+1
			continue
		buf += ch
		i += 1
	if buf != "": out.append(["t",buf])
	return out

static func chip_width(font: Font, kind: String, label: String, size: int) -> float:
	var w = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size-2).x
	if kind == "b": return maxf(size*1.25,w+size*.75)
	return maxf(size*1.3,w+size*.8)

# One glyph with its top-left at pos. Keycap: lighter top face on a darker base, narrower at the
# top (trapezoid). Pad button: a circle, or a pill for longer names (View, Menu, Options).
static func draw_chip(ci: CanvasItem, font: Font, pos: Vector2, kind: String, label: String, size: int) -> float:
	var w = chip_width(font,kind,label,size)
	var h = size*1.3
	var y = pos.y-h*.78
	if kind == "b":
		var r = h*.5
		var fill = Color("2f8fe0")
		if w <= h+1:
			ci.draw_circle(Vector2(pos.x+w*.5,y+r),r,fill)
		else:
			ci.draw_circle(Vector2(pos.x+r,y+r),r,fill)
			ci.draw_circle(Vector2(pos.x+w-r,y+r),r,fill)
			ci.draw_rect(Rect2(pos.x+r,y,w-2*r,h),fill)
		ci.draw_string(font,Vector2(pos.x,y+h*.72),label,HORIZONTAL_ALIGNMENT_CENTER,w,size-3,Color.WHITE)
	else:
		var inset = h*.12
		var base = PackedVector2Array([Vector2(pos.x,y+h),Vector2(pos.x+w,y+h),Vector2(pos.x+w-inset*.6,y),Vector2(pos.x+inset*.6,y)])
		ci.draw_colored_polygon(base,Color(.42,.47,.53))
		var top = PackedVector2Array([Vector2(pos.x+inset*.5,y+h-inset*1.3),Vector2(pos.x+w-inset*.5,y+h-inset*1.3),Vector2(pos.x+w-inset*1.2,y+inset*.4),Vector2(pos.x+inset*1.2,y+inset*.4)])
		ci.draw_colored_polygon(top,Color(.95,.96,.97))
		ci.draw_string(font,Vector2(pos.x,y+h*.66),label,HORIZONTAL_ALIGNMENT_CENTER,w,size-3,Color(.1,.13,.17))
	return w

# Lays the text out from pos, wrapping at width (0: no wrap). Returns the height used.
static func draw_rich(ci: CanvasItem, font: Font, pos: Vector2, text_value: String, size: int, color: Color, width = 0.0, shadow = false, center = false) -> float:
	var line_h = size*1.55
	var lines = []          # each: [[kind, text, w], ...]
	for paragraph in text_value.split("\n"):
		var line = []
		var x = 0.0
		for tok in tokens(paragraph):
			var pieces = [tok] if tok[0] != "t" else []
			if tok[0] == "t":
				# Words wrap one by one (keeping their spaces).
				var word = ""
				for ch in tok[1]:
					word += ch
					if ch == " ":
						pieces.append(["t",word])
						word = ""
				if word != "": pieces.append(["t",word])
			for piece in pieces:
				var w = font.get_string_size(piece[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x if piece[0] == "t" else chip_width(font,piece[0],piece[1],size)+3
				if width > 0 and x+w > width and not line.is_empty():
					lines.append(line)
					line = []
					x = 0.0
				line.append([piece[0],piece[1],w])
				x += w
		lines.append(line)
	var y = pos.y+size
	for line in lines:
		var total = 0.0
		for piece in line: total += piece[2]
		var x = pos.x+((width-total)*.5 if center and width > 0 else 0.0)
		for piece in line:
			if piece[0] == "t":
				if shadow: ci.draw_string(font,Vector2(x+1,y+2),piece[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,.75))
				ci.draw_string(font,Vector2(x,y),piece[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
			else:
				draw_chip(ci,font,Vector2(x+1,y),piece[0],piece[1],size)
			x += piece[2]
		y += line_h
	return lines.size()*line_h
