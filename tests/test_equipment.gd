extends SceneTree
var game
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 10: await process_frame
	game.start_session(false)
	game.mode = "TEST"
	game.angle = 1081
	game.pitch = 100
	game.update_camera()
	check(is_equal_approx(game.angle,1) and game.pitch == 75,"Unbounded yaw, bounded pitch")
	for body in 3:
		game.equipment.preset(body)
		for lens in game.equipment.LENSES[body].size():
			game.equipment.lens_index = lens
			game.focal = 999
			game.apply_equipment()
			check(game.focal == game.equipment.lens().max,"Lens upper bound")
			check(game.apertures()[0] >= game.equipment.lens().long,"Tele end aperture bound")
			check(game.apertures()[-1] <= game.equipment.lens().stop,"Minimum aperture bound")
	game.equipment.preset(0)
	game.apply_equipment()
	check(game.aperture_button.disabled and not game.focus_slider.editable and game.lens_slider.editable,"Easy UI disables manual controls")
	var old_focus = game.focus_distance
	game.adjust_focus(1)
	check(game.focus_distance == old_focus,"AF prevents manual changes")
	game.equipment.preset(1)
	game.apply_equipment()
	check(game.equipment.focus_modes() == ["MF"] and not game.lens_slider.editable and game.af_button.disabled,"Rangefinder compatible equipment")
	game.mode = "SEARCH"
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	game._unhandled_input(wheel)
	check(game.focus_distance != old_focus,"Prime wheel focuses")
	game.equipment.preset(2)
	game.equipment.focus_mode = "MF"
	game.apply_equipment()
	old_focus = game.focus_distance
	var old_focal = game.focal
	wheel.shift_pressed = true
	game._unhandled_input(wheel)
	check(game.focus_distance != old_focus and game.focal == old_focal,"Shift wheel focuses without zoom")
	game.mode = "TEST"
	game.park.set_night(true)
	var lamp = game.park.lamps[0]
	var lit = lamp.global_position+Vector3(0,-1.1,.7)
	var dark = Vector3(0,1,19)
	check(game.park.illumination_ev(lit,true) > game.park.illumination_ev(dark,true)+1,"Lamp changes local meter reading")
	var box = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1,.1,1)
	collision.shape = shape
	box.add_child(collision)
	game.viewport.add_child(box)
	box.position = (lit+lamp.global_position)*.5
	await physics_frame
	await physics_frame
	check(not game.park.light_visible(lit,lamp.global_position),"Occluder blocks lamp metering")
	box.queue_free()
	game.park.set_night(false)
	var ground = Vector3(0,.1,0)
	var day_lit = game.park.illumination_ev(ground,false)
	var shade = StaticBody3D.new()
	var shade_shape = CollisionShape3D.new()
	var roof = BoxShape3D.new()
	roof.size = Vector3(3,.1,3)
	shade_shape.shape = roof
	shade.add_child(shade_shape)
	game.viewport.add_child(shade)
	shade.position = ground+game.park.sun.global_basis.z*2
	await physics_frame
	await physics_frame
	check(day_lit-game.park.illumination_ev(ground,false)>2,"Noon sun and shadow differ in EV")
	shade.queue_free()
	game.park.set_time_of_day("golden")
	var golden_sun = game.park.illumination_ev(Vector3(0, 3.0, 0), "golden")
	check(golden_sun > 13.0 and golden_sun < day_lit, "Golden hour sun EV is warm and softer than noon")
	check(absf(game.park.sun.rotation_degrees.x - (-15.0)) < 2.0, "Golden hour sun is low on horizon")
	game.start_session("golden")
	check(game.time_of_day == "golden" and not game.night, "Golden hour session initialized")
	check(game.status_label.text.begins_with("HORA DORADA"), "Status label shows HORA DORADA")
	game.start_session("day")
	for p in game.people: p.visible = false
	var person = game.people[0]
	person.visible = true
	person.theta = 260
	person.radius = 4
	person.lane = 1
	person.destination_lane = -1
	person.place()
	var other = game.people[1]
	other.visible = true
	other.theta = 270
	other.radius = 4
	other.place()
	check(not game.travel_clear(person,person.position,other.position),"Swept pedestrian collision")
	check(not game.travel_clear(person,person.position,other.position+(other.position-person.position).normalized()*2),"Large step cannot tunnel through pedestrian")
	check(game.try_change_lane(person),"Finds free nearest lane")
	check(person.destination_lane == 0,"Chooses nearest crossing")
	var wall = StaticBody3D.new()
	wall.collision_layer = 2
	var wall_shape = CollisionShape3D.new()
	var wall_box = BoxShape3D.new()
	wall_box.size = Vector3(.1,2,2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	game.viewport.add_child(wall)
	wall.position = game.park.polar(260,3)+Vector3.UP
	await physics_frame
	await physics_frame
	check(not game.travel_clear(person,person.position,game.park.polar(260,1.8)),"Obstacle blocks lane crossing")
	wall.queue_free()
	other.visible = false
	person.destination_lane = 0
	person.state = "CAMINANDO"
	person.lane_timer = 100
	var start_radius = person.radius
	game.update_person(person,.1)
	check(absf(person.radius-start_radius)<=person.speed*.1 and person.radius < start_radius,"Lane movement is gradual")
	for ev in [3.0,7.0,11.0,15.0]:
		game.measured_ev = ev
		game.auto_expose()
		var error = game.Photo.ev(game.apertures()[game.n_index],1.0/game.Photo.DENOMINATORS[game.t_index],game.Photo.ISOS[game.iso_index],ev)
		check(absf(error)<.6,"Auto exposure follows local EV")
	check(is_equal_approx(game.equipment.exposure_compensation(), 0.0), "Initial exposure compensation is 0.0 EV")
	game.equipment.change_exposure_compensation(1)
	check(is_equal_approx(game.equipment.exposure_compensation(), 0.3), "Step up compensation")
	game.equipment.change_exposure_compensation(-2)
	check(is_equal_approx(game.equipment.exposure_compensation(), -0.3), "Step down compensation")
	game.equipment.change_exposure_compensation(-20)
	check(is_equal_approx(game.equipment.exposure_compensation(), -2.0), "Min compensation clamped to -2.0 EV")
	game.equipment.change_exposure_compensation(40)
	check(is_equal_approx(game.equipment.exposure_compensation(), 2.0), "Max compensation clamped to +2.0 EV")
	game.mode = "SEARCH"
	game.equipment.preset(0)
	game.apply_equipment()
	game.measured_ev = 12.0
	game.auto_expose()
	var ev_base = game.Photo.ev(game.apertures()[game.n_index],1.0/game.Photo.DENOMINATORS[game.t_index],game.Photo.ISOS[game.iso_index],12.0)
	game.change_parameter("ev_comp", 3)
	check(is_equal_approx(game.equipment.exposure_compensation(), 1.0), "EV compensation changed via change_parameter")
	var ev_comp_delta = game.Photo.ev(game.apertures()[game.n_index],1.0/game.Photo.DENOMINATORS[game.t_index],game.Photo.ISOS[game.iso_index],12.0)
	check(ev_comp_delta < ev_base - 0.5, "Positive compensation lets in more light (lower camera EV delta)")
	check(game.exposure_button.text == "AUTO +1.0", "Exposure button shows compensated value")
	game.change_parameter("ev_comp", -3)
	check(game.exposure_button.text == "AUTO ±0.0", "Exposure button shows ±0.0 when zeroed")
		# Ornamental farolas with transparent glass panels and warm filament (docs/futuro/02, 2.3.2)
	check(game.park.lamps.size() == 12, "Park has 12 ornamental lampposts")
	check(game.park.glass_material != null and game.park.glass_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Lampposts carry transparent glass panels")
	check(game.park.bulb_material != null, "Lampposts carry incandescent bulb material")
	game.park.set_night(true)
	check(game.park.bulb_material.emission_enabled, "Night enables filament emission")
	game.park.set_night(false)
	check(not game.park.bulb_material.emission_enabled, "Day disables filament emission")
	for i in 500:
		var t = game.casting.generate()
		check(not (game.casting.catalog.piezas.cabeza[t.hair].style == "bald" and (t.profile == 3 or t.gender == "f")),"Appearance compatibility")
	print("EQUIPMENT TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
