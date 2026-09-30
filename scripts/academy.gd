extends Control
# Academia de fotografía (docs/futuro/06_MODO_TUTOR_ACADEMIA.md): five lessons, each with theory
# pages drawn over the live viewfinder, a guided demonstration (the camera moves by itself, with
# subtitles and highlighted controls) and a practice with tasks and live hints. The exam is shown
# as «not available yet». Runs on top of the sandbox session of main.gd (no assignment, unlimited
# shots, pausable scene); all copy lives in data/textos.es.json (academia_*).
const Texts = preload("res://scripts/texts.gd")
const Photo = preload("res://scripts/photography.gd")
const Diagram = preload("res://scripts/academy_diagram.gd")
var progress_path = "user://academia.cfg"   # tests point it elsewhere
const LESSONS = 5
const PHASES = ["teoria","demo","practica"]

# Per lesson: equipment and light, the diagram of each theory page and the practice setup.
# body/lens index into Equipment.LENSES; lens 3/4/5 of the réflex are the Academy primes.
const SETUP = {
	1: {"time":"golden","body":2,"lens":0,"focal":50.0,"auto":false,"focus":"AF puntual","angle":125.0,"pitch":-3.0,"n":4.0,
		"pages":["triangulo","pasos_n","pasos_t","pasos_iso","pasos"],"practice_diagram":"pasos"},
	2: {"time":"golden","cover":1.0,"body":2,"lens":4,"focal":105.0,"auto":false,"focus":"AF puntual","angle":118.0,"pitch":-2.0,"n":1.8,
		"pages":["dof","dof","dof","dof"],"practice_diagram":"dof"},
	3: {"time":"golden","body":2,"lens":0,"focal":50.0,"auto":false,"focus":"AF puntual","angle":70.0,"pitch":-4.0,"t":250,
		"pages":["movimiento","movimiento","movimiento","pasos"],"practice_diagram":"movimiento"},
	4: {"time":"day","body":2,"lens":2,"focal":50.0,"auto":true,"focus":"AF puntual","angle":200.0,"pitch":-3.0,
		"pages":["tercios","tercios","tercios","tercios"],"practice_diagram":"tercios"},
	5: {"time":"day","body":2,"lens":3,"focal":28.0,"auto":true,"focus":"AF puntual","angle":121.0,"pitch":-4.0,
		"pages":["compresion","compresion","compresion","compresion"],"practice_diagram":"compresion"},
}
const THEORY_PAGES = {1:5, 2:4, 3:4, 4:4, 5:4}
const TASKS = 3

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
# UI
var panel: Panel
var header: Label
var title_label: Label
var body_label: Label
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
	for n in range(1,LESSONS+1):
		for ph in PHASES:
			if config.get_value("leccion_%d" % n,ph,false): progress["%d_%s" % [n,ph]] = true

func save_progress() -> void:
	var config = ConfigFile.new()
	for key in progress:
		var parts = str(key).split("_")
		config.set_value("leccion_%s" % parts[0],parts[1],true)
	config.save(progress_path)

func mark(n: int, ph: String) -> void:
	if progress.get("%d_%s" % [n,ph],false): return
	progress["%d_%s" % [n,ph]] = true
	save_progress()

func done(n: int, ph: String) -> bool:
	return progress.get("%d_%s" % [n,ph],false)

func reset_progress() -> void:
	progress = {}
	save_progress()

func practices_done() -> int:
	var count = 0
	for n in range(1,LESSONS+1): if done(n,"practica"): count += 1
	return count

# ---- UI ----
func style(color: Color, radius = 8, border = Color.TRANSPARENT) -> StyleBoxFlat:
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
	node.add_theme_color_override("font_color",color)
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
	node.add_theme_color_override("font_color",Color("19251e") if primary else Color("dfe7d6"))
	node.add_theme_color_override("font_disabled_color",Color("6d7a68"))
	node.add_theme_stylebox_override("normal",style(Color("b8d78c") if primary else Color("26342d"),8,Color("425044")))
	node.add_theme_stylebox_override("hover",style(Color("cee8ab") if primary else Color("35483b"),8,Color("82906f")))
	node.add_theme_stylebox_override("pressed",style(Color("95b966") if primary else Color("1a2721"),8))
	node.add_theme_stylebox_override("disabled",style(Color("1b2520"),8,Color("2c3a31")))
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
	subtitle_panel.position = Vector2(40,556)
	subtitle_panel.size = Vector2(840,58)
	subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_panel.add_theme_stylebox_override("panel",style(Color(0,0,0,.62),8))
	add_child(subtitle_panel)
	subtitle_label = make_label(subtitle_panel,Rect2(14,6,812,46),20,Color("f2f4ec"),true)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func text(key: String) -> String:
	return Texts.get_text(key)

