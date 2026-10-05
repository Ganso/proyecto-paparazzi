extends Control
# Touch interface (docs/futuro/13, first functional version): everything the keyboard, the mouse
# and the gamepad do, with the fingers. Over the camera interface (the same on every device):
#   · on the view: one finger drags the look, a tap focuses there, two fingers pinch the zoom;
#   · right column: pause, help, AF, the shutter and «camera down / up»;
#   · left column: thirds, AF/AE lock, metering and, on the TLR, loupe and crank;
#   · the strip of the control in hand (scripts/control_strip.gd) grows − and + buttons;
#   · walking in the big park: a stick on the left walks (pushed to the edge it runs) and dragging
#     anywhere else looks.
# Active when Glyphs.touch is on: phones and tablets, or -- --touch on the desktop (the mouse then
# plays the finger), which is how it is tested.
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Glyphs = preload("res://scripts/input_glyphs.gd")

const STICK_CENTRE = Vector2(150,560)
const STICK_RADIUS = 95.0
var main
var buttons = {}
var stick_centre = STICK_CENTRE
var stick_finger = -1
var stick_vector = Vector2.ZERO
var look_fingers = {}

func _init(owner_main) -> void:
	main = owner_main

func make(id: String, key: String, callback: Callable, primary = false) -> Button:
	var b = Button.new()
	b.text = Texts.get_text(key)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_stylebox_override("normal",UiStyle.box(UiStyle.SKY if primary else Color(.03,.05,.08,.62),14,Color(1,1,1,.55),2))
	b.add_theme_stylebox_override("hover",UiStyle.box(UiStyle.SKY if primary else Color(.03,.05,.08,.62),14,Color(1,1,1,.55),2))
	b.add_theme_stylebox_override("pressed",UiStyle.box(UiStyle.SKY.lightened(.2),14,Color.WHITE,2))
	b.add_theme_color_override("font_color",Color.WHITE)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_color_override("font_pressed_color",Color.WHITE)
	b.pressed.connect(callback)
	add_child(b)
	buttons[id] = b
	return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	make("pausa","tactil_pausa",func(): main.show_pause())
	make("ayuda","tactil_ayuda",func(): main.show_help())
	make("af","tactil_af",func(): main.autofocus())
	# The shutter in two stages, as on a camera (docs/futuro/26 B1): pressing it focuses, letting
	# go takes the photo, and sliding the finger off the button before letting go cancels it.
	var shutter = make("disparar","tactil_disparar",func(): main.take_photo(),true)
	shutter.add_theme_font_size_override("font_size",40)
	shutter.button_down.connect(func():
		if main.equipment.focus_mode != "MF" and not main.focus_locked: main.autofocus())
	make("camara","tactil_camara_bajar",func(): main.toggle_raise())
	make("tercios","tactil_tercios",func(): main.finder.thirds = not main.finder.thirds)
	make("bloqueo","tactil_bloqueo",func(): main.toggle_lock())
	make("medicion","tactil_medicion",func(): main.next_metering(); main.refresh())
	make("lupa","tactil_lupa",func():
		main.tlr_loupe = not main.tlr_loupe
		main.update_finder_shader()
		main.refresh())
	make("manivela","tactil_manivela",func(): main.wind_film())

func place(id: String, rect: Rect2, show: bool) -> void:
	var b: Button = buttons[id]
	b.visible = show
	b.position = rect.position
	b.size = rect.size

