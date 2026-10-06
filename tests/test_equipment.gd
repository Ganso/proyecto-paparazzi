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
	for body in 4:
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
		var error = game.Photo.ev(game.aperture_value(),1.0/game.shutter_denominator(),game.iso_value(),ev)
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
	var ev_base = game.Photo.ev(game.aperture_value(),1.0/game.shutter_denominator(),game.iso_value(),12.0)
	game.change_parameter("ev_comp", 3)
	check(is_equal_approx(game.equipment.exposure_compensation(), 1.0), "EV compensation changed via change_parameter")
	var ev_comp_delta = game.Photo.ev(game.aperture_value(),1.0/game.shutter_denominator(),game.iso_value(),12.0)
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
	# Thirds of a stop (docs/EQUIPAMIENTO_Y_OPTICAS.md): off, the dials go by whole stops as ever.
	game.exposure_thirds = false
	game.mode = "SEARCH"
	game.equipment.preset(1)
	game.equipment.set_exposure_mode("M")
	game.apply_equipment()
	game.n_index = game.apertures().find(4.0)
	game.t_index = 3
	game.iso_index = 0
	game.change_parameter("n",1)
	check(is_equal_approx(game.aperture_value(),5.6),"Whole stops: f/4 to f/5.6")
	game.exposure_thirds = true
	var seen = []
	for i in 3:
		game.change_parameter("n",1)
		seen.append(game.aperture_value())
	check(seen == [6.3,7.1,8.0],"Thirds: f/5.6, 6.3, 7.1, 8 (%s)" % str(seen))
	game.change_parameter("n",-1)
	check(is_equal_approx(game.aperture_value(),7.1),"Thirds go back the same way")
	seen = []
	for i in 4:
		game.change_parameter("t",1)
		seen.append(game.shutter_denominator())
	check(seen == [100,80,60,50],"Thirds of the shutter: 1/100, 1/80, 1/60, 1/50 (%s)" % str(seen))
	seen = []
	for i in 3:
		game.change_parameter("iso",1)
		seen.append(game.iso_value())
	check(seen == [125,160,200],"Thirds of the ISO: 125, 160, 200 (%s)" % str(seen))
	# Each third is a third: three of them change the exposure by one stop.
	var before = game.Photo.ev(game.aperture_value(),1.0/game.shutter_denominator(),game.iso_value(),12.0)
	game.change_parameter("t",1)
	var third = game.Photo.ev(game.aperture_value(),1.0/game.shutter_denominator(),game.iso_value(),12.0)
	check(absf(absf(third-before)-1.0/3.0) < .08,"A third of a stop is a third (%.2f)" % absf(third-before))
	# Held (D-pad, touch buttons) or with Shift, the dial jumps a whole stop from wherever it is.
	game.whole_hold = true
	var from = game.shutter_denominator()
	game.change_parameter("t",1)
	game.whole_hold = false
	check(game.shutter_denominator() == 20 and from == 40,"A held dial jumps a whole stop (1/%d to 1/%d)" % [from,game.shutter_denominator()])
	# The ends hold, and the lens's limits too.
	for i in 80: game.change_parameter("n",1)
	check(is_equal_approx(game.aperture_value(),game.apertures()[-1]),"The aperture stops at the lens's minimum")
	for i in 80: game.change_parameter("n",-1)
	check(is_equal_approx(game.aperture_value(),game.apertures()[0]),"The aperture stops at the lens's maximum")
	for i in 80: game.change_parameter("t",1)
	check(game.shutter_denominator() == 8,"The shutter stops at 1/8")
	# Film: the ISO is the roll's, thirds or not.
	game.equipment.preset(3)
	game.apply_equipment()
	game.refresh()
	var roll = game.iso_value()
	game.change_parameter("iso",1)
	check(game.iso_value() == roll and game.fine["iso"] == 0,"Film keeps its ISO")
	game.change_parameter("n",1)
	check(game.fine["n"] > 0 or game.third_gap("n",game.n_index-1) == 1,"The TLR moves by thirds too")
	# The automatic modes get closer with thirds than with whole stops.
	game.equipment.preset(1)
	game.equipment.set_exposure_mode("P")
	game.apply_equipment()
	var worst = [0.0,0.0]
	for k in 2:
		game.exposure_thirds = k == 1
		for step in 40:
			game.measured_ev = 5.0+step*.23
			game.auto_expose()
			worst[k] = maxf(worst[k],absf(game.Photo.ev(game.aperture_value(),1.0/game.shutter_denominator(),game.iso_value(),game.measured_ev)))
	check(worst[1] < .25 and worst[1] < worst[0],"Auto exposure in thirds is finer (%.2f against %.2f)" % [worst[1],worst[0]])
	# Aperture priority keeps the player's third.
	game.equipment.set_exposure_mode("A")
	game.apply_equipment()
	game.n_index = game.apertures().find(4.0)
	game.change_parameter("n",1)
	game.measured_ev = 11.3
	game.auto_expose()
	check(is_equal_approx(game.aperture_value(),4.5),"Aperture priority keeps f/4.5 (%.1f)" % game.aperture_value())
	# The Academy teaches with whole stops whatever the switch says.
	game.exposure_thirds = false
	game.clear_fine()
	print("EQUIPMENT TESTS: %d checks, %d failures" % [checks,failures])
	# TLR (docs/futuro/21 §3): film, manual focus only, 80 mm on 6×6 = 50 mm equivalent.
	game.equipment.preset(3)
	check(game.equipment.tlr() and game.equipment.film and game.equipment.focus_modes() == ["MF"] and not game.equipment.auto_exposure,"TLR preset: film, MF only, manual exposure")
	check(game.equipment.lens().min == 50.0 and game.equipment.lens().max == 50.0 and game.equipment.lens().wide == 2.8,"TLR lens: 80 mm f/2.8 (50 mm equivalent)")
	game.equipment.preset(0)
	quit(0 if failures == 0 else 1)