func lesson_text(suffix: String) -> String:
	return Texts.get_text("academia_l%d_%s" % [lesson,suffix])

# ---- Lesson lifecycle ----
func begin(n: int, start_phase = "teoria") -> void:
	lesson = n
	active = true
	visible = true
	paused = false
	var s: Dictionary = SETUP[n]
	main.start_session(s.time,true)
	main.park.clouds_enabled = false
	main.park.forced_cover = s.get("cover",-1.0)
	main.park.update_weather(0)
	main.toast.text = ""
	main.graphics_button.visible = false
	apply_setup()
	main.briefing.text = "%s %d · %s" % [text("academia"),n,lesson_text("titulo")]
	main.sandbox_button.visible = false
	set_phase(start_phase)

func apply_setup() -> void:
	var s: Dictionary = SETUP[lesson]
	main.equipment.film = false
	main.equipment.body = s.body
	main.equipment.lens_index = s.lens
	main.equipment.auto_exposure = s.auto
	main.equipment.focus_mode = s.focus
	main.equipment.ev_comp_index = 6
	main.apply_equipment()
	main.focal = s.focal
	main.angle = s.angle
	main.pitch = s.pitch
	main.finder.thirds = lesson == 4 and phase != "practica"
	main.update_camera()
	main.update_meter()
	if not s.auto:
		if s.has("n"):
			var stops = main.apertures()
			var best = 0
			for i in stops.size(): if absf(stops[i]-s.n) < absf(stops[best]-s.n): best = i
			main.n_index = best
			expose_with_shutter()
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
	update_panel()

func exit_lesson() -> void:
	stop()
	main.show_academy()

# Leave the lesson state (the scene keeps running for whatever screen comes next).
func stop() -> void:
	active = false
	visible = false
	main.park.forced_cover = -1.0
	main.graphics_button.visible = true
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

func toggle_pause() -> void:
	set_scene_pause(not paused)
	update_panel()

func set_scene_pause(value: bool) -> void:
	paused = value
	main.set_sandbox_pause(value)

func go_next() -> void:
	match phase:
		"teoria":
			if page < THEORY_PAGES[lesson]-1:
				page += 1
				highlight = theory_highlight()
				if page == THEORY_PAGES[lesson]-1: mark(lesson,"teoria")
				update_panel()
			else:
				mark(lesson,"teoria")
				set_phase("demo")
		"demo":
			if demo_done: set_phase("practica")
			else: set_phase("practica")
		"practica":
			if lesson < LESSONS: begin(lesson+1)
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

# Which HUD control each theory page points at.
func theory_highlight() -> String:
	match lesson:
		1: return ["exposimetro","diafragma","velocidad","iso",""][page]
		2: return ["nitidez","diafragma","zoom","nitidez"][page]
		3: return ["velocidad","","velocidad","diafragma"][page]
	return ""

