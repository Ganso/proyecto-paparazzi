extends Control
# Tutorial mode (docs/futuro/22 §2): teaches the game from scratch, one action at a time, in the
# classic park. Each step says what to do — with the keys or the gamepad buttons drawn, whichever
# the player is using — notices when it is done and moves on: look, tilt, zoom, lower and raise
# the camera, focus, the on-screen help, shoot and read the result, a real assignment, the aperture
# (aperture priority) and manual focus. Then it points to the Arcade and the Academy.
const Texts = preload("res://scripts/texts.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const GlyphLabel = preload("res://scripts/glyph_label.gd")

const STEPS = ["bienvenida","mirar","zoom","bajar","af","ayuda","disparar","seguir","encargo","controles","diafragma","tercios","abruma","mf","paseo","sacar","foto_paseo","fin"]
# The last steps are in the big park, on foot: the scene reloads there and the tutorial resumes.
const WALKING = ["paseo","sacar","foto_paseo"]
static var resume_step = -1
const Glyphs = preload("res://scripts/input_glyphs.gd")
# Steps that only explain: «Continuar» is there from the start.
const INFO = ["controles","tercios","abruma"]

var main
var active = false
var step = 0
var done_time = -1.0             # seconds since the current step was completed (−1: not yet)
var track = {}                   # per-step progress
var panel: Panel
var counter: Label
var body: Control
var status: Label
var buttons: Array = []

func _init(owner_main) -> void:
	main = owner_main

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	panel = Panel.new()
	panel.position = Vector2(300,438)
	panel.size = Vector2(680,164)
	add_child(panel)
	counter = Label.new()
	counter.position = Vector2(20,12)
	counter.add_theme_font_size_override("font_size",12)
	panel.add_child(counter)
	body = GlyphLabel.new()
	body.position = Vector2(20,34)
	body.size = Vector2(640,82)   # three lines with room to spare (docs/TESTS_Y_VERIFICACION.md §4.3)
	body.font_size = 17
	panel.add_child(body)
	status = Label.new()
	status.position = Vector2(20,126)
	status.add_theme_font_size_override("font_size",14)
	panel.add_child(status)

func start(from = 0) -> void:
	active = true
	visible = true
	step = from
	enter_step()

func stop() -> void:
	active = false
	visible = false
	main.place_view()

func enter_step() -> void:
	done_time = -1.0
	track = {"walked":0.0,"spot":main.player.position if main.player else Vector3.ZERO,"photo":false,"angle":main.angle,"pitch":main.pitch,"turn":0.0,"tilt":0.0,"max_f":main.focal,"min_f":main.focal,"lowered":false,"helps":0,"apertures":0,"n":main.n_index,"mf_time":0.0,"help_state":main.control_help.enabled}
	var id: String = STEPS[step]
	# What each step needs from the camera.
	match id:
		"bienvenida","mirar","zoom","bajar","af","ayuda","disparar","seguir":
			main.equipment.preset(0)
			main.apply_equipment()
		"encargo":
			main.tutorial_assignment()
		"controles", "diafragma", "tercios", "abruma":
			main.equipment.set_exposure_mode("A")
			main.apply_equipment()
			main.selected_control = "zoom"   # the step teaches to choose the aperture on the strip
		"mf":
			main.equipment.set_exposure_mode("P")
			main.equipment.focus_mode = "MF"
			main.apply_equipment()
	# These steps talk about the on-screen help: it has to be there.
	if id in ["ayuda","encargo","diafragma"] and not main.control_help.enabled: main.control_help.set_enabled(true)
	if id in WALKING and main.scenario != "grande":
		resume_step = step
		active = false
		visible = false
		main.start_tutorial()
		return
	# With the fingers there is no list of keys to hide or show: those two steps are skipped.
	if Glyphs.touch and Glyphs.device == "tactil" and id in ["ayuda","abruma"]:
		step += 1
		enter_step()
		return
	# Following with the keys is the keyboard's: with a stick or a finger the turn is one's own.
	if id == "seguir" and (Glyphs.pad() or Glyphs.device == "tactil"):
		step += 1
		enter_step()
		return
	if id == "fin":
		# The end is a screen of its own, with where to go next (main.gd::show_tutorial_end()).
		visible = false
		main.show_tutorial_end()
		return
	if id in INFO: done_time = 0.0
	update_panel()

func id() -> String:
	return STEPS[step]

func complete() -> void:
	if done_time >= 0.0: return
	done_time = 0.0
	if not main.play_sfx("tutorial_ok",-4.0): main.play_tone(1320,.08)
	update_panel()

func next() -> void:
	if step >= STEPS.size()-1: return
	step += 1
	enter_step()

func update_panel() -> void:
	var dark = UiStyle.dark
	panel.add_theme_stylebox_override("panel",UiStyle.box(UiStyle.surf(.9),16,UiStyle.LINE,1,14))
	counter.text = Texts.get_text("tutorial_paso") % [step+1,STEPS.size()]
	counter.add_theme_color_override("font_color",UiStyle.SKY_DEEP)
	body.color = UiStyle.INK
	# With the gamepad some steps are told another way (no mouse, no keys).
	var key = "tutorial_"+id()
	if Glyphs.pad() and Texts.get_text(key+"_mando") != key+"_mando": key += "_mando"
	elif Glyphs.device == "tactil" and Texts.get_text(key+"_tactil") != key+"_tactil": key += "_tactil"
	body.set_rich(Texts.get_rich(key))
	status.add_theme_color_override("font_color",UiStyle.SKY_DEEP if done_time >= 0.0 else UiStyle.SOFT)
	status.text = Texts.get_text("tutorial_bien") if done_time >= 0.0 else Texts.get_text("tutorial_pendiente")
	if id() in INFO: status.text = ""
	for b in buttons: b.queue_free()
	buttons = []
	if id() == "bienvenida":
		add_button(Texts.get_text("tutorial_empezar"),Rect2(470,118,190,36),next,true)
		status.text = ""
	elif done_time >= 0.0:
		# Done: nothing moves until the player says so.
		add_button(Texts.get_text("tutorial_continuar"),Rect2(470,118,190,36),next,true)
	else:
		add_button(Texts.get_text("tutorial_saltar"),Rect2(470,118,90,36),next)
		add_button(Texts.get_text("tutorial_salir"),Rect2(570,118,90,36),func(): stop(); main.intro())
	if dark: pass

func add_button(label_text: String, rect: Rect2, callback: Callable, primary = false) -> void:
	var b = Button.new()
	b.text = label_text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",14)
	if primary: UiStyle.primary(b)
	b.pressed.connect(callback)
	panel.add_child(b)
	buttons.append(b)

# Enter / A moves on from the welcome and the end; elsewhere the game's own controls are taught.
func handle_accept() -> bool:
	if not active: return false
	if id() == "bienvenida" or done_time >= 0.0:
		next()
		return true
	return false

# Every frame while searching: has the player done what the step asks?
func update(dt: float) -> void:
	if not active: return
	visible = main.mode == "SEARCH"
	# The notices of the game (focus confirmed…) go above the panel, not under it.
	if visible and is_instance_valid(main.toast): main.toast.position.y = minf(main.toast.position.y,panel.position.y-40)
	if done_time >= 0.0:
		done_time += dt
		return   # done: the «Continuar» button moves on, when the player is ready
	match id():
		"seguir":
			# The camera has kept someone on the point for a second and a bit.
			if main.follow_state == "siguiendo": track["followed"] = float(track.get("followed",0.0))+dt
			if float(track.get("followed",0.0)) >= 1.2: complete()
		"mirar":
			# To the sides and up and down, in one step.
			track.turn += absf(angle_difference(deg_to_rad(track.angle),deg_to_rad(main.angle)))
			track.angle = main.angle
			track.tilt += absf(main.pitch-track.pitch)
			track.pitch = main.pitch
			if rad_to_deg(track.turn) >= 60.0 and track.tilt >= 15.0: complete()
		"paseo":
			track.walked += main.player.position.distance_to(track.spot)
			track.spot = main.player.position
			if track.walked >= 8.0: complete()
		"sacar":
			if main.eye_ready(): complete()
		"foto_paseo":
			if track.photo and not main.camera_raised: complete()
		"zoom":
			track.max_f = maxf(track.max_f,main.focal)
			track.min_f = minf(track.min_f,main.focal)
			if track.max_f >= 70.0 and main.focal <= 40.0: complete()
		"bajar":
			if not main.camera_raised: track.lowered = true
			if track.lowered and main.eye_ready(): complete()
		"af":
			if main.finder.flash > 0.0 and main.finder.success and main.af_person != null: complete()
		"ayuda":
			if main.control_help.enabled != track.help_state: track.helps += 1
			track.help_state = main.control_help.enabled
			if track.helps >= 2: complete()
		"diafragma":
			if main.n_index != track.n:
				track.apertures += 1
				track.n = main.n_index
			if track.apertures >= 2: complete()
		"mf":
			if main.finder.mf_coincidence and not is_inf(main.focus_distance) and main.focus_distance < 30.0: track.mf_time += dt
			else: track.mf_time = 0.0
			if track.mf_time > .6: complete()

# A photo of the tutorial: "disparar" passes with any photo, "encargo" with a valid one of the
# subject. Returns a line for the result screen.
func on_photo(result: Dictionary) -> String:
	match id():
		"disparar":
			complete()
			return Texts.get_text("tutorial_resultado_disparar")
		"foto_paseo":
			track.photo = true
			return Texts.get_text("tutorial_resultado_paseo")
		"encargo":
			if not result.rejected and result.score >= 50:
				complete()
				return Texts.get_text("tutorial_resultado_bien") % result.score
			return Texts.get_text("tutorial_resultado_otra")
	return ""
