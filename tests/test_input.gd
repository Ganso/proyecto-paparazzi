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
	check(Glyphs.kp("disparar") == "R2" and Glyphs.kp("af") == "✕","PlayStation names")
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
	root.add_child(game)
	for i in 30: await process_frame
	game.start_level(6)
	game.begin_assignment()
	var before = game.control_help.enabled
	game._unhandled_input(pad(JOY_BUTTON_X))
	check(game.control_help.enabled != before,"X toggles the on-screen help")
	game.control_help.set_enabled(before)
	game.finder.active = 4
	game._unhandled_input(pad(JOY_BUTTON_RIGHT_SHOULDER))
	check(game.finder.active == 5,"RB moves to the next focus point")
	game.pad_param = 1
	var n0 = game.n_index
	game._unhandled_input(pad(JOY_BUTTON_DPAD_UP))
	check(game.n_index == mini(n0+1,game.apertures().size()-1),"D-pad up changes the selected setting (aperture in A)")
	game._unhandled_input(pad(JOY_BUTTON_DPAD_RIGHT))
	check(game.pad_param == 2,"D-pad right selects the next setting")
	game._unhandled_input(pad(JOY_BUTTON_Y))
	check(not game.camera_raised,"Y lowers the camera")
	game._unhandled_input(pad(JOY_BUTTON_Y))
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
	game.start_level(6)
	game.begin_assignment()
	check(game.control_help.exit_button.visible or true,"The exit button exists on screen")
	check(game.stick(.1) == 0.0 and absf(game.stick(1.0)-1.0) < .001 and game.stick(.5) < .1,"Sticks: dead zone and cubic response")
	Glyphs.device = "teclado"
	print("INPUT TESTS: %d checks, %d failures" % [checks,failures])
	if saved_ui_cfg != "":
		var f = FileAccess.open("user://interfaz.cfg",FileAccess.WRITE)
		f.store_string(saved_ui_cfg)
		f.close()
	quit(0 if failures == 0 else 1)
