extends SceneTree
# Paparazzi played for real (docs/futuro/29 §19.3), in the big park where the whole mode is played:
# the menu's card, the reduced interface, the camera lowered at the start and brought up by the
# wheel, the zoom, aim_point(), the lock-on (only when asked) and its follow, facing, the zone and the
# look-alikes, a good photo and a wrong person, the traffic light telling the truth, the learning
# line, the cheat sheet, the clock, Freeze, the rescue, the polaroid, a milestone with its album
# photo and the end of the run. It plays as a player would, walking up to the person and locking on.
# Needs a display, and never writes the player's files.
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_paparazzi_play.gd
const Paparazzi = preload("res://scripts/paparazzi.gd")
const Framing = preload("res://scripts/framing.gd")
const Texts = preload("res://scripts/texts.gd")
const Album = preload("res://scripts/album.gd")
const MainScript = preload("res://scripts/main.gd")
const PlaneIcon = preload("res://scripts/plane_icon.gd")
const PLAYER_SAVE = "user://paparazzi.cfg"
const TEST_SAVE = "user://paparazzi_pruebas.cfg"
const TEST_ALBUM = "user://album_pruebas_pz"
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

func album_count() -> int:
	return Album.list().size()

func clear_album() -> void:
	var dir = ProjectSettings.globalize_path(TEST_ALBUM)
	if not DirAccess.dir_exists_absolute(dir): return
	for f in DirAccess.get_files_at(dir): DirAccess.remove_absolute(dir+"/"+f)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var player_before = stamp(PLAYER_SAVE)
	var interface_before = stamp("user://interfaz.cfg")
	Paparazzi.SAVE = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Album.DIR = TEST_ALBUM
	clear_album()
	Texts.set_language("es",false)
	# The big park, cast as a run casts it (with its look-alikes): a test cannot reload the scene.
	MainScript.scenario = "grande"
	Paparazzi.run = {"seed":29}
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"
	game.pad_polling = false
	await frames(30)
	check(game.pz_doubles,"0. the big park was cast with look-alikes")
	var most = 0
	for p in game.people: most = maxi(most,Paparazzi.doubles_count(game.casting,p.traits,game.people.map(func(q): return q.traits)))
	check(most >= 2,"0. someone has two look-alikes or more: %d" % most)
	var own_camera = game.equipment
	# 1. The menu: Paparazzi second; entering starts level 1 in the big park, without clock.
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
	check(pz.spec.n == 1 and game.scenario == "grande" and not pz.spec.clock,"1. level 1, big park, no clock")
	check(game.equipment.lens().max == 600.0 and game.equipment.lens().min == 24.0,"1. the ideal camera, 24–600 mm")
	check(pz.request.plane == Paparazzi.ANY,"1. level 1 asks for any shot")
	var d0 = game.camera.global_position.distance_to(game.target.global_position)
	check(d0 >= 5.0 and d0 <= 16.0,"1. the person is near: %.1f m" % d0)
	check(pz.zone_text().begins_with("Cerca de") and pz.zone_text().ends_with(" m"),"1. the card says where: «%s»" % pz.zone_text())
	check(pz.cards.size() >= 2,"1. the first level's novelty cards are waiting: %s" % str(pz.cards))
	var bank_card = pz.bank
	await frames(20)
	check(pz.bank == bank_card,"10. the clock waits on the cards")
	await dismiss()
	check(game.mode == "SEARCH","1. the cards and the level's card close into the search: %s" % game.mode)
	check(not game.camera_raised,"1. the level starts walking, the camera down")
	check(pz.coach_key() == "pz_coach_andar","1. the learning line says to walk: %s" % pz.coach_key())
	# 2. The reduced interface.
	await frames(3)
	check(game.view_rect == Rect2(0,0,1280,720),"2. the picture fills the screen: %s" % str(game.view_rect))
	check(not game.finder.visible,"2. no finder")
	check(not game.control_strip.visible,"2. no strip of controls")
	check(not game.control_help.visible,"2. no on-screen help of the camera")
	check(game.hud_top.all(func(n): return not n.visible) and game.hud_bottom.all(func(n): return not n.visible),"2. no bars")
	check(pz.hud.visible,"2. Paparazzi's own interface shows")
	check(not game.dof_allowed(),"2. the ideal camera has no depth of field")
	# 3. The wheel brings the camera up; then forty notches reach 600 mm, and back to 24.
	wheel(true)
	await seconds(.5)
	check(game.camera_raised and game.eye_ready(),"3. the wheel brings the camera up")
	check(pz.coach_step >= 2,"3. walking and bringing it up complete their steps: %d" % pz.coach_step)
	for i in 40: wheel(true)
	check(is_equal_approx(game.focal,600.0),"3. 40 notches up: %.1f mm" % game.focal)
	for i in 40: wheel(false)
	check(is_equal_approx(game.focal,24.0),"3. 40 notches down: %.1f mm" % game.focal)
	var before_n = game.n_index
	key(KEY_Q)
	check(game.n_index == before_n,"3. the camera's keys are idle")
	# 4. aim_point(): any point of the world to any place of the frame, at any focal.
	var rng = RandomNumberGenerator.new()
	rng.seed = 29
	for f in [24.0,50.0,200.0,600.0]:
		game.focal = f
		game.update_camera()
		var worst = 0.0
		for i in 40:
			var yaw = deg_to_rad(rng.randf_range(0,360))
			var rise = deg_to_rad(rng.randf_range(-15,15))
			var world = game.camera.global_position+Vector3(sin(yaw)*cos(rise),sin(rise),-cos(yaw)*cos(rise))*rng.randf_range(3,30)
			var screen = Vector2(rng.randf_range(.08,.92),rng.randf_range(.08,.92))
			game.aim_point(world,screen,1.0)
			worst = maxf(worst,(game.camera.unproject_position(world)/Vector2(game.viewport.size)-screen).length())
		check(worst < .002,"4. aim_point at %d mm: worst miss %.5f" % [f,worst])
	game.focal = 24.0
	game.update_camera()
	# 12h. The cheat sheet: H opens it, the clock waits, H closes it.
	key(KEY_H)
	await frames(2)
	check(game.mode == "PZ_HELP","11h. H opens the cheat sheet: %s" % game.mode)
	check(game.modal.find_children("*","Control",true,false).filter(func(c): return c is PlaneIcon).size() == 6,"11h. six pictograms")
	key(KEY_H)
	await frames(2)
	check(game.mode == "SEARCH","11h. H closes it")
	# 7. The photo asked for, of the person asked for → level 2, the clock untouched in 1–3; the
	# polaroid holds the game a moment.
	var bank_before = pz.bank
	var ok = await shoot_target()
	check(ok,"7. a good photo of the person is accepted: %s" % str(pz.last_verdict.get("reasons",[])))
	check(pz.spec.n == 2,"7. level 2 next: %d" % pz.spec.n)
	check(pz.bank == bank_before,"7. no clock in levels 1–3")
	await dismiss()
	ready_eye()
	# 5. The lock-on: only when asked for (zooming in on someone does not lock on); E locks on to the
	# person in the middle and E again lets go. At 200 mm, walking, the follow keeps her anchor where
	# the framing wants it.
	approach(game.target,9.0)
	await frames(2)
	pz.release()
	game.focal = 60.0
	game.update_camera()
	game.aim_point(game.target.control_points()[1],Vector2(.5,.5),1.0)
	await seconds(.5)
	check(pz.locked == null,"5. zooming in does not lock on by itself: %s" % str(pz.locked))
	game.aim_point(game.target.control_points()[1],Vector2(.5,.5),1.0)
	key(KEY_E)
	check(pz.locked == game.target,"5. E locks on to the person in the middle: %s" % str(pz.locked))
	key(KEY_E)
	check(pz.locked == null,"5. E again lets go")
	game.focal = 200.0
	game.update_camera()
	pz.lock(game.target)
	await seconds(.6)
	var worst_follow = 0.0
	var walked = 0.0
	var start_at: Vector3 = game.target.global_position
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec()-t0 < 3000:
		await process_frame
		if pz.locked != game.target: break
		var w = Framing.world_landmarks(game.target)
		var v: Vector3 = game.target.actual_velocity
		var side = signf(v.dot(game.camera.global_basis.x)) if v.length() > .2 else 0.0
		var aim = pz.anchor_for(game.target,w,side)
		var want: Vector2 = aim[1]
		var at = game.camera.unproject_position(aim[0])/Vector2(game.viewport.size)
		worst_follow = maxf(worst_follow,(at-want).length())
		walked = maxf(walked,game.target.global_position.distance_to(start_at))
	check(pz.locked == game.target,"5. still locked after 3 s")
	check(worst_follow < .1,"5. the follow keeps the anchor in place: worst %.3f (walked %.1f m)" % [worst_follow,walked])
	check(pz.coach_step >= 1,"5. locking on completes its step: %d" % pz.coach_step)
	pz.release()
	# 6. facing: towards the camera under 10°, the back over 170°.
	var someone = game.target
	var keep_rotation = someone.rotation.y
	var to: Vector3 = game.camera.global_position-someone.global_position
	someone.rotation.y = atan2(-to.x,-to.z)-someone.look_yaw
	check(game.facing_of(someone) < 10.0,"6. facing the camera: %.1f°" % game.facing_of(someone))
	someone.rotation.y += PI
	check(game.facing_of(someone) > 170.0,"6. the back to it: %.1f°" % game.facing_of(someone))
	someone.rotation.y = keep_rotation
	game.focal = 24.0
	game.update_camera()
	# 8. Someone else, well framed → «Esa no es».
	var wrong = await shoot_someone_else()
	check(wrong.get("reasons",[]).size() > 0 and wrong.reasons[0].key == "no_es","8. another person is refused: %s" % str(wrong.get("reasons",[])))
	var said = game.toast.text
	check(said.begins_with("Esa no es"),"8. the message says so: «%s»" % said)
	check(pz.spec.n == 2,"8. still level 2")
	ok = await shoot_target()
	check(ok and pz.spec.n == 3,"7. level 2 passed: %s" % str(pz.last_verdict.get("reasons",[])))
	# 9. The traffic light tells the truth: locked on to the person, shooting as soon as it turns
	# green passes the level, ten levels in a row (3–12); shooting on amber fails for the reason
	# its advice gave. Level 10 is a milestone: its photo goes to the album.
	for card in ["flecha","taparse"]: pz.mark_seen(card)
	var greens = 0
	var amber_checked = false
	var album_before = album_count()
	for level in 10:
		await dismiss()
		ready_eye()
		var n = pz.spec.n
		if not amber_checked and pz.spec.clock and pz.current_request().plane != Paparazzi.ANY:
			# Amber: far too wide for the shot asked for.
			approach(game.target,9.0)
			await frames(2)
			pz.release()
			game.focal = 24.0
			game.update_camera()
			aim_point(game.target.control_points()[1],Vector2(.5,.5))
			pz.lock(game.target)
			await frames(4)
			var tip: String = pz.live.get("tip","")
			if not pz.live.is_empty() and not pz.live.ok and tip != "":
				await take()
				check(not pz.last_verdict.ok and pz.last_verdict.tip == tip,"9. amber («%s») fails for that: %s" % [tip,str(pz.last_verdict.get("reasons",[]))])
				amber_checked = true
		if await green_shot(): greens += 1
		else: print("NO GREEN n=%d plane=%s live=%s" % [n,pz.current_request().plane,str(pz.live)])
	check(greens == 10,"9. shooting on green passes: %d of 10" % greens)
	check(amber_checked,"9. a shot on amber was tried")
	check(album_count() == album_before+1,"16. the milestone's photo is in the album: %d → %d" % [album_before,album_count()])
	var progress = Paparazzi.load_progress()
	check(progress.hito == 1 and progress.record >= 10,"13. milestone 1 consolidated: %s" % str(progress))
	check(Paparazzi.start_points(progress.hito) == [1,11],"13. starting points 1 and 11")
	# 11. Freeze: for 5 s nobody moves more than 1 cm; then they do.
	await dismiss()
	ready_eye()
	check(int(Paparazzi.run.jokers.congelar) >= 1,"11. a Freeze was given on level 5: %s" % str(Paparazzi.run.jokers))
	pz.release()
	var spots = {}
	for p in game.people: spots[p] = p.global_position
	key(KEY_1)
	check(pz.frozen > 0.0,"11. 1 freezes the park")
	await seconds(4.6)
	var moved = 0.0
	for p in game.people: moved = maxf(moved,p.global_position.distance_to(spots[p]))
	check(moved < .01 and game.mode == "SEARCH","11. nobody moves while frozen: %.3f m (%s)" % [moved,game.mode])
	await seconds(1.4)
	moved = 0.0
	for p in game.people: moved = maxf(moved,p.global_position.distance_to(spots[p]))
	check(moved > .05,"11. and they move again: %.2f m" % moved)
	# 12. The clock at zero: the rescue gives 30 s once; the second time, the end.
	pz.bank = .3
	await seconds(.6)
	check(game.mode == "PZ_RESCUE","12. at zero, the rescue is offered: %s" % game.mode)
	pz.use_rescue()
	await frames(2)
	check(game.mode == "SEARCH" and absf(pz.bank-Paparazzi.RESCUE_TIME) < .3,"12. 30 s more: %.1f" % pz.bank)
	pz.bank = .3
	await seconds(.6)
	check(game.mode == "PZ_END","12. no rescue left: the end (%s)" % game.mode)
	check(Paparazzi.load_progress().record >= 12,"12. the record is in the test file: %s" % str(Paparazzi.load_progress()))
	check(Paparazzi.run.contacts.size() >= 1,"12. the contact sheet keeps the good photos")
	# 10. From level 4 the clock runs while searching, not on a card nor paused.
	pz.start(4)
	await frames(5)
	check(pz.spec.n == 4 and pz.spec.clock and game.mode == "PZ_CARD","10. level 4 has a clock")
	bank_card = pz.bank
	await frames(20)
	check(pz.bank == bank_card,"10. the clock waits on the card")
	await dismiss()
	ready_eye()
	var bank_search = pz.bank
	await seconds(1.0)
	check(pz.bank < bank_search-.6 and pz.bank > bank_search-1.6,"10. it runs while searching: %.2f → %.2f" % [bank_search,pz.bank])
	game.show_pause()
	await frames(2)
	var bank_pause = pz.bank
	await seconds(.5)
	check(pz.bank == bank_pause and game.mode == "PAUSE","10. it waits in the pause")
	game.resume_search()
	key(KEY_H)
	await frames(2)
	var bank_help = pz.bank
	await seconds(.5)
	check(pz.bank == bank_help and game.mode == "PZ_HELP","10. it waits in the cheat sheet")
	key(KEY_ESCAPE)
	await frames(2)
	# A missed photo in stretch 1 costs nothing.
	pz.release()
	var bank_fail = pz.bank
	game.angle = fposmod(game.angle+180.0,360.0)
	game.pitch = 60.0
	game.update_camera()
	await take()
	check(not pz.last_verdict.ok and absf(pz.bank-bank_fail) < .5,"10. a missed photo costs nothing in stretch 1")
	# Stretch 2 brings the planes, and its misses cost 3 s.
	pz.start(11)
	await frames(5)
	check(pz.request.plane == "entero" and pz.spec.penalty == 3.0,"13. level 11 asks for a full shot and a miss costs 3 s")
	await dismiss()
	pz.end_run()
	await frames(3)
	check(game.mode == "PZ_END","12. the end of the run")
	check(Paparazzi.load_progress().carreras >= 1,"12. the run is counted")
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
	clear_album()
	check(stamp(PLAYER_SAVE) == player_before,"the player's Paparazzi file is untouched")
	check(stamp("user://interfaz.cfg") == interface_before,"the player's interface file is untouched")
	print("PAPARAZZI PLAY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

# The camera up and at the eye at once (a player would wait the 0.35 s of the gesture).
func ready_eye() -> void:
	if not game.camera_raised: game.set_raised(true)
	game.raise_anim = 1.0

# Walk up to someone: the photographer at `d` metres, on the line from where it stands.
func approach(p, d: float, turn = 0.0) -> void:
	var from: Vector3 = game.player.global_position
	var away = Vector3(from.x-p.global_position.x,0,from.z-p.global_position.z)
	if away.length() < .1: away = Vector3(0,0,1)
	away = away.normalized().rotated(Vector3.UP,deg_to_rad(turn))
	game.player.global_position = Vector3(p.global_position.x,0,p.global_position.z)+away*d
	game.camera.position = game.player.position+Vector3.UP*game.eye_height
	game.update_camera()

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
	if plane == Paparazzi.ANY: plane = "medio"
	game.pz.release()
	var to = p.global_position-game.camera.global_position
	var d = Vector2(to.x,to.z).length()
	game.focal = clampf(Framing.focal_for(plane,Framing.rest_heights(p),d),24.0,600.0)
	game.update_camera()
	var w = Framing.world_landmarks(p)
	if plane in ["entero","general"]: aim_point((w.crown+w.feet)*.5,Vector2(.5,.5))
	else: aim_point(w.crown,Vector2(.5,Framing.AIR+.02))
	game.pz.lock(p)

# Locked on to the person asked for, zooming as the advice says until the light is green, then the
# photo: whether the level was passed.
func green_shot() -> bool:
	var pz = game.pz
	var n = pz.spec.n
	pz.release()
	ready_eye()
	approach(game.target,8.0)
	await frames(1)
	var w = Framing.world_landmarks(game.target)
	var to = game.target.global_position-game.camera.global_position
	var plane: String = pz.current_request().plane
	if plane == Paparazzi.ANY: plane = "medio"
	game.focal = clampf(Framing.focal_for(plane,Framing.rest_heights(game.target),Vector2(to.x,to.z).length()),24.0,600.0)
	game.update_camera()
	aim_point(w.chest,Vector2(.5,.5))
	pz.lock(game.target)
	var t0 = Time.get_ticks_msec()
	var blocked_since = -1
	while Time.get_ticks_msec()-t0 < 14000:
		await frames(3)
		if game.mode == "PZ_CARD": await dismiss()
		# Something in front for a while: round the person, as a player would.
		if not pz.live.is_empty() and pz.live.tip in ["tapada","se_tapa","apunta","sobra_gente"]:
			if blocked_since < 0: blocked_since = Time.get_ticks_msec()
			elif Time.get_ticks_msec()-blocked_since > 1200:
				blocked_since = -1
				ready_eye()
				approach(game.target,8.0,70.0)
				await frames(1)
				aim_point(game.target.control_points()[1],Vector2(.5,.5))
				pz.release()
				pz.lock(game.target)
				continue
		else: blocked_since = -1
		if pz.locked != game.target:
			ready_eye()
			approach(game.target,8.0)
			await frames(1)
			aim_point(game.target.control_points()[1],Vector2(.5,.5))
			pz.lock(game.target)
		if pz.live.is_empty(): continue
		if pz.live.ok:
			await take()
			if pz.spec.n != n: return true
			print("GREEN BUT MISSED n=%d %s" % [n,str(pz.last_verdict.reasons)])
			return false
		match pz.live.tip:
			"mas_zoom": pz.zoom_step(1)
			"menos_zoom","cabeza": pz.zoom_step(-1)
	return false

func take() -> void:
	game.take_photo()
	await frames(1)
	for i in 120:
		if not game.shooting: break
		await process_frame
	await frames(2)
	while game.mode == "PZ_POLAROID": await process_frame

# The person asked for, framed and shot; a few tries if something passes in front.
func shoot_target() -> bool:
	var n = game.pz.spec.n
	for attempt in 12:
		ready_eye()
		approach(game.target,7.0+attempt%3)
		await frames(1)
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
	var others = game.people.filter(func(p): return p != game.target and p.visible and p.state != "RETIRADO" and not p.runner and not p.is_child())
	others.sort_custom(func(a,b): return a.global_position.distance_to(game.camera.global_position) < b.global_position.distance_to(game.camera.global_position))
	for p in others.slice(0,8):
		ready_eye()
		approach(p,7.0)
		await frames(1)
		frame(p,plane)
		await take()
		var v = game.pz.last_verdict
		if not v.get("reasons",[]).is_empty() and v.reasons[0].key == "no_es": return v
	return game.pz.last_verdict
