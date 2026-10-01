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
var exposure_label: Control
var exposure_button: Button
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
var time_of_day = "day"
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
var focus_dragging = false
var smoothed_focus_aid_offset = 0.0
var dragging = false
var dragged = false
var active_parameter = ""
var parameter_drag = 0.0
var skip_parameter_click = false
var touch_start = {}
var ui_touch_ids = {}
var had_multitouch = false
var sound: AudioStreamPlayer
var graphics_preset: String = "Ultra"
var graphics_button: Button
var graphics_button_intro: Button
var graphics_return: String = "INTRO"
var sandbox = false
var sandbox_paused = false
var shot_serial = 0
var sandbox_button: Button
var brief_preview: Pedestrian
var brief_viewport: SubViewport
var toast_time = 0.0
var boot_frames = 0
var screenshot_path = ""
var advance_seconds = 0.0
var pigeons
var dog
var ambience
# Academia de fotografía (scripts/academy.gd, docs/futuro/06).
var academy
var academy_demo_shot = false
# The person the last autofocus locked on (sandbox photos of fast subjects, see capture_sandbox_evidence).
var af_person = null
var academy_last_thirds = ""
var extras
var forced_activity = ""
var stage = ""
# --academy=<lección>:<teoria|demo|practica>[:página]: open a lesson directly (evidence captures).
var academy_start = ""
var academy_tour = ""
# ---- Scenarios (docs/futuro/01 Alternativa C) ----
# "clasico": the photographer stands in the centre of the cylindrical park (and the Academy uses it).
# "grande": the big park with a path network, walked freely; the camera is raised to the eye with a
# toggle (right click / Y) and only then the camera interface appears.
# Changing scenario reloads the scene; these statics survive the reload.
static var scenario = "clasico"
static var pending_start = {}
static var equipment_state = {}
const GRANDE_PEOPLE = 45
var crowd                           # crowd_graph.gd in the big park
var player: CharacterBody3D
var player_proxy                    # what pedestrians avoid (player_proxy.gd)
var camera_raised = true            # always true in the classic park
var raise_anim = 1.0                # 0 hanging from the neck … 1 at the eye
var eye_height = 1.6
var walk_phase = 0.0
var walk_demo = -1.0                # --walk-demo: a scripted stroll for the evidence video
var demo_keys = {}
# --photo-walk: stroll along the paths and photograph people now and then (evidence video).
var photo_walk = {}
var viewmodel: Node3D
var walk_label: Label
var walk_hint: Label
var raise_flash: ColorRect
const WALK_SPEED = 1.4
const RUN_SPEED = 3.2
const WALK_FOV = 72.0
# ---- Realistic camera finders (docs/futuro/07 §1, scripts/camera_body.gd) ----
# view_rect: where the camera image sits on screen (ui coordinates). In the classic interface it is
# the whole screen; with the camera interface each body frames it its own way (eyepiece, LCD…).
var view_rect = Rect2(0,0,1280,720)
var view_shift = Vector2.ZERO       # rangefinder parallax (ui pixels), see image_position()
var interface_mode = "camara"       # "camara" (immersive) or "clasica"
var camera_body
var hud_top: Array = []
var hud_bottom: Array = []
var controls_shown = false          # Tab: show the camera's controls over the finder
var hud_hover = 0.0
var smoke = false
var run_metrics = false
var stress = false
var metrics: Array[float] = []
var gpu_metrics: Array[float] = []
var cpu_metrics: Array[float] = []
var start_time_of_day = "day"
# Fixed framing for --screenshot captures: --angle=, --pitch=, --focal= (degrees, degrees, mm).
var shot_view = {}
# --burst=<n>: with --screenshot=<path>.png, save n consecutive frames (<path>_000.png, …) to hunt
# single-frame artefacts such as sparkles.
var burst_frames = 0
# Scripted camera for the video evidence (tools/capture_video.sh, docs/TESTS §4.2):
# --lens=<body>,<lens>, --pan=<deg/s>, --zoom-to=<mm> (over 12 s), --follow (tracks the pedestrian
# nearest to the starting angle), --af (autofocus every half second), --hud=0 (hide the HUD).
var demo = {}
var demo_time = -1.0
var demo_follow: Node3D
var demo_focal_start = 0.0
# --debug-off=ssr,ssil,ssao,sdfgi,glow,volumetric,dof,textured,clearcoat: switch effects off to
# isolate rendering artefacts (applied after every graphics preset).
var debug_off: PackedStringArray = []

func apply_debug_off() -> void:
	if debug_off.is_empty() or park == null: return
	var env = park.environment.environment
	for key in debug_off:
		match key:
			"ssr": env.ssr_enabled = false
			"ssil": env.ssil_enabled = false
			"ssao": env.ssao_enabled = false
			"sdfgi": env.sdfgi_enabled = false
			"glow": env.glow_enabled = false
			"volumetric": env.volumetric_fog_enabled = false
			"dof": if is_instance_valid(dof_pass): set_dof_blur(false)
			"textured": Person.mannequin_material().set_shader_parameter("textured",false)
			"clearcoat": Person.mannequin_material().set_shader_parameter("clearcoat_amount",0.0)
			"rim": Person.mannequin_material().set_shader_parameter("rim_amount",0.0)
			"lamps": for lamp in park.lamps: lamp.visible = false
			"pcss": park.sun.light_angular_distance = 0.0
			"sun_shadow": park.sun.shadow_enabled = false
			"pbr": Person.mannequin_material().shader = preload("res://shaders/cel_shading.gdshader")
			"outline": Person.mannequin_material().next_pass = null
			"nanview":
				if not camera.has_node("DebugNan"):
					var quad = QuadMesh.new()
					quad.size = Vector2(2,2)
					var probe = MeshInstance3D.new()
					probe.name = "DebugNan"
					probe.mesh = quad
					probe.extra_cull_margin = 16384
					var probe_material = ShaderMaterial.new()
					probe_material.shader = preload("res://shaders/debug_nan.gdshader")
					probe.material_override = probe_material
					camera.add_child(probe)
var viewport_container: SubViewportContainer
# Post-processing of the viewfinder (docs/futuro/17 postprocesado): exact depth of field in
# Forward+ Ultra and lens character (vignetting, chromatic aberration) in every profile but Bajo.
var dof_pass: MeshInstance3D
var lens_material: ShaderMaterial
var min_frame = 0.0
var max_frame = 0.0
var fps_label: Label

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): screenshot_path = arg.trim_prefix("--screenshot=")
		if arg == "--smoke-test": smoke = true
		if arg == "--metrics": run_metrics = true
		if arg == "--stress": stress = true
		if arg.begins_with("--profile="): graphics_preset = arg.trim_prefix("--profile=")
		if arg.begins_with("--time="): start_time_of_day = arg.trim_prefix("--time=")
		if arg.begins_with("--burst="): burst_frames = int(arg.trim_prefix("--burst="))
		if arg.begins_with("--advance="): advance_seconds = float(arg.trim_prefix("--advance="))
		if arg.begins_with("--activity="): forced_activity = arg.trim_prefix("--activity=")
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
		if arg.begins_with("--academy="): academy_start = arg.trim_prefix("--academy=")
		if arg.begins_with("--academy-tour="): academy_tour = arg.trim_prefix("--academy-tour=")
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg == "--raised": pending_start["raised"] = true
		if arg == "--walk-demo": walk_demo = 0.0
		if arg == "--photo-walk": photo_walk = {"t":0.0,"phase":"walk","timer":3.0}
		if arg == "--sandbox": pending_start["sandbox_demo"] = true
		if arg.begins_with("--at="): pending_start["at"] = arg.trim_prefix("--at=")
		if arg.begins_with("--scare-at="): demo["scare-at"] = float(arg.get_slice("=",1))
		for key in ["lens","pan","zoom-to","hud"]:
			if arg.begins_with("--%s=" % key): demo[key] = arg.get_slice("=",1)
		if arg in ["--follow","--follow-target","--af","--mf-rack","--expose"]: demo[arg.trim_prefix("--")] = true
		if arg.begins_with("--shoot-at="): demo["shoot-at"] = float(arg.get_slice("=",1))
		if arg.begins_with("--debug-off="): debug_off = arg.trim_prefix("--debug-off=").split(",")
		for key in ["angle","pitch","focal"]:
			if arg.begins_with("--%s=" % key): shot_view[key] = float(arg.get_slice("=",1))
	if not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--profile=")): graphics_preset = startup_profile()
	# Ultra needs Forward+ and the other profiles run in gl_compatibility (docs/futuro/17 §2.1).
	# Desktop runs every profile in Forward+ (docs/futuro/17 §2.1). Ultra's effects need it: in the
	# gl_compatibility fallback (Android, no Vulkan) the top profile is Alto.
	if not ParkScene.forward_plus() and graphics_preset == "Ultra" and not smoke and screenshot_path == "" and not run_metrics: graphics_preset = "Alto"
	build_world()
	build_ui()
	academy = preload("res://scripts/academy.gd").new(self)
	ui.add_child(academy)
	preload("res://scripts/academy.gd").register_actions()
	if not InputMap.has_action("camara_controles"):
		InputMap.add_action("camara_controles")
		var tab = InputEventKey.new()
		tab.physical_keycode = KEY_TAB
		InputMap.action_add_event("camara_controles",tab)
		var back = InputEventJoypadButton.new()
		back.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("camara_controles",back)
	if not InputMap.has_action("camara_al_ojo"):
		# Big park: raise / lower the camera (a toggle). Right click is handled in photographer_input().
		InputMap.add_action("camara_al_ojo")
		var y_button = InputEventJoypadButton.new()
		y_button.button_index = JOY_BUTTON_Y
		InputMap.action_add_event("camara_al_ojo",y_button)
	populate()
	sound = AudioStreamPlayer.new()
	add_child(sound)
	await settle_population()
	await warm_up_view()
	update_camera()
	apply_graphics_preset(graphics_preset)
	if not equipment_state.is_empty():
		equipment.body = equipment_state.body
		equipment.lens_index = equipment_state.lens
		equipment.focus_mode = equipment_state.focus
		equipment.auto_exposure = equipment_state.auto
		equipment.film = equipment_state.film
		equipment.film_iso_index = equipment_state.film_iso
		equipment.ev_comp_index = equipment_state.ev
		apply_equipment()
	intro()
	if pending_start.has("time"):
		start_session(pending_start.time,pending_start.get("sandbox",false))
	elif pending_start.has("academy"):
		show_academy()
	for key in ["time","sandbox","academy"]: pending_start.erase(key)
	if run_metrics:
		# Measure the real cost, not the vsync cap.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	if demo.has("lens"):
		var parts = str(demo.lens).split(",")
		equipment.preset(int(parts[0]))
		equipment.lens_index = int(parts[1]) if parts.size() > 1 else 0
		if "--manual" in OS.get_cmdline_user_args(): equipment.auto_exposure = false
	if smoke or screenshot_path != "" or run_metrics or not demo.is_empty() or not photo_walk.is_empty():
		start_session(start_time_of_day,bool(pending_start.get("sandbox_demo",false)))
		begin_assignment()
		if not demo.is_empty():
			apply_equipment()
			if str(demo.get("hud","1")) == "0": ui.visible = false
	if stress:
		for i in people.size():
			people[i].theta = 96.0+48.0*i/(people.size()-1)
			people[i].place()

# Look around once while the intro screen covers the view: every material of the park (water,
# grass, lit windows…) is compiled now instead of stalling the first time it enters the frame.
func warm_up_view() -> void:
	var saved = camera.rotation
	for step in 4:
		camera.rotation = Vector3(0,step*PI*.5,0)
		await RenderingServer.frame_post_draw
	camera.rotation = saved

func build_world() -> void:
	var container = SubViewportContainer.new()
	viewport_container = container
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 2048
	container.add_child(viewport)
	update_render_resolution()
	get_window().size_changed.connect(update_render_resolution)
	park = (preload("res://scripts/park_grande.gd") if scenario == "grande" else ParkScene).new()
	park.detail = "hd" if ParkScene.forward_plus() else "lo"
	Person.detail = "lo" if "lo_people" in debug_off else park.detail
	viewport.add_child(park)
	park.build()
	pigeons = preload("res://scripts/pigeons.gd").new()
	if scenario == "grande":
		# Two flocks on the lawns beside the plaza.
		pigeons.homes = [Vector3(14,0,-5),Vector3(-14,0,5)].map(func(v): return Vector2(fposmod(rad_to_deg(atan2(v.x,-v.z)),360.0),Vector2(v.x,v.z).length()))
	viewport.add_child(pigeons)
	pigeons.build(Person.detail)
	extras = preload("res://scripts/extras.gd").new()
	viewport.add_child(extras)
	# The meadow extras belong to the classic park; in the big park the crowd itself fills it.
	if scenario == "clasico": extras.build(Person.detail)
	ambience = preload("res://scripts/ambience.gd").new()
	if scenario == "grande":
		ambience.fountain_pos = Vector3(0,.8,0)
		ambience.bird_points = [Vector3(-30,5,20),Vector3(30,5,-24),Vector3(-40,5,-30),Vector3(36,5,32),Vector3(4,5,-24),Vector3(-6,5,26)]
		ambience.cricket_points = [Vector3(-20,.3,14),Vector3(20,.3,-14),Vector3(0,.3,-40),Vector3(-48,.3,0),Vector3(48,.3,8)]
	viewport.add_child(ambience)
	ambience.build(park,pigeons)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.near = .08
	# Far enough for the skyline towers at 110–160 m (docs/futuro/17 fase 4).
	camera.far = 320
	# Lock the sensor width; fov is horizontal with KEEP_WIDTH.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	viewport.add_child(camera)
	camera.current = true
	lens_material = ShaderMaterial.new()
	lens_material.shader = preload("res://shaders/viewfinder_lens.gdshader")
	if ParkScene.forward_plus():
		var quad = QuadMesh.new()
		quad.size = Vector2(2,2)
		dof_pass = MeshInstance3D.new()
		dof_pass.mesh = quad
		dof_pass.extra_cull_margin = 16384
		dof_pass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dof_material = ShaderMaterial.new()
		dof_material.shader = preload("res://shaders/viewfinder_dof.gdshader")
		# First of the transparent pass: glass, falling water and other transparents are drawn over it
		# (it copies the opaque image; drawn last, it erased them).
		dof_material.render_priority = -128
		dof_pass.material_override = dof_material
		camera.add_child(dof_pass)