func update_panel() -> void:
	if not active: return
	var phase_name = text("academia_fase_"+phase)
	pause_button.text = text("academia_reanudar") if paused else text("academia_pausar")
	back_button.disabled = phase == "teoria" and page == 0
	for l in task_labels: l.visible = false
	hint_label.visible = false
	diagram.visible = false
	thumbs.visible = false
	subtitle_panel.visible = false
	match phase:
		"teoria":
			var total = THEORY_PAGES[lesson]
			header.text = text("academia_pagina") % ["%s %d · %s" % [text("academia"),lesson,phase_name],page+1,total]
			title_label.text = lesson_text("t%d_titulo" % (page+1))
			body_label.text = lesson_text("t%d_texto" % (page+1))
			body_label.size.y = 150
			diagram.kind = SETUP[lesson].pages[page]
			diagram.visible = true
			next_button.text = text("academia_siguiente") if page < total-1 else text("academia_ir_demo")
			highlight = theory_highlight()
		"demo":
			header.text = "%s %d · %s" % [text("academia"),lesson,phase_name]
			title_label.text = lesson_text("titulo")
			body_label.text = text("academia_demo_en_curso")
			body_label.size.y = 60
			thumbs.visible = not demo_photos.is_empty()
			diagram.kind = SETUP[lesson].practice_diagram
			diagram.visible = demo_photos.is_empty()
			subtitle_panel.visible = subtitle != ""
			subtitle_label.text = subtitle
			next_button.text = text("academia_ir_practica")
		"practica":
			header.text = "%s %d · %s" % [text("academia"),lesson,phase_name]
			title_label.text = lesson_text("titulo")
			body_label.text = text("academia_practica_superada") if tasks.all(func(t): return t) else text("academia_practica_intro")
			body_label.size.y = 60
			for k in TASKS:
				var l: Label = task_labels[k]
				l.visible = true
				l.position.y = 122+k*42
				l.text = "%s  %s" % [text("academia_hecho") if tasks[k] else text("academia_pendiente"),lesson_text("p%d" % (k+1))]
				l.add_theme_color_override("font_color",Color("b8d78c") if tasks[k] else Color("c9d4bf"))
			hint_label.visible = hint != ""
			hint_label.text = hint
			hint_label.position.y = 252
			next_button.text = text("academia_siguiente") if lesson < LESSONS else text("academia_volver_menu")
	for b in extra_buttons: b.visible = phase == "practica" and lesson == 5

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
	match lesson:
		2: subject = stand_person(1,SETUP[2].angle,4.0)
		3: runner = stage_runner()
		4: subject = walk_person(1,SETUP[4].angle+16.0,-1.0)
		5: subject = stand_person(0,SETUP[5].angle,2.3)
		_: subject = null

func stand_person(lane: int, theta: float, radius: float):
	var p = main.pick(func(q): return q.lane == lane and not q.runner)
	if p == null: p = main.pick(func(q): return not q.runner)   # anyone free walking elsewhere
	if p == null: return null
	main.clear_sector([0,1,2,3].slice(0,lane+1),[p],30.0,true)
	main.reset_walker(p,lane,theta,1.0)
	p.set_hidden(false)
	p.set_meta("staged",true)
	p.radius = radius
	p.state = "DETENIDO"
	p.state_time = 9999.0
	p.activity = "movil" if lesson != 5 else "mirar"
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
	main.reset_walker(r,2,SETUP[3].angle-32.0,1.0)
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
	match lesson:
		1: demo_steps = [
			[0.5,1,"expose"],[1.0,-1,"hl:exposimetro"],
			[3.5,2,"hl:diafragma"],[4.2,-1,"n:+1"],[4.9,-1,"n:+1"],
			[6.2,3,"hl:exposimetro"],
			[9.0,4,"hl:velocidad"],[9.7,-1,"t:+1"],[10.4,-1,"t:+1"],
			[12.0,5,"hl:exposimetro"],
			[14.5,6,"hl:iso"],[15.2,-1,"iso:+1"],[15.9,-1,"iso:+1"],
			[17.5,7,"hl:diafragma"],[18.2,-1,"n:+1"],[18.9,-1,"n:+1"],
			[20.5,8,"hl:disparar"],[21.5,-1,"shoot:f"],
			[25.0,-1,"end"]]
		2: demo_steps = [
			[0.3,1,"look_subject"],[1.5,-1,"af"],[2.0,-1,"n:min"],
			[4.0,2,"hl:nitidez"],
			[7.0,3,""],[9.0,-1,"shoot:f/1.8"],
			[11.5,4,"hl:diafragma"],[12.0,-1,"nc:+1"],[12.6,-1,"nc:+1"],[13.2,-1,"nc:+1"],[13.8,-1,"nc:+1"],[14.4,-1,"nc:+1"],[15.0,-1,"nc:+1"],
			[16.0,5,"hl:nitidez"],
			[19.0,6,""],[20.0,-1,"shoot:f/11"],
			[24.0,-1,"end"]]
		3: demo_steps = [
			[0.3,1,"hl:velocidad"],[0.8,-1,"t_set:30"],
			[3.3,2,"shoot_runner:1/30"],
			[7.5,3,"hl:velocidad"],[8.0,-1,"t_set:1000"],
			[11.3,4,"shoot_runner:1/1000"],
			[15.5,5,"hl:velocidad"],
			[19.5,-1,"end"]]
		4: demo_steps = [
			[0.3,1,"thirds"],
			[2.5,2,"frame:0.5:0.42"],
			[5.5,3,""],
			[8.0,4,"frame_lead"],
			[11.0,5,"frame_lead_eyes"],[13.5,-1,"shoot:tercios"],
			[17.0,-1,"end"]]
		5: demo_steps = [
			[0.1,-1,"freeze"],[0.3,1,"frame:0.5:0.35"],
			[3.5,2,"shoot:28 mm"],
			[7.5,3,"lens_tele"],
			[11.0,4,"shoot:135 mm"],
			[14.5,5,""],
			[19.0,-1,"end"]]
	update_panel()

