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
	for key in ["academia_titulo","academia_examen_no_disponible","academia_fase_teoria","academia_fase_demo","academia_fase_practica","academia_boton_inicio"]:
		check(has_text(key),"UI text %s" % key)

	print("· menu")
	# --- Academy menu: five lessons, exam shown as not available ---
	game.show_academy()
	await process_frame
	check(game.mode == "ACADEMY","The Academy menu opens")
	var texts_on_screen = game.modal.find_children("*","Label",true,false).map(func(l): return l.text)
	check(texts_on_screen.count(Texts.get_text("academia_examen_no_disponible")) == academy.LESSONS,"Each lesson shows its exam as not available")

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
	var expected_photos = {1:1, 2:2, 3:2, 4:1, 5:2}
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

	print("· real practice")
	# --- Lesson 4 for real: the tutor sees a head on a crossing with lead room ---
	academy.begin(4,"practica")
	for i in 20: await process_frame
	var walker = academy.subject
	check(walker != null,"Lesson 4 places a walker")
	if walker:
		academy.frame_goal = {"who":walker,"x":.5,"y":.5,"snap":true}
		var t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec()-t0 < 1500: await process_frame
		check(academy.thirds_check() == "cruce","Lesson 4: a centred head is not on a crossing")
		academy.frame_goal = {"who":walker,"x":0.0,"y":1.0/3.0,"lead":true}
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec()-t0 < 3000: await process_frame
		check(academy.thirds_check() == "listo","Lesson 4: head on the crossing with lead room (%s)" % academy.thirds_check())
		academy.frame_goal = {}

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
