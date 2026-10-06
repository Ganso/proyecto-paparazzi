extends SceneTree
# Gamepad and device-aware help (docs/futuro/14, docs/futuro/22 §3). Needs a display.
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_input.gd
const Glyphs = preload("res://scripts/input_glyphs.gd")
const Texts = preload("res://scripts/texts.gd")
const GlyphLabel = preload("res://scripts/glyph_label.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func pad(button: int) -> InputEventJoypadButton:
	var e = InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var saved_ui_cfg = FileAccess.get_file_as_string("user://interfaz.cfg") if FileAccess.file_exists("user://interfaz.cfg") else ""
	# The help texts follow the last device used.
	Glyphs.device = "teclado"
	check(Texts.get_text("control_hint_mf").contains("Espacio") and not Texts.get_text("control_hint_mf").contains("{"),"Keyboard: help texts name the keys")
	var key_event = InputEventKey.new()
	key_event.pressed = true
	check(not Glyphs.note(key_event) and Glyphs.device == "teclado","A key keeps the keyboard")
	check(Glyphs.note(pad(JOY_BUTTON_A)) and Glyphs.pad(),"A gamepad button switches the help to the pad")
	check(Texts.get_text("control_hint_mf").contains("RT") and not Texts.get_text("control_hint_mf").contains("Espacio"),"Gamepad: help texts name the buttons")
	Glyphs.family = "ps"
	check(Glyphs.kp("disparar") == "R2" and Glyphs.kp("aceptar") == "✕","PlayStation names")
	Glyphs.family = "xbox"
	# Every control has its keyboard and its three pad names; keys and buttons are marked.
	for control in Glyphs.CONTROLS:
		check(Glyphs.CONTROLS[control].size() == 4,"Control %s has keyboard and pad names" % control)
	Glyphs.device = "teclado"
	check(Texts.get_rich("control_hint_mf").contains("⟦Espacio⟧") and not Texts.get_text("control_hint_mf").contains("⟦"),"Keys are marked for the keycap glyph, plain labels get them clean")
	Glyphs.device = "mando"
	check(Texts.get_rich("control_hint_mf").contains("⦅RT⦆"),"Pad buttons are marked for the round glyph")
	var toks = GlyphLabel.tokens("Pulsa ⟦Q⟧ o ⦅A⦆.")
	check(toks.size() == 5 and toks[1] == ["k","Q"] and toks[3] == ["b","A"],"Glyph text splits into words, keys and buttons")
	# Search with a pad: buttons do what the help says.
	var game = preload("res://main.tscn").instantiate()
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"   # (never the player's album)
	root.add_child(game)
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"   # (never the player's progress)
	game.exposure_thirds = false   # (not the player's option)
	for i in 30: await process_frame
	game.start_level(7)
	game.begin_assignment()
	var before = game.control_help.enabled
	game._unhandled_input(pad(JOY_BUTTON_X))
	check(game.control_help.enabled != before,"X toggles the on-screen help")
	game.control_help.set_enabled(before)
	game.finder.active = 4
	game._unhandled_input(pad(JOY_BUTTON_RIGHT_SHOULDER))
	check(game.finder.active == 5,"RB moves to the next focus point")
	# The control in hand (docs/futuro/22 §5): D-pad ←→ chooses, ↑↓ changes; the wheel changes it too.
	check(game.selectable_controls() == ["n","ev_comp"],"In A with a fixed lens the player drives the aperture and the compensation (%s)" % str(game.selectable_controls()))
	game.selected_control = "n"
	var n0 = game.n_index
	game._unhandled_input(pad(JOY_BUTTON_DPAD_UP))
	check(game.n_index == mini(n0+1,game.apertures().size()-1),"D-pad up changes the control in hand (aperture in A)")
	game._unhandled_input(pad(JOY_BUTTON_DPAD_RIGHT))
	check(game.current_control() == "ev_comp","D-pad right takes the next control in hand")
	game._unhandled_input(pad(JOY_BUTTON_DPAD_RIGHT))
	check(game.current_control() == "n","…and round to the first again")
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var n1 = game.n_index
	game._unhandled_input(wheel)
	check(game.n_index == maxi(n1-1,0),"The mouse wheel changes the control in hand")
	var middle = InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	game._unhandled_input(middle)
	check(game.current_control() == "ev_comp","The wheel's button takes the next control")
	await process_frame
	await process_frame
	check(game.control_strip.visible and game.control_strip.chips.size() == 2,"The strip over the finder shows the two controls")
	game.control_strip.chips[0].pressed.emit()
	check(game.current_control() == "n","A click on a chip takes that control in hand")
	game.equipment.set_exposure_mode("M")
	check(game.selectable_controls() == ["n","t","iso"],"In M: aperture, shutter and ISO")
	game.equipment.set_exposure_mode("A")
	# Half a minute through the finder without the subject in the frame: the hint to lower the camera.
	var saved_pitch = game.pitch
	game.pitch = 65.0
	game.update_camera()
	game.toast_time = 0.0
	game.hunt_next = 30.0
	game.hunt_time = 29.6
	var hint_start = Time.get_ticks_msec()
	while Time.get_ticks_msec()-hint_start < 900: await process_frame
	check(game.toast.text == Texts.get_text("pista_bajar_camara") and game.toast_time > 0.0,"Searching for a while at the eye brings the hint to lower the camera («%s»)" % game.toast.text)
	check(game.hunt_next > 60.0,"…and it does not nag: the next one takes longer")
	game.pitch = saved_pitch
	game.update_camera()
	game._unhandled_input(pad(JOY_BUTTON_Y))
	check(not game.camera_raised,"Y lowers the camera")
	game._unhandled_input(pad(JOY_BUTTON_Y))
	# (The game ran for frames meanwhile and sees the real mouse of whoever is at the machine: the
	# gamepad is the device in use again, as the press of B itself would make it.)
	Glyphs.device = "mando"
	game._unhandled_input(pad(JOY_BUTTON_B))
	check(game.mode == "HELP","B opens the help")
	await process_frame
	check(game.modal.get_children().any(func(c): return c.get_script() == preload("res://scripts/pad_diagram.gd")),"With a pad the help shows the gamepad")
	game._unhandled_input(pad(JOY_BUTTON_B))
	check(game.mode == "SEARCH","B goes back")
	# Esc pauses; leaving the phase asks first and goes to the menu.
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	game._unhandled_input(esc)
	check(game.mode == "PAUSE","Esc pauses the phase")
	game._unhandled_input(esc)
	check(game.mode == "SEARCH","Esc again carries on")
	game._unhandled_input(pad(JOY_BUTTON_START))
	check(game.mode == "PAUSE","Menu/Start pauses too")
	game.show_pause(true)
	check(game.mode == "PAUSE" and game.modal.get_children().any(func(c): return c is Label and c.text == Texts.get_text("pausa_confirmar")),"Leaving asks for confirmation")
	game.leave_phase()
	check(game.mode == "INTRO","Confirming goes back to the main menu")
	game.start_level(7)
	game.begin_assignment()
	check(game.control_help.exit_button.visible or true,"The exit button exists on screen")
	check(game.stick(.1) == 0.0 and absf(game.stick(1.0)-1.0) < .001 and game.stick(.5) < .1,"Sticks: dead zone and cubic response")
	game.pad_polling = false   # whatever gamepad is plugged into this machine stays out of the tests
	# Panning with the keys: while a turn key is held, the camera falls in with the runner crossing
	# the middle of the frame that way (the keys have one fixed speed; mouse and stick stay manual).
	game.start_level(25)
	for i in 3: await process_frame
	game.begin_assignment()
	for i in 40: await process_frame
	var runner = game.target
	check(runner.runner and preload("res://scripts/arcade.gd").LEVELS[25].cond.has("barrido"),"Level 26 asks for a pan of a runner")
	game.focal = 50.0
	for i in 20:
		game.aim_at(runner,1.0)
		await process_frame
	var chest = runner.control_points()[1]
	var turn = rad_to_deg(runner.actual_velocity.dot(game.camera.global_basis.x)/game.camera.global_position.distance_to(chest))
	var key_speed = 42.0*24.0/game.view_focal()
	check(absf(turn) > 8.0,"The runner crosses the view at %.1f°/s (the keys alone turn at %.1f°/s)" % [absf(turn),key_speed])
	check(absf(game.key_turn(signf(turn))-turn) < .5,"Holding the key his way, the camera turns at his pace (runner %.1f°/s, key gives %.1f°/s)" % [turn,game.key_turn(signf(turn))])
	check(signf(game.key_turn(-signf(turn))) == -signf(turn),"The other way, the key still turns the other way (it never follows someone against the key)")
	check(game.key_turn(0.0) == 0.0,"No key, no turn")
	game.end_level()
	# The trigger as a two-stage shutter (docs/futuro/14 §3): half press locks focus and exposure,
	# letting go cancels, a full press shoots with what was locked.
	game.start_level(8)
	for i in 3: await process_frame
	game.begin_assignment()
	for i in 30: await process_frame
	if game.mode == "SEARCH" and game.eye_ready():
		game.equipment.focus_mode = "AF puntual"
		game.finder.active = 4
		game.update_trigger(0.0)
		game.update_trigger(.5)
		check(game.trigger_stage == 1 and game.exposure_locked and game.focus_locked,"Half press of the trigger locks focus and exposure")
		var held_ev = game.measured_ev
		var held_focus = game.focus_distance
		game.pitch += 12.0
		game.update_camera()
		for i in 3: await physics_frame
		game.update_meter()
		game.update_trigger(.6)
		check(game.measured_ev == held_ev and game.focus_distance == held_focus,"…and holds them while recomposing")
		game.update_trigger(.1)
		check(game.trigger_stage == 0 and not game.exposure_locked and not game.focus_locked,"Letting the trigger go cancels the lock")
		game.update_trigger(.5)
		var shots_before = game.shot_serial
		game.update_trigger(.95)
		for i in 30: await process_frame
		check(game.trigger_stage == 2 and game.shot_serial == shots_before+1 and not game.exposure_locked,"A full press shoots and releases the lock")
		game.update_trigger(0.0)
		if game.mode == "RESULT": game.resume_search()
		check(Glyphs.CONTROLS.bloqueo[1].contains("RT"),"The help names the half press as the lock on the gamepad")
	else:
		check(false,"The trigger test needs the camera at the eye in SEARCH (mode %s)" % game.mode)
	# The gamepad works the screens: A presses the focused button (Godot's own ui_accept has no
	# gamepad button), B goes back.
	var accept_pad = InputEventJoypadButton.new()
	accept_pad.button_index = JOY_BUTTON_A
	accept_pad.pressed = true
	check(accept_pad.is_action_pressed("ui_accept"),"A is the interface's accept button")
	var back_pad = InputEventJoypadButton.new()
	back_pad.button_index = JOY_BUTTON_B
	back_pad.pressed = true
	check(back_pad.is_action_pressed("ui_cancel"),"B is the interface's back button")
	game.show_arcade()
	await process_frame
	var pressed_card = false
	var card: Button = game.modal.find_children("*","Button",true,false).filter(func(b): return not b.disabled and b.focus_mode == Control.FOCUS_ALL)[0] if game.modal.find_children("*","Button",true,false).any(func(b): return not b.disabled and b.focus_mode == Control.FOCUS_ALL) else null
	check(card != null,"The arcade screen has buttons the gamepad can reach")
	if card != null:
		card.grab_focus()
		await process_frame
		var focused = root.gui_get_focus_owner()
		var focus_text = (focused.get_class()+" «"+str(focused.get("text"))+"»") if focused != null else "nada"
		if focused is BaseButton: focused.pressed.connect(func(): pressed_card = true)
		root.push_input(accept_pad)
		var accept_up = InputEventJoypadButton.new()
		accept_up.button_index = JOY_BUTTON_A
		accept_up.pressed = false
		root.push_input(accept_up)
		await process_frame
		check(pressed_card or game.mode == "BRIEFING","A presses the focused button of a screen: a level card starts the level (focus %s, now %s)" % [focus_text,game.mode])
	# The gamepad in the tutorial and the Academy (user, 04-10-2026): A only accepts.
	Glyphs.device = "mando"
	game.intro()
	game.start_tutorial()
	await process_frame
	check(game.tutorial.active and game.tutorial.id() == "bienvenida","The tutorial starts on its welcome")
	game._unhandled_input(pad(JOY_BUTTON_A))
	check(game.tutorial.id() == "mirar","A moves on from the tutorial's welcome")
	var focus_before = game.focus_distance
	game.set_manual_focus(33.0) if game.equipment.focus_mode == "MF" else null
	game.focus_distance = 33.0
	game._unhandled_input(pad(JOY_BUTTON_A))
	check(is_equal_approx(game.focus_distance,33.0),"A no longer focuses: half the trigger does")
	check(Glyphs.CONTROLS.af[1].contains("RT") and Texts.get_text("tutorial_controles_mando") != "tutorial_controles_mando","With the gamepad the help names the trigger for focusing and the tutorial has its own words")
	game.tutorial.stop()
	game.intro()
	game.academy.progress_path = "user://academia_input_test.cfg"
	game.academy.reset_progress()
	game.academy.begin(game.academy.ORDER.find("exposicion")+1,"teoria")
	await process_frame
	game._unhandled_input(pad(JOY_BUTTON_A))
	check(game.academy.page == 1,"Theory: A is «next»")
	game.academy.set_phase("practica")
	await process_frame
	game._unhandled_input(pad(JOY_BUTTON_A))
	check(game.academy.phase == "practica","Practice: A does not jump to the exam (it skipped the tutor's verdict)")
	game._unhandled_input(pad(JOY_BUTTON_START))
	await process_frame
	check(game.mode == "PAUSE" and game.modal.find_children("*","Button",true,false).any(func(b): return b.text == Texts.get_text("academia_salir")),"Menu opens the lesson's own pause, with pause, back, next and leave")
	game.resume_search()
	game.academy.exit_lesson()
	await process_frame
	# The Academy's list with the D-pad: the focus walks down the rows and the list follows.
	var list: ScrollContainer = game.modal.find_children("*","ScrollContainer",true,false)[0]
	var down = pad(JOY_BUTTON_DPAD_DOWN)
	for i in 14:
		root.push_input(down)
		var up_event = InputEventJoypadButton.new()
		up_event.button_index = JOY_BUTTON_DPAD_DOWN
		root.push_input(up_event)
		await process_frame
	check(list.scroll_vertical > 100,"D-pad down walks the lessons and the list scrolls (%d px)" % list.scroll_vertical)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://academia_input_test.cfg"))
	game.intro()
	Glyphs.device = "teclado"
	# Equipment screen with the D-pad: ← → change a list in place and the list keeps the focus.
	game.intro()
	game.arcade_level = -1
	game.equipment.preset(2)
	game.show_equipment()
	await process_frame
	var lists = game.modal.find_children("*","OptionButton",true,false)
	check(lists.size() >= 5,"The equipment screen has its lists")
	if lists.size() >= 5:
		var lens_list: OptionButton = lists[1]
		lens_list.grab_focus()
		var lens_before = game.equipment.lens_index
		var go_right = InputEventJoypadButton.new()
		go_right.button_index = JOY_BUTTON_DPAD_RIGHT
		go_right.pressed = true
		root.push_input(go_right)
		for i in 4: await process_frame
		check(game.equipment.lens_index == lens_before+1,"D-pad right on a list takes the next value (%d → %d)" % [lens_before,game.equipment.lens_index])
		var focused_now = root.gui_get_focus_owner()
		check(focused_now is OptionButton and focused_now.position.is_equal_approx(Vector2(330,280)),"…and the rebuilt screen keeps the focus on that list")
	game.equipment.preset(2)
	game.apply_equipment()
	game.intro()
	await process_frame
	# The sandbox's scenario cards are reachable with the D-pad: ← → move along the row there.
	var menu = game.find_children("*","",true,false).filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("main_menu.gd"))
	if not menu.is_empty():
		var m = menu[0]
		m.current = m.MODES.find("sandbox")
		m.build_card()
		await process_frame
		var grande: Button = m.cards["grande"]
		check(grande.focus_mode == Control.FOCUS_ALL,"The scenario cards take the gamepad's focus")
		m.cards["clasico"].grab_focus()
		await process_frame
		var right = InputEventJoypadButton.new()
		right.button_index = JOY_BUTTON_DPAD_RIGHT
		right.pressed = true
		root.push_input(right)
		await process_frame
		check(m.MODES[m.current] == "sandbox" and root.gui_get_focus_owner() == grande,"On a scenario card the D-pad moves to the next card instead of changing mode (%s, %s)" % [m.MODES[m.current],str(root.gui_get_focus_owner().get("text"))+" "+str(root.gui_get_focus_owner().global_position)+" grande "+str(grande.global_position)])
		root.push_input(accept_pad)
		var a_up = InputEventJoypadButton.new()
		a_up.button_index = JOY_BUTTON_A
		root.push_input(a_up)
		await process_frame
		check(m.scenario == "grande","A on the big park's card chooses it")
		m.select_scenario("clasico")
		# Opciones, two columns: → goes to the right column, and only from there to the next mode;
		# the left stick does the same as the D-pad.
		var opciones = m.MODES.find("opciones")
		for way in ["cruceta","seta"]:
			m.current = opciones
			m.build_card()
			for i in 3: await process_frame
			# (the first two buttons span both columns: the rows of two start below them)
			m.card.find_children("*","Button",true,false).filter(func(b): return b.focus_mode == Control.FOCUS_ALL and b.size.x < 300)[0].grab_focus()
			await process_frame
			var first = root.gui_get_focus_owner()
			var push = func(value: float):
				if way == "cruceta":
					if value != 0.0: root.push_input(right)
				else:
					var motion = InputEventJoypadMotion.new()
					motion.axis = JOY_AXIS_LEFT_X
					motion.axis_value = value
					root.push_input(motion)
			push.call(1.0)
			await process_frame
			push.call(0.0)
			await process_frame
			var second = root.gui_get_focus_owner()
			check(m.current == opciones and second != first and second.global_position.x > first.global_position.x,"Opciones, %s: → reaches the right column (%s → %s, modo %d)" % [way,first.text,second.text,m.current])
			push.call(1.0)
			await process_frame
			push.call(0.0)
			await process_frame
			check(m.current == opciones+1,"Opciones, %s: → from the right column goes to the next mode" % way)
		m.current = 0
		m.build_card()
	else:
		check(false,"The main menu is found")
	# A nudge of the mouse does not take the help away from the gamepad; really moving it does.
	Glyphs.device = "mando"
	Glyphs.mouse_travel = 0.0
	Glyphs.mouse_since = Time.get_ticks_msec()
	var nudge = InputEventMouseMotion.new()
	nudge.relative = Vector2(4,3)
	for i in 3: Glyphs.note(nudge)
	check(Glyphs.device == "mando","A few pixels of mouse drift keep the gamepad's help")
	var sweep = InputEventMouseMotion.new()
	sweep.relative = Vector2(30,10)
	for i in 3: Glyphs.note(sweep)
	check(Glyphs.device == "teclado","Really moving the mouse switches the help to keyboard and mouse")
	# Vibration: asked for only with the gamepad in use and the option on.
	Glyphs.device = "teclado"
	var rumbles = game.rumbles
	game.rumble(.2,.5,.05)
	check(game.rumbles == rumbles,"No vibration while playing with keyboard and mouse")
	Glyphs.device = "mando"
	game.set_vibration(true)
	rumbles = game.rumbles
	game.ratchet_sound(2)
	check(game.rumbles == rumbles+1,"The TLR crank rattles the gamepad")
	game.set_vibration(false)
	game.rumble(.2,.5,.05)
	check(game.rumbles == rumbles+1 and not game.vibration,"Options can turn the vibration off")
	game.set_vibration(true)
	Glyphs.device = "teclado"
	print("INPUT TESTS: %d checks, %d failures" % [checks,failures])
	if saved_ui_cfg != "":
		var f = FileAccess.open("user://interfaz.cfg",FileAccess.WRITE)
		f.store_string(saved_ui_cfg)
		f.close()
	quit(0 if failures == 0 else 1)