func run_demo(dt: float) -> void:
	if paused and lesson == 3: return
	if waiting_runner != null:
		waiting_time += dt
		var off = 99.0
		if runner: off = rad_to_deg(angle_difference(deg_to_rad(main.angle),deg_to_rad(runner.theta)))
		# Shoot the moment one of the central AF points actually lands on the runner (AF puntual on
		# that point), as a photographer pressing at the right instant would.
		var on_runner = point_on(runner,16.0) if runner and absf(off) < 6.0 else -1
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
	demo_time += dt
	while demo_next < demo_steps.size() and demo_time >= demo_steps[demo_next][0]:
		var step: Array = demo_steps[demo_next]
		demo_next += 1
		if step[1] > 0:
			subtitle = lesson_text("d%d" % step[1])
			update_panel()
		do_action(str(step[2]))

func do_action(action: String) -> void:
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
		"lens_tele":
			main.equipment.lens_index = 5
			main.apply_equipment()
			main.focal = 135.0
			if subject: subject.set_hidden(true)
			set_scene_pause(false)
			subject = stand_person(3,SETUP[5].angle,11.6)
			main.clear_sector([1,2],[subject],40.0,true)
			set_scene_pause(true)
			frame_goal = {"who":subject,"x":.5,"y":.5,"snap":true} if subject else {}
			main.refresh()
		"freeze":
			# A lesson about perspective, not motion: nobody crosses the line of sight.
			main.clear_sector([1,2,3],[subject],40.0,true)
			set_scene_pause(true)
		"shoot":
			if subject and lesson != 1:
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
			if lesson == 5: set_scene_pause(false)
			demo_done = true
			highlight = ""
			mark(lesson,"demo")
			subtitle = ""
			update_panel()
	if action.begins_with("n:min"):
		main.n_index = 0
		expose_with_shutter()
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
	# Walking to the left of the frame → place on the right third, and vice versa.
	var motion = p.actual_velocity.dot(main.camera.global_basis.x)
	return 2.0/3.0 if motion < 0 else 1.0/3.0

func step_parameter(kind: String, amount: int) -> void:
	for i in absi(amount): main.change_parameter(kind,signi(amount))

# Shutter to 1/denominator, keeping exposure with aperture first, then ISO.
func set_shutter(denominator: int) -> void:
	var index = Photo.DENOMINATORS.find(denominator)
	if index < 0: return
	main.t_index = index
	main.update_meter()
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
		var cap = make_label(thumbs,Rect2(rect.position.x,rect.end.y+2,w,20),12,Color("b8d78c"))
		cap.text = shot.label if shot.label != "" else text("academia_foto_demo")
	update_panel()

