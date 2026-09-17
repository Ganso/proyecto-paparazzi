extends Node
const Texts = preload("res://scripts/texts.gd")
const Photo = preload("res://scripts/photography.gd")
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
const ParkScene = preload("res://scripts/park.gd")
const Finder = preload("res://scripts/viewfinder.gd")
const Develop = preload("res://shaders/develop.gdshader")

var equipment = preload("res://scripts/equipment.gd").new()
var pitch = 0.0
var measured_ev = 14.0
var meter_timer = 0.0
var af_button: Button
var equipment_label: Button
var control_hint: Label
var exposure_label: Label
var focus_aid: TextureRect
var casting = Cast.new()
var people: Array = []
var park: Park
var viewport: SubViewport
var camera: Camera3D
var ui: Control
var finder: Control
var briefing: Label
var status_label: Label
var aperture_button: Button
var shutter_button: Button
var iso_button: Button
var focal_label: Label
var focus_label: Label
var dof_label: Label
var counter_label: Label
var lens_slider: HSlider
var focus_slider: HSlider
var modal: Control
var toast: Label
var n_index = 3
var t_index = 2
var iso_index = 0
var focal: float = 24.0
var focus_distance: float = 4.0
var angle: float = 120.0
var pan_velocity = 0.0
var target: Pedestrian
var night = false
var mode = "INTRO"
var shots = 3
var assignment = 0
var best: Dictionary = {}
var records: Array[Dictionary] = []
var current_result: Dictionary = {}
var best_photo: ImageTexture
var current_photo: ImageTexture
var total_time = 0.0
var shooting = false
var touches = {}
var mouse_origin = Vector2.ZERO
var mouse_last = Vector2.ZERO
var dragging = false
var dragged = false
var active_parameter = ""
var parameter_drag = 0.0
var skip_parameter_click = false
var touch_start = {}
var ui_touch_ids = {}
var had_multitouch = false
var sound: AudioStreamPlayer
var sandbox = false
var sandbox_paused = false
var shot_serial = 0
var sandbox_button: Button
var brief_preview: Pedestrian
var brief_viewport: SubViewport
var toast_time = 0.0
var boot_frames = 0
var screenshot_path = ""
var smoke = false
var run_metrics = false
var stress = false
var metrics: Array[float] = []
var min_frame = 0.0
var max_frame = 0.0
var fps_label: Label

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): screenshot_path = arg.trim_prefix("--screenshot=")
		if arg == "--smoke-test": smoke = true
		if arg == "--metrics": run_metrics = true
		if arg == "--stress": stress = true
	build_world()
	build_ui()
	populate()
	await settle_population()
	sound = AudioStreamPlayer.new()
	add_child(sound)
	update_camera()
	intro()
	if smoke or screenshot_path != "" or run_metrics:
		start_session(false)
		begin_assignment()
	if stress:
		for i in people.size():
			people[i].theta = 96.0+48.0*i/(people.size()-1)
			people[i].place()

func build_world() -> void:
	var container = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 2048
	container.add_child(viewport)
	park = ParkScene.new()
	viewport.add_child(park)
	park.build()
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.near = .08
	camera.far = 90
	# Lock the sensor width; fov is horizontal with KEEP_WIDTH.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	viewport.add_child(camera)
	camera.current = true

func populate() -> void:
	var counts = [3, 7, 6, 5]
	var radii = [1.8,4.0,7.0,11.5]
	for lane in 4:
		for i in counts[lane]:
			var p = Person.new()
			viewport.add_child(p)
			p.setup(casting.generate(people.size()%7 == 0),casting.catalog,people.size()+905)
			p.lane = lane
			p.direction = -1 if i%2 == 0 else 1
			p.radius = radii[lane] + (LANE_OFFSETS[lane] if p.direction > 0 else -LANE_OFFSETS[lane])
			p.theta = i*(360.0/counts[lane])+lane*7.0
			p.place()
			p.animate(0)
			people.append(p)

func style(color: Color, radius = 8, border = Color.TRANSPARENT) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(1)
	box.border_color = border
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func panel(parent: Control, rect: Rect2, color: Color, radius = 8) -> Panel:
	var node = Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel",style(color,radius))
	parent.add_child(node)
	return node

