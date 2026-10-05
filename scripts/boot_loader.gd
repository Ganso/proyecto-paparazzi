extends CanvasLayer
# «Cargando el parque»: the same picture as the engine's boot image (assets/marca/carga.png: blue,
# the block camera, PhotoHacks in orange), so the change from one to the other is not seen — and
# then the camera turns round (assets/marca/giro.png, 45 frames, tools/build_branding.sh). The
# frame shown goes by the clock, so the turn keeps its speed even though the park is built in
# big blocks between one drawn frame and the next. Only in the real game (main.gd::_ready()).
const UiStyle = preload("res://scripts/ui_style.gd")
const Texts = preload("res://scripts/texts.gd")
const SHEET = preload("res://assets/marca/giro.png")
const COLUMNS = 9
const FRAMES = 45
const TURN_SECONDS = 3.0
var art: Control
var started = 0
var fading = -1.0

func _ready() -> void:
	layer = 120
	started = Time.get_ticks_msec()
	art = Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_STOP
	art.draw.connect(draw_art)
	add_child(art)

func draw_art() -> void:
	art.draw_rect(Rect2(-1280,-720,3840,2160),Color("296ca5"))   # (the bands of a wider screen too)
	var title = UiStyle.font("RussoOne-Regular")
	var name_text = Texts.get_text("nombre_juego")
	var light = UiStyle.font("Roboto-Light")
	var k = int((Time.get_ticks_msec()-started)/1000.0/TURN_SECONDS*FRAMES)%FRAMES
	art.draw_texture_rect_region(SHEET,Rect2(420,40,440,440),Rect2((k%COLUMNS)*256,(k/COLUMNS)*256,256,256))
	art.draw_string(title,Vector2(640-title.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,92).x*.5,470+92*.8),name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,92,UiStyle.BRAND)
	var note = Texts.get_text("cargando_parque")
	art.draw_string(light,Vector2(640-light.get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x*.5,600+28*.8),note,HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("d6ecfb"))

func _process(dt: float) -> void:
	art.queue_redraw()
	if fading >= 0.0:
		fading += dt
		art.modulate.a = clampf(1.0-fading/.35,0,1)
		if fading >= .35: queue_free()

# The park is ready: fade away.
func finish() -> void:
	fading = 0.0
