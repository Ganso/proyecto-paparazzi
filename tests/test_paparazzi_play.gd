extends SceneTree
# Paparazzi played for real (docs/futuro/29 §19.3), the parts of E4: the menu's card, the reduced
# interface, the zoom, a good photo and a wrong person, the clock, a milestone and the end of the
# run. It aims as a player would (without the lock-on, which comes with E5). Needs a display, and
# never writes the player's files.
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_paparazzi_play.gd
const Paparazzi = preload("res://scripts/paparazzi.gd")
const Framing = preload("res://scripts/framing.gd")
const Texts = preload("res://scripts/texts.gd")
const PLAYER_SAVE = "user://paparazzi.cfg"
const TEST_SAVE = "user://paparazzi_pruebas.cfg"
var checks = 0
var failures = 0
var game
func check(ok: bool, message: String) -> void:
	checks += 1
	if OS.has_environment("PZ_DEBUG"): print("CHECK ",ok," ",message)
	if not ok:
		failures += 1
		push_error(message)

func frames(n: int) -> void:
	for i in n: await process_frame

func seconds(t: float) -> void:
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec()-t0 < t*1000.0: await process_frame

func stamp(path: String) -> String:
	if not FileAccess.file_exists(path): return "absent"
	return str(FileAccess.get_modified_time(path))+":"+FileAccess.get_md5(path)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var player_before = stamp(PLAYER_SAVE)
	var interface_before = stamp("user://interfaz.cfg")
	Paparazzi.SAVE = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Texts.set_language("es",false)
	game = preload("res://main.tscn").instantiate()
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"
	root.add_child(game)
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"
	game.pad_polling = false
	await frames(30)
	var own_camera = game.equipment
	# 1. The menu: Paparazzi second; entering starts level 1 in the classic park, without clock.
	game.intro()
	await frames(3)
	var menu = game.modal
	check(menu.MODES.find("paparazzi") == 1,"1. Paparazzi is the second mode")
	menu.current = 1
	menu.build_card()
	await frames(2)
	check(menu.enter_callback.is_valid(),"1. the card can be entered")
	menu.enter_callback.call()
	await frames(5)
	var pz = game.pz
	check(game.paparazzi_active() and game.mode == "PZ_CARD","1. a run starts on a card: %s" % game.mode)
	check(pz.spec.n == 1 and game.scenario == "clasico" and not pz.spec.clock,"1. level 1, classic park, no clock")
	check(game.equipment.lens().max == 600.0 and game.equipment.lens().min == 24.0,"1. the ideal camera, 24–600 mm")
	check(pz.request.plane == "entero","1. level 1 asks for a full shot")
	check(game.target.state in ["DETENIDO","SENTADO"] or game.target.has_meta("seat_activity"),"1. the person of level 1 is still (or about to sit): %s" % game.target.state)
	var turn = absf(rad_to_deg(angle_difference(deg_to_rad(pz.bearing_of(game.target)),deg_to_rad(game.angle))))
	check(turn <= 20.0,"1. and in view: %.0f°" % turn)
	check(pz.cards.size() >= 2,"1. the first level's novelty cards are waiting: %s" % str(pz.cards))
	var bank_card = pz.bank
	await frames(20)
	check(pz.bank == bank_card,"10. the clock waits on the cards")
	await dismiss()
	check(game.mode == "SEARCH","1. the cards and the level's card close into the search: %s" % game.mode)
	# 2. The reduced interface.
	await frames(3)
	check(game.view_rect == Rect2(0,0,1280,720),"2. the picture fills the screen: %s" % str(game.view_rect))
	check(not game.finder.visible,"2. no finder")
	check(not game.control_strip.visible,"2. no strip of controls")
	check(not game.control_help.visible,"2. no on-screen help of the camera")
	check(game.hud_top.all(func(n): return not n.visible) and game.hud_bottom.all(func(n): return not n.visible),"2. no bars")
	check(pz.hud.visible,"2. Paparazzi's own interface shows")
	check(not game.dof_allowed(),"2. the ideal camera has no depth of field")
	# 3. The zoom: forty notches of the wheel reach 600 mm, and back to 24.
	for i in 40: wheel(true)
	check(is_equal_approx(game.focal,600.0),"3. 40 notches up: %.1f mm" % game.focal)
	for i in 40: wheel(false)
	check(is_equal_approx(game.focal,24.0),"3. 40 notches down: %.1f mm" % game.focal)
	# Camera keys do nothing (the aperture key, for one).
	var before_n = game.n_index
	key(KEY_E)
	check(game.n_index == before_n,"3. the camera's keys are idle")
	# 7. The photo asked for, of the person asked for → level 2, the clock untouched in 1–3.
	var bank_before = pz.bank
	var ok = await shoot_target()
	check(ok,"7. a good full shot of the person is accepted: %s" % str(pz.last_verdict.get("reasons",[])))
	check(pz.spec.n == 2,"7. level 2 next: %d" % pz.spec.n)
	check(pz.bank == bank_before,"7. no clock in levels 1–3")
	await dismiss()
	# 8. Someone else, well framed → «Esa no es».
	var wrong = await shoot_someone_else()
	check(wrong.get("reasons",[]).size() > 0 and wrong.reasons[0].key == "no_es","8. another person is refused: %s" % str(wrong.get("reasons",[])))
	var said = game.toast.text
	check(said.begins_with("Esa no es"),"8. the message says so: «%s»" % said)
	check(pz.spec.n == 2,"8. still level 2")
	ok = await shoot_target()
	check(ok and pz.spec.n == 3,"7. level 2 passed: %s" % str(pz.last_verdict.get("reasons",[])))
	# 10. From level 4 the clock runs while searching, not on a card nor paused.
	pz.start(4)
	await frames(5)
	check(pz.spec.n == 4 and pz.spec.clock and game.mode == "PZ_CARD","10. level 4 has a clock")
	bank_card = pz.bank
	await frames(20)
	check(pz.bank == bank_card,"10. the clock waits on the card")
	await dismiss()
	var bank_search = pz.bank
	await seconds(1.0)
	check(pz.bank < bank_search-.6 and pz.bank > bank_search-1.6,"10. it runs while searching: %.2f → %.2f" % [bank_search,pz.bank])
	game.show_pause()
	await frames(2)
	var bank_pause = pz.bank
	await seconds(.5)
	check(pz.bank == bank_pause and game.mode == "PAUSE","10. it waits in the pause")
	game.resume_search()
	# A missed photo in stretch 1 costs nothing.
	var bank_fail = pz.bank
	game.angle = fposmod(game.angle+180.0,360.0)
	game.pitch = 60.0
	game.update_camera()
	await take()
	check(not pz.last_verdict.ok and absf(pz.bank-bank_fail) < .5,"10. a missed photo costs nothing in stretch 1")
	# 13. Level 10: passed, the milestone is consolidated and the menu offers 11.
	pz.start(10)
	await frames(5)
	await dismiss()
	ok = await shoot_target()
	check(ok and pz.spec.n == 11,"13. level 10 passed: %s" % str(pz.last_verdict.get("reasons",[])))
	var progress = Paparazzi.load_progress()
	check(progress.hito == 1 and progress.record >= 10,"13. milestone 1 consolidated: %s" % str(progress))
	check(Paparazzi.start_points(progress.hito) == [1,11],"13. starting points 1 and 11")
	check(pz.spec.penalty == 3.0,"13. stretch 2 costs 3 s per miss")
	# The end of the run.
	await dismiss()
	pz.end_run()
	await frames(3)
	check(game.mode == "PZ_END","12. the end of the run")
	check(Paparazzi.load_progress().carreras >= 1,"12. the run is counted")
	check(Paparazzi.run.contacts.size() >= 1,"12. the contact sheet keeps the good photos")
	game.intro()
	await frames(3)
	check(not game.paparazzi_active() and game.equipment == own_camera,"the player's camera is back after the run")
	check(game.dof_allowed() == bool(preload("res://scripts/graphics.gd").settings(game.graphics_preset).dof),"the depth of field is back")
	menu = game.modal
	menu.current = 1
	menu.build_card()
	await frames(2)
	var points = menu.card.find_children("*","Button",true,false).filter(func(b): return b.text.begins_with("Nivel "))
	check(points.size() == 2,"13. the menu offers two starting points: %d" % points.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	check(stamp(PLAYER_SAVE) == player_before,"the player's Paparazzi file is untouched")
	check(stamp("user://interfaz.cfg") == interface_before,"the player's interface file is untouched")
	print("PAPARAZZI PLAY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

# Close every card of the level, then the level's card.
func dismiss() -> void:
	for i in 20:
		if game.mode != "PZ_CARD": return
		if game.pz.brief_open: game.pz.begin_search()
		else:
			var buttons = game.modal.find_children("*","Button",true,false)
			buttons[0].pressed.emit()
		await frames(2)

func wheel(up: bool) -> void:
	var e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = Vector2(640,360)
	game._unhandled_input(e)

func key(code: int) -> void:
	var e = InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	game._unhandled_input(e)

# Turn and tilt so that a point of the world lands at `screen` (docs/futuro/29 §7.4).
func aim_point(world: Vector3, screen: Vector2) -> void:
	var to = world-game.camera.global_position
	var tan_h = tan(deg_to_rad(game.camera.fov)*.5)
	var tan_v = tan_h*float(game.viewport.size.y)/float(game.viewport.size.x)
	var want = Vector2(rad_to_deg(atan2(to.x,-to.z))-rad_to_deg(atan((screen.x-.5)*2.0*tan_h)),
		rad_to_deg(atan2(to.y,Vector2(to.x,to.z).length()))+rad_to_deg(atan((screen.y-.5)*2.0*tan_v)))
	for i in 4:
		game.angle = fposmod(want.x,360.0)
		game.pitch = want.y
		game.update_camera()
		var miss = game.camera.unproject_position(world)/Vector2(game.viewport.size)-screen
		want.x += rad_to_deg(atan(miss.x*2.0*tan_h))
		want.y -= rad_to_deg(atan(miss.y*2.0*tan_v))

# Frame someone as the request asks: the focal of the shot, the crown with its air (or the whole
# body in the middle), as the auto-framing of E5 will.
func frame(p, plane: String) -> void:
	var to = p.global_position-game.camera.global_position
	var d = Vector2(to.x,to.z).length()
	game.focal = clampf(Framing.focal_for(plane,Framing.rest_heights(p),d),24.0,600.0)
	game.update_camera()
	var w = Framing.world_landmarks(p)
	if plane in ["entero","general"]: aim_point((w.crown+w.feet)*.5,Vector2(.5,.5))
	else: aim_point(w.crown,Vector2(.5,Framing.AIR+.02))

func take() -> void:
	game.take_photo()
	await frames(1)
	for i in 120:
		if not game.shooting: break
		await process_frame
	await frames(2)

# The person asked for, framed and shot; a few tries if something passes in front.
func shoot_target() -> bool:
	var n = game.pz.spec.n
	for attempt in 12:
		frame(game.target,game.pz.current_request().plane)
		await take()
		if game.pz.spec.n != n or game.mode != "SEARCH": return game.pz.spec.n != n
		if true:
			var who = game.pz.protagonist()
			print("MISS n=%d plane=%s target=%s state=%s lane=%d d=%.1f protagonist=%s extra=%s d=%.1f %s" % [n,game.pz.current_request().plane,str(game.target.get_instance_id()),game.target.state,game.target.lane,game.target.global_position.distance_to(game.camera.global_position),str(who.get_instance_id()) if who else "-",str(who != null and not who in game.people),who.global_position.distance_to(game.camera.global_position) if who else -1.0,str(game.pz.last_verdict.reasons)])
		await seconds(.8)
	return false

# Someone else, framed the same way: the judge says who it is not.
func shoot_someone_else() -> Dictionary:
	var plane = game.pz.current_request().plane
	var others = game.people.filter(func(p): return p != game.target and p.visible and p.state != "RETIRADO" and not p.runner and not p.is_child() and p.lane in [1,2])
	for p in others:
		frame(p,plane)
		await take()
		var v = game.pz.last_verdict
		if not v.get("reasons",[]).is_empty() and v.reasons[0].key == "no_es": return v
	return game.pz.last_verdict