func _process(_dt: float) -> void:
	visible = Glyphs.touch and Glyphs.device == "tactil" and main.mode == "SEARCH"
	if not visible:
		stick_finger = -1
		stick_vector = Vector2.ZERO
		main.touch_move = Vector2.ZERO
		return
	var lesson = main.academy != null and main.academy.active
	var hands_off = lesson and main.academy.locks_input()      # theory, demonstration: only the pause
	var eye: bool = main.eye_ready()
	var walking: bool = main.crowd != null and not main.camera_raised
	# The Academy's panel takes the right side: the column moves to its left.
	# On a screen wider than 16:9 the columns move out into the side bands, as far as the notch
	# or the punch-hole camera leaves room (main.gd::fit_frame()): the picture stays clear.
	var out_left = clampf(main.frame_offset.x-main.safe_inset.x,0,134)
	var out_right = clampf(main.frame_offset.x-main.safe_inset.y,0,134)
	var x = 1146.0+out_right
	if lesson and main.academy.panel.visible: x = main.academy.panel.position.x-134.0
	stick_centre = STICK_CENTRE-Vector2(out_left,0)
	place("pausa",Rect2(x,12,124,56),true)
	place("ayuda",Rect2(x,76,124,56),not hands_off)
	place("af",Rect2(x,372,124,66),eye and not hands_off and main.equipment.focus_mode != "MF")
	place("disparar",Rect2(x,448,124,124),eye and not hands_off)
	var can_lower = not lesson and not (main.tutorial.active and main.crowd == null and main.tutorial.id() in ["bienvenida","mirar","zoom"])
	place("camara",Rect2(x,582,124,66),can_lower and not main.shooting)
	buttons.camara.text = Texts.get_text("tactil_camara_bajar" if main.camera_raised else "tactil_camara_subir")
	var left = eye and not hands_off
	place("tercios",Rect2(10-out_left,150,124,58),left)
	place("bloqueo",Rect2(10-out_left,216,124,58),left)
	place("medicion",Rect2(10-out_left,282,124,58),left and not lesson)
	buttons.medicion.text = Texts.get_text("fotometria_"+main.equipment.metering)
	place("lupa",Rect2(10-out_left,348,124,58),left and main.equipment.tlr())
	place("manivela",Rect2(10-out_left,414,124,58),left and main.equipment.tlr() and main.sandbox and not lesson and (not main.tlr_wound or main.tlr_frames <= 0))
	main.touch_move = stick_vector if walking else Vector2.ZERO
	if not walking:
		stick_finger = -1
		stick_vector = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if not (main.crowd != null and not main.camera_raised): return
	# The walking stick: a ring and its knob.
	draw_circle(stick_centre,STICK_RADIUS,Color(0,0,0,.28))
	draw_arc(stick_centre,STICK_RADIUS,0,TAU,64,Color(1,1,1,.6),2.0,true)
	draw_circle(stick_centre+stick_vector*STICK_RADIUS*.75,34,Color(UiStyle.SKY.r,UiStyle.SKY.g,UiStyle.SKY.b,.85))
	var font = UiStyle.font("Roboto-Medium")
	var word = Texts.get_text("tactil_andar")
	draw_string(font,stick_centre+Vector2(-font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x*.5,-STICK_RADIUS-10),word,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)

# Walking: the stick and the look, before the game sees the touch (buttons take theirs first).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (main.crowd != null and not main.camera_raised): return
	if event is InputEventScreenTouch:
		var at = get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed:
			if stick_finger < 0 and at.distance_to(stick_centre) <= STICK_RADIUS*1.6:
				stick_finger = event.index
				push_stick(at)
			else: look_fingers[event.index] = at
		else:
			if event.index == stick_finger:
				stick_finger = -1
				stick_vector = Vector2.ZERO
			look_fingers.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var at = get_global_transform_with_canvas().affine_inverse()*event.position
		if event.index == stick_finger: push_stick(at)
		elif look_fingers.has(event.index):
			main.angle = fposmod(main.angle-event.relative.x*.16*main.look_sign().x,360)
			main.pitch = clampf(main.pitch+event.relative.y*.16*main.look_sign().y,-70,70)
			main.update_camera()
		get_viewport().set_input_as_handled()

func push_stick(at: Vector2) -> void:
	stick_vector = ((at-stick_centre)/STICK_RADIUS).limit_length(1.0)
