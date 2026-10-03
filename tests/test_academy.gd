extends SceneTree
# Academia de fotografía (docs/futuro/06): texts, demonstrations, practice criteria and progress.
# Needs a display (the demos shoot real photos):
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_academy.gd
const Main = preload("res://main.tscn")
const Texts = preload("res://scripts/texts.gd")
const Photo = preload("res://scripts/photography.gd")
const TEST_PROGRESS = "user://academia_prueba.cfg"
var checks = 0
var failures = 0
var game
var academy

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func has_text(key: String) -> bool:
	return Texts.get_text(key) != key

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	for i in 10: await process_frame
	academy = game.academy
	academy.progress_path = TEST_PROGRESS
	academy.reset_progress()

	print("· texts")
	# --- Texts: every page, subtitle, task and title is registered ---
	for n in range(1,academy.LESSONS+1):
		check(has_text("academia_l%d_titulo" % n) and has_text("academia_l%d_resumen" % n),"Lesson %d has title and summary" % n)
		for k in range(1,academy.THEORY_PAGES[n]+1):
			check(has_text("academia_l%d_t%d_titulo" % [n,k]) and has_text("academia_l%d_t%d_texto" % [n,k]),"Lesson %d theory page %d" % [n,k])
			var words = Texts.get_text("academia_l%d_t%d_texto" % [n,k]).split(" ").size()
			check(words <= 60,"Lesson %d page %d stays short (%d words)" % [n,k,words])
		check(academy.SETUP[n].pages.size() == academy.THEORY_PAGES[n],"Lesson %d has a diagram per page" % n)
		for k in range(1,academy.TASKS+1): check(has_text("academia_l%d_p%d" % [n,k]),"Lesson %d task %d" % [n,k])
	for key in ["academia_titulo","academia_examen_boton","academia_fase_teoria","academia_fase_demo","academia_fase_practica","academia_boton_inicio"]:
		check(has_text(key),"UI text %s" % key)

	print("· menu")
	# --- Academy menu: five lessons, exam shown as not available ---
	game.show_academy()
	await process_frame
	check(game.mode == "ACADEMY","The Academy menu opens")
	var texts_on_screen = game.modal.find_children("*","Label",true,false).map(func(l): return l.text)
	check(game.modal.find_children("*","Button",true,false).filter(func(b): return b.text == Texts.get_text("academia_examen_boton")).size() == academy.LESSONS,"Each lesson offers its exam")

	print("· theory")
	# --- Theory: pages, highlights and progress ---
	game.close_modal()
	academy.begin(1)
	await process_frame
	check(academy.active and academy.phase == "teoria" and game.mode == "SEARCH","Lesson 1 opens on its theory over the viewfinder")
	check(game.target == null and game.sandbox,"Lessons run on the sandbox (no assignment)")
	check(academy.highlight == "exposimetro","The first page points at the exposure meter")
	for k in academy.THEORY_PAGES[1]-1: academy.go_next()
	check(academy.page == academy.THEORY_PAGES[1]-1 and academy.done(1,"teoria"),"Reaching the last page marks the theory as seen")

	# --- Demonstrations: they run to the end and take the photos they narrate ---
	var expected_photos = {1:1, 2:2, 3:2, 4:1, 5:2, 6:1, 7:2, 8:1, 9:1, 10:1}
	for n in range(1,academy.LESSONS+1):
		print("· demo %d" % n)
		academy.begin(n,"demo")
		var started = Time.get_ticks_msec()
		while not academy.demo_done and Time.get_ticks_msec()-started < 40000:
			await process_frame
		check(academy.demo_done,"Demo %d finishes" % n)
		check(academy.demo_photos.size() == expected_photos[n],"Demo %d takes %d photos (%d)" % [n,expected_photos[n],academy.demo_photos.size()])
		check(academy.done(n,"demo"),"Demo %d is marked as seen" % n)
		check(game.mode == "SEARCH","Demo %d photos stay in the tutor panel (no result screen)" % n)
		var shots: Array = academy.demo_photos.map(func(s): return s.result.evidence)
		match n:
			1:
				check(absf(game.finder.delta_ev) < .5,"Demo 1 ends with the needle back at 0 (%.2f)" % game.finder.delta_ev)
				if not academy.demo_photos.is_empty(): check(absf(academy.demo_photos[0].result.delta) < .6,"Demo 1 photo is well exposed")
			2:
				if shots.size() == 2:
					check(shots[0].n <= 1.81 and shots[1].n >= 10.9,"Demo 2 compares f/1.8 with f/11 (%s, %s)" % [shots[0].n,shots[1].n])
					var d0 = Photo.dof(shots[0].f,shots[0].n,shots[0].s)
					var d1 = Photo.dof(shots[1].f,shots[1].n,shots[1].s)
					check(d1.y-d1.x > (d0.y-d0.x)*4,"Demo 2: the sharp zone grows a lot when closing down")
			3:
				if shots.size() == 2:
					check(shots[0].t >= 1.0/30-.001 and shots[1].t <= 1.0/1000+.0001,"Demo 3 shoots at 1/30 and 1/1000")
					check(shots[0].v > 1.5 and shots[1].v > 1.5,"Demo 3 catches the runner both times (%.2f, %.2f m/s)" % [shots[0].v,shots[1].v])
					check(academy.demo_photos[0].result.drag > academy.demo_photos[1].result.drag*10,"Demo 3: 1/30 leaves a trail, 1/1000 freezes (%.3f / %.3f mm)" % [academy.demo_photos[0].result.drag,academy.demo_photos[1].result.drag])
			5:
				if shots.size() == 2:
					check(shots[0].f <= 28.1 and shots[0].d < 3.0,"Demo 5: 28 mm close (%.1f m)" % shots[0].d)
					check(academy.person_fill(shots[0]) <= 1.3 and academy.person_fill(shots[1]) <= 1.3,"Demo 5: both show the whole body")
					check(shots[1].f >= 134.9 and shots[1].d > 9.0,"Demo 5: 135 mm far (%.1f m)" % shots[1].d)
	Engine.time_scale = 1.0

	print("· practice criteria")
	# --- Practice criteria, from fabricated evidence (deterministic) ---
	var fake = func(e: Dictionary, delta = 0.0, drag = 0.0) -> Dictionary:
		var base = {"f":50.0,"n":8.0,"t":1.0/250,"iso":100,"s":4.0,"d":4.0,"v":0.0}
		base.merge(e,true)
		return {"evidence":base,"delta":delta,"drag":drag,"coc":0.0,"score":80}
	academy.begin(2,"practica")
	academy.on_practice_photo(null,fake.call({"n":2.8,"d":4.0}))
	check(academy.tasks[1] and not academy.tasks[2],"Lesson 2: a photo at f/2.8 ticks the wide-open task")
	academy.on_practice_photo(null,fake.call({"n":11.0,"d":4.0}))
	check(academy.tasks[2],"Lesson 2: then f/11 ticks the comparison")
	check(academy.comparison_photos().size() == 2,"Lesson 2: the result shows both photos side by side")
	academy.begin(3,"practica")
	check(not academy.paused,"Lesson 3 practice: the runner keeps running")
	academy.on_practice_photo(null,fake.call({"t":1.0/250,"v":.2}))
	check(not academy.tasks.any(func(t): return t),"Lesson 3: missing the runner ticks nothing")
	academy.on_practice_photo(null,fake.call({"t":1.0/30,"v":2.8}))
	check(academy.tasks[0],"Lesson 3: runner at 1/30 shows the trail")
	academy.on_practice_photo(null,fake.call({"t":1.0/1000,"v":2.8},2.5))
	check(academy.tasks[1] and not academy.tasks[2],"Lesson 3: frozen but badly exposed is not enough")
	academy.on_practice_photo(null,fake.call({"t":1.0/1000,"v":2.8},.3))
	check(academy.tasks[2] and academy.done(3,"practica"),"Lesson 3: frozen and well exposed completes the practice")
	academy.begin(5,"practica")
	check(academy.paused,"Lesson 5 practice: the scene holds still")
	check(academy.main.people.any(func(p): return p.lane == 3 and p.visible and p.state != "CAMINANDO"),"Lesson 5 practice: someone stands on the outer path for the telephoto")
	academy.on_practice_photo(null,fake.call({"f":28.0,"d":8.0}))
	check(not academy.tasks[0],"Lesson 5: 28 mm on someone far does not count")
	academy.on_practice_photo(null,fake.call({"f":28.0,"d":2.6}))
	check(academy.tasks[0],"Lesson 5: 28 mm close and full body")
	academy.main.pitch = 70.0   # the focus point on the sky: no meadow extra under it either
	academy.main.update_camera()
	academy.on_practice_photo(null,fake.call({"f":135.0,"d":21.0,"person":false}))
	check(not academy.tasks[1],"Lesson 5: the tele on the bandstand (nobody under the point) does not count")
	academy.on_practice_photo(null,fake.call({"f":135.0,"d":11.5}))
	check(academy.tasks[1] and academy.tasks[2],"Lesson 5: 135 mm far completes the comparison")
	check(academy.comparison_photos().size() == 2,"Lesson 5: diptych of the two photos")

	print("· equipment lessons")
	# --- Lessons 6 to 10 (equipment): choices on the panel, practice criteria and exam reports ---
	check(academy.LESSONS >= 10,"The Academy has at least ten lessons")
	academy.begin(6,"teoria")
	for i in 3: await process_frame
	check(game.equipment.body == 0,"Lesson 6 opens with the compact camera in hand")
	academy.page = 2
	academy.update_panel()
	check(game.equipment.body == 1,"…and its rangefinder page hands over the rangefinder")
	academy.page = 4
	academy.update_panel()
	check(game.equipment.body == 3 and game.equipment.tlr(),"…and the TLR page the TLR")
	academy.begin(6,"practica")
	check(academy.extra_buttons.size() == 4,"Lesson 6: four bodies to choose on the panel")
	academy.do_action("body:1")
	check(game.equipment.body == 1 and game.equipment.focus_mode == "MF","Choosing the rangefinder mounts it, manual focus and all")
	academy.on_practice_photo(null,fake.call({"person":true}))
	check(academy.tasks[0] and not academy.tasks[1],"Lesson 6: a sharp photo with the rangefinder ticks its task")
	academy.do_action("body:3")
	var blurred = fake.call({"person":true})
	blurred.coc = .2
	academy.on_practice_photo(null,blurred)
	check(not academy.tasks[1],"Lesson 6: a blurred TLR photo does not count")
	academy.on_practice_photo(null,fake.call({"person":true}))
	academy.do_action("body:2")
	academy.on_practice_photo(null,fake.call({"person":true}))
	check(academy.tasks == [true,true,true] and academy.done(6,"practica"),"Lesson 6: one sharp photo with each of the three bodies passes the practice")
	academy.begin(7,"practica")
	check(game.time_of_day == "blue" and academy.extra_buttons.size() == 2,"Lesson 7 runs at the blue hour with the zoom and the prime on the panel")
	academy.do_action("lens:2:50")
	check(game.equipment.lens_index == 2 and game.apertures()[0] <= 1.81,"The prime opens to f/1.8")
	academy.begin(9,"practica")
	check(game.equipment.metering == "matricial" and game.equipment.exposure_mode() == "A","Lesson 9 starts in A with matrix metering")
	academy.do_action("meter:puntual")
	academy.hint_timer = 0.0
	academy.check_practice(.3)
	check(academy.tasks[0],"Lesson 9: choosing spot metering ticks the first task")
	academy.begin(10,"practica")
	academy.do_action("mode:A")
	academy.on_practice_photo(null,fake.call({"n":2.0}))
	academy.do_action("mode:S")
	academy.on_practice_photo(null,fake.call({"t":1.0/1000}))
	check(academy.tasks[0] and academy.tasks[1] and not academy.tasks[2],"Lesson 10: A wide open and S fast tick their tasks")
	academy.do_action("mode:M")
	academy.on_practice_photo(null,fake.call({},.2))
	check(academy.tasks[2] and game.equipment.exposure_mode() == "M","Lesson 10: a well exposed photo in M completes it")
	var ok_e = {"f":50.0,"n":2.0,"t":1.0/125,"iso":100,"s":4.0,"d":4.0,"v":0.0,"person":true}
	var AcademyScript = academy.get_script()
	check(AcademyScript.exam_report(6,ok_e,{"delta":0.0,"coc":0.0,"body":1,"person":true}).passed and not AcademyScript.exam_report(6,ok_e,{"delta":0.0,"coc":0.0,"body":2,"person":true}).passed,"Exam 6 asks for the rangefinder")
	var grainy = ok_e.duplicate()
	grainy.iso = 800
	check(AcademyScript.exam_report(7,ok_e,{"delta":0.2,"coc":0.0,"person":true}).passed and not AcademyScript.exam_report(7,grainy,{"delta":0.2,"coc":0.0,"person":true}).passed,"Exam 7 asks for ISO 100")
	check(AcademyScript.exam_report(8,ok_e,{"delta":0.0,"sub_in":true,"sub_x":.3,"sub_sharp":true}).passed and not AcademyScript.exam_report(8,ok_e,{"delta":0.0,"sub_in":true,"sub_x":.5,"sub_sharp":true}).passed and not AcademyScript.exam_report(8,ok_e,{"delta":0.0,"sub_in":true,"sub_x":.3,"sub_sharp":false}).passed,"Exam 8 asks for the subject sharp and off-centre")
	check(AcademyScript.exam_report(9,ok_e,{"delta":0.3,"coc":0.0,"metering":"puntual","person":true}).passed and not AcademyScript.exam_report(9,ok_e,{"delta":0.3,"coc":0.0,"metering":"matricial","person":true}).passed,"Exam 9 asks for spot metering")
	check(AcademyScript.exam_report(10,ok_e,{"delta":0.3,"coc":0.0,"mode":"M","person":true}).passed and not AcademyScript.exam_report(10,ok_e,{"delta":0.3,"coc":0.0,"mode":"A","person":true}).passed and not AcademyScript.exam_report(10,ok_e,{"delta":0.8,"coc":0.0,"mode":"M","person":true}).passed,"Exam 10 asks for M and half a stop")

	print("· real practice")
	# --- Lesson 4 for real: the tutor sees a head on a crossing with lead room ---
	academy.begin(4,"practica")
	for i in 20: await process_frame
	var walker = academy.subject
	check(walker != null,"Lesson 4 places a walker")
	if walker:
		# Only the walker counts here: anyone else whose head happened to fall on a crossing made
		# this check pass or fail by chance.
		for other in game.people:
			if other != walker: other.visible = false
		academy.frame_goal = {"who":walker,"x":.5,"y":.5,"snap":true}
		var t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec()-t0 < 1500: await process_frame
		check(academy.thirds_check() == "cruce","Lesson 4: a centred head is not on a crossing")
		academy.frame_goal = {"who":walker,"x":0.0,"y":1.0/3.0,"lead":true}
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec()-t0 < 3000: await process_frame
		check(academy.thirds_check() == "listo","Lesson 4: head on the crossing with lead room (%s)" % academy.thirds_check())
		academy.frame_goal = {}
		for other in game.people: other.visible = true

	# --- A real practice: lesson 1 by hand ---
	academy.begin(1,"practica")
	for i in 5: await process_frame
	var stops = game.apertures()
	game.n_index = stops.find(11.0)
	game.refresh()
	academy.expose_with_shutter()
	var t1 = Time.get_ticks_msec()
	while Time.get_ticks_msec()-t1 < 800: await process_frame   # the tutor checks every 0.25 s
	check(academy.tasks[0] and academy.tasks[1],"Lesson 1: f/11 and the needle at 0 tick the first two tasks")
	await game.take_photo()
	for i in 3: await process_frame
	check(game.mode == "RESULT","A practice photo opens the Academy result")
	check(academy.tasks[2] and academy.done(1,"practica"),"Lesson 1: a well exposed photo completes the practice")
	game.resume_search()
	check(academy.active and game.mode == "SEARCH","Back to the lesson after the result")

	# --- Exams (docs/futuro/06 §2-§3): deterministic reports from fixed evidence ---
	# Every theory page of every lesson opens (highlight and diagram included).
	for n in range(1,academy.LESSONS+1):
		academy.begin(n,"teoria")
		for k in academy.THEORY_PAGES[n]-1: academy.go_next()
		check(academy.page == academy.THEORY_PAGES[n]-1 and academy.title_label.text == Texts.get_text("academia_l%d_t%d_titulo" % [n,academy.THEORY_PAGES[n]]),"Lesson %d: its last theory page opens" % n)
	check(Texts.get_text("academia_l3_t5_texto").contains("barrido") or Texts.get_text("academia_l3_t5_titulo").contains("barrido"),"Lesson 3 teaches panning")
	# The light meter the first lesson points at is really drawn on the top bar.
	academy.begin(1,"teoria")
	for i in 3: await process_frame
	if game.interface_mode == "camara":
		# One interface everywhere: the lesson points at the meter of the camera's own finder.
		check(academy.highlight == "exposimetro" and academy.highlight_rect() == game.camera_body.meter_box and game.camera_body.meter_box.size.x > 60 and game.hud_top.all(func(n): return not n.visible),"Lesson 1 highlights the light meter of the finder, with no classic bars")
		academy.highlight = "velocidad"
		check(academy.highlight_rect() == game.control_strip.chip_rect("t") and academy.highlight_rect().size.x > 60,"…and the shutter speed on the strip of the control in hand")
		academy.highlight = "exposimetro"
	else:
		check(academy.highlight == "exposimetro" and academy.highlight_rect() == Rect2(game.meter_bar.position,game.meter_bar.size) and game.meter_bar.visible and game.meter_bar.size.x > 150,"Lesson 1 highlights the light meter, and the meter is there")
	print("· exams")
	var Academy = academy.get_script()
	for n in range(1,academy.LESSONS+1): check(has_text("academia_l%d_examen" % n),"Lesson %d has its exam statement" % n)
	var exam_base = {"f":50.0,"n":8.0,"t":1.0/125,"iso":400,"s":4.0,"d":4.0,"v":0.0}
	var exam_r1 = Academy.exam_report(1,exam_base,{"delta":.2})
	check(exam_r1.passed and exam_r1.lines.size() == 2 and Academy.exam_report(1,exam_base,{"delta":.2}) == exam_r1,"Exam 1: centred needle and steady hands pass, always the same")
	check(not Academy.exam_report(1,exam_base,{"delta":-3.0}).passed,"Exam 1: three stops under fails")
	var exam_slow = exam_base.duplicate()
	exam_slow.t = 1.0/15
	check(not Academy.exam_report(1,exam_slow,{"delta":0.0}).passed,"Exam 1: 1/15 s with a 50 mm fails for camera shake")
	var exam_two = {"f":105.0,"n":11.0,"t":1.0/125,"iso":800,"s":4.0,"d":4.0,"v":0.0}
	check(Academy.exam_report(2,exam_two,{"delta":0.0,"d_near":4.0,"d_far":4.4,"both":true}).passed,"Exam 2: f/11 focused on the near one holds both")
	var exam_open = exam_two.duplicate()
	exam_open.n = 1.8
	check(not Academy.exam_report(2,exam_open,{"delta":0.0,"d_near":4.0,"d_far":4.4,"both":true}).passed,"Exam 2: wide open, the far one is soft")
	check(not Academy.exam_report(2,exam_two,{"delta":0.0,"d_near":4.0,"d_far":4.4,"both":false}).passed,"Exam 2: both have to be in the photo")
	var exam_zone = Photo.dof(105.0,11.0,4.0)
	check(exam_zone.x <= 4.0 and exam_zone.y >= 4.4 and exam_zone.y < 4.7,"Exam 2 agrees with Photography.dof() (%.2f to %.2f m)" % [exam_zone.x,exam_zone.y])
	var exam_run = {"f":50.0,"n":4.0,"t":1.0/1000,"iso":400,"s":7.0,"d":7.0,"v":2.8}
	check(Academy.exam_report(3,exam_run,{"delta":0.0,"coc":.01}).passed,"Exam 3: the runner frozen at 1/1000 s passes")
	var exam_dragged = exam_run.duplicate()
	exam_dragged.t = 1.0/60
	check(not Academy.exam_report(3,exam_dragged,{"delta":0.0,"coc":.01}).passed,"Exam 3: 1/60 s drags the runner")
	var exam_walker = exam_run.duplicate()
	exam_walker.v = .6
	check(not Academy.exam_report(3,exam_walker,{"delta":0.0,"coc":.01}).passed,"Exam 3: a exam_walker is not the runner")
	check(Academy.exam_report(4,exam_base,{"delta":0.0,"coc":.01,"thirds":"listo"}).passed and not Academy.exam_report(4,exam_base,{"delta":0.0,"coc":.01,"thirds":"aire"}).passed,"Exam 4: the thirds with lead room")
	var exam_tele = {"f":135.0,"n":5.6,"t":1.0/250,"iso":200,"s":11.5,"d":11.5,"v":0.0}
	check(Academy.exam_report(5,exam_tele,{"delta":0.0,"coc":.01,"fill":1.7*135.0/(11.5*20.25)}).passed,"Exam 5: whole body from afar with the 135 mm")
	var exam_wide = exam_tele.duplicate()
	exam_wide.f = 28.0
	check(not Academy.exam_report(5,exam_wide,{"delta":0.0,"coc":.01,"fill":.2}).passed,"Exam 5: the wide angle does not pass")
	check(not Academy.exam_report(5,exam_tele,{"delta":0.0,"coc":.09,"fill":1.0}).passed,"Exam 5: out of focus fails")
	# A real exam: lesson 1, the sky clouds over and the player brings the needle back.
	academy.begin(1,"examen")
	for i in 5: await process_frame
	check(academy.phase == "examen" and game.park.forced_cover == 1.0,"Exam 1 clouds the sky over")
	game.update_meter()
	game.refresh()
	check(game.finder.delta_ev < -2.4 and game.finder.delta_ev > -4.2,"…and the exposure the tutor left is now about 3 EV under, not more (%.1f EV)" % game.finder.delta_ev)
	await game.take_photo()
	for i in 3: await process_frame
	check(game.mode == "RESULT" and not academy.exam_last.passed and academy.exam_attempts == 1 and not academy.done(1,"examen"),"Shooting without correcting fails the exam, with its report")
	game.resume_search()
	academy.expose_correctly()
	game.update_meter()
	await game.take_photo()
	for i in 3: await process_frame
	check(academy.exam_last.passed and academy.done(1,"examen"),"With the needle back at 0 the exam is passed (%d/100)" % academy.exam_last.score)
	var exam_text = "\n".join(game.modal.find_children("*","Label",true,false).map(func(l): return l.text))
	check(exam_text.contains("APROBADO"),"The result screen shows the tutor's report")
	game.resume_search()
	# Exam 2 stages two people at different distances.
	academy.begin(2,"examen")
	for i in 5: await process_frame
	check(is_instance_valid(academy.subject) and is_instance_valid(academy.second) and absf(academy.second.radius-academy.subject.radius-.4) < .01,"Exam 2 stages two people 40 cm apart in depth")
	var exam_ctx = academy.exam_context({"evidence":exam_two,"delta":0.0,"coc":0.0})
	check(exam_ctx.has("d_near") and exam_ctx.d_far > exam_ctx.d_near,"…and measures both distances for the report")
	check(not academy.graduated() and academy.exams_done() == 1,"One exam passed: not a graduate yet")
	for n in range(1,academy.LESSONS+1): academy.mark(n,"examen")
	check(academy.graduated(),"Five exams passed: Graduate of the Academy")
	game.show_academy()
	await process_frame
	check(game.modal.find_children("*","Label",true,false).any(func(l): return l.text.contains(Texts.get_text("academia_graduado"))),"The Academy menu shows the diploma")

	# --- Progress persists ---
	var saved = ConfigFile.new()
	check(saved.load(TEST_PROGRESS) == OK and saved.get_value("leccion_1","practica",false),"Progress is saved to disk")
	academy.load_progress()
	check(academy.done(1,"practica") and academy.practices_done() >= 3,"Progress loads back")
	academy.exit_lesson()
	check(not academy.active and game.mode == "ACADEMY","Leaving a lesson goes back to the Academy menu")
	check(game.people.all(func(p): return p.visible and not p.has_meta("staged")),"Leaving restores everyone in the park")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROGRESS))
	print("ACADEMY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