func label(parent: Control, text_value: String, rect: Rect2, font_size = 18, color = Color("e6e8dd")) -> Label:
	var node = Label.new()
	node.text = text_value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Control, text_value: String, rect: Rect2, callback: Callable, primary = false) -> Button:
	var node = Button.new()
	node.text = text_value
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",16)
	node.add_theme_color_override("font_color",Color("19251e") if primary else Color("dfe7d6"))
	node.add_theme_stylebox_override("normal",style(Color("b8d78c") if primary else Color("26342d"),8,Color("425044")))
	node.add_theme_stylebox_override("hover",style(Color("cee8ab") if primary else Color("35483b"),8,Color("82906f")))
	node.add_theme_stylebox_override("pressed",style(Color("95b966") if primary else Color("1a2721"),8))
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	panel(ui,Rect2(0,0,1280,78),Color("141d18"),0)
	label(ui,Texts.get_text("afotando"),Rect2(25,12,150,25),20,Color("e2e7d6"))
	label(ui,Texts.get_text("p_a_p_a_r_a_z_z_i"),Rect2(26,39,160,20),11,Color("91a482"))
	shutter_button = button(ui,"",Rect2(205,13,116,50),func(): parameter_click("t"))
	aperture_button = button(ui,"",Rect2(332,13,111,50),func(): parameter_click("n"))
	iso_button = button(ui,"",Rect2(804,13,128,50),func(): parameter_click("iso"))
	for entry in [[shutter_button,"t"],[aperture_button,"n"],[iso_button,"iso"]]:
		entry[0].gui_input.connect(func(event): parameter_input(event,entry[1]))
	equipment_label = button(ui,"Equipo",Rect2(950,18,135,38),show_equipment)
	exposure_label = label(ui,"AUTO",Rect2(1095,20,90,34),22,Color("b8d78c"))
	var job_panel = panel(ui,Rect2(25,96,1230,68),Color(.075,.115,.085,.91))
	sandbox_button = button(job_panel,"Sandbox · escena",Rect2(16,4,200,26),show_sandbox_controls)
	counter_label = label(job_panel,Texts.get_text("encargo_01_05"),Rect2(16,9,185,20),12,Color("b8d78c"))
	briefing = label(job_panel,"",Rect2(16,30,1170,30),20)
	status_label = label(job_panel,"",Rect2(835,8,375,22),13,Color("b5c3ad"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus_aid = TextureRect.new()
	focus_aid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_aid.texture = viewport.get_texture()
	focus_aid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_aid.material = ShaderMaterial.new()
	focus_aid.material.shader = preload("res://shaders/focus_aid.gdshader")
	ui.add_child(focus_aid)
	finder = Finder.new()
	finder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(finder)
	panel(ui,Rect2(0,627,1280,93),Color("141d18"),0)
	focal_label = label(ui,"",Rect2(25,637,170,25),20,Color("b8d78c"))
	lens_slider = HSlider.new()
	lens_slider.position = Vector2(26,675)
	lens_slider.size = Vector2(215,24)
	lens_slider.min_value = 24
	lens_slider.max_value = 105
	lens_slider.step = .1
	lens_slider.value = focal
	lens_slider.value_changed.connect(func(v): focal = v; update_camera())
	ui.add_child(lens_slider)
	focus_label = label(ui,"",Rect2(279,637,210,25),20,Color("b8d78c"))
	focus_slider = HSlider.new()
	focus_slider.position = Vector2(280,675)
	focus_slider.size = Vector2(215,24)
	focus_slider.min_value = 0
	focus_slider.max_value = 1
	focus_slider.step = .001
	focus_slider.value_changed.connect(func(v): set_manual_focus(INF if v >= .999 else .8/(1-v)))
	ui.add_child(focus_slider)
	dof_label = label(ui,"",Rect2(531,638,285,27),14,Color("c8d0bb"))
	control_hint = label(ui,Texts.get_text("arrastra_paneo_rueda_zoom_clic_af_espacio_disparo_ayuda"),Rect2(531,670,350,35),12,Color("90a287"))
	af_button = button(ui,Texts.get_text("enfocar"),Rect2(863,647,128,50),autofocus)
	button(ui,Texts.get_text("disparar"),Rect2(1005,642,248,59),take_photo,true)
	toast = label(ui,"",Rect2(290,574,700,35),16,Color("e2e8d4"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color",Color.BLACK)
	toast.add_theme_constant_override("shadow_offset_x",1)
	toast.add_theme_constant_override("shadow_offset_y",2)
	fps_label = label(ui,"",Rect2(27,586,200,23),12,Color("d2ddc6"))
	refresh()

func parameter_input(event: InputEvent, parameter: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: change_parameter(parameter,-1)
		if event.button_index == MOUSE_BUTTON_LEFT:
			active_parameter = parameter if event.pressed else ""
			if event.pressed: skip_parameter_click = false
			parameter_drag = 0
	elif event is InputEventMouseMotion and active_parameter == parameter:
		parameter_drag += event.relative.x-event.relative.y
		if abs(parameter_drag) >= 24:
			change_parameter(parameter,1 if parameter_drag > 0 else -1)
			skip_parameter_click = true
			parameter_drag = 0
	elif event is InputEventScreenTouch:
		if event.pressed:
			ui_touch_ids[event.index] = parameter
			parameter_drag = 0
		else: ui_touch_ids.erase(event.index)
	elif event is InputEventScreenDrag:
		parameter_drag += event.relative.x-event.relative.y
		if abs(parameter_drag) >= 24:
			change_parameter(parameter,1 if parameter_drag > 0 else -1)
			skip_parameter_click = true
			parameter_drag = 0

func parameter_click(parameter: String) -> void:
	if not skip_parameter_click: change_parameter(parameter,1)
	skip_parameter_click = false

func _input(event: InputEvent) -> void:
	# Releases can be consumed by an overlaid button after a scene drag.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		end_mouse_drag.call_deferred()
	if event is InputEventScreenTouch and not event.pressed:
		end_touch.call_deferred(event.index)

func end_mouse_drag() -> void:
	dragging = false
	active_parameter = ""

func end_touch(index: int) -> void:
	touches.erase(index)
	touch_start.erase(index)
	ui_touch_ids.erase(index)
	if touches.is_empty(): had_multitouch = false

func change_parameter(parameter: String, direction: int) -> void:
	if mode != "SEARCH" or equipment.auto_exposure: return
	match parameter:
		"n": n_index = posmod(n_index+direction,apertures().size())
		"t": t_index = posmod(t_index+direction,Photo.DENOMINATORS.size())
		"iso":
			if not equipment.film: iso_index = posmod(iso_index+direction,Photo.ISOS.size())
	refresh()

func refresh() -> void:
	if not is_instance_valid(aperture_button): return
	if equipment.film: iso_index = equipment.film_iso_index
	n_index = clampi(n_index,0,apertures().size()-1)
	aperture_button.disabled = equipment.auto_exposure
	shutter_button.disabled = equipment.auto_exposure
	iso_button.disabled = equipment.auto_exposure or equipment.film
	lens_slider.editable = equipment.zoom()
	focus_slider.editable = equipment.focus_mode == "MF"
	af_button.disabled = equipment.focus_mode == "MF"
	equipment_label.text = equipment.CAMERAS[equipment.body]
	exposure_label.text = "AUTO" if equipment.auto_exposure else "M"
	if equipment.focus_mode == "MF":
		control_hint.text = "Mirar: arrastrar · Foto: Espacio · H: ayuda\n"+("MF: Shift + rueda" if equipment.zoom() else "MF: rueda / Shift + rueda")
	else:
		control_hint.text = "Mirar: arrastrar · Foto: Espacio · H: ayuda\nClic: AF"+(" · Rueda: zoom" if equipment.zoom() else " · Objetivo fijo")
	finder.af_mode = equipment.focus_mode
	finder.body = equipment.body
	focus_aid.visible = equipment.focus_mode == "MF" and mode == "SEARCH"
	focus_aid.material.set_shader_parameter("body",equipment.body)
	aperture_button.text = Texts.get_text("1f") % apertures()[n_index]
	shutter_button.text = Texts.get_text("1_d") % Photo.DENOMINATORS[t_index]
	iso_button.text = ("▣ " if equipment.film else "")+Texts.get_text("iso_d") % Photo.ISOS[iso_index]
	focal_label.text = ("ZOOM " if equipment.zoom() else "FIJO ")+"%.0f mm" % focal
	focus_label.text = Texts.get_text("foco")+(Texts.get_text("infinito") if is_inf(focus_distance) else Texts.get_text("2f_m") % focus_distance)
	var depth = Photo.dof(focal,apertures()[n_index],focus_distance)
	dof_label.text = Texts.get_text("nitido_2f_m_s") % [depth.x,Texts.get_text("infinito") if is_inf(depth.y) else Texts.get_text("2f_m") % depth.y]
	finder.delta_ev = Photo.ev(apertures()[n_index],1.0/Photo.DENOMINATORS[t_index],Photo.ISOS[iso_index],measured_ev)
	focus_slider.set_value_no_signal(1 if is_inf(focus_distance) else 1-.8/focus_distance)
	lens_slider.set_value_no_signal(focal)
	counter_label.text = Texts.get_text("encargo_02d_05") % (assignment+1)
	counter_label.visible = not sandbox
	sandbox_button.visible = sandbox
	status_label.text = ("NOCHE" if night else "NUBES" if park.cloud_cover > .4 else "SOL")+" · EV %.1f · " % measured_ev+("sin límite" if sandbox else "%d disparos" % shots)

func update_camera() -> void:
	if not is_instance_valid(camera): return
	angle = fposmod(angle,360.0)
	pitch = clampf(pitch,-75,75)
	focal = clampf(focal,equipment.lens().min,equipment.lens().max)
	camera.rotation = Vector3(deg_to_rad(pitch),-deg_to_rad(angle),0)
	camera.fov = rad_to_deg(2*atan(36.0/(2.0*focal)))
	refresh()

func close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null

func create_modal() -> Control:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	panel(modal,Rect2(0,0,1280,720),Color(.035,.058,.043,1.0),0)
	return modal

func intro() -> void:
	mode = "INTRO"
	var root = create_modal()
	label(root,Texts.get_text("estudio_de_fotografia_01"),Rect2(75,70,600,28),14,Color("a7c683"))
	label(root,Texts.get_text("cada_persona_una_oportunidad"),Rect2(70,115,790,160),64,Color("e6ebdb"))
	var desc = label(root,Texts.get_text("encuentra_a_quien_describe_el_encargo_y_consigue_la_fotografia_t"),Rect2(75,302,780,72),22,Color("b7c5ad"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(root,Texts.get_text("05_encargos_03_disparos_por_encargo_tu_mejor_foto_cuenta"),Rect2(75,413,1100,28),13,Color("a7c683"))
	button(root,Texts.get_text("parque_dia"),Rect2(75,477,250,65),func(): start_session(false),true)
	button(root,Texts.get_text("parque_noche"),Rect2(340,477,250,65),func(): start_session(true))
	button(root,"Equipo / modos",Rect2(605,477,220,65),show_equipment)
	button(root,"Sandbox",Rect2(845,477,250,65),func(): start_session(false,true))
	label(root,Texts.get_text("arrastra_para_mirar_rueda_para_acercarte_clic_para_enfocar_espac"),Rect2(75,590,1070,60),16,Color("8f9f86"))
	label(root,Texts.get_text("m"),Rect2(950,161,245,130),95,Color("b8d78c"))
	label(root,"PROYECTO\nPAPARAZZI",Rect2(955,305,230,70),26,Color("a7b897"))

func start_session(is_night: bool, free_play = false) -> void:
	close_modal()
	sandbox = free_play
	sandbox_paused = false
	shot_serial = 0
	park.weather_time = 0
	if not free_play: park.clouds_enabled = true
	night = is_night
	park.set_night(night)
	records.clear()
	assignment = 0
	best_photo = null
	n_index = 0 if night else 3
	t_index = 4 if night else 2
	iso_index = 5 if night else 0
	focal = equipment.lens().min
	pitch = 0
	apply_equipment()
	focus_distance = 4
	angle = 120
	pan_velocity = 0
	update_camera()
	if sandbox:
		if is_instance_valid(target): target.protected_target = false
		target = null
		shots = 3
		best = {}
		briefing.text = "Prueba tu equipo. Clic: punto de medida / AF. Dispara y revisa el resultado."
		resume_search()
	else: new_assignment()

func new_assignment() -> void:
	if is_instance_valid(target): target.protected_target = false
	var candidates = people.filter(func(p): return p.lane in [1,2] and p.state != "RETIRADO")
	if candidates.is_empty(): candidates = people.filter(func(p): return p.visible)
	var all_traits = people.map(func(p): return p.traits)
	target = candidates[casting.rng.randi_range(0,candidates.size()-1)]
	var predicates = casting.predicates_for(target.traits,all_traits)
	assert(not predicates.is_empty(),Texts.get_text("el_encargo_debe_identificar_un_sujeto_unico"))
	target.protected_target = true
	briefing.text = Texts.get_text("busca")+", ".join(predicates)+"."
	shots = 3
	best = {}
	show_assignment()
	refresh()
	notify_player(Texts.get_text("encuentra_los_rasgos_del_encargo_usa_el_exposimetro_para_ajustar"))

func notify_player(message: String) -> void:
	toast.text = message
	toast_time = 4.0

func _process(dt: float) -> void:
	total_time += dt
	boot_frames += 1
	toast_time = maxf(0,toast_time-dt)
	toast.visible = toast_time > 0 and mode == "SEARCH"
	if mode == "SEARCH" and not shooting:
		var axis = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		angle = fposmod(angle+axis*dt*42*24/focal+pan_velocity*dt,360)
		pitch += (float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN)))*dt*30*24/focal
		pan_velocity = move_toward(pan_velocity,0,dt*180)
		if Input.is_physical_key_pressed(KEY_W): focal = clampf(focal+dt*30,equipment.lens().min,equipment.lens().max)
		if Input.is_physical_key_pressed(KEY_S): focal = clampf(focal-dt*30,equipment.lens().min,equipment.lens().max)
		if run_metrics:
			angle = 120.0
			focal = 24.0
		update_camera()
		park.update_weather(dt)
		if not (sandbox and sandbox_paused):
			for p in people: update_person(p,dt)
		meter_timer -= dt
		if meter_timer <= 0:
			meter_timer = .1
			update_meter()
			if equipment.auto_exposure: auto_expose()
			refresh()
	if run_metrics and boot_frames > 120 and mode == "SEARCH":
		metrics.append(dt*1000)
		fps_label.text = Texts.get_text("0f_fps_42_viandantes") % (1.0/maxf(dt,.0001))
	if boot_frames == 100:
		if smoke: smoke_test()
		if screenshot_path != "": save_screenshot.call_deferred()
	if run_metrics and boot_frames == 720:
		metrics.sort()
		var visible_count = people.filter(func(p): return camera.is_position_in_frustum(p.position+Vector3.UP*p.height*.75)).size()
		print("METRICS frames=%d visible=%d median_ms=%.2f p95_ms=%.2f max_ms=%.2f" % [metrics.size(),visible_count,metrics[metrics.size()/2],metrics[int(metrics.size()*.95)],metrics[-1]])
		get_tree().quit()

func update_person(p: Pedestrian, dt: float) -> void:
	var previous_position = p.position
	var previous_heading = p.rotation.y
	if p.state == "RETIRADO":
		p.state_time -= dt
		if p.state_time <= 0:
			# Respawn only behind the playable FOV, then walk continuously into view.
			p.theta = 296 if p.direction < 0 else 304
			p.state = "CAMINANDO"
			p.visible = true
	elif p.state == "CAMINANDO":
		if p.destination_lane >= 0:
			var target_r = LANES[p.destination_lane] + (LANE_OFFSETS[p.destination_lane] if p.direction > 0 else -LANE_OFFSETS[p.destination_lane])
			var new_radius = move_toward(p.radius, target_r, dt * p.speed * 0.7)
			var delta_theta = rad_to_deg(p.speed / maxf(p.radius, 0.5)) * dt * p.direction * 0.5
			var prop_theta = fposmod(p.theta + delta_theta, 360.0)
			var step_diag = park.polar(prop_theta, new_radius)
			if travel_clear(p, p.position, step_diag):
				p.theta = prop_theta
				p.radius = new_radius
				p.lane_change_blocked = 0.0
				p.stuck_time = maxf(0.0, p.stuck_time - dt * 2.0)
				if is_equal_approx(p.radius, target_r) or absf(p.radius - target_r) < 0.15:
					p.lane = p.destination_lane
					p.destination_lane = -1
			elif travel_clear(p, p.position, park.polar(p.theta, new_radius)):
				p.radius = new_radius
				p.lane_change_blocked = 0.0
				p.stuck_time = maxf(0.0, p.stuck_time - dt)
				if is_equal_approx(p.radius, target_r) or absf(p.radius - target_r) < 0.15:
					p.lane = p.destination_lane
					p.destination_lane = -1
			elif travel_clear(p, p.position, park.polar(prop_theta, p.radius)):
				p.theta = prop_theta
				p.stuck_time = maxf(0.0, p.stuck_time - dt)
			else:
				p.lane_change_blocked += dt
				p.stuck_time += dt
				if p.lane_change_blocked > 1.2:
					p.destination_lane = -1
					p.lane_change_blocked = 0.0
					var closest_l = 0
					var min_d = INF
					for l in LANES.size():
						var d = absf(LANES[l] - p.radius)
						if d < min_d: min_d = d; closest_l = l
					p.lane = closest_l
		else:
			var bounds = LANE_BOUNDS[p.lane]
			var nominal_r = LANES[p.lane] + (LANE_OFFSETS[p.lane] if p.direction > 0 else -LANE_OFFSETS[p.lane])
			
			# 2D lookahead & anticipatory lateral steering
			var net_steer = 0.0
			var nearest_dist = INF
			var nearest_rdiff = 0.0
			for other in people:
				if other == p or not other.visible: continue
				var a_diff = fposmod((other.theta - p.theta) * p.direction, 360.0)
				var dist_ahead = deg_to_rad(a_diff) * p.radius
				var r_diff = other.radius - p.radius
				var d_euclid = p.position.distance_to(other.position)
				if dist_ahead > 0.02 and dist_ahead < 2.5 and d_euclid < 2.5:
					var steer_dir = 0.0
					var space_out = bounds.y - other.radius
					var space_in = other.radius - bounds.x
					if space_out < 0.65:
						steer_dir = -1.0
					elif space_in < 0.65:
						steer_dir = 1.0
					elif other.direction == p.direction:
						steer_dir = 1.0 if space_out >= space_in else -1.0
					elif absf(r_diff) < 0.75:
						steer_dir = 1.0 if p.direction > 0 else -1.0
					if steer_dir != 0.0:
						if dist_ahead < nearest_dist:
							nearest_dist = dist_ahead
							nearest_rdiff = r_diff
						var weight = clampf((2.5 - dist_ahead) / 2.5, 0.0, 1.0)
						net_steer += steer_dir * weight

			var target_nominal = nominal_r
			if net_steer != 0.0:
				var evade_max = 0.38 if p.lane <= 1 else 0.48
				target_nominal = clampf(LANES[p.lane] + signf(net_steer) * evade_max, bounds.x, bounds.y)

			var speed_factor = 1.0
			if nearest_dist < 0.90 and absf(nearest_rdiff) < 0.52:
				speed_factor = clampf((nearest_dist - 0.40) / 0.50, 0.20, 1.0)
			var forward_speed = p.speed * speed_factor

			var delta_theta = rad_to_deg(forward_speed / maxf(p.radius, 0.5)) * dt * p.direction
			var proposed_theta = fposmod(p.theta + delta_theta, 360.0)
			var radial_rate = p.speed * 1.4
			var proposed_r = clampf(move_toward(p.radius, target_nominal, radial_rate * dt), bounds.x, bounds.y)

			# Try 2D movement steps
			var step_full = park.polar(proposed_theta, proposed_r)
			if travel_clear(p, p.position, step_full):
				p.theta = proposed_theta
				p.radius = proposed_r
				p.stuck_time = maxf(0.0, p.stuck_time - dt * 2.0)
			else:
				var step_radial = park.polar(p.theta, proposed_r)
				if not is_equal_approx(proposed_r, p.radius) and travel_clear(p, p.position, step_radial):
					p.radius = proposed_r
					p.stuck_time = maxf(0.0, p.stuck_time - dt * 1.5)
				else:
					var step_forward = park.polar(proposed_theta, p.radius)
					if travel_clear(p, p.position, step_forward):
						p.theta = proposed_theta
						p.stuck_time = maxf(0.0, p.stuck_time - dt * 1.5)
					else:
						# Try 2D lateral deflection steps
						var def_sign = 1.0 if p.direction > 0 else -1.0
						var def_r1 = clampf(p.radius + def_sign * 0.12, bounds.x, bounds.y)
						var step_def1 = park.polar(proposed_theta, def_r1)
						if not is_equal_approx(def_r1, p.radius) and travel_clear(p, p.position, step_def1):
							p.theta = proposed_theta
							p.radius = def_r1
							p.stuck_time = maxf(0.0, p.stuck_time - dt * 1.5)
						else:
							var def_r2 = clampf(p.radius - def_sign * 0.12, bounds.x, bounds.y)
							var step_def2 = park.polar(proposed_theta, def_r2)
							if not is_equal_approx(def_r2, p.radius) and travel_clear(p, p.position, step_def2):
								p.theta = proposed_theta
								p.radius = def_r2
								p.stuck_time = maxf(0.0, p.stuck_time - dt * 1.5)
							else:
								p.stuck_time += dt
								if p.stuck_time > 0.8:
									try_change_lane(p)
								if p.stuck_time > 2.5:
									p.direction *= -1
									p.stuck_time = 0.0

		p.lane_timer -= dt
		if p.lane_timer <= 0:
			p.lane_timer = p.rng.randf_range(8, 18)
			if p.destination_lane < 0: try_change_lane(p)
		if stress:
			if p.theta < 96 or p.theta > 144:
				p.theta = clampf(p.theta,96,144)
				p.direction *= -1
		var interest = int(p.theta/30)
		if interest != p.poi and p.theta < 240:
			p.poi = interest
			if not p.runner and p.rng.randf() < .15:
				var poi_blocked = false
				for other in people:
					if other != p and other.lane == p.lane and (other.state == "DETENIDO" or other.state == "SENTADO") and absf(other.theta - p.theta) < 12.0:
						poi_blocked = true
						break
				if not poi_blocked:
					p.state = "DETENIDO"
					p.state_time = p.rng.randf_range(3,8)
		if not p.runner and p.lane == 1 and p.destination_lane < 0 and not p.protected_target:
			for i in park.benches.size():
				var bench = park.benches[i]
				if abs(p.theta-bench.theta) < .35 and not bench.occupied and p.rng.randf() < .06:
					p.state = "SENTADO"
					p.theta = bench.theta
					p.radius = bench.get("radius", 4.85)
					p.state_time = p.rng.randf_range(20,60)
					p.bench_index = i
					bench.occupied = true
					break
	else:
		p.state_time -= dt
		if p.state_time <= 0:
			if p.bench_index >= 0:
				park.benches[p.bench_index].occupied = false
				p.bench_index = -1
				p.radius = LANES[p.lane] + (LANE_OFFSETS[p.lane] if p.direction > 0 else -LANE_OFFSETS[p.lane])
			p.state = "CAMINANDO"
	p.place()
	if p.state == "SENTADO": p.rotation.y = PI-deg_to_rad(p.theta)
	p.actual_velocity = (p.position-previous_position)/maxf(dt,.0001)
	if p.state == "CAMINANDO":
		var heading = atan2(-p.actual_velocity.x,-p.actual_velocity.z) if p.actual_velocity.length() > .01 else previous_heading
		p.rotation.y = lerp_angle(previous_heading,heading,1-exp(-dt*10))
	p.animate(dt,p.position.distance_to(previous_position))

func image_position(point: Vector2) -> Vector2:
	return point*Vector2(viewport.size)/ui.size

func nearest_af(point: Vector2) -> void:
	var nearest = 0
	var distance = INF
	var points = finder.points()
	for i in points.size():
		var d = point.distance_squared_to(points[i])
		if d < distance:
			distance = d
			nearest = i
	finder.active = nearest
	autofocus()

func ray_to(point: Vector3) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(camera.global_position,point)
	return viewport.world_3d.direct_space_state.intersect_ray(query)

func autofocus() -> void:
	if mode != "SEARCH" or equipment.focus_mode == "MF": return
	if equipment.focus_mode == "AF matricial": select_matrix_point()
	var pixel = image_position(finder.points()[finder.active])
	var origin = camera.project_ray_origin(pixel)
	var dir = camera.project_ray_normal(pixel)
	var hit = ray_to(origin+dir*90)
	finder.flash = .15
	finder.success = not hit.is_empty()
	if not hit.is_empty():
		focus_distance = maxf(.8,camera.global_position.distance_to(hit.position))
		refresh()
		play_tone(1100,.085)
		notify_player(Texts.get_text("af_confirmado_2f_m") % focus_distance)
	else:
		play_tone(230,.12)
		notify_player(Texts.get_text("sin_superficie_bajo_ese_punto_el_enfoque_se_mantiene"))

func play_tone(frequency: float, duration: float) -> void:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples = PackedByteArray()
	for i in int(22050*duration):
		var envelope = sin(PI*i/(22050*duration))
		var value = int(sin(TAU*frequency*i/22050)*envelope*2400)
		samples.append(value&255)
		samples.append((value>>8)&255)
	stream.data = samples
	sound.stream = stream
	sound.play()

func capture_evidence() -> Dictionary:
	var points = target.control_points()
	var projected = []
	for p in points: projected.append(camera.unproject_position(p)/Vector2(viewport.size))
	var head_pose = target.rig.get_bone_global_pose(target.bones.cabeza)
	var head_world = target.global_transform*(head_pose*Vector3(0,target.height/target.profile.relacion_cabeza,0))
	var feet_projected: Array[Vector2] = []
	for side in ["I","D"]:
		var foot_pose = target.rig.get_bone_global_pose(target.bones["pie."+side])
		var foot_world = target.global_transform*(foot_pose*Vector3(0,-target.nz*.03,0))
		feet_projected.append(camera.unproject_position(foot_world)/Vector2(viewport.size))
	var feet_point = feet_projected[0] if feet_projected[0].y > feet_projected[1].y else feet_projected[1]
	var blocked: Array[String] = []
	var rays: Array[Dictionary] = []
	for point in points:
		var hit = ray_to(point)
		var blocked_ray = not hit.is_empty() and (not hit.collider.has_meta("person") or hit.collider.get_meta("person") != target)
		var blocker = str(hit.collider.get_meta("label",Texts.get_text("un_elemento_del_parque"))) if blocked_ray else ""
		if blocked_ray: blocked.append(blocker)
		rays.append({"point":point,"blocked":blocked_ray,"label":blocker})
	var velocity = target.actual_velocity if target.state == "CAMINANDO" else Vector3.ZERO
	var view_axis = -camera.global_basis.z
	var perpendicular = (velocity-view_axis*velocity.dot(view_axis)).length()
	return {"f":focal,"n":apertures()[n_index],"t":1.0/Photo.DENOMINATORS[t_index],"iso":Photo.ISOS[iso_index],"s":focus_distance,"d":camera.global_position.distance_to(points[1]),"v":perpendicular,"scene_ev":park.illumination_ev(points[1],night,target),"head":camera.unproject_position(head_world)/Vector2(viewport.size),"feet":feet_point,"chest":projected[1],"in_front":not camera.is_position_behind(points[1]),"blockers":blocked,"rays":rays,"camera_transform":camera.global_transform,"projection":camera.get_camera_projection(),"subject_points":points,"subject_velocity":velocity,"motion_sign":signf(velocity.dot(camera.global_basis.x)),"film":equipment.film,"cloud_cover":park.cloud_cover,"seed":shot_serial+1}

func take_photo() -> void:
	if mode != "SEARCH" or (not sandbox and shots <= 0) or shooting: return
	if equipment.focus_mode != "MF": autofocus()
	update_meter()
	if equipment.auto_exposure: auto_expose()
	shooting = true
	pan_velocity = 0
	# Freeze first, then wait for physics and the render to represent precisely this state.
	await get_tree().physics_frame
	var evidence = capture_sandbox_evidence() if sandbox else capture_evidence()
	current_result = Photo.evaluate(evidence)
	current_result["evidence"] = evidence
	shot_serial += 1
	if not sandbox: shots -= 1
	await RenderingServer.frame_post_draw
	var clean_image = viewport.get_texture().get_image()
	current_photo = ImageTexture.create_from_image(clean_image)
	if not sandbox and (best.is_empty() or current_result.score > best.score):
		best = current_result.duplicate(true)
		best["photo"] = clean_image
	play_tone(100,.09)
	mode = "RESULT"
	shooting = false
	show_results()

func photo_material(result: Dictionary) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = Develop
	var evidence: Dictionary = result.evidence
	mat.set_shader_parameter("coc_pixels",minf(result.coc/36*viewport.size.x*.5,35))
	mat.set_shader_parameter("exposure",clampf(result.delta,-8,8))
	mat.set_shader_parameter("motion",Vector2(minf(result.drag/36*viewport.size.x,90)*evidence.motion_sign,0))
	var shake_angle = fposmod(evidence.seed*2.399963,TAU)
	mat.set_shader_parameter("shake",Vector2.from_angle(shake_angle)*minf(maxf(0,result.ratio-1)*5,45))
	mat.set_shader_parameter("grain",log(evidence.iso/100.0)/log(2.0)*.035)
	mat.set_shader_parameter("shot_seed",float(evidence.seed))
	return mat

func photo_preview(parent: Control, texture, result: Dictionary, rect: Rect2) -> void:
	var preview = TextureRect.new()
	preview.position = rect.position
	preview.size = rect.size
	preview.texture = ImageTexture.create_from_image(texture) if texture is Image else texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.material = photo_material(result)
	parent.add_child(preview)

func show_results() -> void:
	if sandbox:
		show_sandbox_result()
		return
	var root = create_modal()
	label(root,Texts.get_text("revelado_encargo_02d") % (assignment+1),Rect2(25,18,700,25),14,Color("a9c487"))
	label(root,Texts.get_text("cada_ajuste_deja_una_huella"),Rect2(25,50,770,45),30)
	photo_preview(root,current_photo,current_result,Rect2(25,112,750,422))
	var r = current_result
	label(root,Texts.get_text("rechazada") if r.rejected else Texts.get_text("d_100") % r.score,Rect2(25,548,260,51),36,Color("efaf83") if r.rejected else Color("b8d78c"))
	label(root,"—" if r.rejected else "★".repeat(r.stars)+"☆".repeat(5-r.stars),Rect2(295,555,300,40),28,Color("c9d790"))
	label(root,Texts.get_text("d_creditos") % r.credits,Rect2(598,557,180,32),18,Color("b7c5a9"))
	var evidence: Dictionary = r.evidence
	label(root,Texts.get_text("0f_mm_1f_1_d_s_iso_d_foco_s") % [evidence.f,evidence.n,roundi(1/evidence.t),evidence.iso,Texts.get_text("infinito") if is_inf(evidence.s) else Texts.get_text("2f_m") % evidence.s],Rect2(25,606,760,26),15,Color("b5c5a8"))
	label(root,Texts.get_text("mejor_del_encargo_d_100_quedan_d_disparos") % [best.score,shots],Rect2(25,646,745,30),16)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(803,105)
	scroll.size = Vector2(453,509)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",15)
	scroll.add_child(column)
	if r.rejected:
		var reason = Label.new()
		reason.text = r.reason
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_color_override("font_color",Color("f0b087"))
		reason.add_theme_font_size_override("font_size",16)
		column.add_child(reason)
	for line in r.lines:
		var text_label = Label.new()
		text_label.text = line
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.add_theme_color_override("font_color",Color("d4dfca"))
		text_label.add_theme_font_size_override("font_size",16)
		column.add_child(text_label)
	if shots > 0: button(root,Texts.get_text("reintentar_d") % shots,Rect2(803,642,204,52),resume_search)
	button(root,Texts.get_text("siguiente") if assignment < 4 else Texts.get_text("resumen"),Rect2(1020 if shots > 0 else 803,642,234 if shots > 0 else 451,52),finish_assignment,true)

func resume_search() -> void:
	close_modal()
	mode = "SEARCH"
	refresh()

func finish_assignment() -> void:
	if sandbox: resume_search(); return
	records.append(best)
	assignment += 1
	if assignment >= 5: summary()
	else: new_assignment()

func summary() -> void:
	mode = "SUMMARY"
	var root = create_modal()
	var credits = 0
	var passed = 0
	var best_index = 0
	for i in records.size():
		credits += records[i].credits
		if records[i].stars >= 3: passed += 1
		if records[i].score > records[best_index].score: best_index = i
	label(root,Texts.get_text("fin_de_la_sesion"),Rect2(50,38,650,25),14,Color("b8d78c"))
	label(root,Texts.get_text("tu_mirada_en_cinco_fotos"),Rect2(48,82,1180,55),43)
	photo_preview(root,records[best_index].photo,records[best_index],Rect2(50,180,710,400))
	label(root,Texts.get_text("mejor_fotografia_encargo_02d") % (best_index+1),Rect2(50,597,710,26),15,Color("b8d78c"))
	label(root,Texts.get_text("d_5_superados_d_creditos") % [passed,credits],Rect2(805,185,410,120),36,Color("b8d78c"))
	for i in records.size():
		label(root,Texts.get_text("02d_3d_100_s") % [i+1,records[i].score,"★".repeat(records[i].stars) if not records[i].rejected else Texts.get_text("rechazada_2")],Rect2(809,337+i*39,410,31),20)
	button(root,Texts.get_text("otra_sesion"),Rect2(805,593,402,59),intro,true)

func show_help() -> void:
	var previous = mode
	mode = "HELP"
	var root = create_modal()
	label(root,Texts.get_text("tu_camara_a_mano"),Rect2(65,55,1100,55),36,Color("b8d78c"))
	var text_value = "Mirar: arrastra en cualquier dirección. A/D: giro continuo de 360°. ↑/↓: inclinación.\nZoom: rueda o W/S, solo con objetivo zoom.\nAF: clic, F o ENFOCAR. Matricial elige la superficie más cercana entre nueve puntos.\nMF: Shift + rueda, R/T o deslizador. Con objetivo fijo también sirve la rueda sola.\nRéflex: alinea las dos mitades del círculo. Telemétrica: superpón la doble imagen.\nCompacta en MF: ayuda digital de imagen partida. La ayuda usa el centro del visor.\nExposición manual: Q/E diafragma, Z/X velocidad, C/V ISO.\nAUTO ajusta la exposición al punto seleccionado; en carrete conserva el ISO de la película.\n1–9: punto de medición/AF. G: tercios. Espacio: disparar.\nEquipo: pulsa el tipo de cámara arriba para elegir modos u objetivos.\nLas focales se expresan como equivalentes de 35 mm.\nSandbox: disparos ilimitados; pulsa «Sandbox · escena» para cambiar luz, nubes y movimiento."
	label(root,text_value,Rect2(65,128,1130,490),18)
	button(root,Texts.get_text("volver"),Rect2(965,628,250,53),func(): mode = previous; intro() if previous == "INTRO" else close_modal(),true)

func _unhandled_input(event: InputEvent) -> void:
	if run_metrics: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if mode == "HELP": resume_search() if sandbox or is_instance_valid(target) else intro()
			elif mode == "SEARCH": show_help()
			return
		if event.keycode == KEY_ENTER:
			if mode == "RESULT": resume_search() if shots > 0 else finish_assignment()
			elif mode == "BRIEFING": begin_assignment()
			elif mode == "INTRO": start_session(false)
			return
		if mode != "SEARCH": return
		match event.physical_keycode:
			KEY_SPACE: take_photo()
			KEY_F: autofocus()
			KEY_Q: change_parameter("n",-1)
			KEY_E: change_parameter("n",1)
			KEY_Z: change_parameter("t",-1)
			KEY_X: change_parameter("t",1)
			KEY_C: change_parameter("iso",-1)
			KEY_V: change_parameter("iso",1)
			KEY_R: adjust_focus(-1)
			KEY_T: adjust_focus(1)
			KEY_G: finder.thirds = not finder.thirds
		if event.keycode == KEY_QUESTION or event.physical_keycode == KEY_H: show_help()
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9: finder.active = event.physical_keycode-KEY_1
	if mode != "SEARCH": return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var step = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if event.shift_pressed or not equipment.zoom(): adjust_focus(step)
			else: focal += step*3; update_camera()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				dragged = false
				mouse_origin = event.position
				mouse_last = event.position
				pan_velocity = 0
			else:
				if dragging and not dragged: nearest_af(event.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(mouse_origin) > 6: dragged = true
		if dragged:
			var pan_delta = -event.relative.x*.065*24/focal
			angle = fposmod(angle+pan_delta,360)
			pitch -= event.relative.y*.065*24/focal
			pan_velocity = clampf(pan_delta*40,-80,80)
			update_camera()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			touch_start[event.index] = event.position
			if touches.size() >= 2: had_multitouch = true
			pan_velocity = 0
		else:
			if touches.has(event.index) and touches.size() == 1 and not had_multitouch and event.position.distance_to(touch_start[event.index]) < 10: nearest_af(event.position)
			touches.erase(event.index)
			touch_start.erase(event.index)
			if touches.is_empty(): had_multitouch = false
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() == 1:
			var pan_delta = -event.relative.x*.065*24/focal
			angle = fposmod(angle+pan_delta,360)
			pitch -= event.relative.y*.065*24/focal
			pan_velocity = clampf(pan_delta*40,-80,80)
		else:
			var ids = touches.keys()
			var other = ids[0] if ids[1] == event.index else ids[1]
			var old_distance: float = touches[event.index].distance_to(touches[other])
			var new_distance: float = event.position.distance_to(touches[other])
			if old_distance > 10: focal = clampf(focal*new_distance/old_distance,equipment.lens().min,equipment.lens().max)
			set_manual_focus(maxf(.8,(100.0 if is_inf(focus_distance) else focus_distance)*exp(-event.relative.y*.003)))
		touches[event.index] = event.position
		update_camera()

func smoke_test() -> void:
	assert(people.size() == 21)
	assert(target.protected_target)
	var triangles = park.triangle_count
	for p in people:
		assert(p.rig.get_bone_count() == 20)
		assert(p.triangle_count <= 1900,Texts.get_text("presupuesto_por_viandante"))
		triangles += p.triangle_count
	assert(triangles <= 100000,Texts.get_text("presupuesto_de_escena"))
	var evidence = capture_evidence()
	assert(Photo.evaluate(evidence) == Photo.evaluate(evidence))
	print("SMOKE PASS: 21 viandantes, 20 huesos/persona, %d triángulos, expediente determinista" % triangles)
	if screenshot_path == "" and not run_metrics: get_tree().quit()

func save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("SCREENSHOT: "+screenshot_path)
	if not run_metrics: get_tree().quit()

func apertures() -> Array:
	return equipment.apertures(focal)

func apply_equipment() -> void:
	focal = clampf(focal,equipment.lens().min,equipment.lens().max)
	n_index = clampi(n_index,0,apertures().size()-1)
	lens_slider.min_value = equipment.lens().min
	lens_slider.max_value = equipment.lens().max
	if equipment.film: iso_index = equipment.film_iso_index
	if not equipment.focus_mode in equipment.focus_modes(): equipment.focus_mode = equipment.focus_modes()[0]
	update_camera()

func option(parent: Control, values: Array, selected: int, rect: Rect2, callback: Callable) -> OptionButton:
	var control = OptionButton.new()
	control.position = rect.position
	control.size = rect.size
	control.add_theme_font_size_override("font_size",20)
	for value in values: control.add_item(str(value))
	control.select(selected)
	control.item_selected.connect(callback)
	parent.add_child(control)
	return control

var equipment_return = "INTRO"
func show_equipment() -> void:
	if mode != "EQUIPMENT": equipment_return = mode
	mode = "EQUIPMENT"
	var root = create_modal()
	label(root,"Elige tu equipo",Rect2(75,25,1100,60),38)
	for i in 3:
		button(root,["Fácil · todo automático","Calle · telemétrica manual","Acción · réflex AF puntual"][i],Rect2(75+i*380,95,360,52),func(): equipment.preset(i); apply_equipment(); show_equipment())
	label(root,"Selección manual de equipo",Rect2(75,166,1100,35),24)
	label(root,"Cámara",Rect2(75,225,200,35),20)
	option(root,equipment.CAMERAS,equipment.body,Rect2(330,220,700,45),func(i): equipment.body = i; equipment.lens_index = 0; apply_equipment(); show_equipment())
	label(root,"Objetivo (equiv. 35 mm)",Rect2(75,285,250,35),20)
	option(root,equipment.LENSES[equipment.body].map(func(l): return l.name),equipment.lens_index,Rect2(330,280,700,45),func(i): equipment.lens_index = i; apply_equipment(); show_equipment())
	label(root,"Enfoque",Rect2(75,345,200,35),20)
	option(root,equipment.focus_modes(),equipment.focus_modes().find(equipment.focus_mode),Rect2(330,340,700,45),func(i): equipment.focus_mode = equipment.focus_modes()[i]; apply_equipment(); show_equipment())
	label(root,"Exposición / medición",Rect2(75,405,250,35),20)
	option(root,["Manual · lectura del exposímetro","Automática · ajuste de exposición"],1 if equipment.auto_exposure else 0,Rect2(330,400,700,45),func(i): equipment.auto_exposure = i == 1; apply_equipment(); show_equipment())
	label(root,"Soporte",Rect2(75,465,200,35),20)
	option(root,["Digital · ISO variable","Carrete · ISO fijo"],1 if equipment.film else 0,Rect2(330,460,700,45),func(i): equipment.film = i == 1; apply_equipment(); show_equipment())
	if equipment.film:
		label(root,"Cargar película",Rect2(75,525,250,35),20)
		option(root,Photo.ISOS.map(func(iso): return "ISO %d" % iso),equipment.film_iso_index,Rect2(330,520,700,45),func(i): equipment.film_iso_index = i; apply_equipment(); show_equipment())
	label(root,"La telemétrica utiliza objetivos fijos y enfoque manual por coincidencia.",Rect2(75,585,1100,35),18)
	button(root,"Usar este equipo",Rect2(880,630,320,55),restore_equipment_screen,true)

func set_manual_focus(distance: float) -> void:
	if equipment.focus_mode != "MF": return
	focus_distance = maxf(.8,distance)
	refresh()

func adjust_focus(step: int) -> void:
	# Linear diopters include infinity without an unreachable slider endpoint.
	var diopters = 0.0 if is_inf(focus_distance) else 1.0/focus_distance
	diopters = clampf(diopters-step*.02,0,1.25)
	set_manual_focus(INF if diopters == 0 else 1.0/diopters)

func point_hit(point: Vector2) -> Dictionary:
	var pixel = image_position(point)
	var origin = camera.project_ray_origin(pixel)
	return ray_to(origin+camera.project_ray_normal(pixel)*90)

func select_matrix_point() -> void:
	var nearest = INF
	for i in finder.points().size():
		var hit = point_hit(finder.points()[i])
		if not hit.is_empty():
			var distance = camera.global_position.distance_squared_to(hit.position)
			if distance < nearest:
				nearest = distance
				finder.active = i

func update_meter() -> void:
	var hit = point_hit(finder.points()[finder.active])
	measured_ev = park.sky_ev(night) if hit.is_empty() else park.illumination_ev(hit.position,night,hit.collider.get_meta("person") if hit.collider.has_meta("person") else null)
	if equipment.focus_mode == "MF":
		var center_hit = point_hit(ui.size*.5)
		var distance = INF if center_hit.is_empty() else camera.global_position.distance_to(center_hit.position)
		var error = (0.0 if is_inf(focus_distance) else 1.0/focus_distance)-(0.0 if is_inf(distance) else 1.0/distance)
		focus_aid.material.set_shader_parameter("offset",clampf(error*focal*.006,-.06,.06))

func auto_expose() -> void:
	var best_cost = INF
	var stops = apertures()
	for n in stops.size():
		for t in Photo.DENOMINATORS.size():
			for iso in ([equipment.film_iso_index] if equipment.film else range(Photo.ISOS.size())):
				var delta = absf(Photo.ev(stops[n],1.0/Photo.DENOMINATORS[t],Photo.ISOS[iso],measured_ev))
				var cost = delta*10 + maxf(0,focal/Photo.DENOMINATORS[t]-1)*2 + iso*.12 + n*.03
				if cost < best_cost:
					best_cost = cost
					n_index = n
					t_index = t
					iso_index = iso

const LANES = [1.8,4.0,7.0,11.5]
const LANE_OFFSETS = [0.33,0.35,0.35,0.35]
const LANE_BOUNDS = [Vector2(1.2,2.4), Vector2(2.9,4.85), Vector2(6.1,7.9), Vector2(10.6,12.4)]
func travel_clear(p: Pedestrian, from: Vector3, to: Vector3) -> bool:
	# A swept body volume avoids stepping through benches, trunks and other people.
	var shape = CapsuleShape3D.new()
	shape.radius = .30
	shape.height = p.height
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,from+Vector3.UP*(p.height*.5))
	query.motion = to-from
	query.collision_mask = 2
	var space = viewport.world_3d.direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	if space.cast_motion(query)[0] < 1.0: return false
	for other in people:
		if other == p or not other.visible: continue
		var nearest = Geometry3D.get_closest_point_to_segment(other.position,from,to)
		var near_dist = nearest.distance_to(other.position)
		if near_dist < .58:
			var d_from = from.distance_to(other.position)
			var d_to = to.distance_to(other.position)
			if d_to >= d_from - 0.005:
				continue
			return false
	return true

const LANE_CAPACITIES = [3, 7, 7, 6]
func try_change_lane(p: Pedestrian) -> bool:
	if p.destination_lane >= 0: return true
	var choices = range(LANES.size())
	choices.sort_custom(func(a,b): return absf(LANES[a]-p.radius) < absf(LANES[b]-p.radius))
	for lane in choices:
		if lane == p.lane or is_equal_approx(LANES[lane],p.radius): continue
		var in_lane = 0
		for other in people:
			if (other.lane == lane or other.destination_lane == lane) and other.visible: in_lane += 1
		if in_lane >= LANE_CAPACITIES[lane]: continue
		var end = park.polar(p.theta,LANES[lane])
		if travel_clear(p,p.position,end):
			p.destination_lane = lane
			p.lane_change_blocked = 0.0
			return true
	# Waiting pedestrians retry; never teleport or walk through a blocked crossing.
	return false

func settle_population() -> void:
	# Wait for static collision geometry before choosing clear spawn locations.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for p in people:
		for attempt in 180:
			if travel_clear(p,p.position,p.position): break
			p.theta = fposmod(p.theta+2,360)
			p.place()

func show_assignment() -> void:
	mode = "BRIEFING"
	var root = create_modal()
	label(root,"Éste es tu encargo",Rect2(65,40,1120,65),42)
	label(root,"ENCARGO %02d / 05" % (assignment+1),Rect2(65,115,1100,30),16,Color("b8d78c"))
	var container = SubViewportContainer.new()
	container.position = Vector2(65,170)
	container.size = Vector2(450,465)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(container)
	brief_viewport = SubViewport.new()
	brief_viewport.size = Vector2i(450,465)
	brief_viewport.own_world_3d = true
	brief_viewport.transparent_bg = false
	brief_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(brief_viewport)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("263b32")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .65
	brief_viewport.add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0)
	light.light_energy = .9
	brief_viewport.add_child(light)
	brief_preview = Person.new()
	brief_viewport.add_child(brief_preview)
	brief_preview.setup(target.traits.duplicate(true),casting.catalog,701)
	brief_preview.state = "DETENIDO"
	brief_preview.rotation.y = .24
	brief_preview.animate(0)
	var portrait_camera = Camera3D.new()
	brief_viewport.add_child(portrait_camera)
	portrait_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	portrait_camera.size = brief_preview.height*1.3
	portrait_camera.position = Vector3(0,brief_preview.height*.53,-4)
	portrait_camera.look_at(Vector3(0,brief_preview.height*.53,0))
	portrait_camera.current = true
	var description = label(root,"Busca a esta persona en el parque.\n\n"+"\n".join(casting.descriptors(target.traits)),Rect2(565,190,640,285),24)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(root,"Corre con ropa deportiva: cuida la velocidad de obturación." if target.runner else "Recuerda su ropa, peinado y accesorios.",Rect2(565,505,635,65),18,Color("b8d78c")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(root,"Entrar en la fase · Intro",Rect2(750,625,455,60),begin_assignment,true)
	button(root,"Menú",Rect2(565,625,165,60),intro)

func begin_assignment() -> void:
	if mode != "BRIEFING": return
	resume_search()

func restore_equipment_screen() -> void:
	mode = equipment_return
	match mode:
		"INTRO": intro()
		"RESULT": show_results()
		"BRIEFING": show_assignment()
		_: close_modal()
	refresh()

func show_sandbox_controls() -> void:
	if not sandbox: return
	mode = "SANDBOX_SETTINGS"
	var root = create_modal()
	label(root,"Sandbox · prepara la escena",Rect2(75,65,1100,60),38)
	label(root,"Sin encargos, sin puntuación y sin límite de disparos.",Rect2(75,145,1100,40),23)
	label(root,"Iluminación",Rect2(75,250,250,40),22)
	option(root,["Día","Noche"],1 if night else 0,Rect2(350,245,650,48),func(i): night = i == 1; park.set_night(night))
	label(root,"Nubes",Rect2(75,335,250,40),22)
	option(root,["Cielo despejado","Nubes en movimiento"],1 if park.clouds_enabled else 0,Rect2(350,330,650,48),func(i): park.clouds_enabled = i == 1; park.update_weather(0))
	label(root,"Personajes",Rect2(75,420,250,40),22)
	option(root,["En movimiento","Quietos para practicar"],1 if sandbox_paused else 0,Rect2(350,415,650,48),func(i): set_sandbox_pause(i == 1))
	button(root,"Volver al menú",Rect2(75,620,260,60),intro)
	button(root,"Probar la cámara",Rect2(820,620,380,60),resume_search,true)

func set_sandbox_pause(paused: bool) -> void:
	sandbox_paused = paused
	if paused:
		for p in people: p.actual_velocity = Vector3.ZERO

func capture_sandbox_evidence() -> Dictionary:
	var hit = point_hit(finder.points()[finder.active])
	var distance = 80.0 if hit.is_empty() else camera.global_position.distance_to(hit.position)
	var velocity = Vector3.ZERO
	var person = null
	if not hit.is_empty() and hit.collider.has_meta("person"):
		person = hit.collider.get_meta("person")
		velocity = person.actual_velocity
	var axis = -camera.global_basis.z
	var perpendicular = (velocity-axis*velocity.dot(axis)).length()
	return {"f":focal,"n":apertures()[n_index],"t":1.0/Photo.DENOMINATORS[t_index],"iso":Photo.ISOS[iso_index],"s":focus_distance,"d":distance,"v":perpendicular,"scene_ev":park.sky_ev(night) if hit.is_empty() else park.illumination_ev(hit.position,night,person),"head":Vector2(.5,.2),"feet":Vector2(.5,.8),"chest":Vector2(.5,.5),"in_front":true,"blockers":[],"motion_sign":signf(velocity.dot(camera.global_basis.x)),"film":equipment.film,"cloud_cover":park.cloud_cover,"seed":shot_serial+1}

func show_sandbox_result() -> void:
	var root = create_modal()
	label(root,"Sandbox · fotografía %d" % shot_serial,Rect2(25,30,1170,60),36)
	photo_preview(root,current_photo,current_result,Rect2(25,120,825,464))
	var e: Dictionary = current_result.evidence
	var info = "Tu cámara\n\n%.0f mm · f/%.1f\n1/%d s · ISO %d\n%s\n\nLuz medida: EV %.1f\nError de exposición: %+.2f EV\nDistancia: %.2f m\nDesenfoque: %.3f mm\nMovimiento: %.3f mm" % [e.f,e.n,roundi(1/e.t),e.iso,"Carrete · ISO fijo" if e.film else "Digital",e.scene_ev,current_result.delta,e.d,current_result.coc,current_result.drag]
	label(root,info,Rect2(885,120,360,420),20).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(root,"La foto conserva los ajustes del disparo. Prueba otro enfoque, exposición o equipo.",Rect2(25,584,825,50),17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(root,"Menú",Rect2(25,647,165,50),intro)
	button(root,"Cambiar equipo",Rect2(210,647,260,50),show_equipment)
	button(root,"Seguir probando · Intro",Rect2(885,620,360,75),resume_search,true)
