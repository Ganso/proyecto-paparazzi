extends SceneTree
# The touch interface (scripts/touch_controls.gd, docs/futuro/13): the fingers do everything.
# Simulated touches on the desktop. With display:
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_touch.gd
const Main = preload("res://main.tscn")
const MainScript = preload("res://scripts/main.gd")
const Glyphs = preload("res://scripts/input_glyphs.gd")
const Texts = preload("res://scripts/texts.gd")
var checks = 0
var failures = 0
var game

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(n: int) -> void:
	for i in n: await process_frame

func touch(index: int, at: Vector2, pressed: bool) -> void:
	var e = InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	root.push_input(e)

func drag(index: int, from: Vector2, to: Vector2, steps = 6) -> void:
	for k in steps:
		var e = InputEventScreenDrag.new()
		e.index = index
		e.position = from.lerp(to,float(k+1)/steps)
		e.relative = (to-from)/steps
		root.push_input(e)
		await process_frame

func press(b: Button) -> void:
	b.button_down.emit()
	b.pressed.emit()
	b.button_up.emit()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Glyphs.touch = true
	Glyphs.device = "tactil"
	game = Main.instantiate()
	root.add_child(game)
	await frames(30)
	game.pad_polling = false
	var tc = game.touch_controls
	check(game.interface_mode == "camara","The touch interface sits on the camera interface, as every device")
	# --- Searching ---
	game.intro()
	game.arcade_level = -1
	game.equipment.preset(2)
	game.equipment.set_exposure_mode("M")
	game.apply_equipment()
	game.start_session("day",true)
	await frames(10)
	Glyphs.device = "tactil"
	await frames(3)
	check(tc.visible and tc.buttons.disparar.visible and tc.buttons.af.visible and tc.buttons.pausa.visible and tc.buttons.camara.visible,"Searching shows shutter, AF, pause and camera buttons")
	check(not game.control_help.toggle.visible and not game.control_help.raise_button.visible and game.control_help.panel_rect.size == Vector2.ZERO,"No list of keys nor keyboard buttons with the fingers")
	for b in tc.buttons.values():
		if b.visible: check(b.size.x >= 84 and b.size.y >= 56,"Touch button «%s» is big enough (%s)" % [b.text,str(b.size)])
	var centre: Vector2 = game.view_rect.get_center()
	var a0 = game.angle
	var p0 = game.pitch
	touch(0,centre,true)
	await drag(0,centre,centre+Vector2(-160,60))
	touch(0,centre+Vector2(-160,60),false)
	await frames(2)
	check(absf(angle_difference(deg_to_rad(a0),deg_to_rad(game.angle))) > .02 and absf(game.pitch-p0) > .5,"One finger drags the view (%.1f° → %.1f°)" % [a0,game.angle])
	# The finger drags the scene: to the left it turns the view right, downwards it looks up.
	var a1 = game.angle
	var p1 = game.pitch
	touch(0,centre,true)
	await drag(0,centre,centre+Vector2(-100,80))
	touch(0,centre+Vector2(-100,80),false)
	var turned = angle_difference(deg_to_rad(a1),deg_to_rad(game.angle))
	check(turned > 0 and game.pitch > p1,"The finger drags the scene on both axes")
	game.look_invert = "ambos"
	a1 = game.angle
	p1 = game.pitch
	touch(0,centre,true)
	await drag(0,centre,centre+Vector2(-100,80))
	touch(0,centre+Vector2(-100,80),false)
	check(angle_difference(deg_to_rad(a1),deg_to_rad(game.angle)) < 0 and game.pitch < p1,"«Invertir mirada: Ambos» turns both axes round")
	game.look_invert = "v"
	check(game.look_sign() == Vector2(1,-1) and game.INVERT_CHOICES == ["no","h","v","ambos"],"…and it can be only sideways or only up and down")
	game.look_invert = "no"
	var f0 = game.focal
	touch(0,centre+Vector2(-60,0),true)
	touch(1,centre+Vector2(60,0),true)
	await drag(1,centre+Vector2(60,0),centre+Vector2(260,0))
	touch(0,centre+Vector2(-60,0),false)
	touch(1,centre+Vector2(260,0),false)
	await frames(2)
	check(game.focal > f0+5.0,"Two fingers pinch the zoom (%.0f → %.0f mm)" % [f0,game.focal])
	game.finder.active = 4
	var corner: Vector2 = game.finder.points()[0]
	touch(0,corner,true)
	touch(0,corner,false)
	await frames(3)
	check(game.finder.active == 0,"A tap picks the focus point under the finger and focuses")
	# The strip: tap a control, change it with − and +.
	await frames(3)
	var strip = game.control_strip
	check(strip.visible and strip.plus.visible and strip.minus.visible and strip.chips[0].size.y >= 56,"The strip shows − and + and tall chips")
	var k = strip.ids.find("n")
	strip.chips[k].pressed.emit()
	var n0 = game.n_index
	press(strip.plus)
	check(game.current_control() == "n" and game.n_index == mini(n0+1,game.apertures().size()-1),"Tap the aperture on the strip and + closes it one stop")
	press(strip.minus)
	check(game.n_index == n0,"− opens it back")
	press(tc.buttons.tercios)
	check(game.finder.thirds,"«Tercios» shows the grid")
	press(tc.buttons.bloqueo)
	check(game.exposure_locked,"«Bloqueo» locks focus and exposure")
	press(tc.buttons.bloqueo)
	var metering = game.equipment.metering
	press(tc.buttons.medicion)
	check(game.equipment.metering != metering,"The metering button changes the metering mode")
	press(tc.buttons.camara)
	await frames(30)
	check(not game.camera_raised and not tc.buttons.disparar.visible,"«Cámara» lowers the camera, and the shutter goes away")
	press(tc.buttons.camara)
	await create_timer(.6).timeout
	check(game.eye_ready(),"…and raises it again")
	press(tc.buttons.disparar)
	await frames(40)
	check(game.mode == "RESULT","● takes the photo")
	game.resume_search()
	press(tc.buttons.ayuda)
	await frames(2)
	check(game.mode == "HELP" and game.modal.find_children("*","Label",true,false).any(func(l): return l.text == Texts.get_text("ayuda_titulo_tactil")),"«Ayuda» lists the touch gestures, not a keyboard")
	game.resume_search()
	check(Texts.get_text("academia_exposicion_t2_texto").contains("− y +") and not Texts.get_text("academia_exposicion_t2_texto").contains("Q"),"Help texts name the touch controls, not keys")
	# TLR: loupe and crank.
	game.equipment.preset(3)
	game.apply_equipment()
	await frames(4)
	check(tc.buttons.lupa.visible,"The TLR adds the loupe")
	press(tc.buttons.lupa)
	check(game.tlr_loupe,"…and it works")
	press(tc.buttons.lupa)
	# --- Tutorial with the fingers ---
	game.intro()
	game.start_tutorial()
	await frames(5)
	check(game.tutorial.body.rich == Texts.get_rich("tutorial_bienvenida_tactil"),"The tutorial speaks of touches")
	game.tutorial.step = game.tutorial.STEPS.find("ayuda")
	game.tutorial.enter_step()
	check(game.tutorial.id() == "disparar","…and skips the step about the list of keys")
	game.tutorial.stop()
	# --- Academy ---
	game.academy.progress_path = "user://academia_touch_test.cfg"
	game.academy.reset_progress()
	game.academy.begin(game.academy.ORDER.find("exposicion")+1,"teoria")
	await frames(4)
	check(tc.buttons.pausa.visible and not tc.buttons.disparar.visible,"Theory: only the pause (the camera is not the player's yet)")
	game.academy.set_phase("practica")
	await frames(4)
	check(tc.buttons.disparar.visible and tc.buttons.disparar.position.x+tc.buttons.disparar.size.x <= game.academy.panel.position.x,"Practice: the shutter is there, left of the lesson's panel")
	check(strip.plus.position.x+strip.plus.size.x <= tc.buttons.disparar.position.x,"…and the strip's + is not under it")
	game.academy.exit_lesson()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://academia_touch_test.cfg"))
	# --- Big park: the stick walks, a finger looks ---
	game.queue_free()
	await frames(3)
	MainScript.scenario = "grande"
	MainScript.pending_start = {}
	game = Main.instantiate()
	root.add_child(game)
	await frames(30)
	game.pad_polling = false
	game.start_session("day",true)
	await frames(10)
	Glyphs.device = "tactil"
	tc = game.touch_controls
	await frames(3)
	check(tc.visible and tc.buttons.camara.visible and not tc.buttons.disparar.visible and not game.walk_hint.visible,"Walking: the camera button, no shutter, no keyboard hints")
	var start: Vector3 = game.player.position
	var stick: Vector2 = tc.STICK_CENTRE
	touch(0,stick,true)
	await drag(0,stick,stick+Vector2(0,-70),3)
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec()-t0 < 1500: await process_frame
	check(game.player.position.distance_to(start) > .5,"The stick walks (%.1f m)" % game.player.position.distance_to(start))
	var look0 = game.angle
	touch(1,Vector2(800,300),true)
	await drag(1,Vector2(800,300),Vector2(600,300))
	touch(1,Vector2(600,300),false)
	check(absf(angle_difference(deg_to_rad(look0),deg_to_rad(game.angle))) > .1,"…while another finger looks around")
	touch(0,stick+Vector2(0,-70),false)
	await frames(3)
	check(game.touch_move == Vector2.ZERO,"Letting go stops")
	press(tc.buttons.camara)
	await create_timer(.7).timeout
	await frames(3)
	check(game.eye_ready() and tc.buttons.disparar.visible,"«Cámara» brings the camera to the eye")
	print("TOUCH TESTS: %d checks, %d failures" % [checks,failures])
	Glyphs.touch = false
	quit(0 if failures == 0 else 1)
