extends SceneTree
var game
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run")
func frames(n = 3) -> void:
	for i in n: await process_frame
func screenshot(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/paparazzi-"+id+".png")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(12)
	game.start_session(false)
	check(game.mode == "BRIEFING","Assignment opens before search")
	check(game.brief_preview.traits == game.target.traits,"Portrait exactly matches target traits")
	check(game.brief_preview != game.target and game.brief_viewport.world_3d != game.viewport.world_3d,"Portrait is an isolated copy")
	var theta = game.target.theta
	var weather = game.park.weather_time
	await frames(8)
	check(game.target.theta == theta and game.park.weather_time == weather,"Briefing freezes phase")
	await screenshot("encargo-previo")
	var enter = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	game._unhandled_input(enter)
	check(game.mode == "SEARCH","Enter starts the phase")
	game.mode = "TEST"
	var runners = game.people.filter(func(p): return p.runner)
	check(runners.size() >= 2,"Runners populated")
	for p in runners:
		check(game.casting.catalog.piezas.torso[p.traits.upper].get("sport",false) and game.casting.catalog.piezas.piernas[p.traits.lower].get("sport",false),"Runner exclusively sportswear")
		check(p.speed >= 2.6 and p.traits.accessory == 0,"Running speed, no loose accessories")
	var runner = runners[0]
	runner.phase = .3*TAU
	runner.animate(0)
	var first = runner.rig.get_bone_global_pose(runner.bones["pie.I"])
	runner.animate(runner.stride/runner.speed)
	check(first.is_equal_approx(runner.rig.get_bone_global_pose(runner.bones["pie.I"])),"Running animation loops")
	check(absf(runner.rig.get_bone_pose_rotation(runner.bones["antebrazo.I"]).get_euler().x)>1,"Runner bends elbows")
	for i in 100:
		var t = game.casting.generate(true)
		check(game.casting.catalog.piezas.torso[t.upper].sport and game.casting.catalog.piezas.piernas[t.lower].sport,"Generated runners remain compatible")
	var t = game.casting.generate()
	t.hair = 6
	t.accessory = 1
	var sample = game.Person.new()
	game.viewport.add_child(sample)
	sample.setup(t,game.casting.catalog,102)
	sample.theta = 120
	sample.radius = 4
	sample.state = "DETENIDO"
	sample.place()
	game.target = sample
	game.show_assignment()
	await frames(4)
	check(game.brief_preview.triangle_count == sample.triangle_count,"Hat and scarf included in portrait geometry")
	check("bufanda" in ",".join(game.casting.descriptors(t)),"Accessory included in description")
	await screenshot("sombrero-bufanda")
	game.begin_assignment()
	game.equipment.film = true
	game.equipment.film_iso_index = 1
	game.equipment.auto_exposure = false
	game.apply_equipment()
	game.change_parameter("iso",1)
	check(game.iso_index == 1 and game.iso_button.disabled,"Film locks manual ISO")
	game.equipment.auto_exposure = true
	for ev in [3.0,8.0,14.0]:
		game.measured_ev = ev
		game.auto_expose()
		check(game.iso_index == 1,"Automatic exposure preserves film ISO")
	game.show_equipment()
	await frames(3)
	await screenshot("carrete")
	game.restore_equipment_screen()
	game.mode = "TEST"
	game.park.weather_time = 5.9
	game.park.update_weather(0)
	var ev_sun = game.park.illumination_ev(Vector3(0,.5,0),false)
	var energy_sun = game.park.sun.light_energy
	game.park.update_weather(1.4)
	var ev_cloud = game.park.illumination_ev(Vector3(0,.5,0),false)
	check(ev_sun-ev_cloud > 2.0,"Cloud rapidly changes metered exposure")
	check(game.park.sun.light_energy < energy_sun*.15,"Cloud changes visible lighting too")
	game.pitch = 25
	game.update_camera()
	await frames(2)
	await screenshot("nubes")
	game.park.clouds_enabled = false
	game.park.update_weather(0)
	check(game.park.sun.light_energy == energy_sun and not game.park.clouds.visible,"Clear sky restores light")
	game.start_session(false,true)
	check(game.sandbox and game.mode == "SEARCH" and game.target == null,"Sandbox starts without assignment")
	game.set_sandbox_pause(true)
	check(game.people.all(func(p): return p.actual_velocity == Vector3.ZERO),"Paused subjects have no motion blur")
	game.equipment.auto_exposure = false
	game.equipment.focus_mode = "MF"
	game.apply_equipment()
	for i in 4:
		game.t_index = i
		await game.take_photo()
		check(game.mode == "RESULT" and game.current_photo != null,"Sandbox reveals photo")
		check(game.records.is_empty() and game.best.is_empty() and game.shots == 3,"Sandbox has no mission progression or shot limit")
		check(game.current_result.evidence.iso == 200,"Sandbox evidence preserves film ISO")
		game.resume_search()
	check(game.shot_serial == 4,"More than three sandbox photos")
	game.update_meter()
	game.auto_expose()
	await game.take_photo()
	await screenshot("sandbox-revelado")
	var evidence = game.current_result.evidence.duplicate(true)
	game.show_equipment()
	game.equipment.film_iso_index = 3
	game.apply_equipment()
	game.restore_equipment_screen()
	check(game.mode == "RESULT" and game.current_result.evidence == evidence,"Changing equipment preserves developed photo")
	game.resume_search()
	game.show_sandbox_controls()
	await frames(2)
	await screenshot("sandbox-escena")
	game.start_session(true)
	check(not game.sandbox and game.mode == "BRIEFING" and game.records.is_empty(),"Return from sandbox to assignments")
	print("EXPANSION TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
