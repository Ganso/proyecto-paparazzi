extends Control
# Academia de fotografía (docs/futuro/06_MODO_TUTOR_ACADEMIA.md): ten lessons (five on technique,
# five on the equipment), each with theory
# pages drawn over the live viewfinder, a guided demonstration (the camera moves by itself, with
# subtitles and highlighted controls) and a practice with tasks and live hints. The exam is shown
# as «not available yet». Runs on top of the sandbox session of main.gd (no assignment, unlimited
# shots, pausable scene); all copy lives in data/textos.es.json (academia_*).
const Texts = preload("res://scripts/texts.gd")
const Photo = preload("res://scripts/photography.gd")
const Diagram = preload("res://scripts/academy_diagram.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
var progress_path = OS.get_environment("PAPARAZZI_ACADEMY_CFG") if OS.has_environment("PAPARAZZI_ACADEMY_CFG") else "user://academia.cfg"   # tests and capture tools point it elsewhere
# The lessons in the order they are taught. Each has an id: the code, the texts
# (academia_<id>_…) and the progress file go by id, so the order can change without touching them.
# Rule of the order (user, 04-10-2026): no lesson talks about, asks for or examines anything that
# an earlier one has not taught.
const ORDER = ["composicion","enfoque","focal","exposicion","dof","movimiento","medicion","modos","objetivos","camaras"]
const LESSONS = 10
# The order before the ids, to read old progress files (sections leccion_<number>).
const OLD_NUMBERS = {1:"exposicion",2:"dof",3:"movimiento",4:"composicion",5:"focal",6:"objetivos",7:"camaras",8:"enfoque",9:"medicion",10:"modos"}
var kind = ""               # id of the lesson in hand
const PHASES = ["teoria","demo","practica"]
const SAVED = ["teoria","demo","practica","examen"]   # what the progress file keeps

# Good light by default (user, 03-10-2026): day, with some cloud where a slow shutter would burn
# the photo in full sun (half cover) and overcast where f/1.8 has to be usable (dof); another light only when the light is the lesson (1: the golden
# hour for the exposure, 6: the blue hour for the fast lens).
# Per lesson: equipment and light, the diagram of each theory page and the practice setup.
# body/lens index into Equipment.LENSES; lens 3/4/5 of the réflex are the Academy primes.
const SETUP = {
	"composicion": {"time":"day","body":2,"lens":2,"focal":50.0,"auto":true,"focus":"AF puntual","angle":122.0,"pitch":-3.0,
		"pages":["","tercios","tercios","tercios","tercios"],"practice_diagram":"tercios"},
	"enfoque": {"time":"day","body":2,"lens":2,"focal":50.0,"auto":true,"focus":"AF puntual","angle":125.0,"pitch":-3.0,
		"pages":["","","",""],"practice_diagram":""},
	# 53°: clear of the benches (35°, 125°…) and of the lamp posts (8° and 98° at 2.6 m, 38° and 68°
	# at 8.6 m). Through the telephoto, someone sitting on a bench or a post filled the frame. The
	# near subject stands 18° to the side: at 12° its hat still showed in the telephoto frame.
	"focal": {"time":"day","body":2,"lens":3,"focal":28.0,"auto":true,"focus":"AF puntual","angle":53.0,"pitch":-4.0,
		"pages":["compresion","compresion","compresion","compresion"],"practice_diagram":"compresion","page_do":["lens_wide","lens_wide","lens_tele","lens_tele"]},
	"exposicion": {"time":"golden","body":2,"lens":0,"focal":50.0,"auto":false,"focus":"AF puntual","angle":125.0,"pitch":-3.0,"n":4.0,
		"pages":["triangulo","pasos_n","pasos_t","pasos_iso","pasos","pasos"],"practice_diagram":"pasos"},
	# Aperture priority: the lesson is the aperture, the camera keeps the light right.
	"dof": {"time":"day","cover":1.0,"body":2,"lens":4,"focal":105.0,"auto":true,"mode":"A","focus":"AF puntual","angle":118.0,"pitch":-2.0,"n":1.8,
		"pages":["dof","dof","dof","dof"],"practice_diagram":"dof"},
	# Shutter priority, and the camera keeps the runner in focus: the lesson is the shutter speed.
	"movimiento": {"time":"day","cover":0.5,"body":2,"lens":0,"focal":50.0,"auto":true,"mode":"S","focus":"AF puntual","angle":70.0,"pitch":-4.0,"t":250,
		"pages":["movimiento","movimiento","movimiento","pasos","movimiento"],"practice_diagram":"movimiento"},
	# (f/8: wide open in full sun even 1/1000 s burns the photo, and that is not this lesson.)
	"medicion": {"time":"day","body":2,"lens":2,"focal":50.0,"auto":true,"mode":"A","focus":"AF puntual","angle":125.0,"pitch":-3.0,"n":8.0,
		"pages":["","","","",""],"practice_diagram":"","page_do":["meter:matricial","meter:matricial","meter:ponderada","meter:puntual","noche"]},
	"modos": {"time":"day","cover":0.7,"body":2,"lens":2,"focal":50.0,"auto":true,"mode":"P","focus":"AF puntual","angle":125.0,"pitch":-3.0,
		"pages":["","","","",""],"practice_diagram":"","page_do":["mode:P","mode:P","mode:A","mode:S","mode:M"]},
	"objetivos": {"time":"blue","body":2,"lens":0,"focal":50.0,"auto":false,"focus":"AF puntual","angle":125.0,"pitch":-3.0,"n":4.0,"iso":100,
		"pages":["","","",""],"practice_diagram":"","page_do":["lens:0:24","lens:0:105","lens:2:50","lens:2:50"]},
	"camaras": {"time":"day","body":0,"lens":0,"focal":35.0,"auto":true,"focus":"AF matricial","angle":125.0,"pitch":-3.0,
		"pages":["","","","","",""],"practice_diagram":"","page_do":["body:0","body:0","body:1","body:2","body:3","body:0"]},
}
const THEORY_PAGES = {"composicion":5, "enfoque":4, "focal":4, "exposicion":6, "dof":4, "movimiento":5, "medicion":5, "modos":5, "objetivos":4, "camaras":6}
# Lessons whose practice and exam put choices on the panel (lenses, bodies, metering, modes).
const CHOICES = {
	"focal": [["academia_op_28","lens:3:28"],["academia_op_135","lens:5:135"]],
	"camaras": [["academia_op_compacta","body:0"],["academia_op_telemetrica","body:1"],["academia_op_reflex","body:2"],["academia_op_tlr","body:3"]],
	"objetivos": [["academia_op_zoom","lens:0:50"],["academia_op_fijo","lens:2:50"]],
	"medicion": [["academia_op_matricial","meter:matricial"],["academia_op_centro","meter:ponderada"],["academia_op_puntual","meter:puntual"]],
	"modos": [["academia_op_p","mode:P"],["academia_op_a","mode:A"],["academia_op_s","mode:S"],["academia_op_m","mode:M"]],
}
# What each exam looks at besides its own subject: only what its lesson, or an earlier one, taught.
const EXAM_ASKS = {
	"composicion": [], "enfoque": [], "focal": ["nitido"], "exposicion": ["expo"], "dof": [], "movimiento": ["pulso"],
	"medicion": ["nitido","persona"], "modos": ["expo","nitido","persona"],
	"objetivos": ["expo","pulso"], "camaras": ["nitido","persona"],
}
# The dials move in whole stops, so anything under one stop off counts as right (user, 04-10-2026).
const HALF_STOP = .9999
# The demonstrations run at half speed: every caption stays twice as long (user, 04-10-2026).
const DEMO_PACE = .5
var swing_timer = 0.0       # depth of field theory: the aperture opens and closes by itself
var locked_person = null    # lesson 8: who the focus was locked on
var page_applied = ""
const TASKS = 3
# Exam (docs/futuro/06 §2 and §3): one statement per lesson, no hints; every photo gets the tutor's
# report and the exam is passed when all its criteria are met. Passing the five gives the diploma.
var exam_attempts = 0
var exam_last = {}          # report of the last exam photo
var second = null           # second staged person (exam of lesson 2)

var main
var active = false
var lesson = 0
var phase = "teoria"
var page = 0
var paused = false
var progress = {}
# Demonstration timeline
var demo_time = 0.0
var demo_steps: Array = []
var demo_next = 0
var demo_photos: Array = []
var demo_pending_label = ""
var demo_done = false
var frame_goal = {}         # {"who": Pedestrian, "x":…, "y":…}: keep a head at a screen fraction
var waiting_runner = null   # caption of a demo shot waiting for the runner to reach the centre
var waiting_time = 0.0
var waiting_subject = null  # caption of a demo shot waiting for the framing on the subject
var subject = null          # staged person of the lesson
var runner = null           # staged runner (lesson 3)
# Practice
var tasks: Array = [false,false,false]
var practice_photos: Array = []
var hint = ""
var hint_timer = 0.0
var practice_done_shown = false
var highlight = ""
var subtitle = ""
var pulse = 0.0
# Guided tour for the video (--academy-tour=<seconds>:<pages>): a few theory pages, the demo, the practice.
var tour_seconds = 0.0
var tour_pages = 0
var tour_timer = 0.0
# UI
var panel: Panel
var header: Label
var title_label: Label
var body_label: Label
var body_rich: Control      # the same text with its keys drawn as keycaps (theory and exam)
var diagram
var task_labels: Array = []
var hint_label: Label
var back_button: Button
var next_button: Button
var pause_button: Button
var exit_button: Button
var extra_buttons: Array = []
var subtitle_panel: Panel
var subtitle_label: Label
var thumbs: Control

func _init(owner_main) -> void:
	main = owner_main

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	load_progress()
	build_ui()

# ---- Progress (user://academia.cfg) ----
func load_progress() -> void:
	progress = {}
	var config = ConfigFile.new()
	if config.load(progress_path) != OK: return
	for id in ORDER:
		for ph in SAVED:
			if config.get_value("leccion_"+id,ph,false): progress["%s_%s" % [id,ph]] = true
	# A file from before the ids (sections by number, in the order of then).
	for number in OLD_NUMBERS:
		for ph in SAVED:
			if config.get_value("leccion_%d" % number,ph,false): progress["%s_%s" % [OLD_NUMBERS[number],ph]] = true

func save_progress() -> void:
	var config = ConfigFile.new()
	for key in progress:
		var parts = str(key).split("_")
		config.set_value("leccion_"+parts[0],parts[1],true)
	config.save(progress_path)

func mark(n: int, ph: String) -> void:
	var key = "%s_%s" % [ORDER[n-1],ph]
	if progress.get(key,false): return
	progress[key] = true
	save_progress()

func done(n: int, ph: String) -> bool:
	return progress.get("%s_%s" % [ORDER[n-1],ph],false)

# A text of lesson n (the menu asks for titles and summaries).
func lesson_key(n: int, suffix: String) -> String:
	return "academia_%s_%s" % [ORDER[n-1],suffix]

func reset_progress() -> void:
	progress = {}
	save_progress()

func practices_done() -> int:
	var count = 0
	for n in range(1,LESSONS+1): if done(n,"practica"): count += 1
	return count

# ---- UI ----
func style(color: Color, radius = 8, border = Color.TRANSPARENT) -> StyleBoxFlat:
	color = UiStyle.panel_color(color) if UiStyle.lum(color) < .5 else color
	border = UiStyle.LINE if border.a > 0 else border
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(1)
	box.border_color = border
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func make_label(parent: Control, rect: Rect2, size: int, color: Color, wrap = false) -> Label:
	var node = Label.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",UiStyle.text_color(color))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func make_button(parent: Control, text_value: String, rect: Rect2, callback: Callable, primary = false) -> Button:
	var node = Button.new()
	node.text = text_value
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",14)
	if primary: UiStyle.primary(node)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

const PANEL_RECT = Rect2(900,170,365,452)

func build_ui() -> void:
	panel = Panel.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.add_theme_stylebox_override("panel",style(Color(.03,.05,.038,.9),10,Color("425044")))
	add_child(panel)
	header = make_label(panel,Rect2(16,10,335,20),12,Color("a7c683"))
	title_label = make_label(panel,Rect2(16,30,335,30),21,Color("e6ebdb"),true)
	body_label = make_label(panel,Rect2(16,64,335,150),15,Color("c9d4bf"),true)
	body_rich = preload("res://scripts/glyph_label.gd").new()
	body_rich.position = Vector2(16,64)
	body_rich.size = Vector2(335,150)
	body_rich.font_size = 14
	body_rich.color = UiStyle.INK
	panel.add_child(body_rich)
	diagram = Diagram.new()
	diagram.academy = self
	diagram.position = Vector2(12,218)
	diagram.size = Vector2(341,128)
	panel.add_child(diagram)
	for k in TASKS:
		task_labels.append(make_label(panel,Rect2(16,150+k*38,335,36),14,Color("c9d4bf"),true))
	hint_label = make_label(panel,Rect2(16,262,335,80),14,Color("f0d58c"),true)
	thumbs = Control.new()
	thumbs.position = Vector2(12,218)
	thumbs.size = Vector2(341,128)
	thumbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(thumbs)
	pause_button = make_button(panel,Texts.get_text("academia_pausar"),Rect2(12,352,168,32),toggle_pause)
	exit_button = make_button(panel,Texts.get_text("academia_salir"),Rect2(186,352,167,32),exit_lesson)
	back_button = make_button(panel,Texts.get_text("academia_atras"),Rect2(12,394,120,46),go_back)
	next_button = make_button(panel,Texts.get_text("academia_siguiente"),Rect2(138,394,215,46),go_next,true)
	subtitle_panel = Panel.new()
	subtitle_panel.position = Vector2(40,536)   # clear of the LED strip under the SLR finder
	subtitle_panel.size = Vector2(840,58)
	subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_panel.add_theme_stylebox_override("panel",UiStyle.box(Color(UiStyle.SKY.r,UiStyle.SKY.g,UiStyle.SKY.b,.94),12,Color.WHITE,2))
	add_child(subtitle_panel)
	subtitle_label = make_label(subtitle_panel,Rect2(14,6,812,46),20,Color.WHITE,true)
	subtitle_label.add_theme_color_override("font_color",Color.WHITE)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func text(key: String) -> String:
	return Texts.get_text(key)

func lesson_text(suffix: String) -> String:
	return Texts.get_text("academia_%s_%s" % [kind,suffix])

# ---- Lesson lifecycle ----
func begin(n: int, start_phase = "teoria") -> void:
	lesson = n
	kind = ORDER[n-1]
	active = true
	visible = true
	paused = false
	var s: Dictionary = SETUP[kind]
	main.start_session(s.time,true)
	main.park.clouds_enabled = false
	main.park.forced_cover = s.get("cover",-1.0)
	main.park.update_weather(0)
	main.toast.text = ""
	apply_setup()
	main.briefing.text = "%s %d · %s" % [text("academia"),n,lesson_text("titulo")]
	main.sandbox_button.visible = false
	set_phase(start_phase)

func apply_setup() -> void:
	var s: Dictionary = SETUP[kind]
	main.equipment.film = false
	main.equipment.body = s.body
	main.equipment.lens_index = s.lens
	main.equipment.auto_exposure = s.auto
	main.equipment.focus_mode = s.focus
	main.equipment.ev_comp_index = 6
	if s.has("mode"): main.equipment.set_exposure_mode(s.mode)
	else: main.equipment.priority = ""
	main.equipment.metering = "puntual"
	main.apply_equipment()
	if s.has("iso"): main.iso_index = Photo.ISOS.find(int(s.iso))
	page_applied = ""
	main.finder.active = 4
	if main.time_of_day != s.time: main.preview_time(s.time)
	main.focal = s.focal
	main.angle = s.angle
	main.pitch = s.pitch
	main.finder.thirds = kind == "composicion" and phase != "practica"
	if phase == "examen": main.park.forced_cover = SETUP[kind].get("cover",-1.0)
	main.update_camera()
	main.update_meter()
	if s.has("n"):
		var stops = main.apertures()
		var best = 0
		for i in stops.size(): if absf(stops[i]-s.n) < absf(stops[best]-s.n): best = i
		main.n_index = best
	if s.has("t"): main.t_index = Photo.DENOMINATORS.find(int(s.t))
	if s.auto: main.auto_expose()
	elif s.has("n"): expose_with_shutter()
	elif s.has("t"): set_shutter(s.t)
	else: expose_correctly()
	main.refresh()

# Correct exposure for what the active point measures (as a helpful assistant would set it).
func expose_correctly() -> void:
	main.update_meter()
	main.expose_for(main.measured_ev)
	main.refresh()

func set_phase(ph: String) -> void:
	phase = ph
	page = 0
	subtitle = ""
	highlight = ""
	hint = ""
	frame_goal = {}
	clear_thumbs()
	set_scene_pause(false)
	match ph:
		"teoria":
			apply_setup()
			stage_subject()
		"demo":
			apply_setup()
			start_demo()
		"practica":
			apply_setup()
			start_practice()
		"examen":
			apply_setup()
			start_exam()
	update_panel()

func exit_lesson() -> void:
	stop()
	main.show_academy()

# Leave the lesson state (the scene keeps running for whatever screen comes next).
func stop() -> void:
	active = false
	visible = false
	main.park.forced_cover = -1.0
	release_staged()
	for q in main.people: q.set_hidden(false)
	frame_goal = {}
	highlight = ""
	subtitle = ""
	set_scene_pause(false)
	main.finder.thirds = false
	for b in extra_buttons: b.queue_free()
	extra_buttons = []

# Academy actions in the InputMap (docs/futuro/14 §2): next, back, pause the scene.
static func register_actions() -> void:
	var keys = {"academia_siguiente":[KEY_ENTER,KEY_KP_ENTER],"academia_atras":[KEY_BACKSPACE],"academia_pausa":[KEY_P]}
	for action in keys:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		for code in keys[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action,ev)
		var pad = InputEventJoypadButton.new()
		pad.button_index = {"academia_siguiente":JOY_BUTTON_A,"academia_atras":JOY_BUTTON_B,"academia_pausa":JOY_BUTTON_START}[action]
		InputMap.action_add_event(action,pad)

func toggle_pause() -> void:
	set_scene_pause(not paused)
	update_panel()

func set_scene_pause(value: bool) -> void:
	paused = value
	main.set_sandbox_pause(value)

func go_next() -> void:
	match phase:
		"teoria":
			if page < THEORY_PAGES[kind]-1:
				page += 1
				highlight = theory_highlight()
				if page == THEORY_PAGES[kind]-1: mark(lesson,"teoria")
				update_panel()
			else:
				mark(lesson,"teoria")
				set_phase("demo")
		"demo":
			if demo_done: set_phase("practica")
			else: set_phase("practica")
		"practica": set_phase("examen")
		"examen":
			if lesson < LESSONS and done(lesson,"examen"): begin(lesson+1)
			else: exit_lesson()

func go_back() -> void:
	match phase:
		"teoria":
			if page > 0:
				page -= 1
				highlight = theory_highlight()
				update_panel()
		"demo": set_phase("teoria")
		"practica": set_phase("demo")
		"examen": set_phase("practica")

# Which HUD control each theory page points at.
func theory_highlight() -> String:
	match kind:
		"exposicion": return ["exposimetro","diafragma","velocidad","iso","",""][page]
		"dof": return ["nitidez","diafragma","zoom","nitidez"][page]
		"movimiento": return ["velocidad","","velocidad","diafragma","velocidad"][page]
		"objetivos": return ["zoom","zoom","diafragma","velocidad"][page]
		"modos": return ["","","diafragma","velocidad","exposimetro"][page]
	return ""

func update_panel() -> void:
	if not active: return
	var phase_name = text("academia_fase_"+phase)
	pause_button.text = text("academia_reanudar") if paused else text("academia_pausar")
	back_button.disabled = phase == "teoria" and page == 0
	body_rich.visible = phase in ["teoria","examen"]
	body_label.visible = not body_rich.visible
	for l in task_labels: l.visible = false
	hint_label.visible = false
	diagram.visible = false
	thumbs.visible = false
	subtitle_panel.visible = false
	match phase:
		"teoria":
			var total = THEORY_PAGES[kind]
			header.text = text("academia_pagina") % ["%s %d · %s" % [text("academia"),lesson,phase_name],page+1,total]
			title_label.text = lesson_text("t%d_titulo" % (page+1))
			body_rich.set_rich(Texts.get_rich("academia_%s_t%d_texto" % [kind,page+1]))
			diagram.kind = SETUP[kind].pages[page]
			diagram.visible = diagram.kind != ""
			# What this page puts in the player's hands (a body, a lens, a mode), once per page.
			var page_key = "%d:%d" % [lesson,page]
			if SETUP[kind].has("page_do") and page_applied != page_key:
				page_applied = page_key
				if main.time_of_day != SETUP[kind].time: main.preview_time(SETUP[kind].time)
				do_action(SETUP[kind].page_do[page],true)
			next_button.text = text("academia_siguiente") if page < total-1 else text("academia_ir_demo")
			highlight = theory_highlight()
		"demo":
			header.text = "%s %d · %s" % [text("academia"),lesson,phase_name]
			title_label.text = lesson_text("titulo")
			body_label.text = text("academia_demo_en_curso")
			body_label.size.y = 60
			thumbs.visible = not demo_photos.is_empty()
			diagram.kind = SETUP[kind].practice_diagram
			diagram.visible = demo_photos.is_empty() and diagram.kind != ""
			subtitle_panel.visible = subtitle != ""
			subtitle_label.text = subtitle
			next_button.text = text("academia_ir_practica")
			# While the tutor drives, the way on waits dimmed; it lights up when the demo is over.
			next_button.modulate = Color(1,1,1,1.0 if demo_done else .45)
		"practica":
			header.text = "%s %d · %s" % [text("academia"),lesson,phase_name]
			title_label.text = lesson_text("titulo")
			var intro = lesson_text("intro")
			if intro == "academia_%s_intro" % kind: intro = text("academia_practica_intro")
			body_label.text = text("academia_practica_superada") if tasks.all(func(t): return t) else intro
			body_label.size.y = 60
			for k in TASKS:
				var l: Label = task_labels[k]
				l.visible = true
				l.position.y = 122+k*42
				l.text = "%s  %s" % [text("academia_hecho") if tasks[k] else text("academia_pendiente"),lesson_text("p%d" % (k+1))]
				l.add_theme_color_override("font_color",UiStyle.SKY_DEEP if tasks[k] else UiStyle.INK)
			hint_label.visible = hint != ""
			hint_label.text = hint
			hint_label.position.y = 252
			next_button.text = text("academia_ir_examen")
		"examen":
			header.text = "%s %d · %s" % [text("academia"),lesson,phase_name]
			title_label.text = lesson_text("titulo")
			body_rich.set_rich(Texts.get_rich("academia_%s_examen" % kind))
			hint_label.visible = true
			hint_label.position.y = 252
			if done(lesson,"examen"): hint_label.text = text("academia_examen_superado")
			elif exam_attempts == 0: hint_label.text = model_line() if model_line() != "" else text("academia_examen_intro")
			else: hint_label.text = text("academia_examen_intentos") % exam_attempts
			next_button.text = text("academia_siguiente") if lesson < LESSONS and done(lesson,"examen") else text("academia_volver_menu")
	if phase != "demo": next_button.modulate = Color.WHITE
	for b in extra_buttons: b.visible = phase in ["practica","examen"]

func clear_thumbs() -> void:
	demo_photos.clear()
	for c in thumbs.get_children(): c.queue_free()

# ---- Staging: the people each lesson needs, in front of the camera ----
# People placed by an earlier staging go back to their normal routine.
func release_staged() -> void:
	for q in main.people:
		if not q.has_meta("staged"): continue
		q.remove_meta("staged")
		q.set_hidden(false)
		if q.state == "DETENIDO" and q.state_time > 1000.0: q.state_time = 0.0

func stage_subject() -> void:
	release_staged()
	subject = null
	runner = null
	# The inner path (r ≈ 1.8 m) crosses right in front of the lens: its walkers step out of the
	# lessons, except anyone a lesson places there on purpose.
	for q in main.people:
		if q.lane == 0 and q.state != "SENTADO": q.set_hidden(true)
	main.clear_sector([1,2],[],35.0,true)
	match kind:
		"dof": subject = stand_person(1,SETUP["dof"].angle,4.0)
		"movimiento": runner = stage_runner()
		"composicion": subject = walk_person(1,SETUP["composicion"].angle+16.0,-1.0)
		"focal": subject = stand_person(0,SETUP["focal"].angle-18.0,2.3)
		"enfoque", "exposicion", "medicion", "modos", "objetivos", "camaras": subject = stand_person(1,SETUP[kind].angle,4.0)
		_: subject = null

# like: someone of about the same height as that person (the two of the exam of lesson 2 have to
# fit in one frame).
func stand_person(lane: int, theta: float, radius: float, like = null):
	var fits = func(q): return like == null or absf(q.height-like.height) < .12
	var p = main.pick(func(q): return q.lane == lane and not q.runner and fits.call(q))
	if p == null: p = main.pick(func(q): return not q.runner and fits.call(q))
	if p == null: p = main.pick(func(q): return not q.runner)   # anyone free walking elsewhere
	if p == null: return null
	main.clear_sector([0,1,2,3].slice(0,lane+1),[p],30.0,true)
	main.reset_walker(p,lane,theta,1.0)
	p.set_hidden(false)
	p.set_meta("staged",true)
	p.radius = radius
	p.state = "DETENIDO"
	p.state_time = 9999.0
	p.activity = "movil" if kind != "focal" else "mirar"
	p.face_target = PI-deg_to_rad(theta)+.35
	p.place()
	return p

func walk_person(lane: int, theta: float, direction: float):
	var p = main.pick(func(q): return q.lane == lane and not q.runner)
	if p == null: p = main.pick(func(q): return not q.runner)
	if p == null: return null
	main.clear_sector([lane],[p],40.0)
	main.reset_walker(p,lane,theta,direction)
	p.visible = true
	p.speed = .6
	p.set_meta("staged",true)   # no bench, no stops: it keeps walking across the frame
	return p

func stage_runner():
	var r = main.pick(func(q): return q.runner)
	if r == null: return null
	main.clear_sector([2],[r],30.0)
	main.reset_walker(r,2,SETUP["movimiento"].angle-32.0,1.0)
	r.set_hidden(false)
	return r

# Lesson 3: the runner comes round again every few seconds (it reappears out of view behind).
func loop_runner() -> void:
	if runner == null or runner.state != "CAMINANDO": return
	var off = rad_to_deg(angle_difference(deg_to_rad(main.angle),deg_to_rad(runner.theta)))*runner.direction
	if off > 32.0:
		main.reset_walker(runner,2,main.angle-32.0*runner.direction,runner.direction)

# ---- Demonstration ----
# Each step: time (s), subtitle index (or -1), action.
func start_demo() -> void:
	demo_time = 0.0
	waiting_runner = null
	waiting_subject = null
	demo_next = 0
	demo_done = false
	demo_steps = []
	stage_subject()
	match kind:
		"exposicion": demo_steps = [
			[0.5,1,"expose"],[1.0,-1,"hl:exposimetro"],
			[3.5,2,"hl:diafragma"],[4.2,-1,"n:+1"],[4.9,-1,"n:+1"],
			[6.2,3,"hl:exposimetro"],
			[9.0,4,"hl:velocidad"],[9.7,-1,"t:+1"],[10.4,-1,"t:+1"],
			[12.0,5,"hl:exposimetro"],
			[14.5,6,"hl:iso"],[15.2,-1,"iso:+1"],[15.9,-1,"iso:+1"],
			[17.5,7,"hl:diafragma"],[18.2,-1,"n:+1"],[18.9,-1,"n:+1"],
			[20.5,8,"hl:disparar"],[21.5,-1,"shoot:f"],
			[25.0,-1,"end"]]
		"dof": demo_steps = [
			[0.3,1,"look_subject"],[1.5,-1,"af"],[2.0,-1,"n:min"],
			[4.0,2,"hl:nitidez"],
			[7.0,3,""],[9.0,-1,"shoot:f/1.8"],
			[11.5,4,"hl:diafragma"],[12.0,-1,"nc:+1"],[12.6,-1,"nc:+1"],[13.2,-1,"nc:+1"],[13.8,-1,"nc:+1"],[14.4,-1,"nc:+1"],[15.0,-1,"nc:+1"],
			[16.0,5,"hl:nitidez"],
			[19.0,6,""],[20.0,-1,"shoot:f/11"],
			[24.0,-1,"end"]]
		"movimiento": demo_steps = [
			[0.3,1,"hl:velocidad"],[0.8,-1,"t_set:30"],
			[3.3,2,"shoot_runner:1/30"],
			[7.5,3,"hl:velocidad"],[8.0,-1,"t_set:1000"],
			[11.3,4,"shoot_runner:1/1000"],
			[15.5,5,"hl:velocidad"],
			[19.5,-1,"end"]]
		"composicion": demo_steps = [
			[0.3,1,"thirds"],
			[2.5,2,"frame:0.5:0.42"],
			[5.5,3,""],
			[8.0,4,"frame_lead"],
			[11.0,5,"frame_lead_eyes"],[13.5,-1,"shoot:tercios"],
			[17.0,-1,"end"]]
		"focal": demo_steps = [
			[0.1,-1,"freeze"],[0.3,1,"frame:0.5:0.35"],
			[3.5,2,"shoot:28 mm"],
			[7.5,3,"lens_tele"],
			[11.0,4,"shoot:135 mm"],
			[14.5,5,""],
			[19.0,-1,"end"]]
		"camaras": demo_steps = [
			[0.3,1,"body:0"],
			[4.0,2,"body:1"],
			[8.0,3,"body:2"],
			[12.0,4,"body:3"],
			[16.0,5,""],[16.5,-1,"shoot:TLR 6×6"],
			[20.5,-1,"end"]]
		"objetivos": demo_steps = [
			[0.3,1,"lens:0:50"],[0.9,-1,"n:min"],
			[4.5,2,""],[5.0,-1,"shoot:Zoom · f/4"],
			[9.0,3,"lens:2:50"],[9.6,-1,"n:min"],
			[13.0,4,""],[13.5,-1,"shoot:Fijo · f/1,8"],
			[17.5,5,""],
			[20.5,-1,"end"]]
		"enfoque": demo_steps = [
			[0.3,1,"look_subject"],[2.0,-1,"af"],
			[4.0,2,"lock"],
			[6.0,3,"frame:0.3:0.42"],
			[9.5,4,""],[10.0,-1,"shoot_now:Reencuadrada"],
			[14.0,5,""],
			[17.0,-1,"end"]]
		"medicion": demo_steps = [
			[0.3,1,"look_subject"],[0.6,-1,"meter:matricial"],
			[4.0,2,"meter:ponderada"],
			[7.5,3,"meter:puntual"],
			[11.0,4,"comp:+3"],
			[14.0,5,"comp:-3"],[15.0,-1,"shoot:Puntual"],
			[19.0,-1,"end"]]
		"modos": demo_steps = [
			[0.3,1,"look_subject"],[0.5,-1,"mode:P"],
			[4.0,2,"mode:A"],[4.4,-1,"hl:diafragma"],[4.8,-1,"n:-1"],[5.4,-1,"n:-1"],
			[8.0,3,"mode:S"],[8.4,-1,"hl:velocidad"],[8.8,-1,"t:+1"],[9.4,-1,"t:+1"],
			[12.0,4,"mode:M"],[12.4,-1,"hl:exposimetro"],
			[15.5,5,"expose_m"],[16.5,-1,"shoot:Modo M"],
			[20.5,-1,"end"]]
	update_panel()

func run_demo(dt: float) -> void:
	if paused and kind == "movimiento": return
	if waiting_runner != null:
		waiting_time += dt
		var off = 99.0
		if runner: off = rad_to_deg(angle_difference(deg_to_rad(main.angle),deg_to_rad(runner.theta)))
		# Shoot the moment one of the central AF points actually lands on the runner (AF puntual on
		# that point), as a photographer pressing at the right instant would.
		# (A child is narrower: the three probes of the AF point must still fit on the body.)
		var on_runner = point_on(runner,9.0 if runner.is_child() else 16.0) if runner and absf(off) < 6.0 else -1
		if on_runner >= 0 or waiting_time > 8.0:
			if on_runner >= 0: main.finder.active = on_runner
			demo_shoot(waiting_runner)
			waiting_runner = null
		return
	if waiting_subject != null:
		# A shot of the staged subject: wait until the framing has settled on it.
		waiting_time += dt
		var point = point_on(subject,6.0) if subject else -1
		if (point >= 0 and waiting_time > .4) or waiting_time > 4.0:
			if point >= 0: main.finder.active = point
			demo_shoot(waiting_subject)
			waiting_subject = null
		return
	demo_time += dt*DEMO_PACE
	while demo_next < demo_steps.size() and demo_time >= demo_steps[demo_next][0]:
		var step: Array = demo_steps[demo_next]
		demo_next += 1
		if step[1] > 0:
			subtitle = lesson_text("d%d" % step[1])
			update_panel()
		do_action(str(step[2]))

func do_action(action: String, _from_page = false) -> void:
	if action == "": return
	var parts = action.split(":")
	match parts[0]:
		"hl": highlight = parts[1]
		"expose": apply_setup()
		"n": step_parameter("n",int(parts[1]))
		"t": step_parameter("t",int(parts[1]))
		"iso": step_parameter("iso",int(parts[1]))
		"nc":
			# Close one stop and keep the exposure with the shutter (one stop slower).
			step_parameter("n",int(parts[1]))
			step_parameter("t",int(parts[1]))
		"af": main.autofocus()
		"body": set_body(int(parts[1]),phase != "practica" and phase != "examen")
		"lens":
			set_lens(int(parts[1]),float(parts[2]))
			if kind == "objetivos" and phase != "practica" and phase != "examen":
				# Wide open at ISO 100: the shutter speed tells the story of the lens.
				main.iso_index = Photo.ISOS.find(100)
				main.n_index = 0
				expose_with_shutter()
		"mode":
			main.equipment.set_exposure_mode(parts[1])
			main.release_lock()
			main.update_meter()
			if main.equipment.auto_exposure: main.auto_expose()
		"meter":
			main.equipment.metering = parts[1]
			main.release_lock()
			main.update_meter()
			if main.equipment.auto_exposure: main.auto_expose()
		"comp":
			for i in absi(int(parts[1])): main.change_parameter("ev_comp",signi(int(parts[1])))
		"lock":
			if not main.focus_locked: main.toggle_lock()
		"expose_m": expose_correctly()
		"shoot_now": demo_shoot(parts[1] if parts.size() > 1 else "")
		"look_subject":
			if subject: frame_goal = {"who":subject,"x":.5,"y":.45}
		"thirds": main.finder.thirds = true
		"frame":
			var who = subject if subject else null
			if who: frame_goal = {"who":who,"x":float(parts[1]),"y":float(parts[2])}
		"frame_lead":
			if subject: frame_goal = {"who":subject,"x":lead_x(subject),"y":.45,"lead":true}
		"frame_lead_eyes":
			if subject: frame_goal = {"who":subject,"x":lead_x(subject),"y":1.0/3.0,"lead":true}
		"t_set":
			set_shutter(int(parts[1]))
		"noche":
			# When to overrule the meter: a night scene, compensated down so it stays dark.
			main.preview_time("night")
			main.equipment.metering = "matricial"
			main.equipment.ev_comp_index = 6
			main.update_meter()
			for i in 4: main.change_parameter("ev_comp",-1)
		"lens_wide":
			# Back to the wide angle on someone close (theory pages of the focal lesson).
			set_scene_pause(false)
			stage_subject()
			set_lens(3,28.0)
			set_scene_pause(true)
			frame_goal = {"who":subject,"x":.5,"y":.35,"snap":true} if subject else {}
		"lens_tele":
			main.equipment.lens_index = 5
			main.apply_equipment()
			main.focal = 135.0
			if subject: subject.set_hidden(true)
			set_scene_pause(false)
			subject = stand_person(3,SETUP["focal"].angle,11.6)
			main.clear_sector([0,1,2],[subject],40.0,true)
			set_scene_pause(true)
			frame_goal = {"who":subject,"x":.5,"y":.5,"snap":true} if subject else {}
			main.refresh()
		"freeze":
			# A lesson about perspective, not motion: nobody crosses the line of sight.
			main.clear_sector([1,2,3],[subject],40.0,true)
			set_scene_pause(true)
		"shoot":
			if subject and kind != "exposicion":
				waiting_subject = parts[1] if parts.size() > 1 else ""
				waiting_time = 0.0
			else: demo_shoot(parts[1] if parts.size() > 1 else "")
		"shoot_runner":
			# Hold the timeline until the runner crosses the centre of the frame, then shoot.
			waiting_runner = parts[1] if parts.size() > 1 else ""
			waiting_time = 0.0
			if runner:
				main.clear_sector([1,2],[runner],45.0,true)   # a clear run: nobody slows it down
				main.reset_walker(runner,2,main.angle-25.0,1.0)
		"end":
			if kind == "focal": set_scene_pause(false)
			demo_done = true
			highlight = ""
			mark(lesson,"demo")
			subtitle = ""
			update_panel()
	if action.begins_with("n:min"):
		main.n_index = 0
		if main.equipment.auto_exposure: main.auto_expose()
		else: expose_with_shutter()
	main.refresh()

# The AF point (centre first) whose ray lands on `who` with some margin on both sides, or -1.
func point_on(who, margin: float) -> int:
	for i in [4,1,7,3,5,0,2,6,8]:
		var ok = true
		for dx in [-margin,0.0,margin]:
			var hit = main.point_hit(main.finder.points()[i]+Vector2(dx,0))
			if hit.is_empty() or not hit.collider.has_meta("person") or hit.collider.get_meta("person") != who:
				ok = false
				break
		if ok: return i
	return -1

func lead_x(p) -> float:
	# Going (or facing) to the left of the frame → place on the right third, and vice versa.
	return 2.0/3.0 if facing_side(p) < 0 else 1.0/3.0

# Which way a person goes across the frame (−1 left, +1 right, 0 towards or away from the camera):
# by its movement or, standing still, by where it faces.
func facing_side(p) -> float:
	var across = p.actual_velocity.dot(main.camera.global_basis.x)
	if absf(across) <= .05: across = (-p.global_basis.z).dot(main.camera.global_basis.x)*.5
	return signf(across) if absf(across) > .05 else 0.0

func step_parameter(parameter: String, amount: int) -> void:
	for i in absi(amount): main.change_parameter(parameter,signi(amount))

# Shutter to 1/denominator, keeping exposure with aperture first, then ISO.
func set_shutter(denominator: int) -> void:
	var index = Photo.DENOMINATORS.find(denominator)
	if index < 0: return
	main.t_index = index
	main.update_meter()
	if main.equipment.auto_exposure:
		# Shutter priority: the camera sets the rest.
		main.auto_expose()
		main.refresh()
		return
	var best = INF
	var stops = main.apertures()
	for n in stops.size():
		for iso in Photo.ISOS.size():
			var delta = absf(Photo.ev(stops[n],1.0/denominator,Photo.ISOS[iso],main.measured_ev))
			var cost = delta*10+iso*.2+(stops.size()-n)*.01
			if cost < best:
				best = cost
				main.n_index = n
				main.iso_index = iso
	main.refresh()

# Keep the aperture, fix the exposure with the shutter.
func expose_with_shutter() -> void:
	main.update_meter()
	var best = INF
	for t in Photo.DENOMINATORS.size():
		var delta = absf(Photo.ev(main.apertures()[main.n_index],1.0/Photo.DENOMINATORS[t],Photo.ISOS[main.iso_index],main.measured_ev))
		if delta < best:
			best = delta
			main.t_index = t
	main.refresh()

func demo_shoot(caption: String) -> void:
	demo_pending_label = caption
	main.academy_demo_shot = true
	main.take_photo()

# main.gd hands the developed photo of a demo shot back here (no result screen).
func on_demo_photo(texture, result: Dictionary) -> void:
	demo_photos.append({"texture":texture,"result":result,"label":demo_pending_label})
	var count = demo_photos.size()
	for c in thumbs.get_children(): c.queue_free()
	var w = 341.0/count-6 if count > 1 else 220.0
	for i in count:
		var shot: Dictionary = demo_photos[i]
		var rect = Rect2(i*(w+6)+(0 if count > 1 else 60),0,w,w*9/16)
		main.photo_preview(thumbs,shot.texture,shot.result,rect)
		var ring = Panel.new()
		ring.position = rect.position
		ring.size = rect.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel",UiStyle.box(Color.TRANSPARENT,4,UiStyle.SKY,3))
		thumbs.add_child(ring)
		var cap = make_label(thumbs,Rect2(rect.position.x,rect.end.y+2,w,20),12,Color.WHITE)
		cap.text = shot.label if shot.label != "" else text("academia_foto_demo")
	update_panel()

# ---- Practice ----
func start_practice() -> void:
	tasks = [false,false,false]
	practice_photos = []
	practice_done_shown = false
	hint = ""
	second = null
	stage_subject()
	main.finder.thirds = false
	add_choices()
	locked_person = null
	if kind == "focal":
		# Someone far for the telephoto: a person standing on the outer path (11.5 m) in view.
		second = stand_person(3,SETUP["focal"].angle,11.5)
	if kind == "medicion":
		main.equipment.metering = "matricial"
		main.update_meter()
		main.auto_expose()
	# Never ready to shoot (user, 04-10-2026): the camera is handed over pointing elsewhere, and
	# with whatever the lesson is about out of place.
	if kind != "movimiento": main.angle = fposmod(main.angle+22.0,360)
	match kind:
		"enfoque", "dof": main.focus_distance = 40.0
		"exposicion":
			main.t_index = maxi(0,main.t_index-2)
		"objetivos":
			main.iso_index = Photo.ISOS.find(400)
			main.n_index = main.apertures().find(8.0)
	if kind == "dof":
		main.n_index = main.apertures().find(5.6)
		main.auto_expose()
	main.update_camera()
	main.refresh()
	# The scene holds still while practising (the pause button resumes it), except in the lesson
	# on movement, where the runner has to run.
	set_scene_pause(kind != "movimiento")
	update_panel()

# ---- Exam ----
func start_exam() -> void:
	exam_attempts = 0
	exam_last = {}
	hint = ""
	highlight = ""
	second = null
	stage_subject()
	main.finder.thirds = kind == "composicion"
	for b in extra_buttons: b.queue_free()
	extra_buttons = []
	match kind:
		"exposicion":
			# The sky clouds over after the tutor left the exposure right: about 3 EV are gone.
			main.park.forced_cover = 1.0
			main.park.update_weather(0)
			main.update_meter()
			# Where the lens points may be in the shade already and lose little: the settings are
			# left about 3 EV short in any case (faster shutter, then a smaller aperture).
			var guard = 0
			while exam_needle() > -2.6 and guard < 12:
				guard += 1
				if main.t_index > 0: main.t_index -= 1
				elif main.n_index < main.apertures().size()-1: main.n_index += 1
				else: break
		"dof":
			# A second person further away: both have to be sharp in the same photo.
			second = stand_person(1,SETUP["dof"].angle+5.0,EXAM_SECOND_RADIUS,subject)
		"enfoque":
			# By hand this time: the ring starts far from the subject.
			main.equipment.focus_mode = "MF"
			main.apply_equipment()
			main.set_manual_focus(40.0)
		"focal":
			# The model stands far away, somewhere else, with the wide angle mounted.
			second = stand_person(3,SETUP["focal"].angle+27.0,11.5)
		"movimiento":
			main.focal = 70.0
		"medicion":
			main.equipment.metering = "matricial"
			main.update_meter()
			main.auto_expose()
		"objetivos":
			# The prime is mounted: the shot needs the 24 mm end of the zoom.
			set_lens(2,50.0)
			main.iso_index = Photo.ISOS.find(100)
		"camaras":
			set_body(2,false)
	main.angle = fposmod(main.angle+(22.0 if kind in ["enfoque","medicion","modos","camaras","focal"] else 0.0),360)
	main.update_camera()
	add_choices()
	# The model of the composition exam walks: that is the exam.
	set_scene_pause(not kind in ["movimiento","composicion"])
	main.refresh()
	update_panel()

# The needle for the current settings (negative: underexposed), computed here: the finder's own
# value is only refreshed with the HUD.
func exam_needle() -> float:
	return -Photo.ev(main.apertures()[main.n_index],1.0/Photo.DENOMINATORS[main.t_index],Photo.ISOS[main.iso_index],main.measured_ev)

const EXAM_SECOND_RADIUS = 5.0   # far enough to be clearly soft wide open (f/22 on the near one holds both)

# What the photo says beyond its evidence: the second person of lesson 2, the thirds of lesson 4.
func exam_context(result: Dictionary) -> Dictionary:
	var e: Dictionary = result.evidence
	var x = {"delta":result.delta,"coc":result.coc,"drag":result.get("drag",0.0),"thirds":main.academy_last_thirds,"fill":person_fill(e) if e.get("person",true) else 0.0}
	x["body"] = main.equipment.body
	x["manual_focus"] = main.equipment.focus_mode == "MF"
	x["comp"] = main.equipment.exposure_compensation()
	if kind == "composicion": x["thirds"] = thirds_check(subject)
	x["metering"] = main.equipment.metering
	x["mode"] = main.equipment.exposure_mode()
	x["person"] = e.get("person",true)
	if kind == "enfoque" and is_instance_valid(subject):
		var where = head_screen(subject)
		var zone = Photo.dof(e.f,e.n,e.s)
		var far_d = main.camera.global_position.distance_to(subject.control_points()[1])
		x["sub_in"] = Photo.inside(where)
		x["sub_x"] = where.x
		x["sub_sharp"] = zone.x <= far_d and zone.y >= far_d
	if kind == "focal" and not e.get("person",true):
		var far = extra_at_focus()
		if far > 0.0:
			x["d"] = far
			x.fill = 1.7*e.f/(far*20.25)
	if kind == "dof" and is_instance_valid(subject) and is_instance_valid(second):
		var distances = [main.camera.global_position.distance_to(subject.control_points()[1]),main.camera.global_position.distance_to(second.control_points()[1])]
		x["d_near"] = minf(distances[0],distances[1])
		x["d_far"] = maxf(distances[0],distances[1])
		var a = head_screen(subject)
		var b = head_screen(second)
		x["both"] = Photo.inside(a) and Photo.inside(b)
	return x

func on_exam_photo(result: Dictionary) -> Dictionary:
	exam_attempts += 1
	exam_last = exam_report(kind,result.evidence,exam_context(result))
	if exam_last.passed: mark(lesson,"examen")
	if graduated() and main.badges_count() and main.Badges.grant("graduado"): main.announce_badge("graduado")
	update_panel()
	return exam_last

# The tutor's report: deterministic from the evidence and its context. Each line is [ok, text].
static func exam_report(n: String, e: Dictionary, x: Dictionary) -> Dictionary:
	var lines = []
	var asks: Array = EXAM_ASKS[n]
	var delta: float = x.get("delta",0.0)
	var denominator = roundi(1.0/e.t)
	if "expo" in asks:
		var exposed = absf(delta) <= HALF_STOP
		lines.append([exposed,Texts.get_text("academia_ex_expo_ok" if exposed else "academia_ex_expo_mal") % ("%+.1f" % -delta)])   # as the meter reads: negative is underexposed
	if "pulso" in asks:
		# Hand-held rule: no slower than 1/focal.
		var steady = e.t*e.f <= 1.0+.0001
		var safe: int = Photo.DENOMINATORS.max()
		for d in Photo.DENOMINATORS:
			if d >= e.f-.5 and d < safe: safe = d
		lines.append([steady,Texts.get_text("academia_ex_pulso_ok") % [denominator,roundi(e.f)] if steady else Texts.get_text("academia_ex_pulso_mal") % [denominator,roundi(e.f),safe]])
	match n:
		"composicion":
			var state = str(x.get("thirds",""))
			lines.append([state == "listo",Texts.get_text("academia_ex_tercios_"+(state if state in ["listo","cruce","aire"] else "nadie"))])
		"enfoque":
			var by_hand: bool = x.get("manual_focus",true)
			lines.append([by_hand,Texts.get_text("academia_ex_manual_ok" if by_hand else "academia_ex_manual_mal")])
			var crisp: bool = x.get("sub_sharp",false) and x.get("sub_in",false)
			lines.append([crisp,Texts.get_text("academia_ex_sujeto_ok" if crisp else "academia_ex_sujeto_mal")])
		"focal":
			var tele = e.f >= 120.0
			lines.append([tele,Texts.get_text("academia_ex_tele_ok" if tele else "academia_ex_tele_mal") % roundi(e.f)])
			var distance: float = x.get("d",e.d)
			var fill: float = x.get("fill",0.0)
			var framed = distance > 9.0 and fill >= .45 and fill <= 1.3
			lines.append([framed,Texts.get_text("academia_ex_lejos_ok") % ("%.1f" % distance) if framed else Texts.get_text("academia_ex_lejos_mal") % [roundi(fill*100),"%.1f" % distance]])
		"dof":
			var zone = Photo.dof(e.f,e.n,e.s)
			var near: float = x.get("d_near",e.d)
			var far: float = x.get("d_far",e.d)
			var covered = zone.x <= near and zone.y >= far
			var far_text = "∞" if is_inf(zone.y) else "%.1f" % zone.y
			lines.append([covered,Texts.get_text("academia_ex_dos_ok") % ["%.1f" % zone.x,far_text] if covered else Texts.get_text("academia_ex_dos_mal") % ["%.1f" % zone.x,far_text,"%.1f" % near,"%.1f" % far]])
			if not x.get("both",true): lines.append([false,Texts.get_text("academia_ex_dos_fuera")])
		"movimiento":
			var is_runner = e.v > 1.5
			if not is_runner: lines.append([false,Texts.get_text("academia_ex_corredor_mal")])
			else:
				var needed = Photo.needed_shutter(e.v,e.f,e.d)
				var frozen = needed > 0 and denominator >= needed
				# A good pan freezes the runner too (the photo's own relative drag says so).
				if x.has("drag"): frozen = x.drag <= Photo.C+.0005
				lines.append([frozen,Texts.get_text("academia_ex_congelado_ok") % denominator if frozen else Texts.get_text("academia_ex_congelado_mal") % [denominator,needed if needed > 0 else Photo.DENOMINATORS.max()]])
			var long_enough = e.f >= 65.0
			lines.append([long_enough,Texts.get_text("academia_ex_focal_ok" if long_enough else "academia_ex_focal_mal") % roundi(e.f)])
		"medicion":
			var spot = str(x.get("metering","puntual")) == "puntual"
			lines.append([spot,Texts.get_text("academia_ex_medicion_ok" if spot else "academia_ex_medicion_mal")])
			var brighter = float(x.get("comp",1.0)) >= .99
			lines.append([brighter,Texts.get_text("academia_ex_comp_ok" if brighter else "academia_ex_comp_mal") % ("%+.1f" % float(x.get("comp",1.0)))])
		"modos":
			var open_wide = e.n <= 2.8+.01
			lines.append([open_wide,Texts.get_text("academia_ex_abierto_ok" if open_wide else "academia_ex_abierto_mal") % str(e.n)])
		"objetivos":
			var wide = e.f <= 26.0
			lines.append([wide,Texts.get_text("academia_ex_angular_ok" if wide else "academia_ex_angular_mal") % roundi(e.f)])
		"camaras":
			var rangefinder = int(x.get("body",3)) == 3
			lines.append([rangefinder,Texts.get_text("academia_ex_cuerpo_ok" if rangefinder else "academia_ex_cuerpo_mal")])
	if "persona" in asks and not x.get("person",true): lines.append([false,Texts.get_text("academia_ex_sin_persona")])
	if "nitido" in asks:
		var sharp = x.get("coc",0.0) <= Photo.C+.0005
		lines.append([sharp,Texts.get_text("academia_ex_nitido_ok") if sharp else Texts.get_text("academia_ex_nitido_mal") % x.get("coc",0.0)])
	var right = lines.filter(func(l): return l[0]).size()
	var passed = right == lines.size()
	# Only what goes beyond half a stop costs points, and only where the exposure is examined.
	var penalty = 0.0   # in whole stops, under one stop off is as right as it gets
	var score = roundi(100.0*right/maxi(1,lines.size())-penalty)
	return {"passed":passed,"score":score,"mention":passed and score >= 94,"lines":lines}

# Exams with a model: who it is, by its clothes (as an assignment would).
func model_line() -> String:
	var who = subject if kind == "composicion" else (second if kind == "focal" else null)
	if not is_instance_valid(who): return ""
	return text("academia_examen_modelo") % ", ".join(Array(main.casting.descriptors(who.traits)).slice(0,3))

func exams_done() -> int:
	var count = 0
	for n in range(1,LESSONS+1): if done(n,"examen"): count += 1
	return count

func graduated() -> bool:
	return exams_done() == LESSONS

# Another body in the player's hands (lesson 6). Exposure stays automatic: the lesson is about how
# each camera looks and focuses. With prefocus the tutor leaves the manual ones focused on the subject.
func set_body(k: int, prefocus: bool) -> void:
	main.equipment.preset(k)
	main.equipment.auto_exposure = true
	main.apply_equipment()
	main.focal = clampf(40.0,main.equipment.lens().min,main.equipment.lens().max)
	main.update_camera()
	if prefocus and main.equipment.focus_mode == "MF" and is_instance_valid(subject):
		main.set_manual_focus(main.camera.global_position.distance_to(subject.control_points()[1]))
	main.update_meter()
	main.auto_expose()
	main.refresh()

func add_choices() -> void:
	for b in extra_buttons: b.queue_free()
	extra_buttons = []
	if not CHOICES.has(kind): return
	var list: Array = CHOICES[kind]
	var w = (341.0-6.0*(list.size()-1))/list.size()
	for k in list.size():
		var action: String = list[k][1]
		var b = make_button(panel,text(list[k][0]),Rect2(12+k*(w+6),314,w,32),func(): do_action(action))
		if list.size() > 3: b.add_theme_font_size_override("font_size",12)
		extra_buttons.append(b)

func set_lens(index: int, f: float) -> void:
	main.equipment.lens_index = index
	main.apply_equipment()
	main.focal = f
	main.update_camera()
	main.refresh()

func check_practice(dt: float) -> void:
	hint_timer -= dt
	if hint_timer > 0: return
	hint_timer = .25
	var before = tasks.duplicate()
	var new_hint = ""          # built from scratch every time (it used to pile up on itself)
	var needle = exam_needle()
	var n = main.apertures()[main.n_index]
	match kind:
		"composicion":
			if main.finder.thirds: tasks[0] = true
			if not tasks[0]: new_hint = lesson_text("pista_cuadricula")
			elif not tasks[2]:
				var check = thirds_check()
				if check == "listo": tasks[1] = true
				new_hint = lesson_text("pista_"+check) if check != "" else lesson_text("pista_cruce")
		"enfoque":
			if main.finder.active != 4: tasks[0] = true
			if main.focus_locked and is_instance_valid(main.af_person):
				tasks[1] = true
				locked_person = main.af_person
			if not tasks[0]: new_hint = lesson_text("pista_punto")
			elif not tasks[1]: new_hint = lesson_text("pista_bloquea")
			elif not tasks[2]: new_hint = lesson_text("pista_reencuadra")
		"focal":
			if not tasks[0]: new_hint = lesson_text("pista_angular")
			elif not tasks[1]: new_hint = lesson_text("pista_tele")
		"exposicion":
			if n >= 11.0-.01: tasks[0] = true
			if tasks[0] and absf(needle) <= HALF_STOP: tasks[1] = true
			if not tasks[0]: new_hint = lesson_text("pista_cerrar") % str(n)
			elif absf(needle) > HALF_STOP: new_hint = lesson_text("pista_oscura" if needle < 0 else "pista_clara") % ("%+.1f" % needle)
			elif not tasks[2]: new_hint = lesson_text("pista_centrada")
		"dof":
			if main.focus_distance >= 3.0 and main.focus_distance <= 6.0: tasks[0] = true
			if not tasks[0]: new_hint = lesson_text("pista_enfoca") % ("∞" if is_inf(main.focus_distance) else "%.1f m" % main.focus_distance)
			elif not tasks[1]: new_hint = lesson_text("pista_abre")
			elif not tasks[2]: new_hint = lesson_text("pista_cierra")
		"movimiento":
			loop_runner()
			if not tasks[0]: new_hint = lesson_text("pista_espera")+"\n"+lesson_text("pista_lenta")
			elif not tasks[1]: new_hint = lesson_text("pista_rapida")
		"medicion":
			if main.equipment.metering == "puntual": tasks[0] = true
			if tasks[0] and main.equipment.exposure_compensation() >= .99: tasks[1] = true
			if not tasks[0]: new_hint = lesson_text("pista_puntual")
			elif not tasks[1]: new_hint = lesson_text("pista_compensa")
			elif not tasks[2]: new_hint = lesson_text("pista_cero")
		"modos":
			if main.equipment.exposure_mode() == "P" and tasks.has(false): new_hint = lesson_text("pista_p")
			elif not tasks[0]: new_hint = lesson_text("pista_a")
			elif not tasks[1]: new_hint = lesson_text("pista_s")
			elif not tasks[2]: new_hint = lesson_text("pista_m") % ("%+.1f" % needle)
		"objetivos":
			var at_100 = Photo.ISOS[main.iso_index] == 100
			if main.equipment.lens_index == 0 and at_100 and absf(needle) <= HALF_STOP: tasks[0] = true
			if tasks[0] and main.equipment.lens_index == 2 and n <= 1.81 and at_100 and absf(needle) <= HALF_STOP: tasks[1] = true
			if not tasks[0]: new_hint = lesson_text("pista_zoom") % Photo.DENOMINATORS[main.t_index]
			elif not tasks[1]: new_hint = lesson_text("pista_fijo")
			elif not tasks[2]: new_hint = lesson_text("pista_dispara") % Photo.DENOMINATORS[main.t_index]
		"camaras":
			new_hint = lesson_text(["pista_telemetrica","pista_tlr","pista_reflex"][tasks.find(false)]) if tasks.has(false) else ""
	hint = new_hint
	highlight = practice_highlight()
	if tasks != before or hint_label.text != hint: update_panel()
	complete_if_done()

# The control the next pending task needs, pulsing on the HUD.
func practice_highlight() -> String:
	var next = tasks.find(false)
	if next < 0: return ""
	match kind:
		"exposicion": return ["diafragma","velocidad","disparar"][next]
		"dof": return ["nitidez","diafragma","diafragma"][next]
		"movimiento": return "velocidad"
		"objetivos": return "velocidad"
		"modos": return ["diafragma","velocidad","exposimetro"][next]
	return ""

func complete_if_done() -> void:
	if tasks.all(func(t): return t) and not practice_done_shown:
		practice_done_shown = true
		mark(lesson,"practica")
		hint = ""
		update_panel()

# Lesson 4: where the head of the person under the active point is, against the thirds.
# "" (nobody), "cruce" (not on a crossing), "aire" (crossing on the wrong side), "listo".
func thirds_check(only = null) -> String:
	# Whoever in the frame (up to 15 m, not hidden) has the head nearest a crossing of the thirds.
	var best = 1e9
	var best_x = 0.0
	var best_p = null
	for p in main.people:
		if not p.visible or p.position.distance_to(main.camera.global_position) > 15.0: continue
		if only != null and p != only: continue
		var head = head_screen(p)
		if head.x < 0 or head.x > 1 or head.y < 0 or head.y > 1: continue
		for cx in [1.0/3.0,2.0/3.0]:
			for cy in [1.0/3.0,2.0/3.0]:
				var d = Vector2((head.x-cx)*16.0/9.0,head.y-cy).length()
				if d < best:
					best = d
					best_x = cx
					best_p = p
	if best_p == null: return ""
	if best > .06*16.0/9.0: return "cruce"
	# The air goes in front: of where it walks or, standing, of where it faces (a photo of someone
	# looking right from the right third passed the exam).
	var side = facing_side(best_p)
	if (side < 0 and best_x < .5) or (side > 0 and best_x > .5): return "aire"
	return "listo"

func head_screen(p) -> Vector2:
	var head = p.control_points()[0]
	if main.camera.is_position_behind(head): return Vector2(-1,-1)
	return main.camera.unproject_position(head)/Vector2(main.viewport.size)

# A practice photo: record it and tick what it proves. Returns the notes for the result screen.
func on_practice_photo(texture, result: Dictionary) -> Array:
	var e: Dictionary = result.evidence
	practice_photos.append({"texture":texture,"result":result})
	var notes = []
	match kind:
		"composicion":
			if tasks[0] and main.academy_last_thirds == "listo":
				tasks[1] = true
				tasks[2] = true
			elif tasks[0]: notes.append(lesson_text("pista_foto_no"))
		"enfoque":
			if tasks[1] and is_instance_valid(locked_person):
				var where = head_screen(locked_person)
				var zone = Photo.dof(e.f,e.n,e.s)
				var far_d = main.camera.global_position.distance_to(locked_person.control_points()[1])
				if Photo.inside(where) and absf(where.x-.5) >= .12 and zone.x <= far_d and zone.y >= far_d: tasks[2] = true
				else: notes.append(lesson_text("pista_foto_no"))
		"focal":
			# Anyone the player sees counts, also the meadow extras behind the outer path: they have no
			# colliders (docs/futuro/19), so look for one under the focus point on screen.
			if not e.get("person",true):
				var far = extra_at_focus()
				if far > 0.0:
					e = e.duplicate()
					e.d = far
					e.person = true
			var fill = person_fill(e) if e.get("person",true) else 0.0
			if e.f <= 35.0 and e.d < 4.5 and fill >= .45 and fill <= 1.3: tasks[0] = true
			elif e.f <= 35.0 and e.d >= 4.5: notes.append(lesson_text("pista_cerca"))
			if e.f >= 120.0 and e.d > 9.0 and fill >= .45 and fill <= 1.3: tasks[1] = true
			elif e.f >= 120.0 and e.d <= 9.0: notes.append(lesson_text("pista_lejos"))
			if (e.f <= 35.0 or e.f >= 120.0) and (fill < .45 or fill > 1.3) and e.d < 40.0: notes.append(lesson_text("pista_tamano"))
			if tasks[0] and tasks[1]: tasks[2] = true
		"exposicion":
			if absf(result.delta) <= HALF_STOP and tasks[1]: tasks[2] = true
			elif absf(result.delta) > HALF_STOP: notes.append(lesson_text("pista_foto_mal") % ("%+.1f" % result.delta))
		"dof":
			if e.n <= 2.8+.01 and e.d >= 2.5 and e.d <= 7.0: tasks[1] = true
			if e.n >= 8.0-.01 and tasks[1]: tasks[2] = true
		"movimiento":
			var is_runner = e.v > 1.5
			if not is_runner: notes.append(lesson_text("pista_no_corredor"))
			elif e.t >= 1.0/60-.0001: tasks[0] = true
			elif e.t <= 1.0/500+.0001: tasks[1] = true
			if tasks[0] and tasks[1]: tasks[2] = true
		"medicion":
			if tasks[1] and is_zero_approx(main.equipment.exposure_compensation()) and absf(result.delta) <= HALF_STOP: tasks[2] = true
			elif tasks[1]: notes.append(lesson_text("pista_foto_no"))
		"modos":
			var mode_now: String = main.equipment.exposure_mode()
			if mode_now == "A" and e.n <= 4.0+.01: tasks[0] = true
			if mode_now == "S" and e.t <= 1.0/500+.0001: tasks[1] = true
			if mode_now == "M" and absf(result.delta) <= HALF_STOP: tasks[2] = true
			elif mode_now == "M": notes.append(lesson_text("pista_foto_no") % ("%+.1f" % result.delta))
		"objetivos":
			var steady = e.t*e.f <= 1.0+.0001
			if tasks[1] and main.equipment.lens_index == 2 and steady and absf(result.delta) <= HALF_STOP: tasks[2] = true
			elif not steady: notes.append(lesson_text("pista_trepidada") % roundi(1.0/e.t))
		"camaras":
			var sharp = result.coc <= Photo.C+.0005 and e.get("person",true)
			var which = {1:0, 3:1, 2:2}.get(main.equipment.body,-1)
			if which >= 0 and sharp: tasks[which] = true
			elif which >= 0: notes.append(lesson_text("pista_borrosa"))
	complete_if_done()
	update_panel()
	return notes

# Distance to a meadow extra under the active focus point (−1 if none): its screen box from the
# feet to the head, about a third of its height wide.
func extra_at_focus() -> float:
	if not main.extras: return -1.0
	var point: Vector2 = main.image_position(main.finder.points()[main.finder.active])
	var best = -1.0
	for p in main.extras.extras:
		if not p.visible: continue
		var feet: Vector3 = p.global_position
		var head: Vector3 = feet+Vector3.UP*p.height
		if main.camera.is_position_behind(head): continue
		var top = main.camera.unproject_position(head)
		var bottom = main.camera.unproject_position(feet)
		var half = absf(bottom.y-top.y)*.18+6.0
		if point.y >= top.y-6.0 and point.y <= bottom.y+6.0 and absf(point.x-(top.x+bottom.x)*.5) <= half:
			var d = main.camera.global_position.distance_to(feet+Vector3.UP*p.height*.6)
			if best < 0.0 or d < best: best = d
	return best

# Fraction of the frame height a standing person would fill at the photo's distance and focal
# (16:9 frame of a 36 mm wide sensor: 20.25 mm tall).
func person_fill(e: Dictionary) -> float:
	var height = 1.7
	return height*e.f/(e.d*20.25)

# Photos of this practice that make a pair for the comparison of lesson 5 / lesson 2.
func comparison_photos() -> Array:
	var out = []
	match kind:
		"dof":
			var open = practice_photos.filter(func(s): return s.result.evidence.n <= 2.81)
			var closed = practice_photos.filter(func(s): return s.result.evidence.n >= 7.99)
			if not open.is_empty() and not closed.is_empty(): out = [open[-1],closed[-1]]
		"focal":
			var wide = practice_photos.filter(func(s): return s.result.evidence.f <= 35.0)
			var tele = practice_photos.filter(func(s): return s.result.evidence.f >= 120.0)
			if not wide.is_empty() and not tele.is_empty(): out = [wide[-1],tele[-1]]
		"movimiento":
			var slow = practice_photos.filter(func(s): return s.result.evidence.v > 1.5 and s.result.evidence.t >= 1.0/60-.0001)
			var fast = practice_photos.filter(func(s): return s.result.evidence.v > 1.5 and s.result.evidence.t <= 1.0/500+.0001)
			if not slow.is_empty() and not fast.is_empty(): out = [slow[-1],fast[-1]]
	return out

# ---- Per frame ----
func update(dt: float) -> void:
	if not active: return
	pulse += dt
	if tour_pages > 0: run_tour(dt)
	if phase == "demo": run_demo(dt)
	elif phase == "practica" and main.mode == "SEARCH": check_practice(dt)
	elif phase in ["teoria","examen"] and kind == "movimiento": loop_runner()
	if kind == "composicion" and phase in ["practica","examen"]: main.academy_last_thirds = thirds_check(subject if phase == "examen" else null)
	# Depth of field, theory: the aperture opens and closes by itself so the change shows.
	if kind == "dof" and phase == "teoria" and main.mode == "SEARCH" and not paused:
		swing_timer += dt
		if swing_timer >= 2.6:
			swing_timer = 0.0
			var stops: Array = main.apertures()
			main.n_index = stops.find(11.0) if main.n_index == 0 else 0
			main.auto_expose()
			main.refresh()
	# Movement: the camera keeps the runner in focus (the lesson is the shutter speed, not the AF).
	var kept = auto_subject()
	if kept != null and main.mode == "SEARCH":
		main.focus_distance = main.camera.global_position.distance_to(kept.control_points()[1])
	# Theory and demonstration: whoever the lesson shows stays in focus (it drifted out while the
	# tutor talked), and the control being pointed at is also the one in hand on the strip.
	if phase in ["teoria","demo"] and main.mode == "SEARCH":
		if is_instance_valid(subject) and subject.visible and waiting_runner == null:
			var far = main.camera.global_position.distance_to(subject.control_points()[1])
			if absf(far-(1e6 if is_inf(main.focus_distance) else main.focus_distance)) > .03:
				if main.equipment.focus_mode == "MF": main.set_manual_focus(far)
				else: main.focus_distance = far
		var in_hand = {"diafragma":"n","velocidad":"t","iso":"iso","zoom":"zoom"}.get(highlight,"")
		if in_hand != "" and in_hand in main.selectable_controls(): main.selected_control = in_hand
	track_frame_goal(dt)
	diagram.queue_redraw()
	queue_redraw()

# The person the camera focuses by itself and takes as the subject of the photo wherever it is in
# the frame (movement: the runner), or null.
func auto_subject():
	if active and kind == "movimiento" and phase in ["practica","examen"] and is_instance_valid(runner): return runner
	return null

# While the tutor drives (a demonstration running) the player's controls are locked.
func locks_input() -> bool:
	return active and phase in ["teoria","demo"]

# The tutor is driving right now (the red frame and its sign).
func tutor_drives() -> bool:
	return active and phase == "demo" and not demo_done

func run_tour(dt: float) -> void:
	tour_timer += dt
	match phase:
		"teoria":
			if tour_timer >= tour_seconds:
				tour_timer = 0.0
				if page+1 < mini(tour_pages,THEORY_PAGES[kind]): go_next()
				else: set_phase("demo")
		"demo":
			if not demo_done: tour_timer = 0.0
			elif tour_timer >= 2.5:
				tour_timer = 0.0
				set_phase("practica")

# Keep a person's head (or chest) at a fraction of the frame, like a camera operator would.
func track_frame_goal(dt: float) -> void:
	if frame_goal.is_empty() or not is_instance_valid(frame_goal.get("who")): return
	var p = frame_goal.who
	if frame_goal.get("lead",false): frame_goal.x = lead_x(p)
	# Lead a walking subject a little (a camera operator anticipates), so it does not lag behind.
	var head = p.control_points()[0]+p.actual_velocity*.35
	var local = main.camera.global_transform.affine_inverse()*head
	if local.z > -.1: return
	var half_h = deg_to_rad(main.camera.fov)*.5
	var aspect = float(main.viewport.size.y)/main.viewport.size.x
	var want_x = (frame_goal.x-.5)*2.0*tan(half_h)
	var want_y = (.5-frame_goal.y)*2.0*tan(half_h)*aspect
	var err_x = atan2(local.x,-local.z)-atan(want_x)
	var err_y = atan2(local.y,-local.z)-atan(want_y)
	var gain = minf(1.0,dt*2.5)
	if frame_goal.get("snap",false):
		# Cut straight to the new subject (a lens change), then keep tracking smoothly.
		gain = 1.0
		frame_goal.snap = false
	main.angle = fposmod(main.angle+rad_to_deg(err_x)*gain,360)
	main.pitch = clampf(main.pitch+rad_to_deg(err_y)*gain,-40,40)
	main.update_camera()

func highlight_rect() -> Rect2:
	# With the camera interface the lesson points at the camera's own things: the chip of the
	# control on the strip over the finder and the meter of the finder.
	if main.interface_mode == "camara":
		match highlight:
			"exposimetro": return main.camera_body.meter_box
			"diafragma": return main.control_strip.chip_rect("n")
			"velocidad": return main.control_strip.chip_rect("t")
			"iso": return main.control_strip.chip_rect("iso")
			"zoom": return main.control_strip.chip_rect("zoom")
		return Rect2()
	match highlight:
		"exposimetro": return Rect2(main.meter_bar.position,main.meter_bar.size)
		"diafragma": return Rect2(main.aperture_button.position,main.aperture_button.size)
		"velocidad": return Rect2(main.shutter_button.position,main.shutter_button.size)
		"iso": return Rect2(main.iso_button.position,main.iso_button.size)
		"nitidez": return Rect2(main.dof_label.position,main.dof_label.size)
		"zoom": return Rect2(main.focal_label.position,Vector2(220,60))
		"disparar": return Rect2(1005,642,248,59)
	return Rect2()

func _draw() -> void:
	if not active: return
	if tutor_drives() and main.mode == "SEARCH":
		# Hands off: a red frame round the finder and a blinking sign while the tutor drives.
		var view: Rect2 = main.view_rect
		var beat = .55+.45*sin(pulse*4.0)
		draw_rect(view.grow(-2),Color(.95,.2,.18,.35+.4*beat),false,5)
		var sign_text = text("academia_tutor_conduce")
		var font = UiStyle.font("Roboto-Medium")
		var w = font.get_string_size(sign_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+46
		var at = Vector2(view.get_center().x-w*.5,view.position.y+44)
		draw_style_box(UiStyle.box(Color(.72,.1,.1,.92),14,Color.WHITE,1),Rect2(at,Vector2(w,30)))
		if fmod(pulse,1.0) < .6: draw_circle(at+Vector2(17,15),6,Color.WHITE)
		draw_string(font,at+Vector2(32,20),sign_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	if phase == "demo" and demo_done:
		# The demonstration is over: the eye goes to «Ir a la práctica».
		var a = .55+.45*sin(pulse*5.0)
		var button_rect = Rect2(panel.position+next_button.position,next_button.size)
		draw_rect(button_rect.grow(5),Color(1,1,1,a),false,3)
		draw_rect(button_rect.grow(10),Color(UiStyle.SKY.r,UiStyle.SKY.g,UiStyle.SKY.b,a*.6),false,3)
	if highlight == "": return
	var rect = highlight_rect()
	if rect.size == Vector2.ZERO: return
	var a2 = .55+.45*sin(pulse*5.0)
	draw_rect(rect.grow(5),Color(1,1,1,a2),false,3)
	draw_rect(rect.grow(9),Color(UiStyle.SKY.r,UiStyle.SKY.g,UiStyle.SKY.b,a2*.7),false,3)

func handle_key(event: InputEvent) -> bool:
	if not active: return false
	if event.is_action_pressed("academia_siguiente"):
		go_next()
		return true
	if event.is_action_pressed("academia_atras"):
		go_back()
		return true
	if event.is_action_pressed("academia_pausa"):
		toggle_pause()
		return true
	return false
