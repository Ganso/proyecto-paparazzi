extends SceneTree
const MainScript = preload("res://scripts/main.gd")
const Texts = preload("res://scripts/texts.gd")
# Tutorial mode and the main menu of five modes (docs/futuro/22): walks the whole tutorial doing
# what each step asks. Needs a display.
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_tutorial.gd
var checks = 0
var failures = 0
var game
func check(ok: bool, message: String) -> void:
	checks += 1
	if OS.has_environment("TUT_DEBUG"): print("CHECK ",ok," ",message)
	if not ok:
		failures += 1
		push_error(message)

func frames(n: int) -> void:
	for i in n: await process_frame

func wait_step(name: String, timeout = 3.0) -> bool:
	var t0 = Time.get_ticks_msec()
	# A finished step waits for the player: «Continuar» (here, the same as pressing it).
	var waited_done = false
	while game.tutorial.id() != name and Time.get_ticks_msec()-t0 < timeout*1000:
		if game.tutorial.done_time >= 0.0 and game.mode == "SEARCH":
			if not waited_done:
				waited_done = true
				for i in 30: await process_frame
				stayed = stayed and game.tutorial.id() != name
			if game.tutorial.buttons.size() == 1: game.tutorial.buttons[0].pressed.emit()
		await process_frame
	return game.tutorial.id() == name

var stayed = true   # no step moved on by itself