# ---- Practice ----
func start_practice() -> void:
	tasks = [false,false,false]
	practice_photos = []
	practice_done_shown = false
	hint = ""
	stage_subject()
	main.finder.thirds = false
	for b in extra_buttons: b.queue_free()
	extra_buttons = []
	if lesson == 5:
		extra_buttons.append(make_button(panel,text("academia_cambiar_objetivo") % "28 mm",Rect2(12,314,168,32),func(): set_lens(3,28.0)))
		extra_buttons.append(make_button(panel,text("academia_cambiar_objetivo") % "135 mm",Rect2(186,314,167,32),func(): set_lens(5,135.0)))
	update_panel()

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
	var new_hint = hint
	var delta = main.finder.delta_ev
	var n = main.apertures()[main.n_index]
	match lesson:
		1:
			if n >= 11.0-.01: tasks[0] = true
			if tasks[0] and absf(delta) <= .34: tasks[1] = true
			if not tasks[0]: new_hint = lesson_text("pista_cerrar") % str(n)
			elif absf(delta) > .34: new_hint = lesson_text("pista_oscura" if delta < 0 else "pista_clara") % ("%+.1f" % delta)
			elif not tasks[2]: new_hint = lesson_text("pista_centrada")
		2:
			if main.focus_distance >= 3.0 and main.focus_distance <= 6.0: tasks[0] = true
			if not tasks[0]: new_hint = lesson_text("pista_enfoca") % ("∞" if is_inf(main.focus_distance) else "%.1f m" % main.focus_distance)
			elif not tasks[1]: new_hint = lesson_text("pista_abre")
			elif not tasks[2]: new_hint = lesson_text("pista_cierra")
			if absf(delta) > 1.0 and tasks[0]: new_hint += "\n"+lesson_text("pista_luz")
		3:
			loop_runner()
			if not tasks[0]: new_hint = lesson_text("pista_espera")+"\n"+lesson_text("pista_lenta")
			elif not tasks[1] or not tasks[2]: new_hint = lesson_text("pista_rapida")
		4:
			if main.finder.thirds: tasks[0] = true
			if not tasks[0]: new_hint = lesson_text("pista_cuadricula")
			else:
				var check = thirds_check()
				if check == "listo": tasks[1] = true
				new_hint = lesson_text("pista_"+check) if check != "" else lesson_text("pista_cruce")
		5:
			if not tasks[0]: new_hint = lesson_text("pista_angular")
			elif not tasks[1]: new_hint = lesson_text("pista_tele")
	hint = new_hint
	highlight = practice_highlight()
	if tasks != before or hint_label.text != hint: update_panel()
	complete_if_done()

# The control the next pending task needs, pulsing on the HUD.
func practice_highlight() -> String:
	var next = tasks.find(false)
	if next < 0: return ""
	match lesson:
		1: return ["diafragma","velocidad","disparar"][next]
		2: return ["nitidez","diafragma","diafragma"][next]
		3: return "velocidad"
	return ""

func complete_if_done() -> void:
	if tasks.all(func(t): return t) and not practice_done_shown:
		practice_done_shown = true
		mark(lesson,"practica")
		hint = ""
		update_panel()

# Lesson 4: where the head of the person under the active point is, against the thirds.
# "" (nobody), "cruce" (not on a crossing), "aire" (crossing on the wrong side), "listo".
func thirds_check() -> String:
	var hit = main.point_hit(main.finder.points()[main.finder.active])
	if hit.is_empty() or not hit.collider.has_meta("person"): return ""
	var p = hit.collider.get_meta("person")
	var head = head_screen(p)
	if head.x < 0: return ""
	var best = 1e9
	var best_x = 0.0
	for cx in [1.0/3.0,2.0/3.0]:
		for cy in [1.0/3.0,2.0/3.0]:
			var d = Vector2((head.x-cx)*16.0/9.0,head.y-cy).length()
			if d < best:
				best = d
				best_x = cx
	if best > .06*16.0/9.0: return "cruce"
	var motion = p.actual_velocity.dot(main.camera.global_basis.x)
	if absf(motion) > .05 and ((motion < 0 and best_x < .5) or (motion > 0 and best_x > .5)): return "aire"
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
	match lesson:
		1:
			if absf(result.delta) <= .5 and tasks[1]: tasks[2] = true
			elif absf(result.delta) > .5: notes.append(lesson_text("pista_foto_mal") % ("%+.1f" % result.delta))
		2:
			if e.n <= 2.8+.01 and e.d >= 2.5 and e.d <= 7.0: tasks[1] = true
			if e.n >= 8.0-.01 and tasks[1]: tasks[2] = true
		3:
			var is_runner = e.v > 1.5
			if not is_runner: notes.append(lesson_text("pista_no_corredor"))
			elif e.t >= 1.0/60-.0001: tasks[0] = true
			elif e.t <= 1.0/500+.0001:
				tasks[1] = true
				if absf(result.delta) <= 1.0: tasks[2] = true
		4:
			if tasks[0] and main.academy_last_thirds == "listo": tasks[2] = true
			elif tasks[0]: notes.append(lesson_text("pista_foto_no"))
		5:
			var fill = person_fill(e) if e.get("person",true) else 0.0
			if e.f <= 35.0 and e.d < 4.5 and fill >= .45 and fill <= 1.3: tasks[0] = true
			elif e.f <= 35.0 and e.d >= 4.5: notes.append(lesson_text("pista_cerca"))
			if e.f >= 120.0 and e.d > 9.0 and fill >= .45 and fill <= 1.3: tasks[1] = true
			elif e.f >= 120.0 and e.d <= 9.0: notes.append(lesson_text("pista_lejos"))
			if (e.f <= 35.0 or e.f >= 120.0) and (fill < .45 or fill > 1.3) and e.d < 40.0: notes.append(lesson_text("pista_tamano"))
			if tasks[0] and tasks[1]: tasks[2] = true
	complete_if_done()
	update_panel()
	return notes