func populate() -> void:
	if scenario == "grande":
		populate_grande()
		return
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
	# One pedestrian of the bench path walks a dog (docs/futuro/19 §3).
	for p in people:
		if p.lane == 1 and not p.runner and p.traits.profile != 3:
			p.has_dog = true
			dog = preload("res://scripts/dog.gd").new()
			viewport.add_child(dog)
			dog.setup(p,77,Color("a8743f"))
			break

# Big park: 45 pedestrians spread over the path graph (crowd_graph.gd), and the photographer.
func populate_grande() -> void:
	crowd = preload("res://scripts/crowd_graph.gd").new(self)
	var rng = RandomNumberGenerator.new()
	rng.seed = 2610
	for i in GRANDE_PEOPLE:
		var p = Person.new()
		viewport.add_child(p)
		p.setup(casting.generate(people.size()%7 == 0),casting.catalog,people.size()+905)
		p.lane = 1
		p.pref_offset = rng.randf_range(-.15,.25)
		crowd.spawn(p,rng)
		p.animate(0)
		people.append(p)
	for p in people:
		if not p.runner and p.traits.profile != 3:
			p.has_dog = true
			dog = preload("res://scripts/dog.gd").new()
			viewport.add_child(dog)
			dog.setup(p,77,Color("a8743f"))
			break
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	player.collision_layer = 0
	player.collision_mask = 2
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = .85
	player.add_child(shape)
	player.position = Vector3(0,0,15)
	viewport.add_child(player)
	player_proxy = preload("res://scripts/player_proxy.gd").new()
	player_proxy.position = player.position
	viewport.add_child(player_proxy)
	angle = 0.0
	camera_raised = false
	raise_anim = 0.0
	build_viewmodel()

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
	# The camera body (eyecup, finder data) lies under the HUD: the HUD bars fold over it.
	camera_body = preload("res://scripts/camera_body.gd").new(self)
	ui.add_child(camera_body)
	panel(ui,Rect2(0,0,1280,78),Color("141d18"),0)
	label(ui,Texts.get_text("afotando"),Rect2(25,12,150,25),20,Color("e2e7d6"))
	label(ui,Texts.get_text("p_a_p_a_r_a_z_z_i"),Rect2(26,39,160,20),11,Color("91a482"))
	shutter_button = button(ui,"",Rect2(205,13,116,50),func(): parameter_click("t"))
	aperture_button = button(ui,"",Rect2(332,13,111,50),func(): parameter_click("n"))
	iso_button = button(ui,"",Rect2(804,13,128,50),func(): parameter_click("iso"))
	exposure_button = button(ui,"AUTO",Rect2(1095,13,165,50),func(): parameter_click("ev_comp"))
	exposure_label = exposure_button
	for entry in [[shutter_button,"t"],[aperture_button,"n"],[iso_button,"iso"],[exposure_button,"ev_comp"]]:
		entry[0].gui_input.connect(func(event): parameter_input(event,entry[1]))
	equipment_label = button(ui,"Equipo",Rect2(950,18,135,38),show_equipment)
	var job_panel = panel(ui,Rect2(25,96,1230,68),Color(.075,.115,.085,.91))
	sandbox_button = button(job_panel,"Sandbox · escena",Rect2(16,4,200,26),show_sandbox_controls)
	graphics_button = button(job_panel,"Gráficos · " + graphics_preset,Rect2(225,4,130,26),show_graphics_settings)
	counter_label = label(job_panel,Texts.get_text("encargo_01_05"),Rect2(16,9,185,20),12,Color("b8d78c"))
	briefing = label(job_panel,"",Rect2(16,30,1170,30),20)
	status_label = label(job_panel,"",Rect2(835,8,375,22),13,Color("b5c3ad"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus_aid = TextureRect.new()
	focus_aid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_aid.texture = viewport.get_texture()
	focus_aid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # it follows view_rect, smaller than the texture
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
	focus_slider.step = .0005
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
	# Big park walking view: the assignment on top, the controls below, and a quick dark blink when
	# the camera reaches the eye or leaves it.
	walk_label = label(ui,"",Rect2(40,18,1200,30),18,Color("eef2e6"))
	walk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	walk_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	walk_label.add_theme_constant_override("shadow_offset_y",2)
	walk_label.visible = false
	walk_hint = label(ui,Texts.get_text("paseo_ayuda"),Rect2(40,676,1200,24),14,Color("d8dfd0"))
	walk_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	walk_hint.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	walk_hint.add_theme_constant_override("shadow_offset_y",2)
	walk_hint.visible = false
	raise_flash = ColorRect.new()
	raise_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raise_flash.color = Color(0,0,0,0)
	raise_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(raise_flash)
	# HUD bars of the classic interface; the camera interface folds them away (Tab shows them).
	for child in ui.get_children():
		if child in [camera_body,focus_aid,finder,toast,fps_label,walk_label,walk_hint,raise_flash]: continue
		if child is Control:
			if child.position.y < 300: hud_top.append(child)
			else: hud_bottom.append(child)
	load_interface()
	refresh()

func parameter_input(event: InputEvent, parameter: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: change_parameter(parameter,-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: change_parameter(parameter,1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: change_parameter(parameter,-1)
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
	# Moving the pointer to the top or bottom edge unfolds the HUD bars for a moment (camera interface).
	if event is InputEventMouseMotion and is_instance_valid(ui):
		var y = ui.get_local_mouse_position().y
		if y < 70 or y > 640: hud_hover = 1.5
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
	if mode != "SEARCH": return
	if parameter == "ev_comp":
		if equipment.auto_exposure:
			equipment.change_exposure_compensation(direction)
			auto_expose()
			refresh()
		return
	if equipment.auto_exposure: return
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
	if equipment.auto_exposure:
		var ev_c = equipment.exposure_compensation()
		exposure_button.text = "AUTO ±0.0" if is_zero_approx(ev_c) else ("AUTO %+.1f" % ev_c)
		exposure_button.disabled = false
	else:
		exposure_button.text = "M"
		exposure_button.disabled = true
	if equipment.focus_mode == "MF":
		control_hint.text = Texts.get_text("control_hint_mf")
	else:
		control_hint.text = "Mirar: arrastrar · Foto: Espacio · H: ayuda\nClic: AF"+(" · Rueda: zoom" if equipment.zoom() else " · Objetivo fijo")
	finder.af_mode = equipment.focus_mode
	finder.body = equipment.body
	if is_instance_valid(camera_body) and camera_body.body != equipment.body:
		place_view()
		update_dof_pass()
	focus_aid.visible = equipment.focus_mode == "MF" and mode == "SEARCH"
	focus_aid.material.set_shader_parameter("body",equipment.body)
	aperture_button.text = Texts.get_text("1f") % apertures()[n_index]
	shutter_button.text = Texts.get_text("1_d") % Photo.DENOMINATORS[t_index]
	iso_button.text = ("▣ " if equipment.film else "")+Texts.get_text("iso_d") % Photo.ISOS[iso_index]
	focal_label.text = ("ZOOM " if equipment.zoom() else "FIJO ")+"%.0f mm" % focal
	focus_label.text = Texts.get_text("foco")+(Texts.get_text("infinito") if is_inf(focus_distance) else Texts.get_text("2f_m") % focus_distance)
	update_lens_effects()
	var depth = Photo.dof(focal,apertures()[n_index],focus_distance)
	dof_label.text = Texts.get_text("nitido_2f_m_s") % [depth.x,Texts.get_text("infinito") if is_inf(depth.y) else Texts.get_text("2f_m") % depth.y]
	finder.delta_ev = -Photo.ev(apertures()[n_index],1.0/Photo.DENOMINATORS[t_index],Photo.ISOS[iso_index],measured_ev)
	focus_slider.set_value_no_signal(1 if is_inf(focus_distance) else 1-.8/focus_distance)
	lens_slider.set_value_no_signal(focal)
	counter_label.text = Texts.get_text("encargo_02d_05") % (assignment+1)
	counter_label.visible = not sandbox
	sandbox_button.visible = sandbox and not (academy and academy.active)
	var tod_tag = "NOCHE" if night else ("HORA DORADA" if time_of_day == "golden" else ("HORA AZUL" if time_of_day == "blue" else ("NUBES" if park.cloud_cover > .4 else "SOL")))
	status_label.text = tod_tag + " · EV %.1f · " % measured_ev + ("sin límite" if sandbox else "%d disparos" % shots)

func update_camera() -> void:
	if not is_instance_valid(camera): return
	angle = fposmod(angle,360.0)
	pitch = clampf(pitch,-75,75)
	focal = clampf(focal,equipment.lens().min,equipment.lens().max)
	camera.rotation = Vector3(deg_to_rad(pitch),-deg_to_rad(angle),0)
	# Walking in the big park the eye sees a natural field of view; the lens only at the eye.
	camera.fov = WALK_FOV if not eye_ready() else rad_to_deg(2*atan(36.0/(2.0*focal)))
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
	if academy and academy.active: academy.stop()
	var root = create_modal()
	label(root,Texts.get_text("estudio_de_fotografia_01"),Rect2(75,70,600,28),14,Color("a7c683"))
	label(root,Texts.get_text("cada_persona_una_oportunidad"),Rect2(70,115,790,160),64,Color("e6ebdb"))
	graphics_button_intro = button(root,"Gráficos · " + graphics_preset,Rect2(985,55,220,40),show_graphics_settings)
	var desc = label(root,Texts.get_text("encuentra_a_quien_describe_el_encargo_y_consigue_la_fotografia_t"),Rect2(75,302,780,72),22,Color("b7c5ad"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(root,Texts.get_text("05_encargos_03_disparos_por_encargo_tu_mejor_foto_cuenta"),Rect2(75,413,1100,28),13,Color("a7c683"))
	# Two scenarios: the classic park (you stand in its centre) and the big park (you walk it).
	for row in 2:
		var which = ["clasico","grande"][row]
		var y = 452+row*66
		label(root,Texts.get_text("escenario_"+which),Rect2(75,y+6,250,24),15,Color("e2e7d6"))
		label(root,Texts.get_text("escenario_"+which+"_detalle"),Rect2(75,y+30,250,22),12,Color("8f9f86"))
		var primary = which == scenario
		button(root,Texts.get_text("intro_dia"),Rect2(330,y,150,54),func(): start_in(which,"day",false),primary)
		button(root,Texts.get_text("intro_dorada"),Rect2(488,y,180,54),func(): start_in(which,"golden",false))
		button(root,Texts.get_text("intro_azul"),Rect2(676,y,170,54),func(): start_in(which,"blue",false))
		button(root,Texts.get_text("intro_noche"),Rect2(854,y,150,54),func(): start_in(which,"night",false))
		button(root,"Sandbox",Rect2(1012,y,193,54),func(): start_in(which,"day",true))
	button(root,"Equipo / modos",Rect2(75,590,250,48),show_equipment)
	button(root,Texts.get_text("academia_boton_inicio"),Rect2(330,590,410,48),open_academy,true)
	label(root,Texts.get_text("arrastra_para_mirar_rueda_para_acercarte_clic_para_enfocar_espac"),Rect2(75,652,1070,60),15,Color("8f9f86"))
	label(root,Texts.get_text("m"),Rect2(950,161,245,130),95,Color("b8d78c"))
	label(root,"PROYECTO\nPAPARAZZI",Rect2(955,305,230,70),26,Color("a7b897"))

# Start a session in a scenario; another scenario reloads the scene with it (the equipment kept).
func start_in(which: String, time_mode: String, free_play: bool) -> void:
	if which == scenario:
		start_session(time_mode,free_play)
		return
	reload_with(which,{"time":time_mode,"sandbox":free_play})

func reload_with(which: String, start: Dictionary) -> void:
	equipment_state = {"body":equipment.body,"lens":equipment.lens_index,"focus":equipment.focus_mode,"auto":equipment.auto_exposure,"film":equipment.film,"film_iso":equipment.film_iso_index,"ev":equipment.ev_comp_index}
	scenario = which
	pending_start = start
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

# The Academy uses the classic park (its lessons are staged around the photographer).
func open_academy() -> void:
	if scenario != "clasico":
		reload_with("clasico",{"academy":true})
		return
	show_academy()

func start_session(time_mode = "day", free_play = false) -> void:
	close_modal()
	sandbox = free_play
	sandbox_paused = false
	shot_serial = 0
	park.weather_time = 0
	if not free_play: park.clouds_enabled = true
	if time_mode is bool:
		time_of_day = "night" if time_mode else "day"
	else:
		time_of_day = str(time_mode)
	night = (time_of_day == "night")
	park.set_time_of_day(time_of_day)
	if pigeons:
		pigeons.night = night
		if night: pigeons.settle_night()
	if extras: extras.set_time_of_day(time_of_day)
	records.clear()
	assignment = 0
	best_photo = null
	if time_of_day == "night":
		n_index = 0
		t_index = 4
		iso_index = 5
	elif time_of_day == "golden":
		n_index = 2
		t_index = 3
		iso_index = 1
	elif time_of_day == "blue":
		n_index = 1
		t_index = 4
		iso_index = 3
	else:
		n_index = 3
		t_index = 2
		iso_index = 0
	focal = equipment.lens().min
	pitch = 0
	apply_equipment()
	focus_distance = 4
	angle = 120
	pan_velocity = 0
	if crowd:
		angle = 0.0
		pitch = 0.0
		set_raised(bool(pending_start.get("raised",false)))
		raise_anim = 1.0 if camera_raised else 0.0
		if pending_start.has("at"):
			# --at=x,z[,azimuth]: put the photographer somewhere (evidence captures).
			var at = str(pending_start.at).split(",")
			player.position = Vector3(float(at[0]),0,float(at[1]))
			if at.size() > 2: angle = float(at[2])
		free_player_spot()
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
	if crowd: update_photographer(dt)
	if mode == "SEARCH" and not shooting:
		if eye_ready():
			var axis = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			angle = fposmod(angle+axis*dt*42*24/focal+pan_velocity*dt,360)
			pitch += (float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN)))*dt*30*24/focal
			pan_velocity = move_toward(pan_velocity,0,dt*180)
			if Input.is_physical_key_pressed(KEY_W): focal = clampf(focal+dt*30,equipment.lens().min,equipment.lens().max)
			if Input.is_physical_key_pressed(KEY_S): focal = clampf(focal-dt*30,equipment.lens().min,equipment.lens().max)
		if run_metrics:
			angle = 120.0
			focal = 24.0
		if demo.is_empty():
			for key in shot_view: set(key,shot_view[key])
		else:
			update_demo(dt)
		update_camera()
		update_focus_aid(dt)
		if equipment.focus_mode == "MF":
			var key_dir = float(Input.is_physical_key_pressed(KEY_T)) - float(Input.is_physical_key_pressed(KEY_R))
			if key_dir != 0.0:
				var rate = 0.22 if not Input.is_physical_key_pressed(KEY_SHIFT) else 0.07
				if Input.is_physical_key_pressed(KEY_CTRL): rate = 0.65
				adjust_focus_delta(-key_dir * rate * dt)
		park.update_weather(dt)
		if not (sandbox and sandbox_paused):
			for p in people: update_person(p,dt)
			pigeons.update(dt,people,[dog] if dog else [])
			extras.update(dt)
			if dog: dog.update(dt)
		ambience.update(dt)
		if academy: academy.update(dt)
		update_hud_visibility(dt)
		meter_timer -= dt
		if meter_timer <= 0:
			meter_timer = .1
			update_meter()
			if equipment.auto_exposure: auto_expose()
			refresh()
	if run_metrics and boot_frames > 120 and mode == "SEARCH":
		metrics.append(dt*1000)
		gpu_metrics.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
		cpu_metrics.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
		fps_label.text = Texts.get_text("0f_fps_42_viandantes") % (1.0/maxf(dt,.0001))
	if boot_frames == 20 and advance_seconds > 0:
		# --advance=N: let the crowd live N seconds before the capture (benches, chats, activities).
		for step in int(advance_seconds*30):
			for p in people: update_person(p,1.0/30)
			pigeons.update(1.0/30,people,[dog] if dog else [])
			if dog: dog.update(1.0/30)
	if boot_frames == 12 and academy_start != "":
		var parts = academy_start.split(":")
		if parts[0] == "menu":
			show_academy()
			return
		if parts[0] == "inicio":
			intro()
			return
		academy.begin(int(parts[0]),parts[1] if parts.size() > 1 else "teoria")
		if academy_tour != "":
			academy.tour_seconds = float(academy_tour.get_slice(":",0))
			academy.tour_pages = int(academy_tour.get_slice(":",1))
		if parts.size() > 2:
			academy.page = int(parts[2])-1
			academy.update_panel()
	if boot_frames == 20 and stage != "": stage_scene(stage)
	if boot_frames == 20 and forced_activity != "":
		# --activity=movil: everyone stops where they are and does it (evidence captures).
		for p in people:
			if p.state == "CAMINANDO" and not p.runner:
				p.state = "DETENIDO"
				p.state_time = 999.0
				p.face_target = PI-deg_to_rad(p.theta)
			if p.state != "CAMINANDO":
				p.activity = forced_activity
				p.state_time = 999.0
		# A few seconds more so poses blend in and the pigeons reach anyone tossing crumbs.
		for step in 240:
			for p in people: update_person(p,1.0/30)
			pigeons.update(1.0/30,people,[dog] if dog else [])
	if boot_frames == 100:
		if smoke: smoke_test()
		if screenshot_path != "": save_screenshot.call_deferred()
	if run_metrics and boot_frames == 720:
		metrics.sort()
		var visible_count = people.filter(func(p): return camera.is_position_in_frustum(p.position+Vector3.UP*p.height*.75)).size()
		var render_target = viewport.get_viewport_rid()
		var draw_calls = RenderingServer.viewport_get_render_info(render_target,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var shadow_draw_calls = RenderingServer.viewport_get_render_info(render_target,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		print("METRICS frames=%d visible=%d median_ms=%.2f p95_ms=%.2f max_ms=%.2f draw_calls=%d shadow_draw_calls=%d" % [metrics.size(),visible_count,metrics[metrics.size()/2],metrics[int(metrics.size()*.95)],metrics[-1],draw_calls,shadow_draw_calls])
		gpu_metrics.sort()
		cpu_metrics.sort()
		var triangles = RenderingServer.viewport_get_render_info(render_target,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		print("METRICS_GPU profile=%s renderer=%s time=%s resolution=%dx%d gpu_median_ms=%.2f gpu_p95_ms=%.2f render_cpu_median_ms=%.2f primitives=%d vram_mib=%.1f" % [graphics_preset,RenderingServer.get_current_rendering_method(),time_of_day,viewport.size.x,viewport.size.y,gpu_metrics[gpu_metrics.size()/2],gpu_metrics[int(gpu_metrics.size()*.95)],cpu_metrics[cpu_metrics.size()/2],triangles,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0])
		get_tree().quit()

func update_person(p: Pedestrian, dt: float) -> void:
	if crowd:
		crowd.update(p,dt)
		return
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
			# Crossing between paths: slow diagonal walk with the same smooth speeds as walk_step().
			if p.v_fwd < 0: p.v_fwd = p.speed
			p.v_fwd = move_toward(p.v_fwd, p.speed*.55, WALK_BRAKE*dt)
			var new_radius = move_toward(p.radius, target_r, dt * minf(p.speed*.6, .45))
			var delta_theta = rad_to_deg(p.v_fwd / maxf(p.radius, 0.5)) * dt * p.direction
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
			walk_step(p,dt)

		p.lane_timer -= dt
		if p.lane_timer <= 0:
			p.lane_timer = p.rng.randf_range(25, 60)
			if p.destination_lane < 0 and p.bench_goal < 0 and p.pending_stop.is_empty():
				if not p.runner and p.activity == "" and p.rng.randf() < .3:
					p.activity = "movil"
					p.act_time = 0.0
					p.state_time = p.rng.randf_range(8,18)
				else: try_change_lane(p)
		if stress:
			if p.theta < 96 or p.theta > 144:
				p.theta = clampf(p.theta,96,144)
				p.direction *= -1
		var interest = int(p.theta/30)
		if interest != p.poi and p.theta < 240:
			p.poi = interest
			if p.runner and p.pending_stop.is_empty() and p.rng.randf() < .05:
				# Runners stop now and then to stretch by the path.
				p.pending_stop = {"activity":"estirar","time":p.rng.randf_range(6,10),"face":face_view(p)}
			elif not p.runner and not p.has_meta("staged") and p.bench_goal < 0 and p.pending_stop.is_empty() and p.rng.randf() < .12:
				var poi_blocked = false
				for other in people:
					if other != p and other.lane == p.lane and (other.state == "DETENIDO" or other.state == "SENTADO") and absf(other.theta - p.theta) < 12.0:
						poi_blocked = true
						break
				if not poi_blocked: plan_stop(p)
		if not p.runner and p.lane == 1 and p.destination_lane < 0 and not p.protected_target and not p.has_meta("staged") and p.bench_goal < 0 and p.pending_stop.is_empty():
			choose_bench(p)
		if p.bench_goal >= 0: approach_bench(p)
		elif not p.pending_stop.is_empty() and p.v_fwd < .04:
			var stop: Dictionary = p.pending_stop
			p.pending_stop = {}
			p.state = "DETENIDO"
			p.state_time = stop.time
			p.activity = stop.activity
			p.act_time = 0.0
			p.face_target = stop.get("face",NAN)
		# Walking with the phone for a while (slower, head down).
		if p.activity == "movil":
			p.state_time -= dt
			if p.state_time <= 0: p.activity = ""
	else:
		update_still(p,dt)
	p.place()
	if p.state == "SENTADO" or p.state == "LEVANTANDO":
		var bench = park.benches[p.bench_index]
		var e = smoothstep(0,1,p.seat)
		p.theta = p.sit_from.x+angle_difference(deg_to_rad(p.sit_from.x),deg_to_rad(seat_theta(bench,p.bench_slot)))*180.0/PI*e
		p.radius = lerpf(p.sit_from.y,bench_seat(bench,p),e)
		p.position = park.polar(p.theta,p.radius)
	p.actual_velocity = (p.position-previous_position)/maxf(dt,.0001)
	if p.state == "CAMINANDO":
		turn_heading(p,dt,previous_heading)
	else:
		# Stopping keeps the way the person faced (place() would snap it to the path tangent) and
		# turns calmly towards what they look at.
		if not p.heading_ready:
			p.heading = previous_heading
			p.heading_ready = true
		if not is_nan(p.face_target):
			var diff = angle_difference(p.heading,p.face_target)
			p.heading += clampf(diff,-deg_to_rad(70.0)*dt,deg_to_rad(70.0)*dt)
		p.rotation.y = p.heading
	p.animate(dt,p.position.distance_to(previous_position))

# ---- Smooth walking (docs/NAVEGACION_Y_COLISIONES.md §2) ----
# Each pedestrian keeps a forward speed and a radial speed that only change with limited
# acceleration, so nobody darts sideways or stops dead. Passing decisions (side) are latched for
# a few seconds and the heading turns at a bounded rate: no flip-flopping, no trembling.
const WALK_ACCEL = .55          # m/s² to speed up
const WALK_BRAKE = 1.6          # m/s² to slow down
const LATERAL_MAX = .32         # m/s sideways at most (runners .6)
const PERSONAL_SPACE = .72      # centre-to-centre distance kept when passing
const FOLLOW_GAP = 1.3          # distance kept behind someone slower in the same direction

func lane_center(p: Pedestrian) -> float:
	return LANES[p.lane]

# ---- Activities (docs/futuro/19_VIDA_EN_EL_PARQUE.md) ----
const STAND_ACTIVITIES = ["mirar","mirar","movil","foto","cafe"]
const SEAT_ACTIVITIES = ["leer","movil","cafe","palomas",""]

# Path distance from p to angle theta, positive ahead in its walking direction.
func ahead_of(p: Pedestrian, theta: float) -> float:
	return deg_to_rad(fposmod((theta-p.theta)*p.direction+180.0,360.0)-180.0)*p.radius

# A stop at a point of interest: slows down smoothly first (pending_stop, see walk_step()).
# Sometimes two people walking towards each other stop to chat.
func plan_stop(p: Pedestrian) -> void:
	var time = p.rng.randf_range(6,16)
	for q in people:
		if q == p or q.runner or q.protected_target or q.has_meta("staged") or q.lane != p.lane or q.direction == p.direction: continue
		if q.state != "CAMINANDO" or q.destination_lane >= 0 or q.bench_goal >= 0 or not q.pending_stop.is_empty(): continue
		var ahead = ahead_of(p,q.theta)
		if ahead < 1.4 or ahead > 3.6 or absf(q.radius-p.radius) > 1.0: continue
		if p.rng.randf() < .55:
			time += 6
			p.pending_stop = {"activity":"charla","time":time}
			q.pending_stop = {"activity":"charla","time":time}
			p.partner = q
			q.partner = p
			return
	p.pending_stop = {"activity":STAND_ACTIVITIES[p.rng.randi()%STAND_ACTIVITIES.size()],"time":time,"face":face_view(p)}

# Where a person stopped by the path looks: mostly across the park, never straight back.
func face_view(p: Pedestrian) -> float:
	var outward = -deg_to_rad(p.theta)+PI
	return outward+p.rng.randf_range(-1.0,1.0)+(PI if p.rng.randf() < .5 else 0.0)

# Two places per bench, 0.42 m either side of its centre. Someone already sitting makes the other
# place more tempting: two people on a bench chat (update_still()).
const SEAT_SPREAD = .42

func seat_theta(bench: Dictionary, slot: int) -> float:
	return fposmod(bench.theta+(slot*2-1)*rad_to_deg(SEAT_SPREAD/bench.get("radius",4.85)),360.0)

func set_seat(bench: Dictionary, slot: int, who) -> void:
	bench.seats[slot] = who
	bench.occupied = bench.seats[0] != null and bench.seats[1] != null

func choose_bench(p: Pedestrian) -> void:
	for i in park.benches.size():
		var bench = park.benches[i]
		if bench.occupied: continue
		var ahead = ahead_of(p,bench.theta)
		if ahead < 2.5 or ahead > 3.2: continue
		# Decided once per bench passed.
		if p.get_meta("bench_seen",-1) == i: continue
		p.set_meta("bench_seen",i)
		var company = bench.seats[0] != null or bench.seats[1] != null
		if p.rng.randf() < (.55 if company else .4):
			# The free place, or the nearer one if both are free.
			var slot = 0 if bench.seats[0] == null else 1
			if bench.seats[0] == null and bench.seats[1] == null and ahead_of(p,seat_theta(bench,1)) < ahead_of(p,seat_theta(bench,0)): slot = 1
			set_seat(bench,slot,p)
			p.bench_goal = i
			p.bench_slot = slot
		return

# The bench seat spans r 4.80–5.20 (legs from 4.76): people stop just in front of it, then the hips
# go back onto the middle of the seat while the feet stay put.
func bench_front(bench: Dictionary, _p: Pedestrian) -> float:
	return bench.get("radius",4.85)-.25

func bench_seat(bench: Dictionary, p: Pedestrian) -> float:
	return bench_front(bench,p)+p.nz*(.542-.323)

# Walking the last metres to a chosen bench: walk_step() steers to its front and slows down;
# once there, the person turns to face the path and sits (update_still()).
func approach_bench(p: Pedestrian) -> void:
	var bench = park.benches[p.bench_goal]
	var ahead = ahead_of(p,seat_theta(bench,p.bench_slot))
	var front = bench_front(bench,p)
	if ahead < .1 and absf(p.radius-front) < .14:
		p.bench_index = p.bench_goal
		p.bench_goal = -1
		p.state = "DETENIDO"
		p.set_meta("to_sit",true)
		p.state_time = 999.0
		p.face_target = PI-deg_to_rad(bench.theta)
	elif ahead < -.6 or p.stuck_time > 2.5:
		# Missed it or blocked: give up, free the place.
		set_seat(bench,p.bench_slot,null)
		p.bench_goal = -1

# The other person on the same bench, if seated.
func bench_neighbour(p: Pedestrian):
	if p.bench_index < 0: return null
	var other = park.benches[p.bench_index].seats[1-p.bench_slot]
	return other if other != null and other.state == "SENTADO" else null

# ---- Staged scenes for the showcase video (tools/capture_showcase.sh), around the camera azimuth ----
func clear_sector(lanes: Array, keep: Array, width = 40.0, stopped_too = false) -> void:
	for q in people:
		if q in keep or not q.lane in lanes or q.has_meta("staged"): continue
		if q.state != "CAMINANDO" and not (stopped_too and q.state == "DETENIDO"): continue
		if q.state == "DETENIDO":
			# Someone standing in the line of sight walks on.
			if is_instance_valid(q.partner): q.partner.partner = null
			resume_walk(q)
		if absf(angle_difference(deg_to_rad(q.theta),deg_to_rad(angle))) < deg_to_rad(width):
			q.theta = fposmod(q.theta+width*2.2,360)
			q.place()

func pick(filter: Callable, exclude: Array = []):
	for q in people:
		if q in exclude or q.protected_target or q.has_dog or q.has_meta("staged"): continue
		# Only someone walking freely (not seated, not heading to a bench, not chatting).
		if q.state != "CAMINANDO" or q.bench_index >= 0 or q.bench_goal >= 0 or q.partner != null: continue
		if filter.call(q): return q
	return null

func reset_walker(q: Pedestrian, lane: int, theta: float, direction: float) -> void:
	q.state = "CAMINANDO"
	q.lane = lane
	q.destination_lane = -1
	q.bench_goal = -1
	q.pending_stop = {}
	q.activity = ""
	q.partner = null
	q.stuck_time = 0.0
	q.direction = direction
	q.theta = fposmod(theta,360)
	q.radius = LANES[lane]+LANE_OFFSETS[lane]*direction
	q.v_fwd = q.speed
	q.lane_timer = 99.0
	q.place()
	# Facing where it walks right away (place() gives the path tangent).
	q.heading = q.rotation.y
	q.heading_ready = true
	q.face_target = NAN

func stage_scene(name: String) -> void:
	match name:
		"banco", "palomas":
			var bench_i = 0
			for i in park.benches.size():
				if absf(angle_difference(deg_to_rad(park.benches[i].theta),deg_to_rad(angle))) < absf(angle_difference(deg_to_rad(park.benches[bench_i].theta),deg_to_rad(angle))): bench_i = i
			var bench = park.benches[bench_i]
			for q in people:
				if q.bench_index == bench_i or q.bench_goal == bench_i:
					q.set_hidden(true)
			set_seat(bench,0,null)
			set_seat(bench,1,null)
			var first = pick(func(q): return q.lane == 1 and not q.runner)
			var second = pick(func(q): return q.lane == 1 and not q.runner,[first]) if name == "banco" else null
			var walkers = [first] if second == null else [first,second]
			clear_sector([1],walkers,45.0)
			for slot in walkers.size():
				var q = walkers[slot]
				reset_walker(q,1,seat_theta(bench,slot)-(12.0 if slot == 0 else 38.0),1.0)
				set_seat(bench,slot,q)
				q.bench_slot = slot
				q.bench_goal = bench_i
				q.set_meta("seat_activity","palomas" if name == "palomas" else ("leer" if slot == 0 else "charla"))
		"charla":
			var a = pick(func(q): return q.lane == 1 and not q.runner)
			var b = pick(func(q): return q.lane == 1 and not q.runner,[a])
			clear_sector([1],[a,b],50.0)
			reset_walker(a,1,angle-14.0,1.0)
			reset_walker(b,1,angle+14.0,-1.0)
			for pair in [[a,b],[b,a]]:
				pair[0].pending_stop = {"activity":"charla","time":40.0}
				pair[0].partner = pair[1]
		"estirar":
			var r = pick(func(q): return q.runner)
			clear_sector([1,2],[r],50.0)
			reset_walker(r,1,angle-40.0,1.0)
			r.pending_stop = {"activity":"estirar","time":30.0,"face":PI-deg_to_rad(angle)}
		"perro":
			if dog:
				demo_follow = dog.walker
				angle = rad_to_deg(atan2(dog.walker.position.x,-dog.walker.position.z))

func update_still(p: Pedestrian, dt: float) -> void:
	match p.state:
		"DETENIDO":
			if p.get_meta("to_sit",false):
				if absf(angle_difference(p.heading,p.face_target)) < .08:
					p.remove_meta("to_sit")
					p.state = "SENTADO"
					p.sit_from = Vector2(p.theta,p.radius)
					p.state_time = p.rng.randf_range(25,70)
					p.activity = SEAT_ACTIVITIES[p.rng.randi()%SEAT_ACTIVITIES.size()]
					var forced = str(p.get_meta("seat_activity",""))
					if forced != "" and forced != "charla": p.activity = forced
					p.act_time = 0.0
					# Sitting down next to someone: they chat for a while.
					var neighbour = bench_neighbour(p)
					if neighbour != null and (p.rng.randf() < .7 or forced == "charla"):
						p.activity = "charla"
						p.partner = neighbour
						neighbour.activity = "charla"
						neighbour.partner = p
						neighbour.act_time = 0.0
						neighbour.state_time = maxf(neighbour.state_time,p.state_time*.8)
				return
			if p.activity == "charla" and is_instance_valid(p.partner):
				var to = p.partner.position-p.position
				p.face_target = atan2(-to.x,-to.z)
			p.state_time -= dt
			if p.state_time <= 0: resume_walk(p)
		"SENTADO":
			# Seated side by side: turn the head to the other one.
			var target_yaw = 0.0
			if p.activity == "charla" and is_instance_valid(p.partner):
				var to = p.partner.position-p.position
				target_yaw = clampf(angle_difference(p.rotation.y,atan2(-to.x,-to.z)),-1.1,1.1)
			elif p.activity == "charla":
				p.activity = ""
			p.look_yaw = move_toward(p.look_yaw,target_yaw,dt*1.5)
			p.state_time -= dt
			if p.state_time <= 0:
				if p.activity != "":
					if p.activity == "charla" and is_instance_valid(p.partner) and p.partner.partner == p:
						p.partner.activity = SEAT_ACTIVITIES[p.rng.randi()%SEAT_ACTIVITIES.size()]
						p.partner.partner = null
					p.activity = ""
					p.partner = null
				elif p.act_w <= 0 and stand_up_clear(p): p.state = "LEVANTANDO"
		"LEVANTANDO":
			p.look_yaw = move_toward(p.look_yaw,0.0,dt*1.5)
			if p.seat <= 0:
				set_seat(park.benches[p.bench_index],p.bench_slot,null)
				p.bench_index = -1
				if p.rng.randf() < .5: p.direction *= -1
				resume_walk(p)
		_:
			p.state_time -= dt
			if p.state_time <= 0: resume_walk(p)

func resume_walk(p: Pedestrian) -> void:
	p.state = "CAMINANDO"
	p.activity = ""
	p.partner = null
	p.face_target = NAN
	p.v_fwd = 0.0
	p.v_rad = 0.0
	p.stuck_time = 0.0

func stand_up_clear(p: Pedestrian) -> bool:
	var spot = park.polar(p.sit_from.x,p.sit_from.y)
	for other in people:
		if other == p or not other.visible or other.state == "SENTADO": continue
		if other.position.distance_to(spot) < .9: return false
	return true

func walk_step(p: Pedestrian, dt: float) -> void:
	var bounds: Vector2 = LANE_BOUNDS[p.lane]
	var margin = .28
	var lo = bounds.x+margin
	var hi = bounds.y-margin
	if p.v_fwd < 0: p.v_fwd = p.speed
	var v_des = p.speed
	# Preferred place across the lane: keep-right by direction plus a personal offset.
	var keep_right = LANE_OFFSETS[p.lane]*p.direction
	var r_des = clampf(lane_center(p)+keep_right+p.pref_offset,lo,hi)
	if not p.pending_stop.is_empty(): v_des = 0.0
	if p.activity == "movil": v_des *= .8
	# Keep the swept body clear of bench legs; the last metre to a chosen bench ignores them.
	var static_check = true
	for bench in park.benches:
		if p.lane == 1 and absf(ahead_of(p,bench.theta)) < 1.5: hi = minf(hi,bench.get("radius",4.85)-.42)
	if p.bench_goal >= 0:
		var bench = park.benches[p.bench_goal]
		var to_go = ahead_of(p,seat_theta(bench,p.bench_slot))
		# Along the path (clear of anyone already sitting, whose feet reach r ≈ 4.5 m) until
		# the own place, then the last half metre sideways to the front of the bench.
		if to_go < .6:
			hi = bench_front(bench,p)
			static_check = false
			r_des = clampf(bench_front(bench,p),lo,hi)
		else:
			r_des = minf(r_des,4.2)
		v_des = minf(v_des,maxf(.07,(to_go-.05)*.9))
	elif p.radius > hi+.02: static_check = false
	r_des = clampf(r_des,lo,hi)
	p.pass_timer = maxf(0.0,p.pass_timer-dt)
	p.side_flip_cd = maxf(0.0,p.side_flip_cd-dt)
	if p.pass_timer <= 0: p.pass_side = 0.0
	var blocking_ahead = INF
	var nearest_r = NAN
	var nearest_ahead = INF
	for other in people:
		if other == p or not other.visible: continue
		var ahead = deg_to_rad(fposmod((other.theta-p.theta)*p.direction+180.0,360.0)-180.0)*p.radius
		if ahead > -.2 and ahead < nearest_ahead and absf(other.radius-p.radius) < .9:
			nearest_ahead = ahead
			nearest_r = other.radius
		if ahead <= -.9 or ahead > 4.0: continue
		var lateral = other.radius-p.radius
		if absf(lateral) > 1.1: continue
		# Walking up to a bench: whoever already sits on it is not in the way (the approach keeps to
		# the path and only steps to the bench in front of the free place).
		if p.bench_goal >= 0 and other.bench_index == p.bench_goal and other.state == "SENTADO": continue
		var still = other.state != "CAMINANDO"
		var other_v = 0.0 if still else other.v_fwd*(1.0 if other.direction == p.direction else -1.0)
		var closing = p.v_fwd-other_v
		# Alongside (just passing): only keep the side, until well past.
		if ahead <= .05:
			if p.pass_side != 0.0 and absf(lateral) < PERSONAL_SPACE+.05:
				r_des = clampf(other.radius+p.pass_side*PERSONAL_SPACE,lo,hi)
				p.pass_timer = maxf(p.pass_timer,.8)
			continue
		if closing <= .02 and not still: continue
		# Will we come closer than personal space? Then pick a side (once) and move over.
		if absf(lateral) < PERSONAL_SPACE+.1:
			# Oncoming walkers always keep to their own right, whatever side was latched before:
			# both pick opposite sides, so they never mirror each other into a standoff.
			# (Unless already stuck: then the side that frees the way wins, see below.)
			if other.direction != p.direction and not still and p.pass_side != p.direction and p.stuck_time < 1.0:
				p.pass_side = 0.0
			if p.pass_side == 0.0:
				var room_out = hi-(other.radius+PERSONAL_SPACE)
				var room_in = (other.radius-PERSONAL_SPACE)-lo
				if other.direction != p.direction and not still:
					p.pass_side = p.direction
				else:
					p.pass_side = 1.0 if room_out >= room_in else -1.0
				if (p.pass_side > 0 and room_out < -.05) or (p.pass_side < 0 and room_in < -.05):
					p.pass_side = -p.pass_side
				p.pass_timer = 3.0
			var side_target = clampf(other.radius+p.pass_side*PERSONAL_SPACE,lo,hi)
			var can_pass = absf(side_target-other.radius) > PERSONAL_SPACE-.12
			if not can_pass and p.side_flip_cd <= 0 and still:
				# The latched side is walled off (bench, lane edge) by someone who is not moving:
				# take the other one if it fits (at most once every 2.5 s, never flip-flopping).
				var other_side = clampf(other.radius-p.pass_side*PERSONAL_SPACE,lo,hi)
				if absf(other_side-other.radius) > PERSONAL_SPACE-.12:
					p.side_flip_cd = 2.5
					p.pass_timer = 3.0
					p.pass_side = -p.pass_side
					side_target = other_side
					can_pass = true
			var weight = clampf((4.0-ahead)/2.5,0.0,1.0)
			r_des = lerpf(r_des,side_target,weight)
			p.pass_timer = maxf(p.pass_timer,1.2)
			if not can_pass:
				blocking_ahead = minf(blocking_ahead,ahead)
				if other.direction == p.direction or still:
					v_des = minf(v_des,maxf(0.0,other_v)+maxf(0.0,ahead-FOLLOW_GAP)*.8)
		# Someone slow in front, not yet reached: ease off early instead of braking late.
		if absf(lateral) < PERSONAL_SPACE-.2 and ahead < 2.0 and other.direction == p.direction and not still:
			v_des = minf(v_des,maxf(0.0,other_v)+maxf(0.0,ahead-FOLLOW_GAP)*1.2)
	# Forward speed with limited acceleration.
	var accel = (WALK_ACCEL*(2.5 if p.runner else 1.0)) if v_des > p.v_fwd else WALK_BRAKE
	p.v_fwd = move_toward(p.v_fwd,v_des,accel*dt)
	# Radial speed: damped approach to the lateral target, capped.
	var lat_max = LATERAL_MAX*(1.9 if p.runner else 1.0)
	var v_rad_des = clampf((r_des-p.radius)*1.4,-lat_max,lat_max)
	p.v_rad = move_toward(p.v_rad,v_rad_des,1.2*dt)
	var new_theta = fposmod(p.theta+rad_to_deg(p.v_fwd*dt/maxf(p.radius,.5))*p.direction,360.0)
	var new_radius = clampf(p.radius+p.v_rad*dt,bounds.x,bounds.y)
	if travel_clear(p,p.position,park.polar(new_theta,new_radius),static_check):
		p.theta = new_theta
		p.radius = new_radius
		p.stuck_time = maxf(0.0,p.stuck_time-dt*2.0)
	elif travel_clear(p,p.position,park.polar(p.theta,new_radius),static_check):
		# Blocked ahead: keep drifting sideways, slow down smoothly.
		p.radius = new_radius
		p.v_fwd = move_toward(p.v_fwd,0.0,WALK_BRAKE*2.0*dt)
		p.stuck_time += dt*.5
	else:
		p.v_fwd = move_toward(p.v_fwd,0.0,WALK_BRAKE*3.0*dt)
		p.v_rad = 0.0
		p.stuck_time += dt
	# Waiting behind someone is not being stuck; being stopped by nothing for long is.
	if p.stuck_time > 2.0:
		# Try the other side, at most once every 1.5 s (never flip-flop frame by frame).
		if p.pass_timer < 1.5:
			if not is_nan(nearest_r):
				# Step away from whoever is closest in front, towards the side with room.
				var away = 1.0 if p.radius >= nearest_r else -1.0
				if (away > 0 and p.radius > hi-.05) or (away < 0 and p.radius < lo+.05): away = -away
				p.pass_side = away
			else:
				p.pass_side = (-p.pass_side if p.pass_side != 0.0 else 1.0)*(1.0 if p.rng.randf() < .7 else -1.0)
			p.pass_timer = 3.0
		if p.stuck_time > 3.0 and not try_change_lane(p) and p.stuck_time > 5.0:
			# Give way: turn back (the heading turns smoothly, see turn_heading()).
			p.direction *= -1
			p.v_fwd = 0.0
			p.stuck_time = 0.0

# Heading follows the real motion at a bounded turn rate; stands still when barely moving.
func turn_heading(p: Pedestrian, dt: float, previous: float) -> void:
	var v = p.actual_velocity
	var target = p.heading
	if v.length() > .12: target = atan2(-v.x,-v.z)
	if not p.heading_ready:
		p.heading = target
		p.heading_ready = true
	var diff = angle_difference(p.heading,target)
	var max_turn = deg_to_rad(120.0 if p.runner else 75.0)*dt
	p.heading = p.heading+clampf(diff,-max_turn,max_turn)
	p.rotation.y = p.heading

# ---- The photographer in the big park (docs/futuro/01 Alternativa C) ----
# Camera at the eye: the classic park always; the big park only after the toggle and its gesture.
func eye_ready() -> bool:
	return crowd == null or (camera_raised and raise_anim >= 1.0)

# Never start inside a lamp, a bench or a trunk: step out in a widening spiral.
func free_player_spot() -> void:
	var shape = CapsuleShape3D.new()
	shape.radius = .32
	shape.height = 1.7
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 2
	var space = viewport.world_3d.direct_space_state
	var origin = player.position
	for k in 60:
		var a = k*2.39996
		var pos = origin+Vector3(cos(a),0,sin(a))*(.35*sqrt(k))
		query.transform = Transform3D(Basis.IDENTITY,pos+Vector3.UP*.85)
		if space.intersect_shape(query,1).is_empty():
			player.position = pos
			return

func set_raised(value: bool) -> void:
	camera_raised = value
	if player:
		player.velocity = Vector3.ZERO
	if player_proxy:
		player_proxy.state = "DETENIDO"
		player_proxy.actual_velocity = Vector3.ZERO

func toggle_raise() -> void:
	set_raised(not camera_raised)
	if is_instance_valid(raise_flash): raise_flash.color.a = 0.0
	play_tone(420 if camera_raised else 300,.03)

# Walking: WASD (or the arrows), Shift to run, Ctrl to crouch; the mouse looks around (captured).
# Raising the camera takes 0.35 s (the camera comes up to the eye), then the camera interface
# appears; lowering it brings the walking view back.
var was_eye_ready = true
func update_photographer(dt: float) -> void:
	if walk_demo >= 0 and mode in ["SEARCH","RESULT"]: run_walk_demo(dt)
	if not photo_walk.is_empty() and mode in ["SEARCH","RESULT"]: run_photo_walk(dt)
	var before = raise_anim
	raise_anim = move_toward(raise_anim,1.0 if camera_raised else 0.0,dt/.35)
	var moving = false
	if mode == "SEARCH" and not camera_raised and raise_anim <= 0.0:
		var input = Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if walk_demo >= 0 or not photo_walk.is_empty(): input = demo_keys.get("move",Vector2.ZERO)
		var pad = Vector2(Input.get_joy_axis(0,JOY_AXIS_LEFT_X),Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
		if pad.length() > .2: input += pad
		var look = Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
		if look.length() > .2:
			angle = fposmod(angle+look.x*dt*110,360)
			pitch = clampf(pitch-look.y*dt*80,-70,70)
		var yaw = deg_to_rad(angle)
		var forward = Vector3(sin(yaw),0,-cos(yaw))
		var right = Vector3(cos(yaw),0,sin(yaw))
		var wish = forward*(-input.y)+right*input.x
		var crouching = Input.is_physical_key_pressed(KEY_CTRL)
		var speed = (RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED)*(.55 if crouching else 1.0)
		var target_velocity = wish.limit_length(1.0)*speed
		var walk_velocity = player.velocity.move_toward(target_velocity,dt*9.0)
		var start = player.position
		# Explicit motion for this frame, sliding along whatever it hits (fence, benches, trunks).
		player.velocity = walk_velocity
		var motion = walk_velocity*dt
		for bounce in 3:
			if motion.length() < .00001: break
			var hit = player.move_and_collide(motion)
			if hit == null: break
			var normal = hit.get_normal()
			normal.y = 0
			motion = hit.get_remainder().slide(normal.normalized()) if normal.length() > .01 else Vector3.ZERO
		player.position.y = 0.0
		# Never through anyone: step back out of a pedestrian's personal circle.
		for q in people:
			if not q.visible: continue
			var away = Vector3(player.position.x-q.position.x,0,player.position.z-q.position.z)
			if away.length() < .55: player.position = Vector3(q.position.x,0,q.position.z)+away.normalized()*.55
		var moved = player.position.distance_to(start)
		moving = moved > .0005
		walk_phase += moved*TAU/1.5
		eye_height = move_toward(eye_height,1.05 if crouching else 1.6,dt*2.5)
		update_camera()
	player_proxy.position = player.position
	player_proxy.actual_velocity = player.velocity if moving else Vector3.ZERO
	player_proxy.state = "CAMINANDO" if moving else "DETENIDO"
	var bob = sin(walk_phase)*.025*clampf(player.velocity.length()/WALK_SPEED,0,1.4) if not camera_raised else 0.0
	camera.position = player.position+Vector3.UP*(eye_height+bob)
	park.follow_view(camera.position,dt)
	update_viewmodel(dt)
	# Walking view ⇄ camera interface.
	var ready = eye_ready()
	if ready != was_eye_ready:
		was_eye_ready = ready
		place_view()
		update_dof_pass()
		update_camera()
		if is_instance_valid(raise_flash): raise_flash.color.a = .85
	if is_instance_valid(raise_flash): raise_flash.color.a = move_toward(raise_flash.color.a,0.0,dt*5.0)
	var walking_view = mode == "SEARCH" and not ready
	if is_instance_valid(walk_label):
		walk_label.visible = walking_view
		walk_hint.visible = walking_view
		walk_label.text = briefing.text if not sandbox else Texts.get_text("paseo_sandbox")
	var want = Input.MOUSE_MODE_CAPTURED if walking_view and not camera_raised and get_window().has_focus() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want and not smoke and screenshot_path == "": Input.mouse_mode = want

# Walk up the avenue towards the plaza, look round, raise the camera, shoot, lower it, walk on.
func run_walk_demo(dt: float) -> void:
	if walk_demo == 0.0:
		equipment.auto_exposure = true
		refresh()
	walk_demo += dt
	var t = walk_demo
	demo_keys.move = Vector2(0,-1) if (t < 6.0 or (t > 15.5 and t < 19.0)) else Vector2.ZERO
	if t > 5.0 and t < 7.0: angle = fposmod(angle-dt*10.0,360)
	if t >= 7.0 and not demo_keys.has("raised"):
		demo_keys.raised = true
		toggle_raise()
	if t >= 8.5 and t < 11.0 and eye_ready():
		focal = move_toward(focal,minf(equipment.lens().max,105.0),dt*30)
		update_camera()
		if fmod(t,.5) < dt: autofocus()
	if t >= 11.0 and not demo_keys.has("shot"):
		demo_keys.shot = true
		demo_keys.result_at = t
		take_photo()
	if demo_keys.has("result_at") and t > demo_keys.result_at+2.5 and mode == "RESULT": resume_search()
	if t >= 14.5 and not demo_keys.has("lowered"):
		demo_keys.lowered = true
		toggle_raise()

func run_photo_walk(dt: float) -> void:
	var w = photo_walk
	w.t += dt
	w.timer -= dt
	match w.phase:
		"walk":
			# Head for the next node of the path graph, turning smoothly.
			if not w.has("goal") or player.position.distance_to(park.nodes[w.goal]) < 2.0:
				var here = w.get("goal","")
				var options: Array = park.neighbours[here].filter(func(n): return n != w.get("prev","")) if here != "" else park.nodes.keys()
				if here == "":
					options.sort_custom(func(a,b): return park.nodes[a].distance_to(player.position) < park.nodes[b].distance_to(player.position))
					options = [options[0]]
				w.prev = here
				w.goal = options[photo_walk_rng().randi()%options.size()]
			var to = park.nodes[w.goal]-player.position
			var want = rad_to_deg(atan2(to.x,-to.z))
			angle = fposmod(angle+clampf(angle_difference(deg_to_rad(angle),deg_to_rad(want))*57.3,-60*dt,60*dt),360)
			pitch = move_toward(pitch,-2.0,dt*10)
			demo_keys.move = Vector2(0,-1)
			update_camera()
			if w.timer <= 0:
				var subject = photo_walk_subject()
				if subject:
					w.subject = subject
					w.phase = "turn"
					w.timer = 1.4
					demo_keys.move = Vector2.ZERO
				else: w.timer = 1.5
		"turn":
			var subject = w.subject
			if not is_instance_valid(subject): w.phase = "walk"; return
			aim_at(subject,dt*3.0)
			if w.timer <= 0:
				toggle_raise()
				w.phase = "frame"
				w.timer = 2.6
				w.rack = 0.0
		"frame":
			var subject = w.subject
			if not is_instance_valid(subject): w.phase = "lower"; w.timer = .1; return
			aim_at(subject,dt*4.0)
			if eye_ready():
				var d = camera.global_position.distance_to(subject.control_points()[1])
				var want_f = clampf(.62*20.25*d/subject.height,equipment.lens().min,equipment.lens().max)
				focal = move_toward(focal,want_f,dt*40)
				update_camera()
				if equipment.focus_mode == "MF":
					# Turn the focusing ring towards the subject (the double image comes together).
					w.rack = minf(1.0,w.rack+dt/1.6)
					var start = w.get("rack_from",2.0)
					if not w.has("rack_from"): w.rack_from = focus_distance if not is_inf(focus_distance) else 30.0
					set_manual_focus(lerpf(w.rack_from,d,smoothstep(0,1,w.rack)))
				elif fmod(w.t,.4) < dt:
					finder.active = 4
					autofocus()
				if not equipment.auto_exposure and fmod(w.t,.3) < dt:
					expose_for(park.illumination_ev(subject.control_points()[1],time_of_day,subject))
					refresh()
			if w.timer <= 0:
				finder.active = 4
				w.phase = "shoot"
				w.erase("rack_from")
				take_photo()
				w.timer = 3.0
		"shoot":
			if w.timer <= 0:
				if mode == "RESULT": resume_search()
				toggle_raise()
				w.phase = "lower"
				w.timer = .6
		"lower":
			if w.timer <= 0:
				w.phase = "walk"
				w.timer = photo_walk_rng().randf_range(3.5,5.0)

func photo_walk_rng() -> RandomNumberGenerator:
	if not photo_walk.has("rng"):
		photo_walk.rng = RandomNumberGenerator.new()
		photo_walk.rng.seed = 33
	return photo_walk.rng

# Someone 4–13 m away, roughly ahead, with a clear line of sight to the chest.
func photo_walk_subject():
	var best = null
	var best_score = INF
	var fwd = Vector3(sin(deg_to_rad(angle)),0,-cos(deg_to_rad(angle)))
	for p in people:
		if not p.visible: continue
		var to = p.position-player.position
		to.y = 0
		var d = to.length()
		if d < 3.5 or d > 10.0: continue
		if fwd.dot(to/d) < .3: continue
		var hit = ray_to(p.control_points()[1])
		if hit.is_empty() or not hit.collider.has_meta("person") or hit.collider.get_meta("person") != p: continue
		var score = absf(d-6.0)-fwd.dot(to/d)*3.0
		if score < best_score:
			best_score = score
			best = p
	return best

func aim_at(p, rate: float) -> void:
	var chest = p.control_points()[1]+p.actual_velocity*.25
	var to = chest-camera.global_position
	var want_yaw = rad_to_deg(atan2(to.x,-to.z))
	var want_pitch = rad_to_deg(atan2(to.y,Vector2(to.x,to.z).length()))
	angle = fposmod(angle+angle_difference(deg_to_rad(angle),deg_to_rad(want_yaw))*57.3*minf(1.0,rate),360)
	pitch = lerpf(pitch,want_pitch,minf(1.0,rate))
	update_camera()

func photographer_input(event: InputEvent) -> bool:
	var toggle = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("camara_al_ojo")
	if toggle:
		toggle_raise()
		return true
	if camera_raised: return false
	# While walking only looking around, help and Escape reach the rest of the game.
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			angle = fposmod(angle+event.relative.x*.11,360)
			pitch = clampf(pitch-event.relative.y*.11,-70,70)
			update_camera()
		return true
	if event is InputEventMouseButton: return true
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_H,KEY_QUESTION,KEY_ENTER]: return false
	return event is InputEventKey

# The camera hanging from the neck, bobbing as you walk, and coming up to the eye.
func build_viewmodel() -> void:
	viewmodel = Node3D.new()
	camera.add_child(viewmodel)
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color("1d1f22")
	dark.roughness = .7
	var chrome = StandardMaterial3D.new()
	chrome.albedo_color = Color("8d9094")
	chrome.metallic = .35
	chrome.roughness = .55
	var body = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(.14,.09,.065)
	body.mesh = box
	body.material_override = dark
	viewmodel.add_child(body)
	var top = MeshInstance3D.new()
	var plate = BoxMesh.new()
	plate.size = Vector3(.142,.012,.067)
	top.mesh = plate
	top.material_override = chrome
	top.position = Vector3(0,.051,0)
	viewmodel.add_child(top)
	var lens = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = .028
	cyl.bottom_radius = .031
	cyl.height = .07
	lens.mesh = cyl
	lens.material_override = dark
	lens.rotation.x = PI*.5
	lens.position = Vector3(.01,-.004,-.065)
	viewmodel.add_child(lens)
	for node in viewmodel.get_children(): node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewmodel.visible = false

func update_viewmodel(_dt: float) -> void:
	if not is_instance_valid(viewmodel): return
	var e = smoothstep(0.0,1.0,raise_anim)
	# Seen only while it travels to the eye or back (hanging at the chest it looked like a box).
	viewmodel.visible = mode == "SEARCH" and raise_anim > 0.0 and raise_anim < 1.0
	var sway = Vector3(cos(walk_phase*.5)*.008,absf(sin(walk_phase*.5))*.01,0)*clampf(player.velocity.length()/WALK_SPEED,0,1.4)
	var rest = Vector3(.15,-.215,-.55)+sway
	var eye = Vector3(0,-.01,-.11)
	viewmodel.position = rest.lerp(eye,e)
	viewmodel.rotation = Vector3(lerpf(.35,0,e),lerpf(-.25,0,e),lerpf(.1,0,e))

# ---- Camera interface (docs/futuro/07 §1) ----
func place_view() -> void:
	if not is_instance_valid(viewport_container): return
	if is_instance_valid(camera_body):
		var walking = not eye_ready()
		view_rect = camera_body.view_rect_for(equipment.body,"walk" if walking else interface_mode)
		camera_body.body = equipment.body
		camera_body.mode = "walk" if walking else interface_mode
	viewport_container.position = view_rect.position
	viewport_container.scale = view_rect.size/Vector2(viewport.size)
	if is_instance_valid(focus_aid):
		focus_aid.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		focus_aid.position = view_rect.position+view_shift
		focus_aid.size = view_rect.size
	if is_instance_valid(toast):
		toast.position = Vector2(view_rect.get_center().x-350,view_rect.end.y-(100 if interface_mode == "camara" else 146))
	if is_instance_valid(finder):
		finder.view = Rect2(view_rect.position+view_shift,view_rect.size)
		finder.classic = interface_mode != "camara"
		finder.visible = eye_ready()
	update_finder_shader()

# Shutter sound of each body (tools/audio/build_camera_sounds.py): SLR mirror clack, rangefinder
# cloth shutter, compact's electronic click. Falls back to the old tone if the files are missing.
var shutter_player: AudioStreamPlayer
var shutter_streams = {}
func shutter_sound() -> void:
	var name = ["compacta","telemetrica","reflex"][equipment.body]
	if not shutter_streams.has(name):
		var path = "res://assets/audio/camara/%s.wav" % name
		shutter_streams[name] = AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else null
	if shutter_streams[name] == null:
		play_tone(100,.09)
		return
	if shutter_player == null:
		shutter_player = AudioStreamPlayer.new()
		shutter_player.volume_db = -4.0
		add_child(shutter_player)
	shutter_player.stream = shutter_streams[name]
	shutter_player.play()

# The exact depth of field is drawn in Ultra and Alto. A rangefinder's finder is a plain window onto
# the scene, sharp from near to far: there the blur only appears in the photo (take_photo() turns
# the pass on for the capture frame).
func update_dof_pass() -> void:
	if not is_instance_valid(dof_pass): return
	# The pass always runs in Forward+: besides the blur, it repairs non-finite pixels before the
	# glow (otherwise each one flares into a white blob). Only the blur depends on profile and body.
	dof_pass.visible = not ("dof" in debug_off)
	set_dof_blur(dof_allowed() and eye_ready() and not (interface_mode == "camara" and equipment.body == 1))

func set_dof_blur(value: bool) -> void:
	dof_blur = value
	if is_instance_valid(dof_pass): (dof_pass.material_override as ShaderMaterial).set_shader_parameter("enabled",value)

func dof_allowed() -> bool:
	return is_instance_valid(dof_pass) and graphics_preset in ["Ultra","Alto"] and not ("dof" in debug_off)

func update_finder_shader() -> void:
	if lens_material == null: return
	var body_code = equipment.body if interface_mode == "camara" and eye_ready() else -1
	lens_material.set_shader_parameter("finder_body",body_code)
	var shift = view_shift/view_rect.size if view_rect.size.x > 0 else Vector2.ZERO
	lens_material.set_shader_parameter("parallax",shift)
	# Compact LCD noise grows in dim light (scene EV below ~9).
	lens_material.set_shader_parameter("lcd_noise",clampf((9.0-measured_ev)/6.0,0.0,1.0) if equipment.body == 0 else 0.0)

func set_interface(value: String) -> void:
	interface_mode = value
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","modo",value)
	config.save("user://interfaz.cfg")
	controls_shown = false
	place_view()
	update_dof_pass()
	refresh()

func load_interface() -> void:
	var config = ConfigFile.new()
	# Phones keep the classic HUD until the touch interface (docs/futuro/13) exists.
	interface_mode = "clasica" if OS.has_feature("mobile") else "camara"
	if config.load("user://interfaz.cfg") == OK: interface_mode = str(config.get_value("interfaz","modo",interface_mode))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--interface="): interface_mode = arg.trim_prefix("--interface=")
	place_view()

# Which HUD bars show: always in the classic interface; with the camera, while Tab is on, while the
# pointer rests near the top or bottom edge, and during Academy lessons (they point at controls).
func update_hud_visibility(dt: float) -> void:
	if hud_top.is_empty(): return
	hud_hover = maxf(0.0,hud_hover-dt)
	var show = interface_mode != "camara" or controls_shown or hud_hover > 0 or (academy and academy.active) or mode != "SEARCH"
	if mode == "SEARCH" and not eye_ready(): show = false
	for node in hud_top+hud_bottom:
		node.visible = show
	# The parallax of the rangefinder follows the focus distance.
	var shift = Vector2.ZERO
	if interface_mode == "camara" and equipment.body == 1 and eye_ready(): shift = camera_body.parallax()*view_rect.size
	if not shift.is_equal_approx(view_shift):
		view_shift = shift
		place_view()
	elif equipment.body == 0 and interface_mode == "camara":
		update_finder_shader()

# ui point (inside view_rect) → viewport pixel. The rangefinder's parallax shifts what the finder
# shows (camera_body.gd), so the shift is undone here and clicks still land where they look.
func image_position(point: Vector2) -> Vector2:
	return (point-view_rect.position-view_shift)*Vector2(viewport.size)/view_rect.size

func nearest_af(point: Vector2) -> void:
	if equipment.focus_mode == "MF": return
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
	af_person = hit.collider.get_meta("person") if not hit.is_empty() and hit.collider.has_meta("person") else null
	if not hit.is_empty():
		focus_distance = maxf(.8,camera.global_position.distance_to(hit.position))
		refresh()
		# The scripted camera of the evidence video refocuses twice a second: silently.
		if not demo.has("af"): play_tone(1100,.085)
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
	return {"f":focal,"n":apertures()[n_index],"t":1.0/Photo.DENOMINATORS[t_index],"iso":Photo.ISOS[iso_index],"s":focus_distance,"d":camera.global_position.distance_to(points[1]),"v":perpendicular,"scene_ev":park.illumination_ev(points[1],time_of_day,target),"head":camera.unproject_position(head_world)/Vector2(viewport.size),"feet":feet_point,"chest":projected[1],"in_front":not camera.is_position_behind(points[1]),"blockers":blocked,"rays":rays,"camera_transform":camera.global_transform,"projection":camera.get_camera_projection(),"subject_points":points,"subject_velocity":velocity,"motion_sign":signf(velocity.dot(camera.global_basis.x)),"film":equipment.film,"cloud_cover":park.cloud_cover,"seed":shot_serial+1}

func take_photo() -> void:
	if mode != "SEARCH" or (not sandbox and shots <= 0) or shooting: return
	if not eye_ready(): return
	if equipment.focus_mode != "MF": autofocus()
	update_meter()
	if equipment.auto_exposure: auto_expose()
	shooting = true
	pan_velocity = 0
	if dof_allowed() and not dof_blur: set_dof_blur(true)   # rangefinder: blur only in the photo
	# Freeze first, then wait for physics and the render to represent precisely this state.
	await get_tree().physics_frame
	var evidence = capture_sandbox_evidence() if sandbox else capture_evidence()
	evidence["rendered_dof"] = dof_active()
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
	update_dof_pass()
	shutter_sound()
	if is_instance_valid(camera_body): camera_body.blackout(1.0/Photo.DENOMINATORS[t_index])
	shooting = false
	if academy_demo_shot:
		# A shot of the Academy's demonstration: the photo goes to the tutor panel, no result screen.
		academy_demo_shot = false
		academy.on_demo_photo(current_photo,current_result)
		return
	mode = "RESULT"
	show_results()

# Vignetting and lateral chromatic aberration grow with wide angles (the same strengths develop the
# photo). Depth of field follows focal length, aperture and focus distance exactly.
func lens_strengths(focal_mm: float) -> Vector2:
	var wide = clampf((50.0-focal_mm)/26.0,0.0,1.0)
	return Vector2(.22+.26*wide,.14+.24*wide)

var dof_blur = false
func dof_active() -> bool:
	return is_instance_valid(dof_pass) and dof_pass.visible and dof_blur

func update_lens_effects() -> void:
	if not is_instance_valid(camera): return
	var strengths = lens_strengths(focal)
	if lens_material:
		lens_material.set_shader_parameter("vignette_amount",strengths.x)
		lens_material.set_shader_parameter("chromatic_aberration",strengths.y)
	if dof_active():
		var dof_material: ShaderMaterial = dof_pass.material_override
		dof_material.set_shader_parameter("focal_mm",focal)
		dof_material.set_shader_parameter("aperture",apertures()[n_index])
		dof_material.set_shader_parameter("focus_m",-1.0 if is_inf(focus_distance) else focus_distance)

func photo_material(result: Dictionary) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = Develop
	var evidence: Dictionary = result.evidence
	# With the viewfinder's exact depth of field the capture is already blurred per pixel; otherwise
	# the develop pass blurs the whole frame by the subject's circle of confusion.
	mat.set_shader_parameter("coc_pixels",0.0 if evidence.get("rendered_dof",false) else minf(result.coc/36*viewport.size.x*.5,35))
	var strengths = lens_strengths(evidence.f)
	mat.set_shader_parameter("vignette_amount",strengths.x)
	mat.set_shader_parameter("chromatic_aberration",strengths.y)
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
	if academy and academy.active:
		show_academy_result()
		return
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
	var text_value = "Mirar: arrastra en cualquier dirección. A/D: giro continuo de 360°. ↑/↓: inclinación.\nZoom: rueda o W/S, solo con objetivo zoom.\nAF: clic, F o ENFOCAR. Matricial elige la superficie más cercana entre nueve puntos.\nMF: Shift + rueda, R/T o deslizador. Con objetivo fijo también sirve la rueda sola.\nRéflex: alinea las dos mitades del círculo. Telemétrica: superpón la doble imagen.\nCompacta en MF: ayuda digital de imagen partida. La ayuda usa el centro del visor.\nExposición manual: Q/E diafragma, Z/X velocidad, C/V ISO.\nAUTO con compensación de exposición: rueda/clic en botón AUTO o teclas +/- y [ / ].\n1–9: punto de medición/AF. G: tercios. Espacio: disparar. Tab: muestra u oculta los controles sobre el visor.\nEquipo: pulsa el tipo de cámara arriba para elegir modos u objetivos.\nLas focales se expresan como equivalentes de 35 mm.\nSandbox: disparos ilimitados; pulsa «Sandbox · escena» para cambiar luz, nubes y movimiento."
	label(root,text_value,Rect2(65,128,1130,490),18)
	button(root,Texts.get_text("volver"),Rect2(965,628,250,53),func(): mode = previous; intro() if previous == "INTRO" else close_modal(),true)

func _unhandled_input(event: InputEvent) -> void:
	if run_metrics: return
	if crowd and mode == "SEARCH" and photographer_input(event): return
	if event is InputEventJoypadButton and event.pressed and mode == "SEARCH" and academy and academy.handle_key(event): return
	if event is InputEventJoypadButton and event.pressed and mode == "SEARCH" and event.is_action_pressed("camara_controles"):
		controls_shown = not controls_shown
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == "SEARCH" and academy and academy.handle_key(event): return
		if mode == "SEARCH" and event.is_action_pressed("camara_controles"):
			controls_shown = not controls_shown
			return
		if event.keycode == KEY_ENTER and mode == "RESULT" and academy and academy.active:
			resume_search()
			return
		if event.keycode == KEY_ESCAPE:
			if mode == "HELP": resume_search() if sandbox or is_instance_valid(target) else intro()
			elif mode == "GRAPHICS":
				mode = graphics_return
				if graphics_return == "INTRO": intro()
				elif graphics_return == "EQUIPMENT": show_equipment()
				else: close_modal()
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
			KEY_BRACKETLEFT, KEY_MINUS, KEY_KP_SUBTRACT: change_parameter("ev_comp",-1)
			KEY_BRACKETRIGHT, KEY_EQUAL, KEY_KP_ADD: change_parameter("ev_comp",1)
			KEY_R: adjust_focus(-1)
			KEY_T: adjust_focus(1)
			KEY_G: finder.thirds = not finder.thirds
		if event.keycode == KEY_QUESTION or event.physical_keycode == KEY_H: show_help()
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9: finder.active = event.physical_keycode-KEY_1
	if mode != "SEARCH": return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var step = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if event.shift_pressed or not equipment.zoom():
				var delta = step * (0.0012 if event.shift_pressed else (0.012 if (event.ctrl_pressed or event.alt_pressed) else 0.0035))
				adjust_focus_delta(-delta)
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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				focus_dragging = true
				pan_velocity = 0
			else:
				focus_dragging = false
	elif event is InputEventMouseMotion:
		if focus_dragging and equipment.focus_mode == "MF":
			var rate = 0.0006 if not event.shift_pressed else 0.0002
			adjust_focus_delta(-event.relative.x * rate)
		elif dragging:
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
	assert(people.size() == (GRANDE_PEOPLE if scenario == "grande" else 21))
	assert(target.protected_target)
	var triangles = park.triangle_count
	for p in people:
		assert(p.primary_bone_count == 20)
		# 1.900 per pedestrian in the base pieces; 60.000 for the Blender mannequins with wig and clothes (docs/futuro/18).
		assert(p.triangle_count <= (60000 if Person.detail == "hd" else 1900),Texts.get_text("presupuesto_por_viandante"))
		triangles += p.triangle_count
	# Meadow extras (hd only) and the pigeons count towards the scene budget too.
	for p in extras.extras:
		assert(p.ambient and p.colliders.is_empty(),"Meadow extras must have no colliders")
		triangles += p.triangle_count
	triangles += pigeons.triangle_count()
	# Scene budget per profile (docs/futuro/17 §3): the park detail follows the renderer.
	# The mesh detail sets the budget: a saved Ultra profile running in gl_compatibility builds "lo".
	var budget = SCENE_TRIANGLES["Ultra"] if park.detail == "hd" else SCENE_TRIANGLES["Medio"]
	assert(triangles <= budget,Texts.get_text("presupuesto_de_escena"))
	var evidence = capture_evidence()
	assert(Photo.evaluate(evidence) == Photo.evaluate(evidence))
	print("SMOKE PASS: %d viandantes (+%d figurantes, %d palomas), 20 huesos/persona, %d triángulos (límite %d, perfil %s, detalle %s, máximo por viandante %d), expediente determinista" % [people.size(),extras.extras.size(),pigeons.birds.size(),triangles,budget,graphics_preset,park.detail,people.map(func(p): return p.triangle_count).max()])
	if screenshot_path == "" and not run_metrics: get_tree().quit()

func update_demo(dt: float) -> void:
	if demo_time < 0:
		for key in shot_view: set(key,shot_view[key])
		demo_focal_start = focal
		demo_time = 0.0
		if demo.has("follow-target"):
			# The assignment moves to a pedestrian of the outer lane: at 90 mm and ~11.5 m a whole
			# body fills about two thirds of the frame, the framing the score asks for.
			var outer = people.filter(func(p): return p.lane == 3 and p.visible and p.state != "RETIRADO")
			if not outer.is_empty():
				if is_instance_valid(target): target.protected_target = false
				target = outer[0]
				target.protected_target = true
				briefing.text = Texts.get_text("busca")+", ".join(casting.predicates_for(target.traits,people.map(func(p): return p.traits)))+"."
			demo_follow = target
			angle = rad_to_deg(atan2(target.position.x,-target.position.z))
		if demo.has("follow") and not is_instance_valid(demo_follow):
			var best = 1e9
			for p in people:
				var az = rad_to_deg(atan2(p.position.x,-p.position.z))
				var d = absf(angle_difference(deg_to_rad(az),deg_to_rad(angle)))+p.position.length()*.02
				# Mid lanes (4–12 m): a pedestrian that fits the telephoto frame.
				if p.position.length() > 4.5 and p.position.length() < 12.5 and d < best:
					best = d
					demo_follow = p
	demo_time += dt
	angle = fposmod(angle+float(demo.get("pan","0"))*dt,360)
	if demo.has("zoom-to"):
		focal = lerpf(demo_focal_start,float(demo["zoom-to"]),smoothstep(0.0,12.0,demo_time))
	if is_instance_valid(demo_follow):
		# Keep the pedestrian's chest centred (measured in camera space) and in focus, like AF-C.
		var chest = demo_follow.global_position+Vector3.UP*demo_follow.height*.7
		var local = camera.global_transform.affine_inverse()*chest
		var gain = minf(1.0,dt*4.0)
		angle = fposmod(angle+rad_to_deg(atan2(local.x,-local.z))*gain,360)
		pitch += rad_to_deg(atan2(local.y,-local.z))*gain
		var subject_distance = camera.global_position.distance_to(chest)
		if demo.has("mf-rack"):
			# Manual focus: turn the ring from 1.2 m to the subject over 5 s (the split-image aid shows it).
			focus_distance = lerpf(1.2,subject_distance,smoothstep(1.0,6.0,demo_time))
		else:
			focus_distance = subject_distance
		if demo.has("expose") and fmod(demo_time,.5) < dt:
			# Meter the subject itself, as a photographer with a hand meter would.
			expose_for(park.illumination_ev(chest,time_of_day,demo_follow))
	if demo.has("scare-at") and demo_time >= demo["scare-at"] and not demo.has("scared") and pigeons and not pigeons.flocks.is_empty():
		# A dog or a runner gets too close: the flock nearest the camera's line flies to the trees.
		demo["scared"] = true
		var view = park.polar(angle,5.5)
		var nearest = pigeons.flocks[0]
		for f in pigeons.flocks:
			if f.center.distance_to(view) < nearest.center.distance_to(view): nearest = f
		pigeons.take_off(nearest,pigeons.roost(nearest),"posada")
	if demo.has("shoot-at") and demo_time >= demo["shoot-at"] and not demo.has("shot"):
		demo["shot"] = true
		take_photo()
	if demo.has("af") and not is_instance_valid(demo_follow) and fmod(demo_time,.5) < dt and equipment.focus_mode != "MF": autofocus()

func save_burst() -> void:
	var base = screenshot_path.get_basename()
	for k in burst_frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [base,k])
	print("BURST: %d frames in %s_*.png" % [burst_frames,base])
	get_tree().quit()

func save_screenshot() -> void:
	if burst_frames > 0:
		save_burst()
		return
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
	label(root,Texts.get_text("visor_interfaz"),Rect2(75,585,250,35),20)
	option(root,[Texts.get_text("visor_interfaz_camara"),Texts.get_text("visor_interfaz_clasica")],0 if interface_mode == "camara" else 1,Rect2(330,580,700,45),func(i): set_interface("camara" if i == 0 else "clasica"); show_equipment())
	button(root,"Ajustes gráficos (" + graphics_preset + ")",Rect2(75,630,340,55),show_graphics_settings)
	button(root,"Usar este equipo",Rect2(880,630,320,55),restore_equipment_screen,true)


# Same realistic mannequins in every profile; the procedural wood and cloth patterns (a few
# instructions per pixel) are the only thing the two lowest profiles skip.
func apply_mannequin_graphics_preset(preset: String) -> void:
	var mat = Person.mannequin_material()
	if mat is ShaderMaterial: mat.set_shader_parameter("textured",preset != "Bajo")

# The profile persists in override.cfg with the renderer it needs: Godot reads that file at launch,
# before any rendering starts (docs/futuro/17 §2.1). Next to the executable when exported.
const PROFILE_SETTING = "paparazzi/graficos/perfil"
# The "lo" park is shared by Bajo, Medio and Alto, so it must fit the mobile budget of 100.000.
# Ultra targets a desktop GPU (RX 6700 XT at 1440p): the instanced lawn alone adds ~2 M triangles.
# Internal 3D resolution per profile in Forward+ (upscaled with FSR 2).
const RENDER_SCALE = {"Bajo": .5, "Medio": .7, "Alto": .85, "Ultra": 1.0}
const SCENE_TRIANGLES = {"Bajo": 100000, "Medio": 100000, "Alto": 100000, "Ultra": 5000000}

func override_path() -> String:
	if OS.has_feature("template"): return OS.get_executable_path().get_base_dir().path_join("override.cfg")
	return ProjectSettings.globalize_path("res://override.cfg")

func startup_profile() -> String:
	if ProjectSettings.has_setting(PROFILE_SETTING): return str(ProjectSettings.get_setting(PROFILE_SETTING))
	if OS.has_feature("mobile"): return "Medio"
	# First launch on desktop: Ultra on a dedicated GPU, Alto otherwise (02 §10.3.5).
	return "Ultra" if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU else "Alto"

func save_profile(preset: String) -> void:
	if OS.has_feature("mobile"): return
	var config = ConfigFile.new()
	config.load(override_path())
	# The renderer is no longer per profile: drop the key older versions wrote.
	if config.has_section_key("rendering","renderer/rendering_method"): config.erase_section_key("rendering","renderer/rendering_method")
	config.set_value("paparazzi","graficos/perfil",preset)
	config.save(override_path())

# Profile chosen in the settings screen: saved and applied at once (no restart since every
# desktop profile shares the Forward+ renderer).
func select_graphics_profile(preset: String) -> void:
	save_profile(preset)
	apply_graphics_preset(preset)

# In Forward+ the 3D view matches the window's physical pixels (2560 × 1440 on a 1440p screen) and
# the lower profiles render internally at a fraction of it, upscaled with FSR 2 (RENDER_SCALE).
# gl_compatibility keeps 1280 × 720. Everything downstream normalises by viewport.size.
var render_factor = 1.0

func update_render_resolution() -> void:
	var factor = 1.0
	if ParkScene.forward_plus():
		var window = Vector2(get_window().size)
		factor = maxf(1.0,minf(window.x/1280.0,window.y/720.0))
	viewport.size = Vector2i(roundi(1280*factor),roundi(720*factor))
	viewport_container.stretch = false
	viewport_container.size = Vector2(viewport.size)
	render_factor = factor
	place_view()

func apply_graphics_preset(preset: String) -> void:
	graphics_preset = preset
	if park: park.apply_graphics_preset(preset)
	# FXAA smooths the mannequins' ink lines and the scene edges without the memory of MSAA (VRAM < 60 MiB).
	if is_instance_valid(viewport):
		var forward = ParkScene.forward_plus()
		var scale = RENDER_SCALE.get(preset,1.0) if forward else 1.0
		# Forward+: Ultra multisamples at native resolution; lower profiles render fewer pixels and
		# FSR 2 upscales them (it also antialiases). gl_compatibility: FXAA.
		viewport.scaling_3d_scale = scale
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if forward and scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		viewport.msaa_3d = Viewport.MSAA_4X if forward and scale >= 1.0 else Viewport.MSAA_DISABLED
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if not forward and preset != "Bajo" else Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.positional_shadow_atlas_size = 4096 if forward and preset in ["Ultra","Alto"] else 2048
		viewport.use_debanding = forward
		update_render_resolution()
	update_dof_pass()
	# Bajo skips the lens character, but the camera finders (07 §1) still need the shader.
	if is_instance_valid(viewport_container): viewport_container.material = lens_material
	if lens_material: lens_material.set_shader_parameter("lens_off",preset == "Bajo")
	update_lens_effects()
	apply_debug_off()
	apply_mannequin_graphics_preset(preset)
	if is_instance_valid(graphics_button):
		graphics_button.text = "Gráficos · " + graphics_preset
	if is_instance_valid(graphics_button_intro):
		graphics_button_intro.text = "Gráficos · " + graphics_preset

func show_graphics_settings() -> void:
	if mode != "GRAPHICS": graphics_return = mode
	mode = "GRAPHICS"
	var root = create_modal()
	label(root, "Ajustes gráficos del sistema", Rect2(75, 25, 1100, 50), 38)
	label(root, "Configuración escalonada de rendimiento y fidelidad visual (docs/futuro/02, §10)", Rect2(75, 78, 1100, 28), 15, Color("b8d78c"))

	var preset_names = ["Bajo", "Medio", "Alto", "Ultra"]
	# Same look in every profile; the lower ones only drop cost (docs/futuro/17 §2.1).
	var preset_descs = [
		"Bajo: mismo aspecto con el mínimo coste. Resolución interna al 50 % (FSR 2), sin iluminación global ni oclusión ambiental y con poca hierba.",
		"Medio: resolución al 70 %, iluminación global con 3 cascadas, oclusión ambiental y sombras de 2048; sin niebla volumétrica.",
		"Alto: resolución al 85 %, iluminación global completa, niebla volumétrica, penumbra física y profundidad de campo en el visor.",
		"Ultra: resolución nativa con MSAA 4×, reflejos y rebote de luz en pantalla, hierba completa y sombras de farola en las 12."
	]

	for i in 4:
		var pname = preset_names[i]
		var is_active = (graphics_preset == pname)
		button(root, ("✓ " if is_active else "") + pname + (" (Activo)" if is_active else ""), Rect2(75 + i * 280, 118, 260, 52), func():
			select_graphics_profile(pname)
			show_graphics_settings()
		, is_active)
	
	var desc_panel = panel(root, Rect2(75, 185, 1100, 420), Color(.075, .115, .085, .91))
	label(desc_panel, "Perfil seleccionado actualmente: " + graphics_preset, Rect2(25, 18, 1050, 30), 22, Color("b8d78c"))
	
	var current_idx = preset_names.find(graphics_preset)
	if current_idx < 0: current_idx = 3
	var desc_text = preset_descs[current_idx]
	var desc_lbl = label(desc_panel, desc_text, Rect2(25, 54, 1050, 44), 16, Color("e6ebdb"))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	label(desc_panel, "Desglose técnico de parámetros activos:", Rect2(25, 108, 1050, 26), 16, Color("a7c683"))
	
	var fx: Dictionary = park.EFFECTS.get(graphics_preset,park.EFFECTS["Ultra"])
	var specs = [
		"• Resolución interna: %d %% %s" % [int(RENDER_SCALE.get(graphics_preset,1.0)*100),"(nativa, MSAA 4×)" if graphics_preset == "Ultra" else "(escalada con FSR 2)"],
		"• Iluminación global SDFGI: " + ("desactivada (luz ambiente calibrada)" if fx.sdfgi == 0 else "%d cascadas" % fx.sdfgi),
		"• Oclusión ambiental: %s · Rebote en pantalla (SSIL): %s · Reflejos (SSR): %s" % ["sí" if fx.ssao else "no","sí" if fx.ssil else "no","sí" if fx.ssr else "no"],
		"• Niebla volumétrica: %s · Penumbra física del sol: %s · Atlas de sombras: %d" % ["sí" if fx.volumetric else "no","sí" if fx.penumbra else "no",fx.atlas],
		"• Hierba: %d %% · Profundidad de campo en el visor: %s" % [int(fx.grass*100),"sí" if graphics_preset in ["Ultra","Alto"] else "no"]
	]

	for s_idx in specs.size():
		label(desc_panel, specs[s_idx], Rect2(25, 142 + s_idx * 36, 1050, 28), 15, Color("b7c5ad"))
	
	button(root, "Aceptar y volver", Rect2(880, 620, 320, 52), func():
		mode = graphics_return
		match graphics_return:
			"INTRO": intro()
			"RESULT": show_results()
			"BRIEFING": show_assignment()
			"EQUIPMENT": show_equipment()
			_: close_modal()
		refresh()
	, true)

func set_manual_focus(distance: float) -> void:
	if equipment.focus_mode != "MF": return
	focus_distance = maxf(.8,distance)
	refresh()

func adjust_focus_delta(delta_diopters: float) -> void:
	if equipment.focus_mode != "MF": return
	var current_diop = 0.0 if is_inf(focus_distance) else 1.0/focus_distance
	var new_diop = clampf(current_diop + delta_diopters, 0.0, 1.25)
	if absf(new_diop - current_diop) > 0.00005:
		if int(new_diop / 0.025) != int(current_diop / 0.025):
			play_tone(1800, 0.015)
		set_manual_focus(INF if new_diop <= 0.0005 else 1.0/new_diop)

func adjust_focus(step: int) -> void:
	adjust_focus_delta(-step * 0.004)

func update_focus_aid(dt: float) -> void:
	if equipment.focus_mode != "MF" or mode != "SEARCH" or not eye_ready():
		focus_aid.visible = false
		if is_instance_valid(finder): finder.mf_coincidence = false
		return
	focus_aid.visible = true
	var center_pixel = view_rect.get_center()
	var best_dist = INF
	var person_dist = INF
	var patch_samples = [
		center_pixel,
		center_pixel + Vector2(-24, 0),
		center_pixel + Vector2(24, 0),
		center_pixel + Vector2(0, -16),
		center_pixel + Vector2(0, 16)
	]
	for p in patch_samples:
		var hit = point_hit(p)
		if hit.is_empty(): continue
		var d = camera.global_position.distance_to(hit.position)
		if d < 0.8: continue
		if hit.collider.has_meta("person"):
			if d < person_dist: person_dist = d
		elif d < best_dist:
			best_dist = d
	var patch_distance = person_dist if person_dist < INF else best_dist
	var target_error = (0.0 if is_inf(focus_distance) else 1.0/focus_distance) - (0.0 if is_inf(patch_distance) else 1.0/patch_distance)
	var raw_offset = clampf(target_error * focal * 0.006, -0.06, 0.06)
	smoothed_focus_aid_offset = lerpf(smoothed_focus_aid_offset, raw_offset, 1.0 - exp(-dt * 22.0))
	focus_aid.material.set_shader_parameter("offset", smoothed_focus_aid_offset)
	var depth = Photo.dof(focal, apertures()[n_index], focus_distance)
	var in_dof = patch_distance >= depth.x and (is_inf(depth.y) or patch_distance <= depth.y)
	finder.mf_coincidence = in_dof or absf(smoothed_focus_aid_offset) < 0.003

func point_hit(point: Vector2) -> Dictionary:
	var pixel = image_position(point)
	var origin = camera.project_ray_origin(pixel)
	return ray_to(origin+camera.project_ray_normal(pixel)*90)

# Matrix AF (docs/futuro/12 §2.1, fase 0): a geometric rule that never knows who the assignment is
# about. Among the 9 points, the person nearest the centre of the frame wins (ties: the one nearer
# the camera); with nobody under a point, the nearest scenery.
func select_matrix_point() -> void:
	var pts = finder.points()
	var centre = view_rect.get_center()
	var best_person_idx = -1
	var best_person_key = INF
	var best_scenery_idx = -1
	var nearest_scenery_dist = INF
	for i in pts.size():
		var hit = point_hit(pts[i])
		if hit.is_empty(): continue
		var distance = camera.global_position.distance_squared_to(hit.position)
		if distance < 1.0: continue
		if hit.collider.has_meta("person"):
			var key = pts[i].distance_to(centre)/view_rect.size.x+sqrt(distance)*.001
			if key < best_person_key:
				best_person_key = key
				best_person_idx = i
		elif distance < nearest_scenery_dist:
			nearest_scenery_dist = distance
			best_scenery_idx = i
	if best_person_idx != -1:
		finder.active = best_person_idx
	elif best_scenery_idx != -1:
		finder.active = best_scenery_idx
	else:
		finder.active = 4

func update_meter() -> void:
	var hit = point_hit(finder.points()[finder.active])
	# The meter reads what is under the active point, never the assignment's subject (12 §2.1).
	measured_ev = park.sky_ev(time_of_day) if hit.is_empty() else park.illumination_ev(hit.position,time_of_day,hit.collider.get_meta("person") if hit.collider.has_meta("person") else null)

# Correct exposure for a given scene EV (same criteria as auto_expose()).
func expose_for(scene_ev: float) -> void:
	var target_ev = scene_ev-equipment.exposure_compensation()
	var best_cost = INF
	var stops = apertures()
	for n in stops.size():
		for t in Photo.DENOMINATORS.size():
			for iso in ([equipment.film_iso_index] if equipment.film else range(Photo.ISOS.size())):
				var delta = absf(Photo.ev(stops[n],1.0/Photo.DENOMINATORS[t],Photo.ISOS[iso],target_ev))
				var cost = delta*10 + maxf(0,focal/Photo.DENOMINATORS[t]-1)*2 + iso*.12 + n*.03
				if cost < best_cost:
					best_cost = cost
					n_index = n
					t_index = t
					iso_index = iso

func auto_expose() -> void:
	var target_ev = measured_ev-equipment.exposure_compensation()
	var best_cost = INF
	var stops = apertures()
	for n in stops.size():
		for t in Photo.DENOMINATORS.size():
			for iso in ([equipment.film_iso_index] if equipment.film else range(Photo.ISOS.size())):
				var delta = absf(Photo.ev(stops[n],1.0/Photo.DENOMINATORS[t],Photo.ISOS[iso],target_ev))
				var cost = delta*10 + maxf(0,focal/Photo.DENOMINATORS[t]-1)*2 + iso*.12 + n*.03
				if cost < best_cost:
					best_cost = cost
					n_index = n
					t_index = t
					iso_index = iso

const LANES = [1.8,4.0,7.0,11.5]
const LANE_OFFSETS = [0.33,0.35,0.35,0.35]
const LANE_BOUNDS = [Vector2(1.05,2.7), Vector2(2.9,4.85), Vector2(6.1,7.9), Vector2(10.6,12.4)]
func travel_clear(p: Pedestrian, from: Vector3, to: Vector3, static_check = true) -> bool:
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
	if static_check:
		if not space.intersect_shape(query,1).is_empty(): return false
		if space.cast_motion(query)[0] < 1.0: return false
	var others = people+([player_proxy] if player_proxy else [])
	for other in others:
		if other == p or not other.visible: continue
		var nearest = Geometry3D.get_closest_point_to_segment(other.position,from,to)
		var near_dist = nearest.distance_to(other.position)
		if near_dist < .58:
			var d_from = from.distance_to(other.position)
			var d_to = to.distance_to(other.position)
			if d_to >= d_from - 0.0005:
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
			if crowd:
				var f = crowd.frame(p)
				p.position += f.dir*.6
			else:
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

# ---- Academia de fotografía (docs/futuro/06) ----
func show_academy() -> void:
	if academy.active: academy.stop()
	mode = "ACADEMY"
	var root = create_modal()
	label(root,Texts.get_text("academia_titulo"),Rect2(75,30,1100,52),36,Color("e6ebdb"))
	var sub = label(root,Texts.get_text("academia_subtitulo"),Rect2(75,86,1100,50),18,Color("b7c5ad"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for n in range(1,academy.LESSONS+1):
		var y = 146+(n-1)*86
		panel(root,Rect2(75,y,1130,78),Color(.075,.115,.085,.95))
		label(root,"%d" % n,Rect2(92,y+12,40,50),38,Color("b8d78c"))
		label(root,Texts.get_text("academia_l%d_titulo" % n),Rect2(145,y+8,520,32),23,Color("e6ebdb"))
		label(root,Texts.get_text("academia_l%d_resumen" % n),Rect2(145,y+42,520,26),15,Color("a9b8a0"))
		var columns = [675,772,912]
		for k in academy.PHASES.size():
			var ph = academy.PHASES[k]
			var ok = academy.done(n,ph)
			label(root,"%s %s" % [Texts.get_text("academia_hecho") if ok else Texts.get_text("academia_pendiente"),Texts.get_text("academia_fase_"+ph)],Rect2(columns[k],y+10,140,24),14,Color("b8d78c") if ok else Color("8f9f86"))
		label(root,Texts.get_text("academia_examen_no_disponible"),Rect2(675,y+44,300,24),13,Color("5f6d59"))
		var started = academy.done(n,"teoria")
		button(root,Texts.get_text("academia_repasar") if started else Texts.get_text("academia_empezar"),Rect2(1010,y+16,180,46),func(): close_modal(); academy.begin(n),not started)
	label(root,Texts.get_text("academia_progreso") % [academy.practices_done(),academy.LESSONS]+" · "+Texts.get_text("academia_graduado_futuro"),Rect2(75,586,800,28),15,Color("a7c683"))
	button(root,Texts.get_text("academia_volver_menu"),Rect2(75,630,260,55),intro)
	button(root,Texts.get_text("academia_reiniciar"),Rect2(350,630,240,55),func(): academy.reset_progress(); show_academy())

func show_academy_result() -> void:
	var root = create_modal()
	label(root,Texts.get_text("academia_resultado_titulo") % [academy.lesson,shot_serial],Rect2(25,24,1170,50),32)
	var notes: Array = academy.on_practice_photo(current_photo,current_result) if academy.phase == "practica" else []
	var pair: Array = academy.comparison_photos() if academy.phase == "practica" else []
	if pair.size() == 2:
		for i in 2:
			var shot: Dictionary = pair[i]
			photo_preview(root,shot.texture,shot.result,Rect2(25+i*418,100,408,230))
			var e2: Dictionary = shot.result.evidence
			label(root,"%.0f mm · f/%s · 1/%d s · a %.1f m" % [e2.f,str(e2.n),roundi(1/e2.t),e2.d],Rect2(25+i*418,334,408,24),15,Color("b8d78c"))
		photo_preview(root,current_photo,current_result,Rect2(25,370,370,208))
	else:
		photo_preview(root,current_photo,current_result,Rect2(25,100,825,464))
	var e: Dictionary = current_result.evidence
	var info = "%.0f mm · f/%s\n1/%d s · ISO %d\n\nLuz medida: EV %.1f\nError de exposición: %+.2f EV\nDistancia: %.2f m\nDesenfoque: %.3f mm\nMovimiento: %.3f mm" % [e.f,str(e.n),roundi(1/e.t),e.iso,e.scene_ev,current_result.delta,e.d,current_result.coc,current_result.drag]
	academy.make_label(root,Rect2(885,100,360,260),18,Color("e6e8dd"),true).text = info
	var task_text = ""
	for k in academy.TASKS:
		task_text += "%s  %s\n" % [Texts.get_text("academia_hecho") if academy.tasks[k] else Texts.get_text("academia_pendiente"),Texts.get_text("academia_l%d_p%d" % [academy.lesson,k+1])]
	for note in notes: task_text += "\n"+note
	academy.make_label(root,Rect2(885,370,360,240),15,Color("c9d4bf"),true).text = task_text
	button(root,Texts.get_text("academia_volver_menu"),Rect2(25,630,260,55),show_academy)
	button(root,Texts.get_text("academia_seguir"),Rect2(885,620,360,70),resume_search,true)

func show_sandbox_controls() -> void:
	if not sandbox: return
	mode = "SANDBOX_SETTINGS"
	var root = create_modal()
	label(root,"Sandbox · prepara la escena",Rect2(75,65,1100,60),38)
	label(root,"Sin encargos, sin puntuación y sin límite de disparos.",Rect2(75,145,1100,40),23)
	label(root,"Iluminación",Rect2(75,250,250,40),22)
	option(root,["Día","Hora dorada","Hora azul","Noche"],["day","golden","blue","night"].find(time_of_day),Rect2(350,245,650,48),func(i):
		time_of_day = ["day","golden","blue","night"][i]
		night = (time_of_day == "night")
		park.set_time_of_day(time_of_day)
		update_meter()
		refresh()
	)
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
	elif is_instance_valid(af_person) and af_person.visible:
		# A fast subject slipped off the point between focusing and the shutter: the photo is still
		# of the person the AF locked on (in-frame), as it would be for a photographer.
		var chest = af_person.control_points()[1]
		var proj = camera.unproject_position(chest)/Vector2(viewport.size)
		if not camera.is_position_behind(chest) and proj.x > .2 and proj.x < .8 and proj.y > .1 and proj.y < .9:
			person = af_person
			velocity = person.actual_velocity
			distance = camera.global_position.distance_to(chest)
	var axis = -camera.global_basis.z
	var perpendicular = (velocity-axis*velocity.dot(axis)).length()
	return {"f":focal,"n":apertures()[n_index],"t":1.0/Photo.DENOMINATORS[t_index],"iso":Photo.ISOS[iso_index],"s":focus_distance,"d":distance,"v":perpendicular,"scene_ev":park.sky_ev(time_of_day) if hit.is_empty() else park.illumination_ev(hit.position,time_of_day,person),"head":Vector2(.5,.2),"feet":Vector2(.5,.8),"chest":Vector2(.5,.5),"in_front":true,"blockers":[],"motion_sign":signf(velocity.dot(camera.global_basis.x)),"film":equipment.film,"cloud_cover":park.cloud_cover,"seed":shot_serial+1,"person":person != null}

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