func nearest_person():
	var best = null
	for p in game.people:
		if not p.visible or p.runner or p.state == "RETIRADO": continue
		var d = p.global_position.length()
		if d > 3.0 and d < 8.0 and (best == null or d < best.global_position.length()): best = p
	return best

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var saved_ui_cfg = FileAccess.get_file_as_string("user://interfaz.cfg") if FileAccess.file_exists("user://interfaz.cfg") else ""
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.exposure_thirds = false   # (not the player's option)
	await frames(30)
	# Main menu: five modes, changed with the arrows.
	game.intro()
	await frames(3)
	var menu = game.modal
	check(menu.MODES == ["tutorial","arcade","sandbox","academia","opciones","historia"],"The menu has the six modes (Historia announced)")
	menu.current = 5
	menu.build_card()
	check(not menu.enter_callback.is_valid(),"Historia cannot be entered yet")
	menu.current = 0
	menu.build_card()
	var first = menu.current
	var right = InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	menu._input(right)
	check(menu.current == (first+1)%6,"→ changes the mode")
	var pad_left = InputEventJoypadButton.new()
	pad_left.button_index = JOY_BUTTON_DPAD_LEFT
	pad_left.pressed = true
	menu._input(pad_left)
	check(menu.current == first,"D-pad ← changes it back")
	menu.current = 0
	menu.build_card()
	await frames(2)
	check(menu.enter_callback.is_valid(),"The tutorial card has its Enter")
	menu.enter_callback.call()
	await frames(5)
	check(game.tutorial.active and game.mode == "SEARCH" and game.tutorial.id() == "bienvenida","Entering the tutorial starts it")
	var enter = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	game._unhandled_input(enter)
	check(game.tutorial.id() == "mirar","Enter moves on from the welcome")
	game.angle += 70.0
	game.update_camera()
	await frames(6)
	check(game.tutorial.done_time < 0.0,"Looking to the sides alone does not complete «mirar»")
	game.pitch += 20.0
	game.update_camera()
	check(await wait_step("zoom"),"Looking to the sides and up and down completes «mirar»")
	game.focal = 90.0
	game.update_camera()
	await frames(3)
	game.focal = 30.0
	game.update_camera()
	check(await wait_step("bajar"),"Zooming in and out completes «zoom»")
	game.toggle_raise()
	await create_timer(.5).timeout
	game.toggle_raise()
	check(await wait_step("af"),"Lowering and raising the camera completes «bajar»")
	var p = nearest_person()
	game.pitch = 0.0
	game.focal = 50.0
	game.aim_at(p,1.0)
	game.finder.active = 4
	await frames(2)
	game.autofocus()
	game.control_help.set_enabled(false)
	check(await wait_step("ayuda"),"Focusing on someone completes «af»")
	check(game.control_help.enabled,"The step about the on-screen help turns it on")
	game.control_help.set_enabled(not game.control_help.enabled)
	await frames(4)
	game.control_help.set_enabled(not game.control_help.enabled)
	check(await wait_step("disparar"),"Hiding and showing the help completes «ayuda»")
	await game.take_photo()
	check(game.mode == "RESULT" and game.current_result.get("tutorial_note","") != "","The tutorial's photo shows its note")
	game.resume_search()
	check(await wait_step("encargo"),"A photo completes «disparar»")
	check(game.target != null and not game.target.runner and game.briefing.text.begins_with("Busca"),"The assignment has a subject and its description")
	# Frame the subject well and shoot until it passes.
	var passed = false
	for attempt in 40:
		await frames(8)
		if game.mode == "RESULT": game.resume_search()
		var t = game.target
		var d = game.camera.global_position.distance_to(t.control_points()[1])
		game.focal = clampf(.7*20.25*d/t.height,game.equipment.lens().min,game.equipment.lens().max)
		game.aim_at(t,1.0)
		await physics_frame
		var e = game.capture_evidence()
		game.focus_distance = e.d_eyes
		await game.take_photo()
		if game.tutorial.done_time >= 0.0 or game.tutorial.id() != "encargo":
			passed = true
			break
	game.resume_search()
	check(passed and await wait_step("diafragma"),"A good photo of the subject completes «encargo»")
	check(game.equipment.exposure_mode() == "A","«diafragma» puts the camera in aperture priority")
	# Two changes: one way and back (the compact's aperture range is short).
	var dir = 1 if game.n_index < game.apertures().size()-1 else -1
	game.change_parameter("n",dir)
	await frames(3)
	game.change_parameter("n",-dir)
	check(await wait_step("mf"),"Changing the aperture twice completes «diafragma»")
	check(game.equipment.focus_mode == "MF","«mf» puts the camera in manual focus")
	p = nearest_person()
	game.aim_at(p,1.0)
	game.focal = 50.0
	game.update_camera()
	game.set_manual_focus(game.camera.global_position.distance_to(p.control_points()[1]))
	for i in 60:
		game.aim_at(p,1.0)
		game.set_manual_focus(game.camera.global_position.distance_to(p.control_points()[1]))
		await process_frame
		if game.tutorial.done_time >= 0.0: break
	check(await wait_step("paseo",3.0),"Matching the split image completes «mf»")
	# The last steps are in the big park: the scene reloads there (here, a second game).
	var Tutorial = preload("res://scripts/tutorial.gd")
	check(Tutorial.resume_step == Tutorial.STEPS.find("paseo"),"The tutorial asks to go on in the big park")
	game.queue_free()
	await frames(3)
	MainScript.scenario = "grande"
	MainScript.pending_start = {"tutorial":true}
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(40)
	check(game.crowd != null and game.tutorial.active and game.tutorial.id() == "paseo" and not game.camera_raised,"…and resumes there on foot, camera down")
	game.player.position += Vector3(4.5,0,0)
	await frames(3)
	game.player.position += Vector3(4.5,0,0)
	check(await wait_step("sacar"),"Walking a few metres completes «paseo»")
	game.toggle_raise()
	check(await wait_step("foto_paseo",4.0),"Bringing the camera to the eye completes «sacar»")
	await game.take_photo()
	check(game.current_result.get("tutorial_note","") == Texts.get_text("tutorial_resultado_paseo"),"The photo on foot shows its note")
	game.resume_search()
	await frames(5)
	check(game.tutorial.done_time < 0.0,"…but the step waits until the camera is lowered again")
	game.toggle_raise()
	check(await wait_step("fin",4.0),"Lowering the camera completes «foto_paseo»")
	await frames(3)
	check(game.mode == "TUTORIAL_END" and not game.tutorial.visible,"The end is a screen of its own")
	check(stayed,"A finished step waits for «Continuar» instead of moving on by itself")
	check(game.modal.find_children("*","Button",true,false).size() == 4,"…that offers the Arcade, the Academy, the tutorial again and the menu")
	game.tutorial.stop()
	game.intro()
	print("TUTORIAL TESTS: %d checks, %d failures" % [checks,failures])
	if saved_ui_cfg != "":
		var f = FileAccess.open("user://interfaz.cfg",FileAccess.WRITE)
		f.store_string(saved_ui_cfg)
		f.close()
	quit(0 if failures == 0 else 1)