# Fraction of the frame height a standing person would fill at the photo's distance and focal
# (16:9 frame of a 36 mm wide sensor: 20.25 mm tall).
func person_fill(e: Dictionary) -> float:
	var height = 1.7
	return height*e.f/(e.d*20.25)

# Photos of this practice that make a pair for the comparison of lesson 5 / lesson 2.
func comparison_photos() -> Array:
	var out = []
	match lesson:
		2:
			var open = practice_photos.filter(func(s): return s.result.evidence.n <= 2.81)
			var closed = practice_photos.filter(func(s): return s.result.evidence.n >= 7.99)
			if not open.is_empty() and not closed.is_empty(): out = [open[-1],closed[-1]]
		5:
			var wide = practice_photos.filter(func(s): return s.result.evidence.f <= 35.0)
			var tele = practice_photos.filter(func(s): return s.result.evidence.f >= 120.0)
			if not wide.is_empty() and not tele.is_empty(): out = [wide[-1],tele[-1]]
	return out

# ---- Per frame ----
func update(dt: float) -> void:
	if not active: return
	pulse += dt
	if phase == "demo": run_demo(dt)
	elif phase == "practica" and main.mode == "SEARCH": check_practice(dt)
	elif phase == "teoria" and lesson == 3: loop_runner()
	if lesson == 4 and phase == "practica": main.academy_last_thirds = thirds_check()
	track_frame_goal(dt)
	diagram.queue_redraw()
	queue_redraw()

# Keep a person's head (or chest) at a fraction of the frame, like a camera operator would.
func track_frame_goal(dt: float) -> void:
	if frame_goal.is_empty() or not is_instance_valid(frame_goal.get("who")): return
	var p = frame_goal.who
	if frame_goal.get("lead",false): frame_goal.x = lead_x(p)
	var head = p.control_points()[0]
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
	match highlight:
		"exposimetro": return Rect2(540,24,215,40)
		"diafragma": return Rect2(main.aperture_button.position,main.aperture_button.size)
		"velocidad": return Rect2(main.shutter_button.position,main.shutter_button.size)
		"iso": return Rect2(main.iso_button.position,main.iso_button.size)
		"nitidez": return Rect2(main.dof_label.position,main.dof_label.size)
		"zoom": return Rect2(main.focal_label.position,Vector2(220,60))
		"disparar": return Rect2(1005,642,248,59)
	return Rect2()

func _draw() -> void:
	if not active or highlight == "": return
	var rect = highlight_rect()
	if rect.size == Vector2.ZERO: return
	var a = .55+.45*sin(pulse*5.0)
	draw_rect(rect.grow(5),Color(.96,.84,.45,a),false,3)
	draw_rect(rect.grow(9),Color(.96,.84,.45,a*.35),false,2)

func handle_key(event: InputEventKey) -> bool:
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
