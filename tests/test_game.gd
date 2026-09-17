extends SceneTree
const Main = preload("res://main.tscn")
var game
var checks = 0
var failures = 0
var output = "/tmp"
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func frames(count = 3) -> void:
	for i in count: await process_frame
func screenshot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/paparazzi-"+name_value+".png")
func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	await frames(10)
	check(game.mode == "INTRO","Starts at briefing menu")
	await screenshot("inicio")
	game.equipment.preset(2)
	game.start_session(false)
	game.begin_assignment()
	await frames(4)
	# Dispatch actual Godot input events through the viewport, including UI routing.
	var old_n = game.n_index
	var key = InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	await frames(1)
	check(game.n_index == posmod(old_n-1,game.apertures().size()),"Keyboard aperture input")
	key.pressed = false
	Input.parse_input_event(key)
	var old_angle = game.angle
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(640,450)
	press.pressed = true
	Input.parse_input_event(press)
	await frames(1)
	var drag = InputEventMouseMotion.new()
	drag.position = Vector2(690,450)
	drag.relative = Vector2(50,0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	var start_usec = Time.get_ticks_usec()
	Input.parse_input_event(drag)
	await frames(1)
	var latency = (Time.get_ticks_usec()-start_usec)/1000.0
	check(game.angle != old_angle,"Mouse drag pans camera")
	check(latency < 50,"Pan input under 50 ms")
	press.position = drag.position
	press.pressed = false
	Input.parse_input_event(press)
	await frames(1)
	game.pan_velocity = 0
	old_angle = game.angle
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(550,350)
	touch.pressed = true
	Input.parse_input_event(touch)
	await frames(1)
	var touch_drag = InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = Vector2(550,410)
	touch_drag.relative = Vector2(0,60)
	Input.parse_input_event(touch_drag)
	await frames(1)
	check(abs(game.angle-old_angle) < .01 and game.pitch < -1,"Vertical drag tilts without horizontal pan")
	touch.position = touch_drag.position
	touch.pressed = false
	Input.parse_input_event(touch)
	await frames(1)
	game.start_session(false)
	game.begin_assignment()
	game.mode = "TEST"
	var target = game.target
	var t = target.traits
	check(game.people.size() == 21,"Scene population")
	for p in game.people:
		p.state = "DETENIDO"
		p.animate(0)
		p.theta = 300
		p.place()
	target.theta = 120
	target.radius = 7
	target.state = "DETENIDO"
	target.place()
	game.angle = 120
	game.focal = 50
	game.focus_distance = 7
	game.update_camera()
	await frames(4)
	var head = game.camera.unproject_position(target.position+Vector3.UP*target.height)
	var feet = game.camera.unproject_position(target.position)
	var h = abs(feet.y-head.y)/game.viewport.size.y
	var expected = target.height*50/(7*20.25)
	check(abs(h-expected)<.003,"36 mm width maintained in 16:9 projection")
	# Check skin deformation and exact gait loop, stance height, stride cancellation.
	target.runner = false
	target.stride = target.profile.zancada*.8
	var saved_phase = target.phase
	target.state = "CAMINANDO"
	target.phase = .4
	target.animate(0)
	var first = target.rig.get_bone_global_pose(target.bones["pie.I"])
	target.animate(target.stride/target.speed)
	var last = target.rig.get_bone_global_pose(target.bones["pie.I"])
	check(first.is_equal_approx(last),"Exact gait cycle")
	target.state = "DETENIDO"
	target.animate(0)
	await frames(4)
	game.mode = "SEARCH"
	game.finder.active = 7
	game.autofocus()
	check(game.finder.success,"AF ray hits world")
	check(game.focus_distance >= .8,"AF distance remains in range")
	game.equipment.focus_mode = "MF"
	game.focus_distance = game.camera.global_position.distance_to(target.control_points()[1])
	game.update_meter()
	game.auto_expose()
	await game.take_photo()
	check(game.mode == "RESULT" and game.shots == 2,"Shoot freezes and opens result")
	check(game.current_photo != null,"Clean scene captured")
	check(game.current_result.score >= 60,"Correct photograph passes")
	check(game.current_result.evidence.rays.size() == 5,"Five visibility rays recorded")
	await screenshot("resultado")
	var frozen_theta = target.theta
	await frames(6)
	check(target.theta == frozen_theta,"Results freeze simulation")
	var first_score = game.best.score
	game.resume_search()
	game.t_index = 6
	game.n_index = game.apertures().size()-1
	game.focal = 105
	game.update_camera()
	await game.take_photo()
	check(game.current_result.movement == 0,"Long exposure degrades movement")
	check(game.best.score >= first_score,"Best shot retained")
	await screenshot("movida")
	# Finish all five jobs through the same production transitions.
	game.finish_assignment()
	check(game.assignment == 1 and game.shots == 3 and game.mode == "BRIEFING","Next assignment replenishes shots")
	for i in range(1,5):
		game.begin_assignment()
		await game.take_photo()
		game.finish_assignment()
	check(game.mode == "SUMMARY" and game.records.size() == 5,"Five-job session reaches summary")
	await screenshot("resumen")
	print("SESSION VIDEO MEMORY: %.2f MiB, textures %.2f, buffers %.2f, photo %s" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.0,game.current_photo.get_size()])
	check(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) <= 60000000,"Session graphics memory below 60 MB with shadow atlas")
	game.start_session(true)
	game.begin_assignment()
	check(game.night and game.mode == "SEARCH" and game.records.is_empty(),"Night restart resets session")
	check(game.park.lamps[0].light_energy > 0,"Night lamps enabled")
	await frames(5)
	await screenshot("noche")
	game.show_equipment()
	await frames(2)
	await screenshot("equipo")
	game.equipment.preset(1)
	game.apply_equipment()
	game.close_modal()
	game.mode = "SEARCH"
	await frames(8)
	await screenshot("mf")
	# Strong target guarantee across repeated boundaries.
	game.target.state = "CAMINANDO"
	game.target.theta = 237.9
	game.target.direction = 1
	for i in 200: game.update_person(game.target,.1)
	check(game.target.theta >= 0 and game.target.theta < 360 and game.target.visible,"Target remains in circular park")
	print("GAME TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
