extends SceneTree
# Automatisms never know who the assignment is about (docs/futuro/12 §2.1, fase 0): matrix AF and
# the automatic exposure pick the same point and reading whoever the target is.
# Needs a display: ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_automatisms.gd
const Main = preload("res://main.tscn")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"   # (never the player's progress)
	game.exposure_thirds = false   # (not the player's option)
	for i in 10: await process_frame
	game.start_session("day")
	game.begin_assignment()
	game.mode = "SEARCH"
	game.equipment.focus_mode = "AF matricial"
	game.equipment.auto_exposure = true
	var tested = 0
	for view in [60.0,120.0,200.0,300.0]:
		game.angle = view
		game.pitch = -4.0
		game.focal = game.equipment.lens().min
		game.update_camera()
		for i in 3: await physics_frame
		await process_frame
		var visible_people = game.people.filter(func(p): return game.camera.is_position_in_frustum(p.position+Vector3.UP))
		if visible_people.size() < 2: continue
		var picks = []
		var readings = []
		for candidate in visible_people.slice(0,3):
			game.target = candidate
			game.select_matrix_point()
			game.update_meter()
			picks.append(game.finder.active)
			readings.append(snappedf(game.measured_ev,.001))
		tested += 1
		check(picks.all(func(v): return v == picks[0]),"Matrix AF picks the same point whoever the target is (view %d°: %s)" % [view,str(picks)])
		check(readings.all(func(v): return v == readings[0]),"The meter reads the same whoever the target is (view %d°)" % view)
	check(tested >= 2,"Enough views with several people to compare (%d)" % tested)
	# --- Metering modes and AF-L / AE-L (docs/futuro/12 fase 1) ---
	game.equipment.focus_mode = "AF puntual"
	game.finder.active = 4
	check(game.equipment.metering == "matricial" and game.equipment.DEFAULT_METERING == "matricial","Matrix metering is the norm (user, 05-10-2026)")
	var modes_tested = 0
	for view in [60.0,120.0,200.0,300.0]:
		game.angle = view
		game.pitch = -4.0
		game.focal = 50.0
		game.update_camera()
		for i in 3: await physics_frame
		await process_frame
		game.release_lock()
		game.equipment.metering = "puntual"
		game.update_meter()
		var spot = game.measured_ev
		var hit = game.point_hit(game.finder.points()[4])
		var expected = game.park.sky_ev(game.time_of_day) if hit.is_empty() else game.park.illumination_ev(hit.position,game.time_of_day,hit.collider.get_meta("person") if hit.collider.has_meta("person") else null)
		check(is_equal_approx(spot,expected),"Spot metering reads exactly what is under the active point (view %d)" % view)
		var samples = []
		for row in 5:
			for col in 5: samples.append(game.ev_under(game.view_point(Vector2((col+.5)/5.0,(row+.5)/5.0))))
		for metering in ["ponderada","matricial"]:
			game.equipment.metering = metering
			var by_target = []
			for candidate in game.people.slice(0,3):
				game.target = candidate
				game.update_meter()
				by_target.append(game.measured_ev)
			check(by_target.min() == by_target.max(),"%s metering does not depend on who the assignment is about" % metering)
			game.update_meter()
			check(game.measured_ev == by_target[0],"%s metering is deterministic" % metering)
			if metering == "matricial": check(game.measured_ev >= samples.min()-.001 and game.measured_ev <= samples.max()+.001,"Matrix metering stays within its zones (%.1f in %.1f…%.1f)" % [game.measured_ev,samples.min(),samples.max()])
		modes_tested += 1
	check(modes_tested == 4,"Metering modes checked in four views")
	# The matrix mode damps a much brighter sky: its reading is not above the plain mean of the zones.
	game.angle = 120.0
	game.pitch = 18.0
	game.update_camera()
	for i in 3: await physics_frame
	var zones = []
	for row in 5:
		for col in 5: zones.append(game.ev_under(game.view_point(Vector2((col+.5)/5.0,(row+.5)/5.0))))
	var plain_mean = zones.reduce(func(a,b): return a+b,0.0)/25.0
	game.finder.active = 7
	game.equipment.metering = "matricial"
	game.update_meter()
	check(game.measured_ev <= plain_mean+.6,"Matrix metering leans on the zone of the active point, not on the sky (%.1f, plain mean %.1f)" % [game.measured_ev,plain_mean])
	game.next_metering()
	check(game.equipment.metering == "puntual","The key goes round the three modes")
	# Lock, recompose, shoot.
	game.pitch = -4.0
	game.finder.active = 4
	var someone = game.people.filter(func(p): return p.lane == 1 and p.visible and p.state == "CAMINANDO")[0]
	game.aim_at(someone,1.0)
	for i in 3: await physics_frame
	game.toggle_lock()
	check(game.exposure_locked and game.focus_locked,"The lock key locks focus and exposure")
	var locked_focus = game.focus_distance
	var locked_ev = game.measured_ev
	var locked_settings = [game.n_index,game.t_index,game.iso_index]
	game.angle += 14.0
	game.pitch = 20.0
	game.update_camera()
	for i in 3: await physics_frame
	game.update_meter()
	game.auto_expose() if not game.exposure_locked else null
	check(game.measured_ev == locked_ev and game.focus_distance == locked_focus,"Recomposing keeps the locked focus and reading")
	await game.take_photo()
	check(is_equal_approx(game.current_result.evidence.s,locked_focus) and [game.n_index,game.t_index,game.iso_index] == locked_settings,"The photo is taken with the locked focus and exposure")
	check(not game.exposure_locked and not game.focus_locked,"The photo releases the lock")
	game.resume_search()
	game.toggle_lock()
	game.toggle_lock()
	check(not game.exposure_locked,"The key again releases it")
	for key in ["fotometria_puntual","fotometria_ponderada","fotometria_matricial","ayuda_fotometria","ayuda_bloqueo","bloqueo_puesto","bloqueo_suelto"]:
		check(preload("res://scripts/texts.gd").get_text(key) != key,"Text %s" % key)
	# --- AF-C (docs/futuro/12 §4.2): the lens follows what is under the active point by itself ---
	check("AF continuo" in game.equipment.focus_modes(),"The SLR offers continuous AF")
	game.equipment.body = 1
	check(game.equipment.focus_modes() == ["MF"],"The rangefinder stays manual")
	game.equipment.body = 2
	game.equipment.focus_mode = "AF continuo"
	game.finder.active = 4
	game.focal = 50.0
	var follow = func(who, seconds: float):
		var t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec()-t0 < seconds*1000.0:
			# Straight at the chest (aim_at() leads a walker, and at 7 m the lead misses the body).
			var to = who.control_points()[1]-game.camera.global_position
			game.angle = fposmod(rad_to_deg(atan2(to.x,-to.z)),360.0)
			game.pitch = rad_to_deg(atan2(to.y,Vector2(to.x,to.z).length()))
			game.update_camera()
			await process_frame
	var walker = game.people.filter(func(p): return p.lane == 2 and p.visible and p.state == "CAMINANDO" and not p.runner)[0]
	game.focus_distance = 2.0
	await follow.call(walker,1.2)
	var far_d = game.camera.global_position.distance_to(walker.control_points()[1])
	check(absf(game.focus_distance-far_d) < .6,"AF-C brings the focus to the person under the point (%.2f m away, lens at %.2f m)" % [far_d,game.focus_distance])
	var near = game.people.filter(func(p): return p.lane == 1 and p.visible and p.state == "CAMINANDO")[0]
	await follow.call(near,1.2)
	var near_d = game.camera.global_position.distance_to(near.control_points()[1])
	check(absf(game.focus_distance-near_d) < .6 and game.focus_distance < far_d-1.0,"…and follows when the camera turns to someone nearer (%.2f m away, lens at %.2f m)" % [near_d,game.focus_distance])
	game.toggle_lock()
	var held = game.focus_distance
	await follow.call(walker,.8)
	check(game.focus_distance == held,"A focus lock stops the continuous AF")
	game.release_lock()
	game.equipment.focus_mode = "AF puntual"
	await follow.call(walker,.6)
	check(game.focus_distance == held,"Single AF does not refocus by itself")
	check(game.SHUTTER_LAG > 0.0 and game.AF_C_INTERVAL < .2,"AF-C refocuses several times a second and allows for the shutter lag")
	# --- AF-A (§4.3): continuous only while the person under the point moves ---
	check("AF automático" in game.equipment.focus_modes(),"The SLR offers automatic AF")
	game.equipment.focus_mode = "AF automático"
	game.af_a_following = false
	game.focus_distance = 2.0
	# (Whoever is walking now: the one followed a few seconds ago may have stopped to look around,
	# and then AF-A, rightly, does not follow.)
	var moving = game.people.filter(func(p): return p.lane == 2 and p.visible and p.state == "CAMINANDO" and not p.runner and p.pending_stop.is_empty() and p.actual_velocity.length() > .3)
	if not moving.is_empty(): walker = moving[0]
	# Followed until nothing has stood between the camera and the walker for a second (someone
	# crossing on a nearer path, a lamp post): AF-A is about what is under the point.
	var clear = 0
	for k in 100:
		await follow.call(walker,.1)
		var hit = game.point_hit(game.finder.points()[game.finder.active])
		clear = clear+1 if not hit.is_empty() and hit.collider.has_meta("person") and hit.collider.get_meta("person") == walker else 0
		if clear >= 10: break
	check(game.af_a_following and absf(game.focus_distance-game.camera.global_position.distance_to(walker.control_points()[1])) < .6,"AF-A follows a person who is walking (%s at %.2f m/s, following %s, lens %.2f m of %.2f)" % [walker.state,walker.actual_velocity.length(),str(game.af_a_following),game.focus_distance,game.camera.global_position.distance_to(walker.control_points()[1])])
	var still = game.people.filter(func(p): return p.visible and p.state in ["DETENIDO","SENTADO"])
	if not still.is_empty():
		game.focus_distance = 2.0
		await follow.call(still[0],1.0)
		check(not game.af_a_following and game.focus_distance == 2.0,"…and leaves the focus alone with someone standing or sitting (single AF)")
		game.autofocus()
		check(absf(game.focus_distance-2.0) > .3,"…where focusing is on demand, as in single AF")
	print("AUTOMATISMS TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
