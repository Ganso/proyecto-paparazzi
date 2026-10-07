extends Node
const Texts = preload("res://scripts/texts.gd")
const Photo = preload("res://scripts/photography.gd")
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
const ParkScene = preload("res://scripts/park.gd")
const Finder = preload("res://scripts/viewfinder.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Arcade = preload("res://scripts/arcade.gd")
const Conditions = preload("res://scripts/conditions.gd")
const Glyphs = preload("res://scripts/input_glyphs.gd")
const Badges = preload("res://scripts/badges.gd")
const Album = preload("res://scripts/album.gd")
const Graphics = preload("res://scripts/graphics.gd")
const Develop = preload("res://shaders/develop.gdshader")

var equipment = preload("res://scripts/equipment.gd").new()
var pitch = 0.0
var measured_ev = 14.0
var meter_timer = 0.0
var af_button: Button
var equipment_label: Button
var control_hint                    # scripts/glyph_label.gd: keys as keycaps, pad buttons round
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
# The dials move by whole stops over these tables. With «Pasos de exposición: Tercios» each one
# also carries how many thirds it is past its index (fine), so everything written for whole stops
# keeps working: changing an index puts its thirds back to zero.
var n_index = 3:
	set(value):
		if value != n_index: fine["n"] = 0
		n_index = value
var t_index = 4:
	set(value):
		if value != t_index: fine["t"] = 0
		t_index = value
var iso_index = 0:
	set(value):
		if value != iso_index: fine["iso"] = 0
		iso_index = value
var fine = {"n":0,"t":0,"iso":0}
var exposure_thirds = false         # the switch in Opciones (user://interfaz.cfg)
var whole_hold = false              # a held D-pad or touch button goes by whole stops
var focal: float = 24.0
var focus_distance: float = 4.0
var angle: float = 120.0
var pan_velocity = 0.0
# How fast the camera is turning (degrees per second, + to the right), smoothed over the last
# tenths of a second: the photo records it, because following a runner with the camera keeps the
# runner sharp and streaks the background (panning, docs/futuro/11 §1).
var camera_omega = 0.0
var omega_last_angle = 0.0
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
var sfx                             # scripts/sfx.gd: the recorded effects (camera, interface, people)
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
var boot_done = false
var screenshot_path = ""
var advance_seconds = 0.0
var start_screen = ""
var ducks: Node3D
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
var academy_play = ""             # --academy-play=<seconds per page>[:<first>-<last>]: the Academy plays itself (video)
var academy_player
# ---- Arcade (docs/futuro/21) ----
var arcade_level = -1               # level being played (-1: sandbox, Academy or a scripted session)
var walk_pace = 1.0                 # walkers' pace in this level (runners keep theirs)
var level_time = 0.0                # seconds left (levels with a time limit)
var level_over = false
# ---- TLR (docs/futuro/21 §3) ----
var tlr_frames = 12                 # 120 film: 12 frames (counted in the sandbox)
var tlr_wound = true                # the crank advances the film before every shot
var tlr_loupe = false               # L: 3× loupe over the ground glass
var control_help                    # on-screen help (scripts/control_help.gd), F1
var tutorial                        # tutorial mode (scripts/tutorial.gd)
# A small copy of the subject turning round at the top left while searching (docs/futuro/22 §7).
var portrait: Panel                 # dark glass card holding the miniature (portrait_box)
var portrait_box: SubViewportContainer
var portrait_view: SubViewport
var portrait_person
var portrait_of = null
# ---- Gamepad (docs/futuro/14) ----
# The control in hand (scripts/control_strip.gd, docs/futuro/22 §5): the one setting the wheel, the
# D-pad ↑↓ or Page Up/Down change. "" until chosen: then the first the camera lets the player drive.
var selected_control = ""
var touch_controls: Control
var touch_crouch = false             # …and its «crouch» and «run» buttons (toggles)
var touch_run = false
var touch_move = Vector2.ZERO        # the walking stick of the touch interface
var control_strip: Control
var hunt_time = 0.0                 # seconds searching with the camera at the eye (hint: lower it)
var hunt_next = 30.0
var pad_precision = false           # L3: sticks three times finer
var pad_run = false                 # L3 while walking: run until the left stick is released
var trigger_stage = 0               # RT: 0 rest, 1 half (AF), 2 fired
var pad_held = 0.0
var pad_repeat = 0.0                # D-pad ↑/↓ auto-repeat timer
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
var walk_hint
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
	load_theme()
	# A phone or a tablet, also when the game runs in its browser (docs/futuro/27 B7).
	var handheld = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if handheld: Glyphs.touch = true
	lean_poses = handheld or OS.has_feature("web") or "--lean" in OS.get_cmdline_user_args()
	if handheld or "--touch" in OS.get_cmdline_user_args():
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		get_viewport().size_changed.connect(fit_frame)
		fit_frame()
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
		if arg.begins_with("--academy-play="): academy_play = arg.trim_prefix("--academy-play=")
		if arg.begins_with("--scenario="): scenario = arg.trim_prefix("--scenario=")
		if arg == "--raised": pending_start["raised"] = true
		if arg == "--walk-demo": walk_demo = 0.0
		if arg == "--photo-walk": photo_walk = {"t":0.0,"phase":"walk","timer":3.0}
		if arg == "--sandbox": pending_start["sandbox_demo"] = true
		# The touch interface on the desktop: the mouse plays the finger (how it is tested).
		if arg == "--touch":
			Glyphs.touch = true
			Input.emulate_touch_from_mouse = true
		if arg == "--tutorial": pending_start["tutorial"] = true
		if arg.begins_with("--level="): pending_start["level"] = int(arg.trim_prefix("--level="))-1
		# Cheat code: every arcade level open for this run (the saved progress is not touched).
		if arg == "--cheat=niveles": Arcade.all_open = true
		if arg.begins_with("--at="): pending_start["at"] = arg.trim_prefix("--at=")
		if arg.begins_with("--scare-at="): demo["scare-at"] = float(arg.get_slice("=",1))
		for key in ["lens","pan","zoom-to","hud"]:
			if arg.begins_with("--%s=" % key): demo[key] = arg.get_slice("=",1)
		if arg in ["--follow","--follow-target","--af","--mf-rack","--expose","--pan-shot","--strip-demo"]: demo[arg.trim_prefix("--")] = true
		# Capture helper: the help texts of a device (teclado, mando) whatever is plugged in.
		if arg.begins_with("--device="):
			preload("res://scripts/input_glyphs.gd").device = arg.get_slice("=",1)
			pad_polling = false
		# Capture helpers: --shutter=30 fixes the speed of the demo shot (a pan needs a slow one),
		# --pan-shot lets the scripted camera's own turn count as a pan, --screen= opens a screen.
		if arg.begins_with("--shutter="): demo["shutter"] = int(arg.get_slice("=",1))
		if arg.begins_with("--screen="): start_screen = arg.get_slice("=",1)
		if arg.begins_with("--shoot-at="): demo["shoot-at"] = float(arg.get_slice("=",1))
		# Sound evidence (docs/futuro/24): --sound-board=camara|interfaz plays those sounds one after
		# another with their names on screen; --sonidos-seguidos makes the park's occasional sounds
		# (barks, laughs, pages…) come five times as often; --end-at=N ends the level at second N
		# and --clock=N leaves it N seconds on the clock.
		if arg.begins_with("--sound-board="): sound_board = arg.get_slice("=",1)
		if arg.begins_with("--end-at="): demo["end-at"] = float(arg.get_slice("=",1))
		# --hold-turn=N: the camera waits ahead of the level's subject and the turn key is held its
		# way from second N (evidence of the following with the keys).
		if arg.begins_with("--hold-turn="): demo["hold-turn"] = float(arg.get_slice("=",1))
		if arg.begins_with("--clock="): demo["clock"] = float(arg.get_slice("=",1))
		if arg.begins_with("--debug-off="): debug_off = arg.trim_prefix("--debug-off=").split(",")
		for key in ["angle","pitch","focal"]:
			if arg.begins_with("--%s=" % key): shot_view[key] = float(arg.get_slice("=",1))
	if Glyphs.touch: Glyphs.device = "tactil"
	if not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--profile=")): graphics_preset = startup_profile()
	# Ultra needs Forward+ and the other profiles run in gl_compatibility (docs/futuro/17 §2.1).
	# Desktop runs every profile in Forward+ (docs/futuro/17 §2.1). Ultra's effects need it: in the
	# gl_compatibility fallback (Android, no Vulkan) the top profile is Alto.
	if not ParkScene.forward_plus() and graphics_preset == "Ultra" and not smoke and screenshot_path == "" and not run_metrics: graphics_preset = "Alto"
	var t_start = Time.get_ticks_msec()
	# The real game shows the camera turning while the park is built (scripts/boot_loader.gd) and
	# lets a frame through between stages; tests and capture tools build in one go, as before.
	if get_tree().current_scene == self and not smoke and screenshot_path == "" and not run_metrics and demo.is_empty() and photo_walk.is_empty():
		boot_loader = preload("res://scripts/boot_loader.gd").new()
		add_child(boot_loader)
		frame_layer(boot_loader)
		if frame_offset != Vector2.ZERO: RenderingServer.set_default_clear_color(Color("296ca5"))
		await boot_step()
	await build_world()
	var t_world = Time.get_ticks_msec()
	build_ui()
	var t_ui = Time.get_ticks_msec()
	academy = preload("res://scripts/academy.gd").new(self)
	ui.add_child(academy)
	preload("res://scripts/academy.gd").register_actions()
	register_pad_ui()
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
	var t_people = Time.get_ticks_msec()
	await boot_step()
	await populate()
	# -- --timing: where the start-up time goes (the park by stage, the people, the interface).
	if "--timing" in OS.get_cmdline_user_args():
		print("TIMING total=%d ms · mundo=%d (%s; parque: %s) · interfaz=%d · gente=%d" % [Time.get_ticks_msec()-t_start,t_world-t_start,str(world_times),str(park.build_times),t_ui-t_world,Time.get_ticks_msec()-t_people])
	sound = AudioStreamPlayer.new()
	add_child(sound)
	await settle_population()
	await warm_up_view()
	update_camera()
	apply_graphics_preset(graphics_preset)
	# The saved display (window mode and size) applies to a normal run only: never to tests,
	# captures or scripted runs, which need their own window.
	if get_tree().current_scene == self and not smoke and screenshot_path == "" and not run_metrics and demo.is_empty() and photo_walk.is_empty():
		if Graphics.load_display(): Graphics.apply_display(get_window())
		Graphics.apply_fps_limit()
		fps_limited = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--version-as="): version_override = arg.trim_prefix("--version-as=")
		# (Not under a tool or a test, which run the game from their own script: the news would
		# cover the screens they look at, and they have no business on the network.)
		if not ("--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args()):
			check_version()
			check_update()
	if not equipment_state.is_empty():
		equipment.body = equipment_state.body
		equipment.lens_index = equipment_state.lens
		equipment.focus_mode = equipment_state.focus
		equipment.auto_exposure = equipment_state.auto
		equipment.priority = equipment_state.get("priority","")
		equipment.film = equipment_state.film
		equipment.film_iso_index = equipment_state.film_iso
		equipment.ev_comp_index = equipment_state.ev
		apply_equipment()
	intro()
	boot_done = true
	if is_instance_valid(boot_loader): boot_loader.finish()
	if pending_start.has("level"):
		start_level(int(pending_start.level))
	elif pending_start.has("time"):
		start_session(pending_start.time,pending_start.get("sandbox",false))
	elif pending_start.has("tutorial"):
		start_tutorial()
	elif pending_start.has("academy"):
		show_academy()
	for key in ["time","sandbox","academy","level","tutorial"]: pending_start.erase(key)
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
		# With --level the level already set scenario, light and equipment: just enter it.
		if arcade_level < 0: start_session(start_time_of_day,bool(pending_start.get("sandbox_demo",false)))
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
		if OS.has_feature("web"):
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
	camera.rotation = saved

var world_times = {}
var boot_loader
# One frame for the loading screen, when there is one.
func boot_step() -> void:
	if is_instance_valid(boot_loader): await get_tree().process_frame

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
	# The park's sounds are placed in this world: without its own listener nothing placed in it
	# was heard at all (birds, fountain, pigeons), only the camera and the interface.
	viewport.audio_listener_enable_3d = true
	container.add_child(viewport)
	update_render_resolution()
	get_window().size_changed.connect(update_render_resolution)
	park = (preload("res://scripts/park_grande.gd") if scenario == "grande" else ParkScene).new()
	park.detail = "hd" if ParkScene.forward_plus() else "lo"
	Person.detail = "lo" if "lo_people" in debug_off else park.detail
	Person.preload_pieces(["res://data/piezas","res://data/piezas_hd"] if Person.detail == "hd" else ["res://data/piezas"])
	viewport.add_child(park)
	var t_park = Time.get_ticks_msec()
	park.build()
	world_times["parque"] = Time.get_ticks_msec()-t_park
	await boot_step()
	var t_stage = Time.get_ticks_msec()
	pigeons = preload("res://scripts/pigeons.gd").new()
	if scenario == "grande":
		# Two flocks on the lawns beside the plaza.
		pigeons.homes = [Vector3(14,0,-5),Vector3(-14,0,5)].map(func(v): return Vector2(fposmod(rad_to_deg(atan2(v.x,-v.z)),360.0),Vector2(v.x,v.z).length()))
	viewport.add_child(pigeons)
	pigeons.build(Person.detail)
	# In the big park the flocks perch on its real trees (the classic park's curtain is elsewhere).
	if scenario == "grande": pigeons.perches = park.tree_spots
	else: pigeons.fence = park.fence_perches
	if "--pigeons=verja" in OS.get_cmdline_user_args() and not pigeons.fence.is_empty(): pigeons.settle_fence()
	world_times["palomas"] = Time.get_ticks_msec()-t_stage
	await boot_step()
	t_stage = Time.get_ticks_msec()
	extras = preload("res://scripts/extras.gd").new()
	viewport.add_child(extras)
	# The meadow extras belong to the classic park; in the big park the crowd itself fills it.
	if scenario == "clasico": extras.build(Person.detail)
	else: extras.build_playground(park.PLAYGROUND_POS,Person.detail)
	# Ducks on the pond (desktop only, beyond the fence).
	if scenario == "clasico" and Person.detail == "hd" and park.detail == "hd":
		ducks = preload("res://scripts/ducks.gd").new()
		viewport.add_child(ducks)
		var pond_pos = park.polar(park.POND.x,park.POND.y)
		ducks.build(pond_pos,park.facing_center(pond_pos)+PI*.5)
	world_times["figurantes"] = Time.get_ticks_msec()-t_stage
	await boot_step()
	t_stage = Time.get_ticks_msec()
	ambience = preload("res://scripts/ambience.gd").new()
	if scenario == "grande":
		ambience.fountain_pos = Vector3(0,.8,0)
		ambience.fountain_unit = 7.0
		ambience.fountain_db = -2.0
		ambience.bird_points = [Vector3(-30,5,20),Vector3(30,5,-24),Vector3(-40,5,-30),Vector3(36,5,32),Vector3(4,5,-24),Vector3(-6,5,26)]
		ambience.cricket_points = [Vector3(-20,.3,14),Vector3(20,.3,-14),Vector3(0,.3,-40),Vector3(-48,.3,0),Vector3(48,.3,8)]
	viewport.add_child(ambience)
	ambience.build(park,pigeons)
	sfx = preload("res://scripts/sfx.gd").new()
	add_child(sfx)
	sfx.setup(self,viewport)
	world_times["sonido"] = Time.get_ticks_msec()-t_stage
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

# Which of the 21 run (in the order they are created: 0–2 the inner path, 3–9 the benches' path,
# 10–15 the third, 16–20 the outer one). One on the third path and two on the outer one: the inner
# paths are short and busy, and a runner lapping the photographer every four seconds was only in
# the way.
const RUNNER_PLACES = [12,17,20]
func populate() -> void:
	pose_debt.clear()
	step_debt.clear()
	if scenario == "grande":
		populate_grande()
		return
	var counts = [3, 7, 6, 5]
	var radii = [1.8,4.0,7.0,11.5]
	for lane in 4:
		for i in counts[lane]:
			var p = Person.new()
			viewport.add_child(p)
			p.setup(casting.generate(people.size() in RUNNER_PLACES),casting.catalog,people.size()+905)
			p.lane = lane
			p.direction = -1 if i%2 == 0 else 1
			# Runners all go round the same way, like on any track: they never meet head-on.
			if p.runner: p.direction = 1
			p.radius = home_radius(lane,p.direction,p.runner)
			p.theta = i*(360.0/counts[lane])+lane*7.0
			p.place()
			p.animate(0)
			people.append(p)
			await boot_step()
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
	# Light theme (docs/futuro/20): dark panels become white glass with a soft sky-blue edge.
	node.add_theme_stylebox_override("panel",UiStyle.box(UiStyle.panel_color(color),maxi(radius,12) if radius > 0 else 0,UiStyle.LINE if radius > 0 else Color.TRANSPARENT))
	parent.add_child(node)
	return node

# Lists with an orange dot before each item (the briefing, the report of a photo).
func dot() -> String:
	return "[color=#%s]●[/color] " % UiStyle.BRAND.to_html(false)
func plain_bb(text_value: String) -> String:
	return text_value.replace("[","[lb]")
func dotted(items: Array) -> String:
	return "\n".join(items.map(func(item): return dot()+plain_bb(str(item).substr(0,1).to_upper()+str(item).substr(1))))
func rich_label(parent: Control, bbcode: String, rect: Rect2, font_size = 18, color = Color("e6e8dd")) -> RichTextLabel:
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.scroll_active = false
	node.text = bbcode
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("normal_font_size",font_size)
	node.add_theme_color_override("default_color",UiStyle.text_color(color))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent: parent.add_child(node)
	return node

func label(parent: Control, text_value: String, rect: Rect2, font_size = 18, color = Color("e6e8dd")) -> Label:
	var node = Label.new()
	node.text = text_value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",UiStyle.text_color(color))
	# Titles in Russo One (the font of the name), the rest in Roboto (theme default).
	# Menu titles take the orange of the logo unless the caller gives a colour with a meaning
	# (a score, passed or failed); nothing drawn over the viewfinder is this big.
	if font_size >= 26:
		node.add_theme_font_override("font",UiStyle.font("RussoOne-Regular"))
		if color == Color("e6e8dd") or color == Color("b8d78c"): node.add_theme_color_override("font_color",UiStyle.BRAND)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	# A long text widens the label as it enters the tree; callers turn on the wrap afterwards, so
	# the width asked for is put back once they have (or the text would never wrap).
	node.set_deferred("size",rect.size)
	return node

# Text with keys drawn as keycaps and pad buttons as round buttons (scripts/glyph_label.gd).
func glyph_label(parent: Control, rich: String, rect: Rect2, font_size = 16, color = Color.WHITE, shadow = false) -> Control:
	var node = preload("res://scripts/glyph_label.gd").new()
	node.position = rect.position
	node.size = rect.size
	node.font_size = font_size
	node.color = color
	node.shadow = shadow
	node.rich = rich
	parent.add_child(node)
	return node

# Under a finger (docs/futuro/26 A3) the buttons and lists of the screens grow to a height that
# can be hit — about 6.5 mm on a 6.7" phone — around their own middle, without leaving the screen.
# The screens are laid out with at least 60 units between rows, so nothing overlaps.
const TOUCH_BUTTON = 66.0
const TOUCH_OPTION = 56.0
func finger_rect(rect: Rect2, least: float) -> Rect2:
	if not Glyphs.touch or rect.size.y >= least or rect.size.y < 40: return rect
	var grown = Rect2(rect.position.x,rect.position.y-(least-rect.size.y)*.5,rect.size.x,least)
	grown.position.y = clampf(grown.position.y,4,716-least)
	return grown

func button(parent: Control, text_value: String, rect: Rect2, callback: Callable, primary = false) -> Button:
	var node = Button.new()
	node.text = text_value
	rect = finger_rect(rect,TOUCH_BUTTON)
	node.position = rect.position
	node.size = rect.size
	# Buttons of the screens can take the focus (gamepad and keyboard navigation, docs/futuro/14 §5);
	# the HUD's stay out of it so the D-pad never steals it while searching.
	var on_screen = is_instance_valid(modal) and (parent == modal or modal.is_ancestor_of(parent))
	node.focus_mode = Control.FOCUS_ALL if on_screen else Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",18 if Glyphs.touch and on_screen else 16)
	if primary:
		UiStyle.primary(node)
		if on_screen: node.call_deferred("grab_focus")
	node.pressed.connect(callback)
	# (going back sounds like going back: the buttons that lead to the menu or to the level list)
	var back = callback in [Callable(self,"intro"),Callable(self,"show_arcade"),Callable(self,"show_academy")]
	if on_screen: node.pressed.connect(func(): play_sfx("ui_atras" if back else "ui_aceptar",-6.0))
	parent.add_child(node)
	return node

# --- The whole screen on a phone (docs/futuro/26 A1, A2) --------------------------------------
# The game is laid out on 1280 × 720. A phone is wider (20:9, 19.5:9) and a tablet taller: with
# the touch interface the window shows more than those 1280 × 720 instead of adding black bands,
# the game stays in the middle (frame_offset is its top-left corner; every CanvasLayer is moved
# by it) and the touch buttons move out into the side bands, off the picture (touch_controls.gd).
# safe_inset: what the notch or the punch-hole camera takes from each side, in ui units.
var frame_offset = Vector2.ZERO
var safe_inset = Vector2.ZERO       # x: left, y: right
var frame_layers = []

func fit_frame() -> void:
	var window = get_window()
	if window.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND: return
	var size = get_viewport().get_visible_rect().size
	frame_offset = ((size-Vector2(1280,720))*.5).max(Vector2.ZERO).floor()
	frame_layers = frame_layers.filter(func(l): return is_instance_valid(l))
	for layer in frame_layers: layer.offset = frame_offset
	safe_inset = Vector2.ZERO
	if OS.has_feature("mobile"):
		var screen = Vector2(DisplayServer.screen_get_size())
		var safe = DisplayServer.get_display_safe_area()
		if screen.x > 0 and safe.size.x > 0:
			var unit = size.x/screen.x
			safe_inset = Vector2(maxf(0,safe.position.x),maxf(0,screen.x-safe.end.x))*unit
	update_bands()

# The whole window in ui coordinates (the game's 1280 × 720 plus the bands): backgrounds use it.
func full_rect() -> Rect2:
	return Rect2(-frame_offset,Vector2(1280,720)+frame_offset*2)

# Follows a layer of the interface: it moves with the game when the window is wider than 16:9.
func frame_layer(layer: CanvasLayer) -> void:
	frame_layers.append(layer)
	layer.offset = frame_offset

# What is seen at the sides of the game: the camera's body while shooting through it, the colour
# of the screens otherwise (the loading screen sets its own blue).
func update_bands() -> void:
	if frame_offset == Vector2.ZERO: return
	var body = mode == "SEARCH" and interface_mode == "camara"
	RenderingServer.set_default_clear_color(BAND_BODY if body else UiStyle.surf(1.0))
const BAND_BODY = Color("2b2d30")

func build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	frame_layer(layer)
	ui = Control.new()
	ui.size = Vector2(1280,720)      # (not the window's: it may be wider than the game)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiStyle.theme()
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
	sandbox_button = button(job_panel,Texts.get_text("sandbox_boton_escena"),Rect2(16,4,200,26),show_sandbox_controls)
	# (The graphics are changed from the main menu's options, not during a phase.)
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
	control_hint = glyph_label(ui,Texts.get_rich("arrastra_paneo_rueda_zoom_clic_af_espacio_disparo_ayuda"),Rect2(531,664,330,40),11,UiStyle.text_color(Color("90a287")))
	af_button = button(ui,Texts.get_text("enfocar"),Rect2(863,647,128,50),autofocus)
	button(ui,Texts.get_text("disparar"),Rect2(1005,642,248,59),take_photo,true)
	toast = label(ui,"",Rect2(290,574,700,35),16,Color("e2e8d4"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color",Color("f4f8fc"))
	toast.add_theme_color_override("font_shadow_color",Color.BLACK)
	toast.add_theme_constant_override("shadow_offset_x",1)
	toast.add_theme_constant_override("shadow_offset_y",2)
	fps_label = label(ui,"",Rect2(27,586,200,23),12,Color("d2ddc6"))
	# Big park walking view: the assignment on top, the controls below, and a quick dark blink when
	# the camera reaches the eye or leaves it.
	walk_label = label(ui,"",Rect2(40,18,1200,30),18,Color("eef2e6"))
	walk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	walk_label.add_theme_color_override("font_color",Color("f4f8fc"))
	walk_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	walk_label.add_theme_constant_override("shadow_offset_y",2)
	walk_label.visible = false
	walk_hint = glyph_label(ui,Texts.get_rich("paseo_ayuda"),Rect2(40,668,1200,30),14,Color("eef3f8"),true)
	walk_hint.align_center = true
	walk_hint.visible = false
	control_help = preload("res://scripts/control_help.gd").new(self)
	ui.add_child(control_help)
	control_strip = preload("res://scripts/control_strip.gd").new(self)
	ui.add_child(control_strip)
	tutorial = preload("res://scripts/tutorial.gd").new(self)
	ui.add_child(tutorial)
	touch_controls = preload("res://scripts/touch_controls.gd").new(self)
	ui.add_child(touch_controls)
	raise_flash = ColorRect.new()
	raise_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raise_flash.color = Color(0,0,0,0)
	raise_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(raise_flash)
	# The light meter on the top bar, between the exposure buttons: scale from −2 to +2 EV and the
	# needle. (Only the classic full-screen finder drew it; with the camera interface the place the
	# Academy points at was an empty gap.)
	meter_bar = Control.new()
	meter_bar.position = Vector2(540,18)
	meter_bar.size = Vector2(215,50)
	meter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_bar.draw.connect(draw_meter_bar)
	ui.add_child(meter_bar)
	# HUD bars of the classic interface; the camera interface folds them away (Tab shows them).
	for child in ui.get_children():
		if child in [camera_body,focus_aid,finder,toast,fps_label,walk_label,walk_hint,raise_flash,control_help,control_strip,tutorial,touch_controls]: continue
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
	# Help texts follow the last device used (keyboard and mouse, or gamepad).
	if Glyphs.note(event):
		log_device(event)
		refresh_device()
	# (The HUD bars no longer unfold when the pointer nears the edges: only Tab shows them.)
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
	if equipment.auto_exposure and not ((parameter == "n" and equipment.priority == "A") or (parameter == "t" and equipment.priority == "S")): return
	# The dials stop at their ends (wrapping from f/22 back to f/1.4 was disorienting).
	if parameter == "iso" and equipment.film: return
	var dial_before = [whole_index(parameter),fine[parameter]]
	if thirds_on() and not (whole_hold or Input.is_key_pressed(KEY_SHIFT)):
		fine_step(parameter,direction)
	elif thirds_on():
		for i in 3: fine_step(parameter,direction)
	else:
		fine[parameter] = 0
		match parameter:
			"n": n_index = clampi(n_index+direction,0,apertures().size()-1)
			"t": t_index = clampi(t_index+direction,fastest_index(),Photo.DENOMINATORS.size()-1)
			"iso": iso_index = clampi(iso_index+direction,0,Photo.ISOS.size()-1)
	# A click of the dial, or the dull stop at the end of its travel.
	play_sfx("dial" if [whole_index(parameter),fine[parameter]] != dial_before else "dial_tope",-3.0,randf_range(.96,1.04))
	if equipment.auto_exposure: auto_expose()
	refresh()

# Thirds of a stop (docs/EQUIPAMIENTO_Y_OPTICAS.md §8). The Academy teaches with whole stops.
func thirds_on() -> bool:
	return exposure_thirds and not (academy and academy.active)

# The fastest shutter of the camera in hand: 1/4000 s on the SLR and the rangefinder, 1/1000 s on
# the compact and the TLR, and in the Academy, whose lessons are written for 1/1000 s.
func fastest_index() -> int:
	if equipment.body in [1,2] and not (academy and academy.active): return 0
	return Photo.DENOMINATORS.find(1000)

func whole_table(parameter: String) -> Array:
	return {"n":apertures(),"t":Photo.DENOMINATORS,"iso":Photo.ISOS}[parameter]
func third_table(parameter: String) -> Array:
	return {"n":equipment.THIRD_STOPS,"t":Photo.THIRD_DENOMINATORS,"iso":Photo.THIRD_ISOS}[parameter]
func whole_index(parameter: String) -> int:
	return {"n":n_index,"t":t_index,"iso":iso_index}[parameter]

# Thirds between an entry of the whole-stop table and the next one (f/1.4 to f/1.8 is two).
func third_gap(parameter: String, index: int) -> int:
	var whole = whole_table(parameter)
	if index >= whole.size()-1: return 1
	var thirds = third_table(parameter)
	return maxi(1,thirds.find(whole[index+1])-thirds.find(whole[index]))

# A setting as [index, thirds], moved a number of thirds; it stops at the ends of the dial.
func fine_moved(parameter: String, at: Array, amount: int) -> Array:
	var index: int = at[0]
	var thirds: int = at[1]
	var last = whole_table(parameter).size()-1
	var first = fastest_index() if parameter == "t" else 0
	for i in absi(amount):
		if amount > 0:
			if index >= last: break
			thirds += 1
			if thirds >= third_gap(parameter,index):
				index += 1
				thirds = 0
		elif thirds > 0: thirds -= 1
		elif index > first:
			index -= 1
			thirds = third_gap(parameter,index)-1
	return [index,thirds]

func fine_value(parameter: String, at: Array):
	var whole = whole_table(parameter)
	var index = clampi(at[0],0,whole.size()-1)
	if at[1] <= 0 or index >= whole.size()-1: return whole[index]
	var thirds = third_table(parameter)
	return thirds[mini(thirds.find(whole[index])+at[1],thirds.size()-1)]

func set_fine(parameter: String, at: Array) -> void:
	match parameter:
		"n": n_index = at[0]
		"t": t_index = at[0]
		"iso": iso_index = at[0]
	fine[parameter] = at[1]

func fine_step(parameter: String, direction: int) -> void:
	set_fine(parameter,fine_moved(parameter,[whole_index(parameter),fine[parameter]],direction))

func clear_fine() -> void:
	fine = {"n":0,"t":0,"iso":0}

func aperture_value() -> float:
	return fine_value("n",[n_index,fine["n"]])
func shutter_denominator() -> int:
	return fine_value("t",[t_index,fine["t"]])
func iso_value() -> int:
	return fine_value("iso",[iso_index,fine["iso"]])

func set_exposure_thirds(value: bool) -> void:
	exposure_thirds = value
	if not value: clear_fine()
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","tercios",value)
	config.save("user://interfaz.cfg")
	if is_instance_valid(aperture_button): refresh()

# After the whole stops are chosen, the camera trims what is left over with thirds on one dial:
# the shutter if it is its own to move, else the aperture, else the ISO.
func trim_exposure(target_ev: float) -> void:
	var free = []
	if equipment.priority != "S": free.append("t")
	if equipment.priority != "A": free.append("n")
	if not equipment.film: free.append("iso")
	for parameter in free: fine[parameter] = 0
	# The camera's own exposure is not tied to the player's whole stops: rounded to a whole stop,
	# a reading half a stop off the subject became a photo a whole stop off. (The Academy keeps
	# whole stops: its lessons count them.)
	if academy and academy.active:
		clear_fine()
		return
	var best = absf(Photo.ev(aperture_value(),1.0/shutter_denominator(),iso_value(),target_ev))
	var choice = []
	for parameter in free:
		var here = [whole_index(parameter),0]
		for amount in [-1,1,-2,2]:
			var at = fine_moved(parameter,here,amount)
			var n = fine_value("n",at) if parameter == "n" else aperture_value()
			var t = fine_value("t",at) if parameter == "t" else shutter_denominator()
			var iso = fine_value("iso",at) if parameter == "iso" else iso_value()
			var delta = absf(Photo.ev(n,1.0/t,iso,target_ev))
			if delta < best-.02:
				best = delta
				choice = [parameter,at]
		if not choice.is_empty(): break
	if not choice.is_empty(): set_fine(choice[0],choice[1])

# The settings the player drives on this camera, in the order of the strip.
func selectable_controls() -> Array:
	var m: String = equipment.exposure_mode()
	var out = []
	if equipment.zoom(): out.append("zoom")
	if equipment.focus_mode == "MF": out.append("foco")
	if m in ["M","A"]: out.append("n")
	if m in ["M","S"]: out.append("t")
	if m == "M" and not equipment.film: out.append("iso")
	if m != "M": out.append("ev_comp")
	return out

func current_control() -> String:
	var list = selectable_controls()
	if list.is_empty(): return ""
	if not selected_control in list: selected_control = list[0]
	return selected_control

func select_control(step: int) -> void:
	var list = selectable_controls()
	if list.is_empty() or mode != "SEARCH": return
	selected_control = list[posmod(list.find(current_control())+step,list.size())]
	if not play_sfx("control_elegir",-4.0): play_tone(1500,.02)

func change_control(step: int, coarse = 1.0) -> void:
	if mode != "SEARCH": return
	match current_control():
		"": pass
		"zoom":
			focal += step*3
			update_camera()
		"foco": adjust_focus_delta(-step*.0035*coarse)
		_: change_parameter(current_control(),step)

func refresh() -> void:
	if not is_instance_valid(aperture_button): return
	if equipment.film: iso_index = equipment.film_iso_index
	n_index = clampi(n_index,0,apertures().size()-1)
	aperture_button.disabled = equipment.auto_exposure and equipment.priority != "A"
	shutter_button.disabled = equipment.auto_exposure and equipment.priority != "S"
	iso_button.disabled = equipment.auto_exposure or equipment.film
	lens_slider.editable = equipment.zoom()
	focus_slider.editable = equipment.focus_mode == "MF"
	af_button.disabled = equipment.focus_mode == "MF"
	equipment_label.text = equipment.CAMERAS[equipment.body]
	if equipment.auto_exposure:
		var ev_c = equipment.exposure_compensation()
		var tag = {"A":"A","S":"S"}.get(equipment.priority,"AUTO")
		exposure_button.text = tag+(" ±0.0" if is_zero_approx(ev_c) else (" %+.1f" % ev_c))
		exposure_button.disabled = false
	else:
		exposure_button.text = "M"
		exposure_button.disabled = true
	if equipment.focus_mode == "MF":
		control_hint.set_rich(Texts.get_rich("control_hint_mf"))
	else:
		control_hint.set_rich(Texts.get_rich("control_hint_af")+"\n"+Texts.get_rich("control_hint_af_zoom" if equipment.zoom() else "control_hint_af_fijo"))
	finder.af_mode = equipment.focus_mode
	finder.body = equipment.body
	if is_instance_valid(camera_body) and camera_body.body != equipment.body:
		place_view()
		update_dof_pass()
	focus_aid.visible = equipment.focus_mode == "MF" and mode == "SEARCH" and not tlr_loupe and eye_ready()   # (walking with the camera down it blinked: refresh() showed it, update_focus_aid() hid it)
	focus_aid.material.set_shader_parameter("body",equipment.body)
	aperture_button.text = Texts.get_text("1f") % aperture_value()
	shutter_button.text = Texts.get_text("1_d") % shutter_denominator()
	iso_button.text = ("▣ " if equipment.film else "")+Texts.get_text("iso_d") % iso_value()
	focal_label.text = (Texts.get_text("estado_zoom") if equipment.zoom() else Texts.get_text("estado_fijo"))+" %.0f mm" % focal
	focus_label.text = Texts.get_text("foco")+(Texts.get_text("infinito") if is_inf(focus_distance) else Texts.get_text("2f_m") % focus_distance)
	update_lens_effects()
	var depth = Photo.dof(focal,aperture_value(),focus_distance)
	dof_label.text = Texts.get_text("nitido_2f_m_s") % [depth.x,Texts.get_text("infinito") if is_inf(depth.y) else Texts.get_text("2f_m") % depth.y]
	finder.delta_ev = -Photo.ev(aperture_value(),1.0/shutter_denominator(),iso_value(),measured_ev)
	if is_instance_valid(meter_bar): meter_bar.queue_redraw()
	focus_slider.set_value_no_signal(1 if is_inf(focus_distance) else 1-.8/focus_distance)
	lens_slider.set_value_no_signal(focal)
	counter_label.text = Texts.get_text("arcade_nivel_d") % (arcade_level+1) if arcade_level >= 0 else "ENCARGO %02d" % (assignment+1)
	counter_label.visible = not sandbox
	sandbox_button.visible = sandbox and not (academy and academy.active) and not (tutorial and tutorial.active)
	var tod_tag = Texts.get_text("estado_noche") if night else (Texts.get_text("estado_dorada") if time_of_day == "golden" else (Texts.get_text("estado_azul") if time_of_day == "blue" else (Texts.get_text("estado_nubes") if park.cloud_cover > .4 else Texts.get_text("estado_sol"))))
	var frames_text = Texts.get_text("estado_sin_limite") if sandbox else Texts.get_text("estado_disparos_d") % shots
	if sandbox and equipment.tlr(): frames_text = "%d / 12" % tlr_frames
	status_label.text = tod_tag + " · EV %.1f · " % measured_ev + frames_text + (" · "+clock_text() if arcade_level >= 0 and level_limit() > 0 and not sandbox else "")

func update_camera() -> void:
	if not is_instance_valid(camera): return
	angle = fposmod(angle,360.0)
	pitch = clampf(pitch,-75,75)
	focal = clampf(focal,equipment.lens().min,equipment.lens().max)
	camera.rotation = Vector3(deg_to_rad(pitch),-deg_to_rad(angle),0)
	# The TLR is held at the waist and looked into from above (1.10 m instead of the eye's 1.60 m).
	if not crowd: camera.position.y = 1.1 if equipment.tlr() else 1.6
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
	# Every screen: the park behind frosted white glass, as the main menu.
	var glass = ColorRect.new()
	glass.position = full_rect().position
	glass.size = full_rect().size
	var glass_material = ShaderMaterial.new()
	glass_material.shader = preload("res://shaders/frosted_glass.gdshader")
	glass_material.set_shader_parameter("wash",.6)
	glass_material.set_shader_parameter("tint",UiStyle.GLASS_TINT)
	glass.material = glass_material
	modal.add_child(glass)
	# Whatever the screen, the gamepad needs a button with the focus to start from.
	call_deferred("ensure_modal_focus")
	return modal

func ensure_modal_focus() -> void:
	if not is_instance_valid(modal): return
	var owner_now = get_viewport().gui_get_focus_owner()
	if owner_now != null and modal.is_ancestor_of(owner_now): return
	for b in modal.find_children("*","Button",true,false):
		if b.visible and not b.disabled and b.focus_mode == Control.FOCUS_ALL and b.is_visible_in_tree():
			b.grab_focus()
			return

# Main menu (scripts/main_menu.gd, docs/futuro/20): the live park behind frosted glass.
func intro() -> void:
	mode = "INTRO"
	if tutorial and tutorial.active: tutorial.stop()
	if academy and academy.active: academy.stop()
	close_modal()
	modal = preload("res://scripts/main_menu.gd").new(self)
	ui.add_child(modal)
	menu_park_ready()
	place_view()
	update_finder_shader()

# Behind the menu the park lives: people walk, the camera drifts slowly at eye level.
func menu_park_ready() -> void:
	if crowd: camera.position = Vector3(0,1.6,16)
	pitch = 2.0
	focal = equipment.lens().min
	update_camera()

func update_menu_background(dt: float) -> void:
	for p in people: update_person(p,dt)
	pigeons.update(dt,people,([dog] if dog else [])+([player_proxy] if player_proxy else []))
	if extras: extras.update(dt)
	if ducks: ducks.update(dt)
	if dog: dog.update(dt)
	ambience.update(dt)
	angle = fposmod(angle+dt*2.2,360)
	update_camera()

# Choosing the light in the menu changes the park behind the glass at once.
func preview_time(tod: String) -> void:
	time_of_day = tod
	night = tod == "night"
	park.set_time_of_day(tod)
	if pigeons:
		pigeons.night = night
		if ducks: ducks.night = night
		if night: pigeons.settle_night()
	if extras: extras.set_time_of_day(tod)

# Start a session in a scenario; another scenario reloads the scene with it (the equipment kept).
func start_in(which: String, time_mode: String, free_play: bool) -> void:
	arcade_level = -1
	if which == scenario:
		start_session(time_mode,free_play)
		return
	reload_with(which,{"time":time_mode,"sandbox":free_play})

func reload_with(which: String, start: Dictionary) -> void:
	equipment_state = {"body":equipment.body,"lens":equipment.lens_index,"focus":equipment.focus_mode,"auto":equipment.auto_exposure,"priority":equipment.priority,"film":equipment.film,"film_iso":equipment.film_iso_index,"ev":equipment.ev_comp_index}
	scenario = which
	pending_start = start
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

# The Academy uses the classic park (its lessons are staged around the photographer).
func open_academy() -> void:
	arcade_level = -1
	if scenario != "clasico":
		reload_with("clasico",{"academy":true})
		return
	show_academy()

func start_session(time_mode = "day", free_play = false) -> void:
	close_modal()
	mode = "STARTING"
	place_view()
	sandbox = free_play
	if free_play: arcade_level = -1
	level_over = false
	level_time = level_limit()
	walk_pace = float(Arcade.LEVELS[arcade_level].get("pace",1.0)) if arcade_level >= 0 and not free_play else 1.0
	tlr_frames = 12
	tlr_wound = true
	tlr_loupe = false
	sandbox_paused = false
	shot_serial = 0
	release_lock()
	park.weather_time = 0
	# Clouds that darken the park: only the arcade levels that say so; the sandbox asks for them
	# in its own settings.
	park.clouds_enabled = Arcade.clouds(arcade_level) and not free_play
	if time_mode is bool:
		time_of_day = "night" if time_mode else "day"
	else:
		time_of_day = str(time_mode)
	night = (time_of_day == "night")
	park.set_time_of_day(time_of_day)
	if pigeons:
		pigeons.night = night
		if ducks: ducks.night = night
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
	if not crowd:
		camera_raised = true
		raise_anim = 1.0
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
	finder.golden = false
	if sandbox:
		if is_instance_valid(target): target.protected_target = false
		target = null
		shots = 3
		best = {}
		briefing.text = Texts.get_text("sandbox_encargo")
		resume_search()
	else: new_assignment()

func new_assignment() -> void:
	if is_instance_valid(target): target.protected_target = false
	var level: Dictionary = Arcade.LEVELS[arcade_level] if arcade_level >= 0 else {}
	# Levels that ask for the subject alone get a quieter park: three out of five people stay away
	# (hidden, and out of the way of the photo). With the full park it could not be done.
	for p in people:
		if p.has_meta("away"):
			p.remove_meta("away")
			p.set_hidden(false)
	if level.get("cond",{}).has("aislado"):
		for i in people.size():
			if i%5 >= 2:
				people[i].set_meta("away",true)
				people[i].set_hidden(true)
	# The subject never runs, except in the levels about freezing a runner.
	var candidates = people.filter(func(p): return p.lane in [1,2] and p.state != "RETIRADO" and not p.runner and p.visible)
	if level.get("target","") == "runner":
		# Never the runner passing right in front (lane 0): one further away, to follow.
		var runners = people.filter(func(p): return p.runner and p.visible and p.state != "RETIRADO" and p.lane >= 1)
		if runners.is_empty(): runners = people.filter(func(p): return p.runner and p.visible and p.state != "RETIRADO")
		# Of those, the one on the third path (7 m): near enough to fill the frame, far enough to
		# follow; the outer path otherwise.
		if not runners.is_empty():
			var best_lane = 2 if runners.any(func(p): return p.lane == 2) else runners.map(func(p): return p.lane).max()
			runners = runners.filter(func(p): return p.lane == best_lane)
		if not runners.is_empty(): candidates = runners
	if candidates.is_empty(): candidates = people.filter(func(p): return p.visible)
	var kind = str(level.get("target",""))
	# The dog's owner; someone who can sit down on a bench (classic park: lane of the benches).
	if kind == "dog" and dog and is_instance_valid(dog.walker): candidates = [dog.walker]
	if kind == "activity" and not crowd:
		var sitters = candidates.filter(func(p): return p.lane == 1 and not p.never_sits and not p.has_dog and p.state == "CAMINANDO")
		if not sitters.is_empty(): candidates = sitters
	var all_traits = people.map(func(p): return p.traits)
	target = candidates[casting.rng.randi_range(0,candidates.size()-1)]
	# Levels that need the subject somewhere (in front of the bandstand, against the sun): whoever
	# will get there first, so that nobody waits a whole lap.
	if level.has("toward") and not crowd and kind == "":
		var goal = toward_theta(str(level.toward))
		var soonest = INF
		# (on the third path: far enough for a whole figure and what is behind it)
		var far = candidates.filter(func(p): return p.lane == 2)
		for p in (far if not far.is_empty() else candidates):
			var lead = fposmod((goal-p.theta)*p.direction-25.0,360.0)/maxf(.05,p.speed/p.radius)
			if lead < soonest:
				soonest = lead
				target = p
	if kind == "activity" and not crowd: seat_target()
	var predicates = casting.predicates_for(target.traits,all_traits)
	assert(not predicates.is_empty(),Texts.get_text("el_encargo_debe_identificar_un_sujeto_unico"))
	target.protected_target = true
	# If the level's runner was stretching, the run goes on.
	if runner_on_duty(target):
		target.pending_stop = {}
		if target.state == "DETENIDO": resume_walk(target)
	briefing.text = Texts.get_text("busca")+", ".join(predicates)+"."
	shots = int(level.get("shots",3))
	# Framing guides: the golden section where the level asks for it, thirds otherwise (G hides them).
	finder.golden = not level.is_empty() and level.cond.has("aurea")
	finder.thirds = true
	# Manual exposure in the arcade starts metered for the subject: the player fine-tunes it.
	if not level.is_empty() and equipment.exposure_mode() != "P":
		expose_for(park.illumination_ev(target.control_points()[1],time_of_day,target))
	if not level.is_empty() and not level.cond.is_empty():
		var conds = []
		for key in level.cond: conds.append(Conditions.describe(key,level.cond[key]).to_lower())
		briefing.text += "  ·  "+", ".join(conds)
	best = {}
	show_assignment()
	refresh()
	notify_player(Texts.get_text("encuentra_los_rasgos_del_encargo_usa_el_exposimetro_para_ajustar"))

# Only the game itself earns badges: the test suites and the capture tools run the same scene and
# must not fill the player's file (they are never the tree's current scene, or carry their flags).
func badges_count() -> bool:
	return get_tree().current_scene == self and not smoke and screenshot_path == "" and not run_metrics and demo.is_empty() and photo_walk.is_empty()

# ---- Photo album (scripts/album.gd) ----
# Develops the photo off screen (the same material the result screen uses) and saves it.
func save_to_album(texture: Texture2D, result: Dictionary) -> String:
	var size = Vector2i(1280,roundi(1280.0*texture.get_height()/maxf(1.0,texture.get_width())))
	var darkroom = SubViewport.new()
	darkroom.size = size
	darkroom.disable_3d = true
	darkroom.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(darkroom)
	var print_rect = TextureRect.new()
	print_rect.texture = texture
	print_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	print_rect.size = Vector2(size)
	print_rect.material = photo_material(result)
	darkroom.add_child(print_rect)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image = darkroom.get_texture().get_image()
	darkroom.queue_free()
	var e: Dictionary = result.evidence
	var where = Texts.get_text("album_nivel") % (arcade_level+1) if arcade_level >= 0 else (Texts.get_text("academia") if academy and academy.active else Texts.get_text("album_tutorial"))
	play_sfx("album",-6.0)
	return Album.add(image,{"score":result.score,"stars":result.stars,"f":e.f,"n":e.n,"t":e.t,"iso":e.iso,"date":Time.get_datetime_string_from_system(false,true).substr(0,16),"where":where,"panning":result.get("panning",false)})

var album_page = 0
var album_viewing = false
func show_album(page = 0) -> void:
	album_viewing = false
	mode = "ALBUM"
	var root = create_modal()
	var photos = Album.list()
	var per_page = 8
	var pages = maxi(1,ceili(photos.size()/float(per_page)))
	album_page = clampi(page,0,pages-1)
	label(root,Texts.get_text("album_titulo"),Rect2(65,26,600,55),38)
	label(root,Texts.get_text("album_subtitulo") % [Album.MIN_SCORE,photos.size(),Album.MAX],Rect2(65,82,1150,26),16,Color("b5c3ad"))
	if photos.is_empty(): label(root,Texts.get_text("album_vacio"),Rect2(65,300,1150,40),24,Color("b7c5ad"))
	for k in per_page:
		var index = album_page*per_page+k
		if index >= photos.size(): break
		var photo: Dictionary = photos[index]
		var cell = Rect2(65+(k%4)*290,124+(k/4)*250,276,236)
		var card = Button.new()
		card.position = cell.position
		card.size = cell.size
		card.focus_mode = Control.FOCUS_ALL
		if k == 0: card.call_deferred("grab_focus")
		card.pressed.connect(func(): show_album_photo(index))
		root.add_child(card)
		var image = Album.load_image(photo.file)
		if image != null:
			var thumb = TextureRect.new()
			thumb.position = Vector2(8,8)
			thumb.size = Vector2(260,170)
			thumb.texture = ImageTexture.create_from_image(image)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(thumb)
		label(card,album_caption(photo),Rect2(10,182,256,22),14)
		label(card,"%s · %s" % [photo.get("where",""),photo.get("date","")],Rect2(10,206,256,20),12,Color("a9b8a0"))
	if pages > 1:
		label(root,Texts.get_text("album_pagina") % [album_page+1,pages],Rect2(540,652,200,30),16,Color("b7c5ad"))
		if album_page > 0: button(root,"‹",Rect2(470,640,60,52),func(): show_album(album_page-1))
		if album_page < pages-1: button(root,"›",Rect2(750,640,60,52),func(): show_album(album_page+1))
	button(root,Texts.get_text("academia_volver_menu"),Rect2(65,640,260,52),intro)
	if not photos.is_empty() and not OS.has_feature("web"): button(root,Texts.get_text("album_abrir_carpeta"),Rect2(955,640,260,52),func(): OS.shell_open(ProjectSettings.globalize_path(Album.DIR)))

func album_caption(photo: Dictionary) -> String:
	var caption = "%d/100 · %.0f mm · ƒ/%s · 1/%d s" % [int(photo.get("score",0)),float(photo.get("f",50.0)),str(photo.get("n",8.0)),roundi(1.0/float(photo.get("t",.004)))]
	return caption+(" · "+Texts.get_text("album_barrido") if photo.get("panning",false) else "")

func show_album_photo(index: int) -> void:
	album_viewing = true
	var photos = Album.list()
	if index < 0 or index >= photos.size():
		show_album(album_page)
		return
	var photo: Dictionary = photos[index]
	var root = create_modal()
	var image = Album.load_image(photo.file)
	if image != null:
		var view = TextureRect.new()
		view.position = Vector2(65,24)
		view.size = Vector2(1150,590)
		view.texture = ImageTexture.create_from_image(image)
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(view)
	label(root,"%s · ISO %d · %s · %s" % [album_caption(photo),int(photo.get("iso",100)),photo.get("where",""),photo.get("date","")],Rect2(340,652,560,30),15,Color("b7c5ad"))
	button(root,Texts.get_text("album_volver"),Rect2(65,640,260,52),func(): show_album(album_page))
	button(root,Texts.get_text("album_borrar"),Rect2(955,640,260,52),func(): Album.remove(photo.file); show_album(album_page))

func announce_badge(id: String) -> void:
	notify_player(Texts.get_text("insignia_ganada") % Texts.get_text("insignia_%s_nombre" % id))
	toast_time = 9.0
	if not play_sfx("graduado" if id == "graduado" else "insignia",-4.0): play_tone(1568,.12)

# The badges screen (Options): what each one asks for and how far the player is.
func show_badges() -> void:
	mode = "BADGES"
	var root = create_modal()
	label(root,Texts.get_text("insignias_titulo"),Rect2(75,30,1100,52),36)
	label(root,Texts.get_text("insignias_subtitulo"),Rect2(75,86,1100,30),18,Color("b7c5ad"))
	var state = Badges.load_state()
	# Two columns of five.
	for k in Badges.BADGES.size():
		var id: String = Badges.BADGES[k]
		var x = 60+(k/5)*585
		var y = 132+(k%5)*96
		var done = Badges.earned(id,state)
		panel(root,Rect2(x,y,573,88),Color(.075,.115,.085,.95))
		label(root,Texts.get_text("insignia_conseguida") if done else Texts.get_text("insignia_pendiente"),Rect2(x+10,y+16,50,54),36,Color("f0c75e") if done else Color("5f6d59"))
		label(root,Texts.get_text("insignia_%s_nombre" % id),Rect2(x+64,y+6,380,30),21,Color("e6ebdb"))
		label(root,Texts.get_text("insignia_%s_texto" % id),Rect2(x+64,y+36,496,46),14,Color("a9b8a0")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label(root,Texts.get_text("insignia_hecha") if done else "%d / %d" % [mini(state[id],Badges.GOALS[id]),Badges.GOALS[id]],Rect2(x+440,y+8,120,26),15,Color("f0c75e") if done else Color("b7c5ad")).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button(root,Texts.get_text("academia_volver_menu"),Rect2(75,630,260,55),intro)

func notify_player(message: String) -> void:
	toast.text = message
	toast_time = 4.0

# Turning with the keys (degrees per second). The keys have one fixed speed, which made panning
# with them a matter of luck: so, while a key is held, the camera falls in with whoever is crossing
# the middle of the frame that way, like a photographer following a subject. Mouse and gamepad
# stick stay fully manual.
# ---- Following with the keys (docs/futuro/11 §1.4) ----
# Holding a turn key towards where someone is going, the camera does not turn at the key's own
# speed: it waits for that person to reach the active focus point (or catches up if they are
# already past it) and then turns at their pace, keeping them on the point. The finder says so:
# «Esperando al sujeto», then a blinking «Siguiendo al sujeto». The assignment's subject and
# whoever runs are waited for and chased while in the frame or about to enter it; a passer-by is
# only taken when already on the point (or every key press would be hijacked by someone).
var follow_state = ""            # "", "esperando", "siguiendo"
var follow_subject = null
var follow_wait = 0.0
var follow_given_up = false      # waited too long: the key turns freely until it is released
const FOLLOW_GAIN = 4.0          # per second: how hard it closes the gap to the point
const FOLLOW_PATIENCE = 4.0
func key_turn(axis: float, dt = 0.0) -> float:
	var speed = 42.0*24.0/view_focal()
	if axis == 0.0:
		follow_state = ""
		follow_subject = null
		follow_wait = 0.0
		follow_given_up = false
		return 0.0
	if legacy:
		var old = legacy_follow(axis,speed)
		return old if old != 0.0 else axis*speed
	var turn = follow_turn(axis,speed,dt)
	return turn if follow_state != "" else axis*speed

# (as it was: the pace of whoever walks the key's way near the middle of the frame, nothing else)
func legacy_follow(axis: float, speed: float) -> float:
	if not eye_ready() or crowd != null: return 0.0
	var best = 0.0
	var best_score = 0.0
	for p in people:
		if not p.visible or p.state != "CAMINANDO": continue
		var chest: Vector3 = p.control_points()[1]
		if camera.is_position_behind(chest): continue
		var on_screen = camera.unproject_position(chest)/Vector2(viewport.size)-Vector2(.5,.5)
		var offset = Vector2(on_screen.x,on_screen.y*float(viewport.size.y)/viewport.size.x).length()
		if offset >= .3: continue
		var turn = rad_to_deg(p.actual_velocity.dot(camera.global_basis.x)/maxf(.5,camera.global_position.distance_to(chest)))
		if signf(turn) != signf(axis) or absf(turn) < speed*.3 or absf(turn) > speed*2.5: continue
		var score = absf(turn)*(1.0-offset/.3)
		if score > best_score:
			best_score = score
			best = turn
	return best

func follow_turn(axis: float, speed: float, dt: float) -> float:
	follow_state = ""
	if not eye_ready() or follow_given_up or mode != "SEARCH" and mode != "TEST": return 0.0
	var mark: Vector2 = image_position(finder.points()[finder.active])/Vector2(viewport.size)
	var hfov = rad_to_deg(2.0*atan(36.0/(2.0*view_focal())))
	var best = null
	var best_score = 0.0
	var best_gap = 0.0
	var best_turn = 0.0
	for p in people:
		if not p.visible or p.state != "CAMINANDO": continue
		var chest: Vector3 = p.control_points()[1]
		if camera.is_position_behind(chest): continue
		var turn = rad_to_deg(p.actual_velocity.dot(camera.global_basis.x)/maxf(.5,camera.global_position.distance_to(chest)))
		if signf(turn) != signf(axis) or absf(turn) < 1.0: continue
		var at = camera.unproject_position(chest)/Vector2(viewport.size)
		var mine = p == target and not sandbox
		var fast = p.runner or p.actual_velocity.length() > 1.5
		# (on the point's row; the subject and the runners, anywhere up or down the frame but its edges)
		if absf(at.y-mark.y) > (.42 if mine or fast else .3): continue
		# Degrees from the point, along the way they go: + already past it, − still coming.
		var gap = (at.x-mark.x)*signf(axis)*hfov
		var reach = hfov*(.75 if mine or fast else .08)
		if gap < -reach or gap > hfov*(.45 if mine or fast else .08): continue
		# (the assignment's subject before anyone else: a passer-by crossing the point at that
		# moment must not take the camera away from the runner it is waiting for)
		var score = (100.0 if mine else 1.0)*(2.0 if fast else 1.0)*(1.5 if p == follow_subject else 1.0)/(1.0+absf(gap)/hfov*4.0)
		if score > best_score:
			best_score = score
			best = p
			best_gap = gap
			best_turn = turn
	follow_subject = best
	if best == null:
		follow_wait = 0.0
		return 0.0
	# Their pace plus what closes the gap: still while they are coming, faster than them when
	# they are ahead, exactly their pace once on the point.
	var want = clampf(absf(best_turn)+FOLLOW_GAIN*best_gap,0.0,absf(best_turn)*1.8+6.0)
	var locked = absf(best_gap) <= hfov*.04+.3
	follow_state = "siguiendo" if locked else "esperando"
	if locked: follow_wait = 0.0
	else:
		follow_wait += dt
		if follow_wait > FOLLOW_PATIENCE:
			follow_given_up = true
			follow_state = ""
			return 0.0
	return want*signf(axis)

# The mark on the finder (never in the photo): fixed while waiting, blinking while following.
var follow_label: Label
func update_follow_mark() -> void:
	if follow_label == null:
		follow_label = label(ui,"",Rect2(0,0,420,30),20,UiStyle.SKY)
		follow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		follow_label.add_theme_color_override("font_color",Color("9ad8ff"))
		follow_label.add_theme_color_override("font_outline_color",Color(0,0,0,.85))
		follow_label.add_theme_constant_override("outline_size",6)
		follow_label.z_index = 20
	var on = follow_state != "" and mode == "SEARCH"
	follow_label.visible = on
	if not on: return
	follow_label.text = Texts.get_text("seguimiento_"+follow_state)
	follow_label.position = Vector2(view_rect.position.x+view_rect.size.x*.5-210,view_rect.position.y+view_rect.size.y*.16)
	follow_label.modulate.a = 1.0 if follow_state == "esperando" or fmod(Time.get_ticks_msec()/1000.0,.5) < .3 else .15

var meter_bar: Control
func draw_meter_bar() -> void:
	if interface_mode != "camara": return   # the classic finder draws its own
	var font = UiStyle.font("Roboto-Regular")
	var centre = meter_bar.size.x*.5
	var step = 44.0
	for i in range(-8,9):
		var x = centre+i*step/4.0
		meter_bar.draw_line(Vector2(x,26),Vector2(x,26+(9 if i%4 == 0 else 4)),UiStyle.FAINT,1)
	for i in range(-2,3): meter_bar.draw_string(font,Vector2(centre+i*step-10,20),str(i) if i <= 0 else "+"+str(i),HORIZONTAL_ALIGNMENT_CENTER,20,13,UiStyle.SOFT)
	var needle = centre+clampf(finder.delta_ev,-2,2)*step
	var good = absf(finder.delta_ev) <= .5
	meter_bar.draw_colored_polygon(PackedVector2Array([Vector2(needle-6,48),Vector2(needle+6,48),Vector2(needle,37)]),Color("5fbf6a") if good else Color("e3ac6a"))

func track_camera_turn(dt: float) -> void:
	var step = wrapf(angle-omega_last_angle,-180.0,180.0)
	omega_last_angle = angle
	# A jump (a staged framing, a lesson, a test placing the camera) is not a turn of the wrist.
	if dt <= 0.0 or mode != "SEARCH" or absf(step) > 6.0:
		camera_omega = 0.0
		return
	camera_omega = lerpf(camera_omega,step/dt,clampf(dt*14.0,0.0,1.0))
	if absf(camera_omega) < .05: camera_omega = 0.0

# Android (docs/futuro/26 B7, E1): the system's «back» button or gesture does what Escape does
# (pause while playing, back on a screen) and leaves the game from the menu; going to the
# background (another app, a call, the screen off) pauses the game and silences it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED: to_background(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED: to_background(false)

var last_back = -1000
func go_back() -> void:
	# (Android sends the request more than once for one press: one is enough.)
	if Time.get_ticks_msec()-last_back < 350: return
	last_back = Time.get_ticks_msec()
	if mode == "INTRO":
		get_tree().quit()
		return
	for pressed in [true,false]:
		var esc = InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = pressed
		Input.parse_input_event(esc)

var in_background = false
func to_background(away: bool) -> void:
	if away == in_background: return
	in_background = away
	AudioServer.set_bus_mute(0,away)
	if away and mode == "SEARCH" and not shooting and not smoke: show_pause()

# A long press on the picture (docs/futuro/26 B4): focus there and lock focus and exposure, to
# reframe afterwards. A short touch only focuses; a second long press lets the lock go.
var touch_time = {}
var touch_held = false
const HOLD_SECONDS = .55
func check_long_press() -> void:
	if touch_held or touches.size() != 1 or had_multitouch or mode != "SEARCH" or not eye_ready(): return
	var id = touches.keys()[0]
	if total_time-touch_time.get(id,total_time) < HOLD_SECONDS or touches[id].distance_to(touch_start.get(id,touches[id])) >= 10: return
	touch_held = true
	if not (exposure_locked or focus_locked): nearest_af(touches[id])
	toggle_lock()
	rumble(.3,.6,.12)

# The game is going slowly (under SLOW_FPS over SLOW_SECONDS of play, in the real game and with a
# profile that can still go down): say so once, with the way out. Nobody looks for a graphics
# screen on their own when a laptop's fans start.
const SLOW_FPS = 42.0
const SLOW_SECONDS = 12.0
var slow_time = 0.0
var slow_frames = 0
var slow_told = false
func watch_speed(dt: float) -> void:
	if slow_told or not fps_limited or mode != "SEARCH" or not ParkScene.forward_plus() or graphics_preset == "Bajo": return
	slow_time += dt
	slow_frames += 1
	if slow_time < SLOW_SECONDS: return
	if slow_frames/slow_time < SLOW_FPS:
		slow_told = true
		notify_player(Texts.get_text("aviso_rendimiento"))
		toast_time = 9.0
	slow_time = 0.0
	slow_frames = 0

var band_key = ""
func _process(dt: float) -> void:
	if exposing: return     # the shutter is open: expose_photo() moves the world itself
	total_time += dt
	watch_speed(dt)
	if not debug_off.is_empty(): apply_debug_off()   # (the light of each hour sets the effects again)
	check_long_press()
	if frame_offset != Vector2.ZERO and not is_instance_valid(boot_loader) and band_key != mode+interface_mode:
		band_key = mode+interface_mode
		update_bands()
		place_view()
	poll_pad()
	if not shooting: track_camera_turn(dt)
	update_continuous_af(dt)
	update_fps_counter(dt)
	scroll_with_stick(dt)
	if toast == null: return   # the world is still being built behind the loading screen
	# (The start-up options below count frames from the menu: counted from before, with the world
	# still loading, --academy, --arcade and --screen opened their screen and the menu covered it.)
	if boot_done: boot_frames += 1
	if ambience: ambience.fountain_on = boot_done and boot_frames > 20
	if sound_board != "" and boot_done and sfx: update_sound_board(dt)
	# (--end-at counts by itself: the demo's clock stops on the result screen)
	if demo.has("end-at") and boot_done and arcade_level >= 0 and not demo.has("ended"):
		demo["end-clock"] = float(demo.get("end-clock",0.0))+dt
		if demo["end-clock"] >= demo["end-at"]:
			demo["ended"] = true
			end_level()
	if sfx and "--sonidos-seguidos" in OS.get_cmdline_user_args(): sfx.hurry = .2
	toast_time = maxf(0,toast_time-dt)
	toast.visible = toast_time > 0 and mode == "SEARCH"
	if mode == "INTRO" and is_instance_valid(modal) and modal.get_script() == preload("res://scripts/main_menu.gd"): update_menu_background(dt)
	# (The bars of the classic HUD used to show through the glass of the menu, like a ghost.)
	if mode == "INTRO" and not hud_top.is_empty() and hud_top[0].visible: update_hud_visibility(dt)
	update_portrait(dt)
	if crowd and mode != "INTRO": update_photographer(dt)
	elif mode != "INTRO": update_classic_raise(dt)
	# Arcade clock: it runs while searching; at zero the level ends with the best photo so far.
	if mode == "SEARCH" and arcade_level >= 0 and level_limit() > 0 and not level_over:
		var second_before = ceili(level_time)
		level_time = maxf(0.0,level_time-dt)
		if ceili(level_time) != second_before and level_time > 0.0 and level_time <= 10.0: play_sfx("tictac",-2.0)
		if level_time <= 0.0:
			level_over = true
			play_sfx("tiempo_agotado",-4.0)
			end_level()
	if mode == "SEARCH" and not shooting:
		# (While a demonstration of the Academy runs, the tutor drives: the held keys do nothing.)
		var hands_off = academy != null and academy.locks_input()
		if (eye_ready() or not crowd) and not hands_off:
			var axis = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			axis += float(demo_keys.get("turn",0.0))   # (tests and captures hold the key this way)
			angle = fposmod(angle+key_turn(axis,dt)*dt+pan_velocity*dt,360)
			pitch += (float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN)))*dt*30*24/view_focal()
			pan_velocity = move_toward(pan_velocity,0,dt*180)
			if eye_ready() and Input.is_physical_key_pressed(KEY_W): focal = clampf(focal+dt*30,equipment.lens().min,equipment.lens().max)
			if eye_ready() and Input.is_physical_key_pressed(KEY_S): focal = clampf(focal-dt*30,equipment.lens().min,equipment.lens().max)
		if run_metrics:
			angle = 120.0
			focal = 24.0
		if demo.is_empty():
			for key in shot_view: set(key,shot_view[key])
		else:
			update_demo(dt)
		update_pad(dt)
		update_camera()
		update_focus_aid(dt)
		if equipment.focus_mode == "MF" and not hands_off:
			var key_dir = float(Input.is_physical_key_pressed(KEY_T)) - float(Input.is_physical_key_pressed(KEY_R))
			if key_dir != 0.0:
				var rate = 0.22 if not Input.is_physical_key_pressed(KEY_SHIFT) else 0.07
				if Input.is_physical_key_pressed(KEY_CTRL): rate = 0.65
				adjust_focus_delta(-key_dir * rate * dt)
		park.update_weather(dt)
		if not (sandbox and sandbox_paused):
			for p in people: step_person(p,dt)
			pigeons.update(dt,people,([dog] if dog else [])+([player_proxy] if player_proxy else []))
			extras.update(dt)
			if ducks: ducks.update(dt)
			if dog: dog.update(dt)
		ambience.update(dt)
		if sfx:
			sfx.update_world(dt)
			zoom_sound(dt)
		if academy: academy.update(dt)
		if tutorial and tutorial.active: tutorial.update(dt)
		update_follow_mark()
		update_hud_visibility(dt)
		update_hunt_hint(dt)
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
			pigeons.update(1.0/30,people,([dog] if dog else [])+([player_proxy] if player_proxy else []))
			if dog: dog.update(1.0/30)
			if extras: extras.update(1.0/30)
			if ducks: ducks.update(1.0/30)
	if boot_frames == 12 and academy_play != "": play_academy()
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
	if boot_frames == 12 and "--arcade" in OS.get_cmdline_user_args(): show_arcade()
	if boot_frames == 12 and start_screen != "":
		match start_screen:
			"insignias": show_badges()
			"ayuda": show_help()
			"album": show_album()
			"opciones":
				if is_instance_valid(modal) and modal.has_method("change_mode"): modal.change_mode(modal.MODES.find("opciones")-modal.current)
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
			pigeons.update(1.0/30,people,([dog] if dog else [])+([player_proxy] if player_proxy else []))
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
	# A new round over the people (several per frame when time is fast-forwarded): everybody()
	# takes everyone's place again.
	if p == people[0]: everybody_frame = -1
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
			p.visible = not p.has_meta("away")   # (a quieter level keeps its absentees away)
	elif p.state == "CAMINANDO":
		if p.destination_lane >= 0:
			var target_r = home_radius(p.destination_lane,p.direction,p.runner)
			p.r_goal = target_r
			p.pass_r = NAN
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
				elif not p.runner: try_change_lane(p)
		if stress:
			if p.theta < 96 or p.theta > 144:
				p.theta = clampf(p.theta,96,144)
				p.direction *= -1
		var interest = int(p.theta/30)
		if interest != p.poi and p.theta < 240:
			p.poi = interest
			if p.runner and p.pending_stop.is_empty() and p.rng.randf() < .015:
				# Runners stop now and then to stretch by the path (once every few minutes: at 5 %
				# per sector they spent a sixth of their time standing).
				if not runner_on_duty(p): p.pending_stop = {"activity":"estirar","time":p.rng.randf_range(6,10),"face":face_view(p)}
			elif not p.runner and not p.has_meta("staged") and p.bench_goal < 0 and p.pending_stop.is_empty() and is_nan(p.pass_r) and p.rng.randf() < .12:
				var poi_blocked = false
				for other in people:
					if other != p and other.lane == p.lane and (other.state == "DETENIDO" or other.state == "SENTADO") and absf(other.theta - p.theta) < 12.0:
						poi_blocked = true
						break
				if not poi_blocked: plan_stop(p)
		if not p.runner and p.lane == 1 and p.destination_lane < 0 and not p.protected_target and not p.has_meta("staged") and p.bench_goal < 0 and p.pending_stop.is_empty():
			choose_bench(p)
		if p.bench_goal >= 0: approach_bench(p)
		elif not p.pending_stop.is_empty() and p.v_fwd < .04 and (is_nan(p.r_goal) or absf(p.radius-p.r_goal) < .05 or p.stuck_time > 1.0):
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
	pose_person(p,dt,p.position.distance_to(previous_position))

# On a phone or in a browser the processor is what holds the game back, and posing the 21
# skeletons is a quarter of every frame (docs/futuro/26 C3). There, whoever is out of the picture
# is posed one frame in POSE_EVERY — with all the time and distance gone by since, so the gait
# keeps its step — and everyone in the picture, every frame. Where each one walks, the photo and
# its mark do not change: only how often a body nobody sees is bent.
const POSE_EVERY = 2      # (of its steps: out of the picture those are already one frame in two)
const POSE_FAR = 22.0      # metres with the naked eye (30 mm); further with a longer lens
var lean_poses = false
var pose_debt = {}
func person_seen(p: Pedestrian) -> bool:
	var to: Vector3 = p.global_position+Vector3.UP*p.height*.5-camera.global_position
	# (Half the diagonal of the picture — 36 × 20 mm — plus a margin as wide as a body up close.)
	var half = atan(20.7/maxf(view_focal(),12.0))+deg_to_rad(12.0)
	return to.length() < 4.0 or (-camera.global_basis.z).angle_to(to) < half

# The same saving for the steps (docs/futuro/26 C3): out of the picture a pedestrian walks one
# frame in two, with the time of both — what the whole game does anyway on a slower machine.
var step_debt = {}
func step_person(p: Pedestrian, dt: float) -> void:
	if not lean_poses or shooting:
		update_person(p,dt)
		return
	var debt: float = step_debt.get(p,0.0)+dt
	if (Engine.get_process_frames()+p.get_index())%2 == 0 and debt < .08 and not person_seen(p):
		step_debt[p] = debt
		return
	step_debt[p] = 0.0
	update_person(p,debt)

func pose_person(p: Pedestrian, dt: float, distance: float) -> void:
	if not lean_poses or shooting:
		p.animate(dt,distance)
		return
	var debt: Array = pose_debt.get(p,[0.0,0.0,p.get_index()%POSE_EVERY])
	debt[0] += dt
	debt[1] += distance
	debt[2] += 1
	var to: Vector3 = p.global_position+Vector3.UP*p.height*.5-camera.global_position
	var seen = person_seen(p)
	# In the picture but far away (a figure a few pixels tall): every other frame is enough.
	if seen and to.length() > POSE_FAR*view_focal()/30.0 and debt[2] < 2: seen = false
	if seen or debt[2] >= POSE_EVERY:
		p.animate(debt[0],debt[1])
		pose_debt[p] = [0.0,0.0,0]
	else: pose_debt[p] = debt

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
# Where a level wants its subject, as an angle of the classic park: a landmark, or the sun.
func toward_theta(what: String) -> float:
	var at: Vector3 = park.sun.global_basis.z if what == "sol" else park.places.get(what,Vector3.FORWARD)
	return fposmod(rad_to_deg(atan2(at.x,-at.z)),360.0)

# The subject of an «actividad» level walks to a free bench, sits and stays at it for the level.
const TARGET_ACTIVITIES = ["leer","movil","cafe","palomas"]
func seat_target() -> void:
	var bench_i = -1
	for i in park.benches.size():
		if park.benches[i].seats[0] == null and park.benches[i].seats[1] == null and not people.any(func(q): return q.bench_goal == i): bench_i = i
	if bench_i < 0:
		# No bench free: it stops where it is, with something in the hands.
		target.pending_stop = {"activity":["movil","cafe"][casting.rng.randi()%2],"time":600.0}
		return
	var bench = park.benches[bench_i]
	clear_sector([1],[target],30.0)
	reset_walker(target,1,seat_theta(bench,0)-12.0,1.0)
	set_seat(bench,0,target)
	target.bench_slot = 0
	target.bench_goal = bench_i
	target.set_meta("seat_activity",TARGET_ACTIVITIES[casting.rng.randi()%TARGET_ACTIVITIES.size()])

func activity_on_duty(p) -> bool:
	return p.protected_target and arcade_level >= 0 and not sandbox and Arcade.LEVELS[arcade_level].get("target","") == "activity"

func runner_on_duty(p) -> bool:
	return p.protected_target and p.runner and arcade_level >= 0 and Arcade.LEVELS[arcade_level].get("target","") == "runner"

func plan_stop(p: Pedestrian) -> void:
	# The runner of a level about freezing or panning keeps running: no stretching meanwhile.
	if runner_on_duty(p): return
	var time = p.rng.randf_range(6,16)
	for q in people:
		if q == p or q.runner or q.protected_target or q.has_meta("staged") or q.lane != p.lane or q.direction == p.direction: continue
		if q.state != "CAMINANDO" or q.destination_lane >= 0 or q.bench_goal >= 0 or not q.pending_stop.is_empty() or not is_nan(q.pass_r): continue
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
	if p.never_sits: return   # (a backpack against the backrest, the tails of a trench coat)
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
			# The place reached first. The far one only if whoever has the near one is already
			# sitting: two people walking to the same bench from opposite ends would have to cross
			# each other right in front of it, and stood there face to face instead.
			var near = 1 if ahead_of(p,seat_theta(bench,1)) < ahead_of(p,seat_theta(bench,0)) else 0
			var slot = near
			if bench.seats[near] != null:
				if bench.seats[near].state != "SENTADO": return
				slot = 1-near
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
	q.radius = home_radius(lane,direction,q.runner)
	q.pass_r = NAN
	q.r_goal = NAN
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
			if activity_on_duty(p) and p.activity != "": p.state_time = maxf(p.state_time,10.0)
			if p.state_time <= 0: resume_walk(p)
		"SENTADO":
			if activity_on_duty(p): p.state_time = maxf(p.state_time,10.0)   # (the level's subject stays at it)
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

# ---- Three lines per path (docs/NAVEGACION_Y_COLISIONES.md §3) ----
# A path is just wide enough for three people abreast. Walkers keep to the edge on their right
# (one file each way) and the middle stays free: it is where anyone passes someone standing or
# slower, and where the runners run. Nobody steps into a line unless it will stay free for as long
# as the manoeuvre takes (free_time() against pass_need()), so a walker never pulls out in front of
# a runner and two people never meet head-on in the middle. Before this, the two files took the
# two places the path had and overtaking meant using the oncoming file, which was hardly ever
# free: runners spent most of their time held up behind somebody.
const PASS_SPACE = .62          # centre-to-centre distance between neighbouring lines
const ALONGSIDE = .8            # along the path, closer than this two people are side by side
const HOME_CLEAR = 4.0          # seconds of free way ahead that make one's own line good enough
# Innermost and outermost line of each path (radius of the body's centre), checked against the
# fixed things beside it with a swept body (tools/measure_flow.gd -- --edges):
#   0  the outer line stops short of the four lamps that stand at 2.6 m (two files, no middle);
#   1  the inner file walks close to the inner kerb, because whoever sits on a bench takes some of
#      the outer side (their feet reach r ≈ 4.5 m): three lines still fit beside a bench;
#   3  a little inwards, clear of the shrubs behind the outer kerb.
const LANE_LINES = [Vector2(1.33,2.12), Vector2(3.07,4.57), Vector2(6.38,7.62), Vector2(10.80,12.04)]
const BENCH_CLEAR = .55         # outer line this far inside the bench's own radius, next to it
var jam_turns = 0               # how many jams ended with someone turning back (tools/measure_flow.gd)

# Usable band of a path (inner, outer).
func lane_edges(lane: int) -> Vector2:
	return LANE_LINES[lane]

# The line a person keeps when nothing is in the way: runners the middle, walkers their right edge.
func home_radius(lane: int, direction: float, runner: bool) -> float:
	var edges = lane_edges(lane)
	if runner: return (edges.x+edges.y)*.5
	return edges.y if direction > 0 else edges.x

# Everybody who matters to p's lateral choice: {a: metres ahead (negative behind), r: radius,
# g: radius they are heading for, v: speed along p's direction, still, runner}.
func people_around(p: Pedestrian, lo: float, hi: float) -> Array:
	var around = []
	for other in people:
		if other == p or not other.visible: continue
		if other.radius < lo-PASS_SPACE or other.radius > hi+PASS_SPACE+.45: continue
		# Walking up to a bench: whoever already sits on it is not in the way.
		if p.bench_goal >= 0 and other.bench_index == p.bench_goal and other.state == "SENTADO": continue
		var a = deg_to_rad(fposmod((other.theta-p.theta)*p.direction+180.0,360.0)-180.0)*p.radius
		var still = other.state != "CAMINANDO"
		var v = 0.0 if still else other.v_fwd*(1.0 if other.direction == p.direction else -1.0)
		var goal = other.radius if still or is_nan(other.r_goal) else other.r_goal
		around.append({"a":a,"r":other.radius,"g":goal,"v":v,"still":still,"runner":other.runner,"facing":not still and other.direction != p.direction})
	return around

# Seconds until line c stops being free for p (INF if nothing is coming, 0 if it is taken right
# now). Someone in the line ahead counts by how fast p closes on them; someone beside it, at once;
# someone coming up from behind only if p would be moving into their line (or they are a runner:
# runners have the right of way). Stepping across also needs nobody beside p on the way there.
func free_time(p: Pedestrian, c: float, around: Array, v_plan: float) -> float:
	var best = INF
	var moving = absf(c-p.radius) > .15
	var lateral_speed = LATERAL_MAX*(1.9 if p.runner else 1.0)
	var crossing = absf(c-p.radius)/lateral_speed+.3
	for o in around:
		var closing: float = v_plan-o.v
		if minf(absf(o.r-c),absf(o.g-c)) < PASS_SPACE-.03:
			if o.a > ALONGSIDE:
				if closing > .02: best = minf(best,(o.a-ALONGSIDE)/closing)
			elif o.a > -ALONGSIDE:
				best = 0.0
			elif -closing > .02 and (moving or o.runner):
				best = minf(best,(-o.a-ALONGSIDE)/-closing)
		elif moving and signf(o.r-p.radius) == signf(c-p.radius) and absf(o.r-p.radius) >= HARD_SPACE+.025 and absf(o.r-p.radius) < absf(c-p.radius)+PASS_SPACE-.03:
			# Only in the way of the sidestep: beside p now, or while it crosses. (Whoever is in p's
			# own line is not: p is following them, see the speed rule in walk_step().)
			var later: float = o.a-closing*crossing
			if absf(o.a) < ALONGSIDE or absf(later) < ALONGSIDE or (o.a > 0.0) != (later > 0.0): best = 0.0
	return best

# Seconds p needs out of its own line to get past whoever blocks it there (INF if it cannot: the
# other walks as fast).
func pass_need(home: float, around: Array, v_plan: float) -> float:
	var need = 0.0
	for o in around:
		if absf(o.r-home) >= PASS_SPACE-.03 or o.a < -ALONGSIDE or o.a > 12.0: continue
		var closing: float = v_plan-o.v
		if closing <= .05:
			if o.a < 3.0: return INF
			continue
		if (o.a-ALONGSIDE)/closing > HOME_CLEAR: continue
		need = maxf(need,(o.a+ALONGSIDE+.4)/closing)
	return need

func walk_step(p: Pedestrian, dt: float) -> void:
	var bounds: Vector2 = LANE_BOUNDS[p.lane]
	var lo: float = LANE_LINES[p.lane].x
	var hi: float = LANE_LINES[p.lane].y
	if p.v_fwd < 0: p.v_fwd = p.speed
	var v_own = p.speed*(1.0 if p.runner else walk_pace)*(.8 if p.activity == "movil" else 1.0)
	var v_des = v_own
	if not p.pending_stop.is_empty(): v_des = 0.0
	# Keep the swept body clear of bench legs; the last metre to a chosen bench ignores them.
	var static_check = true
	for bench in park.benches:
		if p.lane == 1 and absf(ahead_of(p,bench.theta)) < 1.5: hi = minf(hi,bench.get("radius",4.85)-BENCH_CLEAR)
	var mid = (lo+hi)*.5
	# Own line: runners the middle (the outer edge while they slow down to stretch), walkers the
	# edge on their right.
	var home = hi if p.direction > 0 else lo
	if p.runner and p.pending_stop.is_empty(): home = mid
	elif p.runner: home = hi
	home = clampf(home+p.pref_offset,lo,hi)
	var around = people_around(p,lo,hi)
	var target = home
	# Off the path (a crossing between paths given up half way, standing up from a bench): walk
	# back onto it across whatever is there, at walking pace. Clamping the radius to the path made
	# a half-metre jump that never passed the collision sweep, and the person stayed out there.
	var off_path = p.radius < bounds.x-.02 or p.radius > hi+.02
	if p.bench_goal >= 0:
		var bench = park.benches[p.bench_goal]
		var to_go = ahead_of(p,seat_theta(bench,p.bench_slot))
		# Along the path (clear of anyone already sitting, whose feet reach r ≈ 4.5 m) until
		# the own place, then the last half metre sideways to the front of the bench.
		if to_go < .6:
			hi = bench_front(bench,p)
			static_check = false
			target = clampf(bench_front(bench,p),lo,hi)
		else:
			target = clampf(4.2,lo,hi)
		v_des = minf(v_des,maxf(.07,(to_go-.05)*.9))
		p.pass_r = NAN
	else:
		if off_path: static_check = false
		var v_plan = maxf(v_own,.3)
		var home_free = free_time(p,home,around,v_plan)
		if home_free >= HOME_CLEAR or not p.pending_stop.is_empty():
			# Own line free (or stopping: no passing while slowing down to stop).
			p.pass_r = NAN
		elif not is_nan(p.pass_r) and free_time(p,p.pass_r,around,v_plan) > 1.0:
			# Committed to a pass: keep the line until past (no flip-flopping).
			target = clampf(p.pass_r,lo,hi)
		else:
			p.pass_r = NAN
			var need = pass_need(home,around,v_plan)
			var best_cost = INF
			# The lines of the path first, then just clear of whoever is nearest.
			var options = [mid,lo,hi]
			for o in around:
				if o.a > -ALONGSIDE and o.a < 6.0:
					options.append(o.r+PASS_SPACE)
					options.append(o.r-PASS_SPACE)
			# Walkers leave a wide margin (a runner brakes long before reaching whoever is in its
			# line) and only use the line next to their own: crossing the middle to walk down the
			# oncoming file is the runners' business.
			var margin = .5 if p.runner else 2.5
			for c in options:
				if c < lo-.001 or c > hi+.001 or absf(c-home) < .2: continue
				if not p.runner and absf(c-home) > PASS_SPACE+.12: continue
				if free_time(p,c,around,v_plan) <= need+margin: continue
				# Nearest to the own side wins: the oncoming file is the last resort.
				var cost = absf(c-home)+.3*absf(c-p.radius)
				if cost < best_cost:
					best_cost = cost
					p.pass_r = c
			if not is_nan(p.pass_r): target = p.pass_r
			elif home_free <= 0.0 and absf(p.radius-home) > .2:
				# Out of the own line with someone beside it: hold this line until they are past.
				target = p.radius
	target = clampf(target,lo,hi)
	p.r_goal = target
	p.pass_side = signf(target-home) if absf(target-home) > .05 else 0.0
	# Speed: never run into whoever is in the way right now. Behind someone going the same way (or
	# standing), follow at a distance; facing someone, brake until one of the two has moved over.
	var nearest_r = NAN
	var nearest_ahead = INF
	for o in around:
		if o.a <= .3 or absf(o.r-p.radius) >= HARD_SPACE+.025: continue
		if o.a < nearest_ahead:
			nearest_ahead = o.a
			nearest_r = o.r
		if not o.facing: v_des = minf(v_des,maxf(0.0,o.v)+maxf(0.0,o.a-FOLLOW_GAP)*.8)
		else:
			# Coming the other way (even if it has stopped to wait, as p may have): brake short of
			# them. Face to face and both waiting is a jam in the making, not a queue: it counts as
			# being stuck, so one of the two gives way.
			v_des = minf(v_des,maxf(0.0,o.a-1.1)*.9)
			if o.a < 1.4 and p.v_fwd < .05: p.stuck_time += dt*1.5
	# Forward speed with limited acceleration.
	var accel = (WALK_ACCEL*(2.5 if p.runner else 1.0)) if v_des > p.v_fwd else WALK_BRAKE*(1.6 if p.runner else 1.0)
	p.v_fwd = move_toward(p.v_fwd,v_des,accel*dt)
	# Radial speed: damped approach to the lateral target, capped.
	var lat_max = LATERAL_MAX*(1.9 if p.runner else 1.0)
	# (With a floor: the last centimetres to the line are not an endless crawl, which left people
	# a hand's breadth inside the next line, in the way.)
	var off = target-p.radius
	var v_rad_des = 0.0 if absf(off) < .004 else signf(off)*minf(lat_max,maxf(.1,absf(off)*(2.2 if p.runner else 1.4)))
	p.v_rad = move_toward(p.v_rad,v_rad_des,(2.6 if p.runner else 1.2)*dt)
	var new_theta = fposmod(p.theta+rad_to_deg(p.v_fwd*dt/maxf(p.radius,.5))*p.direction,360.0)
	var new_radius = p.radius+p.v_rad*dt
	if p.radius >= bounds.x and p.radius <= bounds.y: new_radius = clampf(new_radius,bounds.x,bounds.y)
	if travel_clear(p,p.position,park.polar(new_theta,new_radius),static_check):
		p.theta = new_theta
		p.radius = new_radius
		p.stuck_time = maxf(0.0,p.stuck_time-dt*2.0)
	elif travel_clear(p,p.position,park.polar(p.theta,new_radius),static_check):
		# Blocked ahead: keep drifting sideways, slow down smoothly.
		p.radius = new_radius
		p.v_fwd = move_toward(p.v_fwd,0.0,WALK_BRAKE*2.0*dt)
		p.stuck_time += dt*.5
	elif travel_clear(p,p.position,park.polar(new_theta,p.radius),static_check):
		# Blocked sideways only: walk on in this line.
		p.theta = new_theta
		p.v_rad = 0.0
		p.stuck_time = maxf(0.0,p.stuck_time-dt)
	else:
		p.v_fwd = move_toward(p.v_fwd,0.0,WALK_BRAKE*3.0*dt)
		p.v_rad = 0.0
		p.stuck_time += dt
	# Waiting behind someone is not being stuck; being stopped by nothing for long is. The plan
	# above should never get here: this is the safety net.
	if p.stuck_time > 2.0:
		# Step away from whoever is closest in front, towards the side with room (held for a while:
		# never flip-flopping frame by frame).
		p.pass_timer = maxf(0.0,p.pass_timer-dt)
		if p.pass_timer <= 0.0:
			var away = 1.0 if is_nan(nearest_r) or p.radius >= nearest_r else -1.0
			if (away > 0 and p.radius > hi-.05) or (away < 0 and p.radius < lo+.05): away = -away
			p.pass_r = clampf((nearest_r if not is_nan(nearest_r) else p.radius)+away*PASS_SPACE,lo,hi)
			p.pass_timer = 2.0
		if not p.runner and p.stuck_time > 3.0 and not try_change_lane(p) and p.stuck_time > 5.0:
			# Give way: turn back (the heading turns smoothly, see turn_heading()).
			p.direction *= -1
			p.v_fwd = 0.0
			p.stuck_time = 0.0
			p.pass_r = NAN
			jam_turns += 1

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
# Focal length the view turns with: the lens at the eye, a natural ~30 mm with the camera lowered.
func view_focal() -> float:
	return focal if eye_ready() else 30.0

func eye_ready() -> bool:
	return camera_raised and raise_anim >= 1.0

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
	if not play_sfx("camara_subir" if camera_raised else "camara_bajar",2.0): play_tone(420 if camera_raised else 300,.03)

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
		input += touch_move
		var look = Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
		# Walking with the gamepad: once a second, the sticks and the view, in user://dispositivo.log
		# (to see on the player's machine whether the left stick turns the view).
		if pad.length() > .2 and Engine.get_process_frames()%60 == 0:
			log_line("paseo · seta izq (%.2f, %.2f) · der (%.2f, %.2f) · vista %.1f° / %.1f°" % [pad.x,pad.y,look.x,look.y,angle,pitch])
		if look.length() > .2:
			angle = fposmod(angle+look.x*dt*110*look_sign().x,360)
			pitch = clampf(pitch-look.y*dt*80*look_sign().y,-70,70)
		var yaw = deg_to_rad(angle)
		var forward = Vector3(sin(yaw),0,-cos(yaw))
		var right = Vector3(cos(yaw),0,sin(yaw))
		var wish = forward*(-input.y)+right*input.x
		# Gamepad: L3 toggles running (off again when the stick is let go), LT held crouches.
		if pad.length() <= .2: pad_run = false
		var crouching = Input.is_physical_key_pressed(KEY_CTRL) or Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT) > .5 or touch_crouch
		var running = Input.is_physical_key_pressed(KEY_SHIFT) or pad_run or touch_move.length() > .92 or (touch_run and touch_move.length() > .2)
		var speed = (RUN_SPEED if running else WALK_SPEED)*(.55 if crouching else 1.0)
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
		# (Also the children of the playground, the swing with its child and the dogs, which have
		# no colliders of their own: nothing in the park can be walked through.)
		var bodies: Array = people.duplicate()
		if extras: bodies += extras.extras+extras.dogs
		if dog: bodies.append(dog)
		for q in bodies:
			if not q.visible or not q.is_inside_tree(): continue
			var at: Vector3 = q.global_position
			if at.y > 1.2: continue     # up on the slide's platform
			var away = Vector3(player.position.x-at.x,0,player.position.z-at.z)
			if away.length() < .55 and away.length() > .0001: player.position = Vector3(at.x,0,at.z)+away.normalized()*.55
		var moved = player.position.distance_to(start)
		moving = moved > .0005
		walk_phase += moved*TAU/1.5
		eye_height = move_toward(eye_height,1.05 if crouching else (1.1 if equipment.tlr() and camera_raised else 1.6),dt*2.5)
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
		walk_hint.visible = walking_view and not OS.has_feature("movie") and not Glyphs.touch
		walk_label.text = briefing.text if not sandbox else Texts.get_text("paseo_sandbox")
	var want = Input.MOUSE_MODE_CAPTURED if walking_view and not camera_raised and get_window().has_focus() and not Glyphs.touch else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want and not smoke and screenshot_path == "": Input.mouse_mode = want

# Classic park (docs/futuro/21 §8): the camera can be lowered too (Y or the on-screen button) to
# search with the naked eye, a wide natural view, and brought back to the eye to shoot. The
# direction of the view is kept, so what you found is what you frame.
func update_classic_raise(dt: float) -> void:
	raise_anim = move_toward(raise_anim,1.0 if camera_raised else 0.0,dt/.35)
	var ready = eye_ready()
	if ready != was_eye_ready:
		was_eye_ready = ready
		place_view()
		update_dof_pass()
		update_camera()
		if is_instance_valid(raise_flash): raise_flash.color.a = .85
	if is_instance_valid(raise_flash): raise_flash.color.a = move_toward(raise_flash.color.a,0.0,dt*5.0)
	var naked = mode == "SEARCH" and not ready
	if is_instance_valid(walk_label):
		walk_label.visible = naked
		walk_hint.visible = naked and not OS.has_feature("movie") and not Glyphs.touch
		walk_label.text = briefing.text
		walk_hint.set_rich(Texts.get_rich("buscar_ayuda"))

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
	# With the fingers: the stick and the look are touch_controls.gd's; the mouse a touch emulates
	# (or the real one playing the finger) does nothing here.
	if Glyphs.touch and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag): return not camera_raised
	var toggle = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("camara_al_ojo") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Y)
	if toggle:
		toggle_raise()
		return true
	if camera_raised: return false
	# While walking only looking around, help and Escape reach the rest of the game.
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			angle = fposmod(angle+event.relative.x*.11*look_sign().x,360)
			pitch = clampf(pitch-event.relative.y*.11*look_sign().y,-70,70)
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
		var walking = not eye_ready() or mode == "INTRO"
		view_rect = camera_body.view_rect_for(equipment.body,"walk" if walking else interface_mode)
		camera_body.body = equipment.body
		camera_body.mode = "walk" if walking else interface_mode
		# With the naked eye there is no camera around the picture: on a screen wider than 16:9
		# the park fills it all (docs/futuro/26 A1). The photo is always the camera's 16:9.
		var wide = walking and mode == "SEARCH" and frame_offset != Vector2.ZERO
		if wide: view_rect = full_rect()
		var wanted = Vector2i((view_rect.size if wide else Vector2(1280,720))*render_factor)
		if viewport.size != wanted:
			viewport.size = wanted
			viewport_container.size = Vector2(wanted)
	viewport_container.position = view_rect.position+frame_offset
	viewport_container.scale = view_rect.size/Vector2(viewport.size)
	# On a screen: the park behind the glass covers the whole window, bands included.
	if frame_offset != Vector2.ZERO and mode != "SEARCH":
		var full = full_rect()
		var cover = maxf(full.size.x/viewport.size.x,full.size.y/viewport.size.y)
		viewport_container.scale = Vector2(cover,cover)
		viewport_container.position = frame_offset+full.get_center()-Vector2(viewport.size)*cover*.5
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
# ---- The virtual shutter (docs/SIMULACION_FOTOGRAFICA.md §9) ----
# The photo is not one frame worked over afterwards: while the shutter is open the game renders
# many frames and averages them in linear light, as a sensor does.
#   · between frames the world moves on by a slice of the exposure time and the camera goes on
#     turning if it was panning: the pan, the trail, the arms and legs that move more than the
#     body, all come out by themselves;
#   · the hand's tremble is a real wander of the camera during the exposure;
#   · each frame is taken from another point of the lens's aperture with the plane of focus held
#     still: depth of field with real edges, the same in Forward+ and in OpenGL;
#   · each frame is shifted a fraction of a pixel: the photo is antialiased;
#   · the exposure is set in the renderer's own tone curve for those frames, not multiplied
#     afterwards on 8 bits: what burns, burns where the light really is.
# Nothing here touches the score, which is decided before (capture_evidence()).
var exposing = false
# Evidence only (tools/capture_before_after.sh): the photo and the key turn as they were before
# 07-10-2026 (one frame worked over afterwards, no glass, the old grain; the key only matching
# the pace of whoever was already near the middle, with no mark).
static var legacy = OS.has_environment("PAPARAZZI_LEGACY")
static var photo_samples_override = -1      # tests: a fixed number of frames (1 = the plain frame)
var acc_view: SubViewport
var acc_rect: TextureRect
var res_view: SubViewport
var res_rect: TextureRect
var curtain: ColorRect

# Most frames a photo may take here: fewer where every frame waits for the screen.
func photo_samples_cap() -> int:
	if legacy: return 1
	if photo_samples_override >= 0: return photo_samples_override
	if OS.has_environment("PAPARAZZI_PHOTO_SAMPLES"): return int(OS.get_environment("PAPARAZZI_PHOTO_SAMPLES"))   # (evidence tools)
	# Tests and tools run the game from their own script: one frame, as fast as before.
	if "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args() or smoke or run_metrics: return 1
	if OS.has_feature("movie"): return 24      # (a recording shows every frame of the exposure as black)
	if OS.has_feature("web"): return 16
	if OS.has_feature("mobile"): return 24
	if not ParkScene.forward_plus(): return 32
	return {"Bajo":24,"Medio":32,"Alto":48,"Ultra":64}.get(graphics_preset,48)

# Frames this photo needs: as many as its longest blur asks for, eight at least (for the edges).
func photo_samples(e: Dictionary, result: Dictionary) -> int:
	var most = photo_samples_cap()
	if most <= 1: return 1
	var width = float(viewport.size.x)
	var streak = maxf(float(result.get("drag",0.0)),float(result.get("background",0.0)))/36.0*width
	var others = 3.0*e.t*e.f/3.0/36.0*width            # someone running three metres away
	var shake = shake_pixels(e,result)
	var far = Photo.coc(e.f,e.n,60.0,e.s)/36.0*width*.5
	var near = Photo.coc(e.f,e.n,1.5,e.s)/36.0*width*.5
	var blur = maxf(far,near)
	return clampi(ceili(maxf(maxf(streak,maxf(others,shake))*.6,blur*blur*.2)),mini(8,most),most)

# How far the hand's tremble carries the image during the exposure, in pixels (none in a pan or a
# trail, where the slow shutter is deliberate and braced: Photography.evaluate() says the same).
func shake_pixels(e: Dictionary, result: Dictionary) -> float:
	var drag = float(result.get("drag",0.0))
	var streak = float(result.get("background",0.0))
	var panning = streak >= Photo.PAN_STREAK and drag <= Photo.PAN_TOLERANCE and e.v >= Photo.PAN_SUBJECT_SPEED
	var trail = e.get("trail",false) and e.v >= Photo.PAN_SUBJECT_SPEED and drag >= Photo.TRAIL and streak <= Photo.C
	if panning or trail: return 0.0
	return minf(maxf(0.0,float(result.get("ratio",e.t*e.f))-1.0)*5.0,45.0)*viewport.size.x/1280.0

func build_darkroom() -> void:
	if is_instance_valid(acc_view): return
	acc_view = SubViewport.new()
	acc_view.disable_3d = true
	acc_view.use_hdr_2d = true
	acc_view.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	acc_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(acc_view)
	acc_rect = TextureRect.new()
	acc_rect.texture = viewport.get_texture()
	acc_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	acc_rect.material = ShaderMaterial.new()
	acc_rect.material.shader = preload("res://shaders/photo_accumulate.gdshader")
	acc_view.add_child(acc_rect)
	res_view = SubViewport.new()
	res_view.disable_3d = true
	res_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(res_view)
	res_rect = TextureRect.new()
	res_rect.texture = acc_view.get_texture()
	res_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	res_rect.material = ShaderMaterial.new()
	res_rect.material.shader = preload("res://shaders/photo_resolve.gdshader")
	res_view.add_child(res_rect)
	# The finder goes dark while the shutter is open (the frames in between are not to be seen).
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.visible = false
	curtain.z_index = 30
	ui.add_child(curtain)

# The world, a slice of the exposure on (what _process() does for it while searching).
func advance_world(dt: float) -> void:
	if (sandbox and sandbox_paused) or (academy and academy.active and academy.paused): return
	for p in people: step_person(p,dt)
	if pigeons: pigeons.update(dt,people,([dog] if dog else [])+([player_proxy] if player_proxy else []))
	if extras: extras.update(dt)
	if ducks: ducks.update(dt)
	if dog: dog.update(dt)

# What the glass will make of the lights in front of it (only for the developed image, never for
# the score): where the sun is and whether it reaches the lens, and the lamps that are lit.
func lens_evidence(e: Dictionary) -> void:
	var size = Vector2(viewport.size)
	var wide = size.x/size.y
	var to_frame = func(world: Vector3) -> Vector2:
		var at = camera.unproject_position(world)/size
		# (the TLR's negative is the central square of the frame)
		if equipment.tlr(): at.x = .5+(at.x-.5)*wide
		return at
	e["tod"] = str(time_of_day)
	e["aspect"] = 1.0 if equipment.tlr() else wide
	var eye: Vector3 = camera.global_position
	if str(time_of_day) in ["day","golden"]:
		var toward: Vector3 = park.sun.global_basis.z
		var far = eye+toward*500.0
		if not camera.is_position_behind(far): e["sun"] = {"pos":to_frame.call(far),"seen":park.light_visible(eye,eye+toward*80.0,null)}
	var lit = []
	for lamp in park.lamps:
		if lit.size() >= 12: break
		if not lamp.visible or lamp.light_energy < .05: continue
		var bulb: Vector3 = lamp.global_position
		if camera.is_position_behind(bulb): continue
		var at: Vector2 = to_frame.call(bulb)
		if at.x < -.05 or at.x > 1.05 or at.y < -.05 or at.y > 1.05: continue
		if park.light_visible(eye,bulb,null): lit.append(at)
	e["lights"] = lit

# The shape of the aperture: a circle wide open, a polygon of seven blades once it is closed a stop
# or more (how far the edge is in that direction, against the circle of the same f-number).
const BLADES = 7
func blade_reach(direction: float, e: Dictionary) -> float:
	var closed = clampf(float(e.get("stops",0.0)),0.0,1.0)
	if closed <= 0.0: return 1.0
	var sector = TAU/BLADES
	var polygon = cos(sector*.5)/cos(fposmod(direction,sector)-sector*.5)
	return lerpf(1.0,polygon*1.06,closed)

func expose_photo(e: Dictionary, result: Dictionary, omega: float, samples: int) -> Image:
	build_darkroom()
	var size: Vector2i = viewport.size
	acc_view.size = size
	res_view.size = size
	acc_rect.size = Vector2(size)
	res_rect.size = Vector2(size)
	(acc_rect.material as ShaderMaterial).set_shader_parameter("decode",not ParkScene.forward_plus())
	curtain.position = view_rect.position
	curtain.size = view_rect.size
	curtain.visible = true
	exposing = true
	set_dof_blur(false)
	# As fast as the machine renders, not one frame per refresh of the screen.
	var vsync = DisplayServer.window_get_vsync_mode()
	var fps_cap = Engine.max_fps
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	# The exposure, in the renderer's tone curve (and what a backlit level adds: conditions.gd).
	var env: Environment = park.environment.environment
	var tone = env.tonemap_exposure
	var stops = clampf(float(result.get("delta",0.0))+float(e.get("ev_shift",0.0)),-7.0,7.0)
	env.tonemap_exposure = tone*pow(2.0,-stops)
	await get_tree().process_frame      # (the accumulator's own canvas, laid out)
	acc_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var near = camera.near
	var far = camera.far
	var width = near*36.0/focal
	var radius = focal/1000.0/(2.0*e.n)
	var focus = clampf(e.s,.3,10000.0) if not is_inf(e.s) else 10000.0
	var hfov = rad_to_deg(2.0*atan(36.0/(2.0*focal)))
	var tremble = shake_pixels(e,result)/float(size.x)*hfov
	var wander = float(e.get("seed",1))
	var turn = rad_to_deg(omega)
	var base_angle = angle
	var base_pitch = pitch
	var material = acc_rect.material as ShaderMaterial
	for k in samples:
		var u = (k+.5)/samples
		advance_world(e.t/samples)
		# The pan goes on, and the hand wanders (two slow waves each way, by the shot's seed).
		angle = base_angle+turn*e.t*u+tremble*(sin(TAU*(.8*u+wander*.37))+.5*sin(TAU*(2.1*u+wander*.11)))/1.5*.5
		pitch = base_pitch+tremble*(sin(TAU*(.6*u+wander*.73))+.5*sin(TAU*(1.7*u+wander*.29)))/1.5*.5
		update_camera()
		var base = camera.position
		# A point of the aperture (even over the disc) and a fraction of a pixel.
		var lens_turn = TAU*fmod(k*.569840291+wander*.13,1.0)
		var lens = Vector2.from_angle(lens_turn)*radius*sqrt(fmod(k*.754877666+.5,1.0))*blade_reach(lens_turn,e)
		var jitter = Vector2(fmod(k*.618033989,1.0)-.5,fmod(k*.414213562,1.0)-.5)*width/size.x
		camera.set_frustum(width,-lens*near/focus+jitter,near,far)
		camera.position = base+camera.basis.x*lens.x+camera.basis.y*lens.y
		material.set_shader_parameter("weight",1.0/(k+1))
		await RenderingServer.frame_post_draw
		camera.position = base
	camera.set_perspective(camera.fov,near,far)
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	angle = base_angle+turn*e.t
	pitch = base_pitch
	update_camera()
	env.tonemap_exposure = tone
	acc_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	res_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image = res_view.get_texture().get_image()
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		DisplayServer.window_set_vsync_mode(vsync)
		Engine.max_fps = fps_cap
	e["exposed"] = true
	e["samples"] = samples
	exposing = false
	curtain.visible = false
	return image

# The compact's zoom motor: it whirrs while the focal length changes and stops with a tick.
var zoom_heard = 0.0
var zoom_hold = 0.0
func zoom_sound(dt: float) -> void:
	var moving = equipment.body == 0 and mode == "SEARCH" and absf(focal-zoom_heard) > .02 and eye_ready()
	zoom_heard = focal
	if moving:
		zoom_hold = .1
		sfx.loop_at("zoom","zoom_compacta",null,-12.0)
	elif zoom_hold > 0:
		zoom_hold -= dt
		if zoom_hold <= 0:
			sfx.stop_loop("zoom",true)
			play_sfx("zoom_compacta_fin",-10.0)

func shutter_sound() -> void:
	# The recorded shutter of the body in hand; the SLR's changes with the speed (the mirror's two
	# clacks apart at slow speeds, one tight snap at the fastest).
	var slow = shutter_denominator() <= 15
	var fast = shutter_denominator() >= 2000
	var recorded = ["obturador_compacta","obturador_telemetrica","obturador_reflex_lento" if slow else ("obturador_reflex_rapido" if fast else "obturador_reflex"),"obturador_tlr"][equipment.body]
	if play_sfx(recorded,-1.0): return
	play_tone(100,.09)

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
	return is_instance_valid(dof_pass) and bool(Graphics.settings(graphics_preset).dof) and not ("dof" in debug_off)

func update_finder_shader() -> void:
	if lens_material == null: return
	var body_code = equipment.body if interface_mode == "camara" and eye_ready() else -1
	lens_material.set_shader_parameter("finder_body",body_code)
	var tlr_view = equipment.tlr() and eye_ready() and mode != "INTRO"
	lens_material.set_shader_parameter("mirror",tlr_view)
	lens_material.set_shader_parameter("square",tlr_view)
	lens_material.set_shader_parameter("loupe",3.0 if tlr_view and tlr_loupe else 1.0)
	if is_instance_valid(focus_aid): focus_aid.material.set_shader_parameter("mirror",tlr_view)
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

# Gamepad vibration (docs/futuro/22 §4): a tap on the shutter, a tick when the autofocus locks and
# a rattle with the TLR crank. Only while the gamepad is the device in use; Options turns it off.
var vibration = true
var rumbles = 0          # how many were asked for (tests: no pad is plugged in there)
func rumble(weak: float, strong: float, seconds: float) -> void:
	if not vibration: return
	# The phone itself: a short tick for the focus and the dials, a longer one for the shutter.
	if Glyphs.touch and Glyphs.device == "tactil" and OS.has_feature("mobile"): Input.vibrate_handheld(int(clampf(seconds*250+strong*30,8,45)))
	if not Glyphs.pad(): return
	rumbles += 1
	for id in Input.get_connected_joypads(): Input.start_joy_vibration(id,weak,strong,seconds)

# Invert the look (Options): "no", "h" (sideways), "v" (up and down) or "ambos". It applies to
# whatever looks by dragging or pushing — the finger, the mouse and the sticks — not to the keys.
const INVERT_CHOICES = ["no","h","v","ambos"]
var look_invert = "no"
func look_sign() -> Vector2:
	return Vector2(-1.0 if look_invert in ["h","ambos"] else 1.0,-1.0 if look_invert in ["v","ambos"] else 1.0)

func set_look_invert(value: String) -> void:
	look_invert = value
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","invertir_mirada",value)
	config.save("user://interfaz.cfg")

func set_vibration(value: bool) -> void:
	vibration = value
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","vibracion",value)
	config.save("user://interfaz.cfg")
	if value: rumble(.3,.6,.12)

# Interface theme (docs/futuro/20): light by default, dark on request; --ui=claro|oscuro overrides.
func load_theme() -> void:
	var config = ConfigFile.new()
	var dark = config.load("user://interfaz.cfg") == OK and str(config.get_value("interfaz","tema","claro")) == "oscuro"
	vibration = bool(config.get_value("interfaz","vibracion",true))
	look_invert = str(config.get_value("interfaz","invertir_mirada","no"))
	exposure_thirds = bool(config.get_value("interfaz","tercios",false))
	if not look_invert in INVERT_CHOICES: look_invert = "no"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui="): dark = arg == "--ui=oscuro"
	UiStyle.set_dark(dark)

# The whole interface is built with the palette, so changing it reloads the game (only from the menu).
func set_theme(dark: bool) -> void:
	if dark == UiStyle.dark: return
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","tema","oscuro" if dark else "claro")
	config.save("user://interfaz.cfg")
	UiStyle.set_dark(dark)
	get_tree().call_deferred("reload_current_scene")

func load_interface() -> void:
	var config = ConfigFile.new()
	# Phones keep the classic HUD until the touch interface (docs/futuro/13) exists.
	# The camera interface everywhere on desktop (the classic full-screen HUD added nothing once the
	# controls unfold with Tab and the on-screen help lists them); phones keep the classic one until
	# the touch interface exists (docs/futuro/13). --interface= still forces either for tests.
	# One interface on every device: the camera's. Phones add the touch layer (touch_controls.gd).
	interface_mode = "camara"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--interface="): interface_mode = arg.trim_prefix("--interface=")
	place_view()

# Which HUD bars show: always in the classic interface; with the camera, while Tab is on, while the
# pointer rests near the top or bottom edge, and during Academy lessons (they point at controls).
func update_hud_visibility(dt: float) -> void:
	if hud_top.is_empty(): return
	hud_hover = maxf(0.0,hud_hover-dt)
	# One interface everywhere: with the camera interface (desktop) the bars of the classic HUD
	# never show — not in the Academy, not with Tab. The camera's own finder, the strip of the
	# control in hand and the on-screen help are the whole interface, in every mode.
	var show = interface_mode != "camara"
	if mode == "SEARCH" and not eye_ready(): show = false
	if mode == "INTRO": show = false
	finder.visible = eye_ready() and mode != "INTRO"
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
	var local = (point-view_rect.position-view_shift)/view_rect.size
	if equipment.tlr(): local.x = 1.0-local.x       # the waist-level finder is mirrored
	return local*Vector2(viewport.size)

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
	if continuous_now():
		# The shot itself: the predicted distance, at once and without the beep of a single AF.
		var wanted = continuous_distance()
		finder.flash = .15
		finder.success = wanted > 0.0
		if wanted > 0.0:
			focus_distance = wanted
			refresh()
		return
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
		if not demo.has("af"):
			if equipment.body == 2: play_sfx("motor_af",-8.0)
			if not play_sfx("af_confirmado",-6.0): play_tone(1100,.085)
		rumble(.3,0.0,.04)
		notify_player(Texts.get_text("af_confirmado_2f_m") % focus_distance)
	else:
		if not play_sfx("af_fallo",-6.0): play_tone(230,.12)
		notify_player(Texts.get_text("sin_superficie_bajo_ese_punto_el_enfoque_se_mantiene"))

# AF-C (docs/futuro/12 §4.2): while this mode is on, the lens keeps following whatever is under
# the active point, silently, eight times a second, and aims where a moving person will be when
# the shutter opens (its speed times the shutter lag). A focus lock holds it still.
const AF_C_INTERVAL = .12
const SHUTTER_LAG = .04
var af_c_timer = 0.0
func continuous_distance() -> float:
	var hit = point_hit(finder.points()[finder.active])
	if hit.is_empty(): return -1.0
	var where: Vector3 = hit.position
	if hit.collider.has_meta("person"):
		var person = hit.collider.get_meta("person")
		if is_instance_valid(person) and "actual_velocity" in person: where += person.actual_velocity*SHUTTER_LAG
	return maxf(.8,camera.global_position.distance_to(where))

# AF-A (§4.3): continuous only while the person under the active point moves faster than
# AF_A_SPEED; with someone still (or scenery) it behaves as single AF. A double beep tells when it
# starts following.
const AF_A_SPEED = .3
var af_a_following = false
func subject_moving() -> bool:
	var hit = point_hit(finder.points()[finder.active])
	if hit.is_empty() or not hit.collider.has_meta("person"): return false
	var person = hit.collider.get_meta("person")
	return is_instance_valid(person) and "actual_velocity" in person and person.actual_velocity.length() > AF_A_SPEED

func continuous_now() -> bool:
	return equipment.focus_mode == "AF continuo" or (equipment.focus_mode == "AF automático" and af_a_following)

func update_continuous_af(dt: float) -> void:
	if not equipment.focus_mode in ["AF continuo","AF automático"] or focus_locked or mode != "SEARCH" or shooting or not eye_ready(): return
	af_c_timer -= dt
	if af_c_timer > 0.0: return
	af_c_timer = AF_C_INTERVAL
	if equipment.focus_mode == "AF automático":
		var moving = subject_moving()
		if moving and not af_a_following and demo.is_empty():
			play_tone(1320,.04)
			get_tree().create_timer(.09).timeout.connect(func(): play_tone(1320,.04))
		af_a_following = moving
		if not moving: return
	var wanted = continuous_distance()
	if wanted < 0.0: return
	# The lens takes a moment to get there: most of the way on each step.
	var from = wanted if is_inf(focus_distance) else focus_distance
	var next = lerpf(from,wanted,.7)
	if absf(next-focus_distance) > .005:
		focus_distance = next
		refresh()

# TLR crank (K): advances the film one frame with a ratchet sound; with the roll finished, loads a
# new one (sandbox; in the arcade the film winds itself).
func wind_film() -> void:
	if not equipment.tlr() or mode != "SEARCH": return
	if tlr_frames <= 0:
		tlr_frames = 12
		tlr_wound = true
		notify_player(Texts.get_text("tlr_carrete_cargado"))
		if play_sfx("carrete_nuevo",0.0): rumble(.35,.15,.35)
		else: ratchet_sound(10)
	elif not tlr_wound:
		tlr_wound = true
		if play_sfx("manivela_tlr",0.0): rumble(.35,.15,.2)
		else: ratchet_sound(6)
	refresh()

func ratchet_sound(clicks: int) -> void:
	rumble(.35,.15,.035*clicks)
	var rate = 22050
	var data = PackedByteArray()
	var rng = RandomNumberGenerator.new()
	rng.seed = clicks
	var length = int(rate*.07*clicks)
	data.resize(length*2)
	for i in length:
		var t = fmod(float(i)/rate,.07)
		var v = rng.randf_range(-1,1)*exp(-t*160.0)*.55+sin(t*TAU*1900.0)*exp(-t*90.0)*.25
		data.encode_s16(i*2,int(clampf(v,-1,1)*32000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	var player_node = AudioStreamPlayer.new()
	player_node.stream = stream
	player_node.volume_db = -6.0
	add_child(player_node)
	player_node.play()
	player_node.finished.connect(player_node.queue_free)

# The subject in miniature, slowly turning 360°: always a reference of who you are looking for,
# seen from every side. Its own little world (no park, no shadows), lit like the briefing.
func update_portrait(dt: float) -> void:
	var show = mode == "SEARCH" and is_instance_valid(target) and not sandbox and not (academy and academy.active)
	if not show:
		if is_instance_valid(portrait): portrait.visible = false
		return
	if not is_instance_valid(portrait):
		# A translucent dark card (like the on-screen help) so the miniature stands out from any
		# background, in the light and the dark theme.
		portrait = Panel.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.size = Vector2(124,172)
		var card = StyleBoxFlat.new()
		card.bg_color = Color(.03,.05,.08,.62)
		card.set_corner_radius_all(10)
		card.anti_aliasing = true
		portrait.add_theme_stylebox_override("panel",card)
		ui.add_child(portrait)
		ui.move_child(portrait,ui.get_child_count()-1)
		portrait_box = SubViewportContainer.new()
		portrait_box.stretch = true
		portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_box.position = Vector2(2,4)
		portrait_box.size = Vector2(120,165)
		portrait.add_child(portrait_box)
		portrait_view = SubViewport.new()
		portrait_view.size = Vector2i(240,330)
		portrait_view.own_world_3d = true
		portrait_view.transparent_bg = true
		portrait_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		portrait_box.add_child(portrait_view)
		var env = WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = .7
		portrait_view.add_child(env)
		var light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35,-30,0)
		light.light_energy = .9
		portrait_view.add_child(light)
		var cam = Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.name = "Camara"
		portrait_view.add_child(cam)
		cam.current = true
	if portrait_of != target:
		portrait_of = target
		if is_instance_valid(portrait_person): portrait_person.queue_free()
		portrait_person = Person.new()
		portrait_view.add_child(portrait_person)
		portrait_person.setup(target.traits.duplicate(true),casting.catalog,702)
		portrait_person.state = "DETENIDO"
		portrait_person.animate(0)
		var cam: Camera3D = portrait_view.get_node("Camara")
		cam.size = portrait_person.height*1.15
		cam.position = Vector3(0,portrait_person.height*.52,-4)
		cam.look_at(Vector3(0,portrait_person.height*.52,0))
	portrait_person.rotation.y += dt*TAU/8.0     # a full turn every 8 s
	portrait.visible = true
	portrait.position = Vector2(view_rect.position.x+10,hud_clear_top())

# The first free height over the image: under the top bar and the assignment panel whenever they
# show (classic interface, or the camera interface with its controls unfolded), else the image's top.
func hud_clear_top() -> float:
	if not hud_top.is_empty() and hud_top[0].visible: return 172.0
	return view_rect.position.y+10

# ---- Gamepad (docs/futuro/14, docs/futuro/22 §3) ----
# The device changed: every help text on screen is redone for it (Texts fills {controls}).
# The gamepad buttons the interface itself needs (Godot's defaults have none for accepting): A
# presses the focused button of a screen and B goes back (handled with Escape in _unhandled_input()).
static func register_pad_ui() -> void:
	var accept = InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	if not InputMap.action_get_events("ui_accept").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A):
		InputMap.action_add_event("ui_accept",accept)
	var back = InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	if not InputMap.action_get_events("ui_cancel").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B):
		InputMap.action_add_event("ui_cancel",back)

# The gamepad is also noticed by polling, every frame: a screen that takes an event before this
# node sees it must not leave the help showing the keys.
func poll_pad() -> void:
	if Glyphs.pad() or Input.get_connected_joypads().is_empty() or not pad_polling: return
	var used = false
	for button in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START,JOY_BUTTON_BACK,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_LEFT_STICK,JOY_BUTTON_RIGHT_STICK]:
		if Input.is_joy_button_pressed(0,button): used = true
	for axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y,JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
		if absf(Input.get_joy_axis(0,axis)) > .5: used = true
	if used:
		Glyphs.device = "mando"
		log_device(null)
		refresh_device()

# Last changes of device, with what caused them, in user://dispositivo.log: to see what switches
# the help back to the keys on a machine where it happens (the newest 120 lines are kept).
var device_log: PackedStringArray = []
func log_device(event) -> void:
	log_line("%s · %s" % [Glyphs.device,"sondeo del mando" if event == null else event.as_text()])

func log_line(text: String) -> void:
	device_log.append("%s · %s" % [Time.get_time_string_from_system(),text])
	if device_log.size() > 120: device_log = device_log.slice(device_log.size()-120)
	var file = FileAccess.open("user://dispositivo.log",FileAccess.WRITE)
	if file: file.store_string("\n".join(device_log)+"\n")

func refresh_device() -> void:
	if is_instance_valid(walk_hint): walk_hint.set_rich(Texts.get_rich("buscar_ayuda" if not crowd else "paseo_ayuda"))
	refresh()
	if tutorial and tutorial.active: tutorial.update_panel()
	if mode == "HELP": show_help()

# Buttons while searching. Returns true when the event was used.
func pad_button(event: InputEventJoypadButton) -> bool:
	if not event.pressed or mode != "SEARCH": return false
	match event.button_index:
		JOY_BUTTON_A:
			# A only accepts (user, 04-10-2026: it did too many things). Half the trigger focuses.
			if not (tutorial and tutorial.handle_accept()): return false
		JOY_BUTTON_B: show_help()
		JOY_BUTTON_START: show_pause()
		JOY_BUTTON_X:
			if equipment.tlr() and sandbox and eye_ready() and (not tlr_wound or tlr_frames <= 0) and not (academy and academy.active): wind_film()
			else: control_help.set_enabled(not control_help.enabled)
		JOY_BUTTON_Y:
			if not crowd and not (academy and academy.active): toggle_raise()
			else: return false
		JOY_BUTTON_LEFT_SHOULDER: finder.active = posmod(finder.active-1,9)
		JOY_BUTTON_RIGHT_SHOULDER: finder.active = posmod(finder.active+1,9)
		JOY_BUTTON_DPAD_LEFT: select_control(-1)
		JOY_BUTTON_DPAD_RIGHT: select_control(1)
		JOY_BUTTON_DPAD_UP:
			change_control(1)
			pad_repeat = .35
			pad_held = 0.0
		JOY_BUTTON_DPAD_DOWN:
			change_control(-1)
			pad_repeat = .35
			pad_held = 0.0
		JOY_BUTTON_RIGHT_STICK:
			if finder.golden: finder.golden = false
			else: finder.thirds = not finder.thirds
		JOY_BUTTON_LEFT_STICK:
			if crowd and not camera_raised: pad_run = not pad_run
			else: pad_precision = not pad_precision
		_: return false
	refresh()
	return true

static func stick(x: float) -> float:
	# Radial dead zone 0.15 and a cubic response: fine aim near the centre.
	if absf(x) < .15: return 0.0
	var v = (absf(x)-.15)/.85
	return signf(x)*v*v*v

# The right trigger as a real shutter button (docs/futuro/14 §3): from 0.35 it focuses on the active
# point and holds focus and exposure (AF-L / AE-L) for as long as it stays there, so the photo can
# be recomposed; from 0.90 it shoots; let go below 0.30 without shooting and the lock is released.
func update_trigger(rt: float) -> void:
	if trigger_stage == 0 and rt >= .35:
		trigger_stage = 1
		if eye_ready() and mode == "SEARCH":
			if equipment.focus_mode != "MF": autofocus()
			update_meter()
			if equipment.auto_exposure: auto_expose()
			exposure_locked = true
			focus_locked = equipment.focus_mode != "MF"
			trigger_lock = true
			refresh()
	if trigger_stage == 1 and rt >= .9:
		trigger_stage = 2
		trigger_lock = false
		take_photo()
	if rt < .3:
		if trigger_stage == 1 and trigger_lock:
			# Cancelled: the half press is let go without a photo.
			release_lock()
			refresh()
		trigger_lock = false
		trigger_stage = 0

var trigger_lock = false         # the lock in force was set by the trigger's half press

# Sticks, triggers and D-pad repeat, every frame while searching.
var pad_polling = true           # tests switch it off: a gamepad left plugged in must not drive them
# On a screen with a list that scrolls (Academy, graphics), the right stick moves it like a wheel.
func scroll_with_stick(dt: float) -> void:
	if mode == "SEARCH" or not is_instance_valid(modal) or Input.get_connected_joypads().is_empty() or not pad_polling: return
	var push = Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y)
	if absf(push) < .25: push = Input.get_joy_axis(0,JOY_AXIS_LEFT_Y)
	if absf(push) < .25: return
	for list in modal.find_children("*","ScrollContainer",true,false): list.scroll_vertical += roundi(push*dt*900.0)

func update_pad(dt: float) -> void:
	if Input.get_connected_joypads().is_empty() or not pad_polling: return
	if academy and academy.locks_input(): return
	var slow = 1.0/3.0 if pad_precision else 1.0
	var lx = stick(Input.get_joy_axis(0,JOY_AXIS_LEFT_X))
	var ly = stick(Input.get_joy_axis(0,JOY_AXIS_LEFT_Y))
	# Walking in the big park the left stick walks (update_photographer()) and the right one looks:
	# it also turned and tilted the view here, so walking forward looked up as well.
	var walking = crowd != null and not camera_raised
	if (lx != 0.0 or ly != 0.0) and not walking:
		angle = fposmod(angle+lx*dt*42*24/view_focal()*slow*look_sign().x,360)
		pitch -= ly*dt*30*24/view_focal()*slow*look_sign().y
	var rx = stick(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X))
	var ry = stick(Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
	if eye_ready():
		if ry != 0.0 and equipment.zoom(): focal = clampf(focal-ry*dt*40*slow,equipment.lens().min,equipment.lens().max)
		if rx != 0.0 and equipment.focus_mode == "MF": adjust_focus_delta(-rx*.3*slow*dt)
		# TLR: the left trigger holds the loupe over the ground glass.
		if equipment.tlr():
			var loupe = Input.get_joy_axis(0,JOY_AXIS_TRIGGER_LEFT) > .5
			if loupe != tlr_loupe:
				tlr_loupe = loupe
				play_sfx("lupa_tlr",-2.0)
				update_finder_shader()
	# Right trigger, a two-stage shutter: half way focuses (AF), all the way shoots.
	update_trigger(Input.get_joy_axis(0,JOY_AXIS_TRIGGER_RIGHT))
	# D-pad ↑/↓ held: repeat at 8 Hz after 0.35 s.
	for dir in [[JOY_BUTTON_DPAD_UP,1],[JOY_BUTTON_DPAD_DOWN,-1]]:
		if Input.is_joy_button_pressed(0,dir[0]):
			pad_repeat -= dt
			pad_held += dt
			if pad_repeat <= 0.0:
				# Held more than half a second, the dial goes by whole stops.
				whole_hold = pad_held > .5
				change_control(dir[1])
				whole_hold = false
				pad_repeat = .125

# --sound-board: the camera's or the interface's sounds in a row, each with its name on screen.
const SOUND_BOARDS = {
	"camara": ["obturador_compacta","obturador_telemetrica","obturador_reflex","obturador_reflex_lento","obturador_reflex_rapido","obturador_tlr","manivela_tlr","carrete_nuevo","af_confirmado","af_fallo","motor_af","bloqueo","anillo_enfoque","anillo_enfoque","anillo_enfoque","dial","dial","dial","dial_tope","control_elegir","medicion","lupa_tlr","camara_subir","camara_bajar","zoom_compacta","zoom_compacta_fin"],
	"interfaz": ["ui_mover","ui_mover","ui_aceptar","ui_atras","ui_bloqueado","pausa","revelado","condicion_ok","condicion_ok","estrella","estrella","estrella","foto_rechazada","album","tictac","tictac","tictac","tiempo_agotado","nivel_superado","nivel_no_superado","tutorial_ok","leccion_superada","insignia","graduado"]}
var sound_board = ""
var board_time = -1.0
var board_index = -1
var board_label: Label
func update_sound_board(dt: float) -> void:
	var list: Array = SOUND_BOARDS.get(sound_board,[])
	if board_label == null:
		board_label = Label.new()
		board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		board_label.add_theme_font_size_override("font_size",64)
		board_label.add_theme_color_override("font_color",UiStyle.BRAND)
		board_label.add_theme_color_override("font_outline_color",Color.BLACK)
		board_label.add_theme_constant_override("outline_size",12)
		var layer = CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		layer.add_child(board_label)
		board_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board_time = 4.2    # (the capture discards the first four seconds)
	board_time -= dt
	if board_time > 0 or board_index >= list.size()-1: return
	board_index += 1
	var name: String = list[board_index]
	board_label.text = name
	# The long ones get their time; the zoom motor is a loop, heard for a second.
	board_time = {"carrete_nuevo":2.4,"nivel_superado":3.0,"nivel_no_superado":2.2,"graduado":5.4,"insignia":1.6,"leccion_superada":1.9,"tiempo_agotado":1.6,"obturador_reflex_lento":1.4,"manivela_tlr":1.3,"zoom_compacta":1.3}.get(name,.85 if sound_board == "camara" else 1.0)
	if name == "zoom_compacta": sfx.loop_at("board","zoom_compacta",null,-6.0)
	else:
		sfx.stop_loop("board",true)
		var rise = board_index-list.find(name) if name == "estrella" else 0
		play_sfx(name,-2.0,1.0+.06*rise)

# A recorded effect by name (scripts/sfx.gd); false if there is none, and the caller keeps its tone.
func play_sfx(name: String, db = 0.0, pitch = 1.0) -> bool:
	return sfx != null and sfx.play(name,db,pitch)

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
	var e = {"f":focal,"n":aperture_value(),"t":1.0/shutter_denominator(),"iso":iso_value(),"s":focus_distance,"d":camera.global_position.distance_to(points[1]),"v":perpendicular,"scene_ev":park.illumination_ev(points[1],time_of_day,target),"head":camera.unproject_position(head_world)/Vector2(viewport.size),"feet":feet_point,"chest":projected[1],"in_front":not camera.is_position_behind(points[1]),"blockers":blocked,"rays":rays,"camera_transform":camera.global_transform,"projection":camera.get_camera_projection(),"subject_points":points,"subject_velocity":velocity,"motion_sign":signf(velocity.dot(camera.global_basis.x)),"film":equipment.film,"cloud_cover":park.cloud_cover,"seed":shot_serial+1}
	# The subject is judged on its eyes, as photographers do (docs/futuro/21 §2): focus distance and
	# position of the eyes, halfway up the head.
	var eyes_world = target.global_transform*(head_pose*Vector3(0,.5*target.height/target.profile.relacion_cabeza,0))
	e["eyes"] = camera.unproject_position(eyes_world)/Vector2(viewport.size)
	e["d_eyes"] = camera.global_position.distance_to(eyes_world)
	# Everyone else who shows in the frame (conditions "aislado" and "acompanado").
	var others = []
	for p in people:
		if p == target or not p.visible: continue
		var chest_world: Vector3 = p.control_points()[1]
		if camera.is_position_behind(chest_world): continue
		var chest = camera.unproject_position(chest_world)/Vector2(viewport.size)
		var top = camera.unproject_position(p.global_position+Vector3.UP*p.height)/Vector2(viewport.size)
		var bottom = camera.unproject_position(p.global_position)/Vector2(viewport.size)
		if chest.x < -.2 or chest.x > 1.2 or chest.y < -.2 or chest.y > 1.2: continue
		var hit = ray_to(chest_world)
		var seen = hit.is_empty() or (hit.collider.has_meta("person") and hit.collider.get_meta("person") == p)
		others.append({"chest":chest,"h":absf(bottom.y-top.y),"visible":seen})
	e["others"] = others
	# For the arcade conditions about light, place and company (scripts/conditions.gd).
	var sun_dir: Vector3 = park.sun.global_basis.z
	e["backlight"] = Vector2(view_axis.x,view_axis.z).normalized().dot(Vector2(sun_dir.x,sun_dir.z).normalized())
	e["sunlit"] = str(time_of_day) in ["day","golden"] and park.light_visible(points[1],points[1]+sun_dir*80,target)
	e["activity"] = str(target.activity) if target.state in ["SENTADO","DETENIDO"] else ""
	var places = {}
	for key in park.places:
		var spot: Vector3 = park.places[key]+Vector3.UP*1.6
		places[key] = {"pos":camera.unproject_position(spot)/Vector2(viewport.size),"d":camera.global_position.distance_to(spot),"front":not camera.is_position_behind(spot)}
	e["places"] = places
	if dog and is_instance_valid(dog) and dog.walker == target:
		var at: Vector3 = dog.global_position+Vector3.UP*.25
		e["dog"] = {"pos":camera.unproject_position(at)/Vector2(viewport.size),"d":camera.global_position.distance_to(at),"front":not camera.is_position_behind(at)}
	if equipment.tlr(): square_evidence(e)
	return e

# The TLR takes a square: positions are measured on the central square of the 16:9 image, so a
# subject outside the square is out of the frame (docs/futuro/21 §3).
func square_evidence(e: Dictionary) -> void:
	var aspect = float(viewport.size.x)/viewport.size.y
	var to_square = func(v: Vector2) -> Vector2: return Vector2(.5+(v.x-.5)*aspect,v.y)
	for key in ["head","feet","chest","eyes"]:
		if e.has(key): e[key] = to_square.call(e[key])
	for o in e.get("others",[]): o.chest = to_square.call(o.chest)
	for key in e.get("places",{}): e.places[key].pos = to_square.call(e.places[key].pos)
	if e.has("dog"): e.dog.pos = to_square.call(e.dog.pos)
	e["square"] = true

func take_photo() -> void:
	if mode != "SEARCH" or (not sandbox and shots <= 0) or shooting or level_over: return
	if not eye_ready(): return
	# TLR in the sandbox: 12 frames per roll and the crank between shots (in the arcade the level's
	# shots rule and the film winds itself).
	if equipment.tlr() and sandbox and not (academy and academy.active):
		if tlr_frames <= 0:
			notify_player(Texts.get_text("tlr_carrete_acabado"))
			return
		if not tlr_wound:
			notify_player(Texts.get_text("tlr_manivela"))
			return
	# (In a scripted capture with --mf-rack the script has already put the focus on the subject.)
	if equipment.focus_mode != "MF" and not focus_locked and not demo.has("mf-rack") and not (academy and academy.active and academy.auto_subject() != null): autofocus()
	update_meter()
	if equipment.auto_exposure and not exposure_locked: auto_expose()
	release_lock()
	shooting = true
	rumble(.2,.75,.09)
	# The turn of the camera at the instant of the shot (0 in the guided demonstrations, where the
	# tutor's own tracking must not freeze the runner it is showing blurred).
	var shot_omega = 0.0 if (academy and academy.active and academy.phase == "demo") or (not demo.is_empty() and not demo.has("pan-shot")) else deg_to_rad(camera_omega)
	# The tutor's pan in the Academy's demonstration: the camera is taken to follow the runner exactly.
	if academy and academy.active and academy.phase == "demo" and academy.demo_pan and is_instance_valid(academy.runner):
		shot_omega = academy.runner.actual_velocity.dot(camera.global_basis.x)/maxf(.5,camera.global_position.distance_to(academy.runner.control_points()[1]))
	if demo.has("pan-shot") and is_instance_valid(target):
		# Capture helper: the scripted camera is taken to follow the subject exactly (its own
		# smoothed tracking lags a little, which a real pan cannot afford).
		shot_omega = target.actual_velocity.dot(camera.global_basis.x)/maxf(.5,camera.global_position.distance_to(target.control_points()[1]))
	pan_velocity = 0
	if dof_allowed() and not dof_blur: set_dof_blur(true)   # rangefinder: blur only in the photo
	# Freeze first, then wait for physics and the render to represent precisely this state.
	await get_tree().physics_frame
	var evidence = capture_sandbox_evidence() if sandbox else capture_evidence()
	evidence["camera_omega"] = shot_omega
	evidence["rendered_dof"] = dof_active()
	evidence["ca"] = float(equipment.lens().get("ca",.5))
	evidence["stops"] = 2.0*log(aperture_value()/equipment.apertures(focal)[0])/log(2.0)
	lens_evidence(evidence)
	if arcade_level >= 0 and not sandbox: current_result = Conditions.judge(evidence,Arcade.LEVELS[arcade_level].cond)
	else: current_result = Photo.evaluate(evidence)
	current_result["evidence"] = evidence
	if equipment.tlr() and sandbox:
		tlr_frames -= 1
		tlr_wound = false
	shot_serial += 1
	# Mastery badges (docs/futuro/05 §3): every photo of a real assignment counts, never the sandbox
	# nor the automatic captures.
	if badges_count() and not sandbox and not (academy and academy.active and academy.phase == "demo"):
		for id in Badges.register(current_result,{"night":time_of_day == "night","first_shot":shot_serial == 1,"manual":equipment.exposure_mode() == "M"}): announce_badge(id)
	if not sandbox: shots -= 1
	var clean_image: Image
	var samples = photo_samples(evidence,current_result)
	if samples > 1:
		shutter_sound()
		clean_image = await expose_photo(evidence,current_result,shot_omega,samples)
	else:
		await RenderingServer.frame_post_draw
		clean_image = viewport.get_texture().get_image()
	if equipment.tlr():
		# The TLR negative is square, and the right way round (only the finder is mirrored).
		var side = clean_image.get_height()
		clean_image = clean_image.get_region(Rect2i((clean_image.get_width()-side)/2,0,side,side))
	current_photo = ImageTexture.create_from_image(clean_image)
	# The good ones go to the album (only in the real game: tests and capture tools never write there).
	if badges_count() and not sandbox and not current_result.rejected and current_result.score >= Album.MIN_SCORE:
		save_to_album(current_photo,current_result)
	if not sandbox and (best.is_empty() or current_result.score > best.score):
		best = current_result.duplicate(true)
		best["photo"] = clean_image
	update_dof_pass()
	if samples <= 1: shutter_sound()
	if is_instance_valid(camera_body): camera_body.blackout(1.0/shutter_denominator())
	shooting = false
	if academy_demo_shot:
		# A shot of the Academy's demonstration: the photo goes to the tutor panel, no result screen.
		academy_demo_shot = false
		academy.on_demo_photo(current_photo,current_result)
		return
	if tutorial and tutorial.active: current_result["tutorial_note"] = tutorial.on_photo(current_result)
	mode = "RESULT"
	show_results()

# Vignetting and lateral chromatic aberration grow with wide angles (the same strengths develop the
# photo). Depth of field follows focal length, aperture and focus distance exactly.
# x: vignetting. y: lateral chromatic aberration (colour fringes towards the corners): it depends
# on the lens ("ca" in equipment.gd), grows at wide angles and at full aperture, and fades as the
# diaphragm closes. ca_lens < 0 uses the mounted lens and the current aperture.
func lens_strengths(focal_mm: float, ca_lens = -1.0, stops_closed = -1.0) -> Vector2:
	var wide = clampf((50.0-focal_mm)/26.0,0.0,1.0)
	if ca_lens < 0.0:
		ca_lens = float(equipment.lens().get("ca",.5))
		var open = equipment.apertures(focal_mm)[0]
		stops_closed = 2.0*log(aperture_value()/open)/log(2.0)
	var aperture_factor = clampf(1.0-.22*stops_closed,.35,1.0)
	return Vector2(.22+.26*wide,ca_lens*(.55+.45*wide)*aperture_factor)

var dof_blur = false
func dof_active() -> bool:
	return is_instance_valid(dof_pass) and dof_pass.visible and dof_blur

func update_lens_effects() -> void:
	if not is_instance_valid(camera): return
	var strengths = lens_strengths(focal)
	if lens_material:
		lens_material.set_shader_parameter("vignette_amount",strengths.x)
		# The rangefinder's finder is a window beside the lens: it shows none of its aberration
		# (the photo does).
		# With the camera lowered you look with your own eyes: no lens character at all.
		var through_lens = eye_ready() and not (equipment.body == 1 and interface_mode == "camara")
		lens_material.set_shader_parameter("chromatic_aberration",strengths.y if through_lens else 0.0)
		if not eye_ready(): lens_material.set_shader_parameter("vignette_amount",0.0)
	if dof_active():
		var dof_material: ShaderMaterial = dof_pass.material_override
		dof_material.set_shader_parameter("focal_mm",focal)
		dof_material.set_shader_parameter("aperture",aperture_value())
		dof_material.set_shader_parameter("focus_m",-1.0 if is_inf(focus_distance) else focus_distance)
		# Longitudinal chromatic aberration: the lens's own, strongest wide open (docs/futuro/07 §6).
		dof_material.set_shader_parameter("loca",clampf(lens_strengths(focal).y*1.6,0.0,1.0) if Graphics.settings(graphics_preset).lens else 0.0)

func photo_material(result: Dictionary) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = Develop
	var evidence: Dictionary = result.evidence
	# With the viewfinder's exact depth of field the capture is already blurred per pixel; otherwise
	# the develop pass blurs the whole frame by the subject's circle of confusion.
	# A photo taken with the virtual shutter (expose_photo()) already has its depth of field, its
	# movement, its shake and its exposure: the develop pass only adds the lens and the grain.
	var exposed: bool = evidence.get("exposed",false)
	# Diffraction: past f/11 the aperture itself softens everything a little (a pixel and a bit at f/22).
	var diffraction = maxf(0.0,(float(evidence.n)-11.0)/11.0)*1.2*viewport.size.x/1280.0
	mat.set_shader_parameter("coc_pixels",diffraction+(0.0 if exposed or evidence.get("rendered_dof",false) else minf(result.coc/36*viewport.size.x*.5,35)))
	# The photo keeps the lens and aperture it was taken with (evidence.ca, evidence.stops).
	var strengths = lens_strengths(evidence.f,evidence.get("ca",.5),evidence.get("stops",1.0))
	mat.set_shader_parameter("vignette_amount",strengths.x)
	mat.set_shader_parameter("chromatic_aberration",strengths.y)
	mat.set_shader_parameter("exposure",0.0 if exposed else clampf(result.delta+float(result.get("evidence",{}).get("ev_shift",0.0)),-8,8))
	mat.set_shader_parameter("motion",Vector2.ZERO if exposed else Vector2(minf(result.drag/36*viewport.size.x,90)*result.get("drag_sign",evidence.get("motion_sign",1.0)),0))
	# Panning: the background streaks by the camera's sweep and the subject keeps its own blur.
	var streak: float = result.get("background",0.0)
	if streak > Photo.C and evidence.has("head") and evidence.has("feet") and not exposed:
		var top: Vector2 = evidence.head
		var bottom: Vector2 = evidence.feet
		var tall = maxf(absf(bottom.y-top.y),.05)
		mat.set_shader_parameter("pan",Vector2(minf(streak/36*viewport.size.x,140),0))
		mat.set_shader_parameter("subject_box",Vector4((top.x+bottom.x)*.5,(top.y+bottom.y)*.5,tall*.24,tall*.6))
	var shake_angle = fposmod(evidence.seed*2.399963,TAU)
	mat.set_shader_parameter("shake",Vector2.ZERO if exposed else Vector2.from_angle(shake_angle)*minf(maxf(0,result.ratio-1)*5,45))
	mat.set_shader_parameter("grain",log(evidence.iso/100.0)/log(2.0)*.035)
	mat.set_shader_parameter("film",1.0 if evidence.get("film",false) else 0.0)
	mat.set_shader_parameter("legacy_grain",legacy)
	if legacy:
		mat.set_shader_parameter("coc_pixels",0.0 if exposed or evidence.get("rendered_dof",false) else minf(result.coc/36*viewport.size.x*.5,35))
		return mat
	# The glass (docs/SIMULACION_FOTOGRAFICA.md §9.5).
	# Wide angles bow straight lines out, telephotos a little in.
	mat.set_shader_parameter("distortion",.07*clampf((50.0-evidence.f)/26.0,-.3,1.0))
	mat.set_shader_parameter("aspect",float(evidence.get("aspect",16.0/9.0)))
	mat.set_shader_parameter("halation",1.0 if evidence.get("film",false) else 0.0)
	# The sun in or near the frame veils the picture with its own light (more at the golden hour,
	# when it is low and in front), fading as it leaves the frame.
	var sun: Dictionary = evidence.get("sun",{})
	var veil = 0.0
	if not sun.is_empty() and sun.seen:
		var out = maxf(0.0,maxf(absf(sun.pos.x-.5),absf(sun.pos.y-.5))-.5)
		veil = (.9 if evidence.get("tod","day") == "golden" else .5)*clampf(1.0-out/.45,0.0,1.0)
		mat.set_shader_parameter("sun_uv",sun.pos)
		mat.set_shader_parameter("sun_color",Color(1.0,.78,.5) if evidence.get("tod","day") == "golden" else Color(1.0,.95,.86))
	mat.set_shader_parameter("sun_veil",veil)
	# Stars on the lamps once the aperture is small (from f/11; long at f/22).
	var lights: Array = evidence.get("lights",[])
	var star = clampf((float(evidence.n)-8.0)/14.0,0.0,1.0) if not lights.is_empty() else 0.0
	mat.set_shader_parameter("star",star)
	mat.set_shader_parameter("light_count",lights.size() if star > 0.0 else 0)
	if star > 0.0:
		var spots = PackedVector2Array(lights)
		spots.resize(12)
		mat.set_shader_parameter("lights",spots)
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

# The photo comes out: the print, then a tick per condition met and a chime per star, going up.
func result_sounds(r: Dictionary) -> void:
	if r.rejected:
		play_sfx("foto_rechazada",-4.0)
		return
	play_sfx("revelado",-4.0)
	var at = .35
	for c in r.get("conditions",[]):
		if not c.ok: continue
		get_tree().create_timer(at).timeout.connect(func(): if mode == "RESULT": play_sfx("condicion_ok",-6.0))
		at += .14
	for k in int(r.stars):
		get_tree().create_timer(at).timeout.connect(func(): if mode == "RESULT": play_sfx("estrella",-8.0,1.0+.06*k))
		at += .16

func show_results() -> void:
	if academy and academy.active:
		show_academy_result()
		return
	if sandbox:
		show_sandbox_result()
		return
	var root = create_modal()
	result_sounds(current_result)
	var tutorial_on = tutorial and tutorial.active
	var header = (Texts.get_text("arcade_nivel_d") % (arcade_level+1)+" · "+level_title(arcade_level)) if arcade_level >= 0 else Texts.get_text("revelado_encargo_02d") % (assignment+1)
	label(root,header,Rect2(25,18,700,25),14,Color("a9c487"))
	label(root,Texts.get_text("cada_ajuste_deja_una_huella"),Rect2(25,50,770,45),30)
	photo_preview(root,current_photo,current_result,Rect2(25,112,750,422))
	var r = current_result
	label(root,Texts.get_text("rechazada") if r.rejected else Texts.get_text("d_100") % r.score,Rect2(25,548,260,51),36,Color("efaf83") if r.rejected else Color("b8d78c"))
	label(root,"—" if r.rejected else "★".repeat(r.stars)+"☆".repeat(5-r.stars),Rect2(295,555,300,40),28,Color("c9d790"))
	label(root,Texts.get_text("d_creditos") % r.credits,Rect2(598,557,180,32),18,Color("b7c5a9"))
	var evidence: Dictionary = r.evidence
	label(root,Texts.get_text("0f_mm_1f_1_d_s_iso_d_foco_s") % [evidence.f,evidence.n,roundi(1/evidence.t),evidence.iso,Texts.get_text("infinito") if is_inf(evidence.s) else Texts.get_text("2f_m") % evidence.s],Rect2(25,606,760,26),15,Color("b5c5a8"))
	label(root,Texts.get_text("mejor_del_encargo_d_100_quedan_d_disparos") % [best.score,shots]+(" · %s" % clock_text() if arcade_level >= 0 and level_limit() > 0 else ""),Rect2(25,646,745,30),16)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(803,105)
	scroll.size = Vector2(453,509)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",15)
	scroll.add_child(column)
	for c in r.get("conditions",[]):
		var cond_label = Label.new()
		cond_label.text = ("✓ " if c.ok else "✗ ")+c.text
		cond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cond_label.add_theme_color_override("font_color",UiStyle.SKY_DEEP if c.ok else UiStyle.WARN)
		cond_label.add_theme_font_size_override("font_size",16)
		column.add_child(cond_label)
	if r.rejected:
		var reason = Label.new()
		reason.text = r.reason
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.add_theme_color_override("font_color",UiStyle.WARN)
		reason.add_theme_font_size_override("font_size",16)
		column.add_child(reason)
	for line in r.lines:
		# Each part of the report with its orange dot, and its name and mark standing out.
		var parts: PackedStringArray = str(line).split("\n",true,1)
		var text_label = rich_label(null,dot()+"[b]"+plain_bb(parts[0])+"[/b]"+("\n"+plain_bb(parts[1]) if parts.size() > 1 else ""),Rect2(),16,UiStyle.INK)
		text_label.fit_content = true
		text_label.add_theme_color_override("default_color",UiStyle.INK)
		text_label.add_theme_font_override("bold_font",UiStyle.font("Roboto-Medium"))
		text_label.add_theme_font_size_override("bold_font_size",16)
		column.add_child(text_label)
	if tutorial_on:
		# Beside the title: at the bottom it ran over the line of the best photo.
		var note = label(root,current_result.get("tutorial_note",""),Rect2(370,30,885,52),16,UiStyle.SKY_DEEP)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button(root,Texts.get_text("tutorial_continuar"),Rect2(803,642,451,52),resume_search,true)
		return
	if arcade_level >= 0:
		var more = shots > 0 and not level_over
		# A failed photo with shots left: the button in hand is «another photo», not «end the level».
		var failed = r.rejected or r.score < int(Arcade.LEVELS[arcade_level].min)
		if more: button(root,Texts.get_text("arcade_otra_foto_d") % shots,Rect2(803,642,204,52),resume_search,failed)
		button(root,Texts.get_text("arcade_terminar") if more else Texts.get_text("arcade_ver_resultado"),Rect2(1020 if more else 803,642,234 if more else 451,52),end_level,not (more and failed))
		return
	if shots > 0: button(root,Texts.get_text("reintentar_d") % shots,Rect2(803,642,204,52),resume_search)
	button(root,Texts.get_text("siguiente"),Rect2(1020 if shots > 0 else 803,642,234 if shots > 0 else 451,52),finish_assignment,true)

func resume_search() -> void:
	close_modal()
	mode = "SEARCH"
	refresh()

# Scripted sessions without a level (evidence, tests): one assignment after another.
func finish_assignment() -> void:
	if sandbox: resume_search(); return
	if arcade_level >= 0:
		end_level()
		return
	records.append(best)
	assignment += 1
	new_assignment()

# ---- Arcade (docs/futuro/21 §1) ----
func level_title(n: int) -> String:
	return Texts.get_text("arcade_nivel_%d_titulo" % (n+1))

func level_limit() -> float:
	return float(Arcade.LEVELS[arcade_level].limit) if arcade_level >= 0 else 0.0

func clock_text() -> String:
	var t = ceili(level_time)
	return ("" if OS.has_feature("web") else "⏱ ")+"%d:%02d" % [t/60,t%60]   # (no font in the browser has the stopwatch)

func show_arcade() -> void:
	mode = "ARCADE"
	arcade_level = -1
	var root = create_modal()
	label(root,Texts.get_text("arcade_titulo"),Rect2(65,26,600,55),38)
	label(root,Texts.get_text("arcade_subtitulo"),Rect2(65,82,1100,26),16,Color("b5c3ad"))
	if Arcade.all_open: label(root,Texts.get_text("arcade_trampa"),Rect2(65,662,700,26),15,Color("f0c75e"))
	var progress = Arcade.load_progress()
	var focus_set = false
	for block in Arcade.BLOCKS.size():
		var y = 112+block*88   # (six blocks)
		label(root,Texts.get_text(Arcade.BLOCKS[block]),Rect2(65,y,1100,22),13,Color("b8d78c"))
		for k in 5:
			var n = block*5+k
			var open = Arcade.unlocked(n,progress)
			var card = Button.new()
			card.position = Vector2(65+k*232,y+22)
			card.size = Vector2(220,62)
			# Reachable with the gamepad (D-pad / stick to move, A to start); the focus starts on the
			# first level still to pass.
			card.focus_mode = Control.FOCUS_ALL
			card.disabled = not open
			card.pressed.connect(func(): start_level(n))
			root.add_child(card)
			if open and not progress.has(n) and not focus_set:
				card.call_deferred("grab_focus")
				focus_set = true
			label(card,Texts.get_text("arcade_nivel_d") % (n+1),Rect2(14,3,190,16),11,Color("b8d78c"))
			label(card,level_title(n) if open else Texts.get_text("arcade_bloqueado"),Rect2(14,16,196,26),18)
			var stars = int(progress[n].stars) if progress.has(n) else 0
			label(card,"★".repeat(stars)+"☆".repeat(5-stars) if open else ("—" if OS.has_feature("web") else "🔒"),Rect2(14,38,196,22),15,Color("c9d790"))
	button(root,Texts.get_text("arcade_menu"),Rect2(1035,650,180,48),intro)

# A level fixes scenario, light and equipment; another scenario reloads the scene first.
func start_level(n: int) -> void:
	var level: Dictionary = Arcade.LEVELS[n]
	if level.scenario != scenario:
		pending_start = {}
		reload_with(level.scenario,{"level":n})
		return
	equipment.preset(level.body)
	equipment.lens_index = level.lens
	equipment.set_exposure_mode({true:"P",false:"M"}.get(level.auto,str(level.auto)))
	if level.has("focus"): equipment.focus_mode = level.focus
	if level.has("metering"): equipment.metering = level.metering
	equipment.ev_comp_index = equipment.EV_COMPENSATIONS.find(0.0)   # (each level starts without the last one's compensation)
	if level.has("iso"):
		equipment.film = true
		equipment.film_iso_index = level.iso
	arcade_level = n
	start_session(level.time,false)

# ---- Tutorial (docs/futuro/22 §2) ----
func start_tutorial() -> void:
	# It starts in the classic park and ends walking in the big one (the scene reloads in between).
	var Tutorial = preload("res://scripts/tutorial.gd")
	var from: int = Tutorial.resume_step
	var where = "grande" if from >= 0 else "clasico"
	if scenario != where:
		reload_with(where,{"tutorial":true})
		return
	Tutorial.resume_step = -1
	arcade_level = -1
	equipment.preset(0)
	start_session("day",true)
	briefing.text = Texts.get_text("modo_tutorial_titulo")
	tutorial.start(maxi(0,from))

# The tutorial's assignment: a real subject and its description, without the briefing screen.
func tutorial_assignment() -> void:
	sandbox = false
	if is_instance_valid(target): target.protected_target = false
	var candidates = people.filter(func(p): return p.lane in [1,2] and p.state != "RETIRADO" and not p.runner)
	target = candidates[casting.rng.randi_range(0,candidates.size()-1)]
	target.protected_target = true
	briefing.text = Texts.get_text("busca")+", ".join(casting.predicates_for(target.traits,people.map(func(p): return p.traits)))+"."
	shots = 99
	best = {}
	refresh()

func end_level() -> void:
	if arcade_level < 0 or mode == "LEVEL_END": return
	level_over = true
	mode = "LEVEL_END"
	var level: Dictionary = Arcade.LEVELS[arcade_level]
	var passed = not best.is_empty() and not best.rejected and best.score >= level.min
	var stars = Arcade.stars_for(best.score,level.min) if passed else 0
	# (out of time, the bell has already said so)
	if passed: play_sfx("nivel_superado",-3.0)
	elif not (level_limit() > 0 and level_time <= 0): play_sfx("nivel_no_superado",-3.0)
	if passed:
		Arcade.save_result(arcade_level,best.score,stars)
		# Every level passed: the badge of the whole arcade.
		if badges_count() and Arcade.load_progress().size() >= Arcade.LEVELS.size() and Badges.grant("calle"): announce_badge("calle")
	var root = create_modal()
	label(root,Texts.get_text("arcade_nivel_d") % (arcade_level+1)+" · "+level_title(arcade_level),Rect2(50,38,900,25),14,Color("b8d78c"))
	label(root,Texts.get_text("arcade_superado") if passed else Texts.get_text("arcade_no_superado"),Rect2(48,72,1180,55),43,Color("b8d78c") if passed else Color("efaf83"))
	var why = ""
	if not passed:
		if best.is_empty() or best.rejected:
			why = (Texts.get_text("arcade_tiempo_agotado")+" " if level_limit() > 0 and level_time <= 0 else "")+(best.reason if not best.is_empty() and best.reason != "" else Texts.get_text("arcade_sin_foto_valida"))
		else: why = Texts.get_text("arcade_nota_insuficiente_d_d") % [best.score,level.min]
	if not best.is_empty() and best.has("photo"):
		photo_preview(root,best.photo,best,Rect2(50,150,710,430))
	var info = label(root,(Texts.get_text("arcade_mejor_foto_d") % best.score if not best.is_empty() else Texts.get_text("arcade_sin_foto_valida"))+("\n"+"★".repeat(stars)+"☆".repeat(5-stars) if passed else "")+("\n\n"+why if why != "" else ""),Rect2(805,160,410,300),24)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.set_deferred("size",Vector2(410,300))
	button(root,Texts.get_text("arcade_repetir"),Rect2(805,520,195,56),func(): start_level(arcade_level))
	var n = arcade_level
	if passed and n+1 < Arcade.LEVELS.size():
		button(root,Texts.get_text("arcade_siguiente"),Rect2(1012,520,203,56),func(): start_level(n+1),true)
	button(root,Texts.get_text("arcade_niveles"),Rect2(805,592,410,52),show_arcade,not passed)

# The tutorial is over: a screen of its own says so and offers where to go next (the last panel
# over the finder left the player in the park without knowing what to do).
func show_tutorial_end() -> void:
	mode = "TUTORIAL_END"
	var root = create_modal()
	label(root,Texts.get_text("tutorial_fin_titulo"),Rect2(65,50,1150,60),42,Color("b8d78c"))
	glyph_label(root,Texts.get_rich("tutorial_fin"),Rect2(65,130,900,90),20,UiStyle.INK)
	var options = [["tutorial_ir_arcade","tutorial_ir_arcade_texto",func(): tutorial.stop(); show_arcade()],
		["tutorial_ir_academia","tutorial_ir_academia_texto",func(): tutorial.stop(); open_academy()],
		["tutorial_repetir","tutorial_repetir_texto",func(): tutorial.stop(); start_tutorial()],
		["tutorial_menu","tutorial_menu_texto",func(): tutorial.stop(); intro()]]
	for k in options.size():
		button(root,Texts.get_text(options[k][0]),Rect2(65,240+k*84,330,64),options[k][2],k == 0)
		label(root,Texts.get_text(options[k][1]),Rect2(425,240+k*84,760,64),18,Color("b5c3ad")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# Someone who has been looking for the subject through the finder for a while is told that the
# camera can be lowered to search with the naked eye (with the key or button in use).
func update_hunt_hint(dt: float) -> void:
	var hunting = mode == "SEARCH" and not sandbox and is_instance_valid(target) and not (academy and academy.active) and not (tutorial and tutorial.active) and demo.is_empty() and photo_walk.is_empty() and walk_demo < 0
	if not hunting or not eye_ready():
		hunt_time = 0.0
		if mode != "SEARCH": hunt_next = 30.0
		return
	# With the subject in the frame there is nothing to search for.
	if camera.is_position_in_frustum(target.global_position+Vector3.UP*target.height*.7):
		hunt_time = 0.0
		return
	hunt_time += dt
	if hunt_time >= hunt_next:
		hunt_time = 0.0
		hunt_next = 75.0
		notify_player(Texts.get_text("pista_bajar_camara"))
		toast_time = 8.0

# Pause (Esc, the on-screen button or Menu/Start): carry on, the help, or leave the phase for the
# main menu after a confirmation (docs/futuro/22 §4).
func show_pause(confirm = false) -> void:
	if academy and academy.active and not confirm:
		show_lesson_menu()
		return
	mode = "PAUSE"
	play_sfx("pausa",-4.0)
	var root = create_modal()
	label(root,Texts.get_text("pausa_titulo"),Rect2(440,190,400,60),40)
	if not confirm:
		button(root,Texts.get_text("pausa_seguir"),Rect2(440,270 if Glyphs.touch else 280,400,56),resume_search,true)
		button(root,Texts.get_text("pausa_ayuda"),Rect2(440,350,400,56),show_help)
		button(root,Texts.get_text("pausa_salir"),Rect2(440,430 if Glyphs.touch else 420,400,56),func(): show_pause(true))
	else:
		var warn = label(root,Texts.get_text("pausa_confirmar"),Rect2(440,260,400,60),18,UiStyle.WARN)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button(root,Texts.get_text("pausa_no"),Rect2(440,340,400,56),resume_search,true)
		button(root,Texts.get_text("pausa_si"),Rect2(440,420 if Glyphs.touch else 410,400,56),leave_phase)

# Pause of a lesson of the Academy (Esc, the ✕ button, Menu on the gamepad): everything the panel
# offers, within reach of the gamepad too — carry on, next, back, pause the scene, leave.
func show_lesson_menu() -> void:
	mode = "PAUSE"
	var root = create_modal()
	label(root,Texts.get_text("academia_menu_titulo") % [academy.lesson,Texts.get_text(academy.lesson_key(academy.lesson,"titulo"))],Rect2(340,120,600,50),30)
	var entries = [[Texts.get_text("pausa_seguir"),resume_search],
		[academy.next_button.text,func(): resume_search(); academy.go_next()],
		[Texts.get_text("academia_atras"),func(): resume_search(); academy.go_back()],
		[Texts.get_text("academia_reanudar") if academy.paused else Texts.get_text("academia_pausar"),func(): resume_search(); academy.toggle_pause()],
		[Texts.get_text("academia_salir"),func(): academy.exit_lesson()]]
	for k in entries.size():
		var b = button(root,entries[k][0],Rect2(440,200+k*(76 if Glyphs.touch else 66),400,54),entries[k][1],k == 0)
		if k == 2 and academy.back_button.disabled: b.disabled = true

func leave_phase() -> void:
	if academy and academy.active: academy.stop()
	if tutorial and tutorial.active: tutorial.stop()
	if crowd: set_raised(false)
	intro()

func show_help() -> void:
	var previous = mode if mode != "HELP" else help_return
	help_return = previous
	mode = "HELP"
	var root = create_modal()
	if Glyphs.touch and Glyphs.device == "tactil":
		label(root,Texts.get_text("ayuda_titulo_tactil"),Rect2(65,40,1100,55),36,Color("b8d78c"))
		var gestures = label(root,Texts.get_text("ayuda_texto_tactil"),Rect2(65,120,1150,480),21)
		gestures.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif Glyphs.pad():
		# With a gamepad: the pad drawn with what every button does.
		label(root,Texts.get_text("ayuda_titulo_mando"),Rect2(65,40,1100,55),36,Color("b8d78c"))
		var diagram = preload("res://scripts/pad_diagram.gd").new()
		diagram.position = Vector2(40,110)
		diagram.size = Vector2(1200,500)
		root.add_child(diagram)
	else:
		# Keyboard and mouse: the keyboard drawn with the keys lit by group, and the mouse.
		label(root,Texts.get_text("ayuda_titulo_teclado"),Rect2(65,40,1100,55),36,Color("b8d78c"))
		var keyboard = preload("res://scripts/keyboard_diagram.gd").new()
		keyboard.position = Vector2(45,105)
		keyboard.size = Vector2(1200,520)
		root.add_child(keyboard)
	button(root,Texts.get_text("volver"),Rect2(965,628,250,53),func(): mode = help_return; intro() if help_return == "INTRO" else close_modal(),true)

var help_return = "SEARCH"
func _unhandled_input(event: InputEvent) -> void:
	if run_metrics: return
	# The pointer comes in window coordinates: bring it to the game's (see fit_frame()).
	if frame_offset != Vector2.ZERO and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
		event = event.duplicate()
		event.position -= frame_offset
	if crowd and mode == "SEARCH" and photographer_input(event): return
	# A demonstration of the Academy is running: the tutor drives. Only the lesson's own keys
	# (next, back, pause the scene) and the pause menu answer.
	if academy and academy.locks_input() and mode == "SEARCH":
		if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and academy.handle_key(event): return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: show_pause()
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START: show_pause()
		return
	if event is InputEventJoypadButton and event.pressed and mode == "SEARCH" and academy and academy.handle_key(event): return
	if event is InputEventJoypadButton and event.pressed and mode == "SEARCH" and event.is_action_pressed("camara_controles"):
		select_control(1)   # Tab / View: the next control in hand
		return
	if event is InputEventJoypadButton and pad_button(event): return
	# B on a screen goes back, as Escape does.
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B and mode != "SEARCH":
		var esc = InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		_unhandled_input(esc)
		return
	if event is InputEventJoypadButton and event.pressed and mode == "SEARCH" and event.is_action_pressed("camara_controles"):
		select_control(1)   # Tab / View: the next control in hand
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == "SEARCH" and academy and academy.handle_key(event): return
		if event.physical_keycode == KEY_Y and mode == "SEARCH" and not crowd and not (academy and academy.active):
			toggle_raise()
			return
		# I (it was F1, which a Mac keeps for the screen brightness and a browser for its own help;
		# F1 still works where it did).
		if event.physical_keycode in [KEY_I,KEY_F1] and mode == "SEARCH":
			control_help.set_enabled(not control_help.enabled)
			return
		if mode == "SEARCH" and event.is_action_pressed("camara_controles"):
			select_control(1)   # Tab / View: the next control in hand
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
			elif mode == "SEARCH": show_pause()
			elif mode == "PAUSE": resume_search()
			elif mode == "EQUIPMENT": restore_equipment_screen()
			elif mode in ["ARCADE","OPTIONS"]: intro()
			elif mode == "TUTORIAL_END":
				tutorial.stop()
				intro()
			elif mode == "BRIEFING": show_arcade() if arcade_level >= 0 else intro()
			# (These three had no way back but their own button: Escape, B and Android's «back» now do.)
			elif mode == "ALBUM":
				if album_viewing: show_album(album_page)
				else: intro()
			elif mode in ["BADGES","ACADEMY"]: intro()
			elif mode == "LEVEL_END": show_arcade()
			elif mode == "RESULT" and not (academy and academy.active): resume_search() if shots > 0 and not level_over else finish_assignment()
			return
		if event.keycode == KEY_ENTER:
			if mode == "RESULT": resume_search() if shots > 0 else finish_assignment()
			elif mode == "BRIEFING": begin_assignment()
			elif mode == "SEARCH" and tutorial and tutorial.handle_accept(): pass
			return
		if mode != "SEARCH": return
		# The control in hand: , . choose it, Page Up/Down change it (the wheel and the D-pad too).
		if event.unicode == 44: select_control(-1)
		elif event.unicode == 46: select_control(1)
		match event.physical_keycode:
			KEY_PAGEUP: change_control(1)
			KEY_PAGEDOWN: change_control(-1)
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
			KEY_G:
				if finder.golden: finder.golden = false
				else: finder.thirds = not finder.thirds
			KEY_K: wind_film()
			KEY_M: next_metering()
			KEY_B: toggle_lock()
			KEY_L:
				if equipment.tlr():
					tlr_loupe = not tlr_loupe
					play_sfx("lupa_tlr",-2.0)
					update_finder_shader()
					refresh()
		if event.keycode == KEY_QUESTION or event.physical_keycode == KEY_H: show_help()
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9: finder.active = event.physical_keycode-KEY_1
	if mode != "SEARCH": return
	# Touch interface: the fingers drive the view (below); the mouse events a touch emulates, or
	# the desktop mouse playing the finger, would move it twice.
	if Glyphs.touch and event is InputEventMouse and not (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]): return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var step = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			# The wheel changes the control in hand; with Shift it is the fine focus ring (shortcut).
			if event.shift_pressed and equipment.focus_mode == "MF": adjust_focus_delta(-step*.0012)
			else: change_control(step,3.4 if (event.ctrl_pressed or event.alt_pressed) else 1.0)
		if event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE: select_control(1)
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
				# The view follows the mouse on both axes (it used to drag the scene sideways but
				# follow the mouse vertically, which felt inverted).
				var pan_delta = event.relative.x*.065*24/view_focal()*look_sign().x
				angle = fposmod(angle+pan_delta,360)
				pitch -= event.relative.y*.065*24/view_focal()*look_sign().y
				pan_velocity = clampf(pan_delta*40,-80,80)
				update_camera()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			touch_start[event.index] = event.position
			touch_time[event.index] = total_time
			touch_held = false
			if touches.size() >= 2: had_multitouch = true
			pan_velocity = 0
		else:
			if touches.has(event.index) and touches.size() == 1 and not had_multitouch and not touch_held and event.position.distance_to(touch_start[event.index]) < 10: nearest_af(event.position)
			touches.erase(event.index)
			touch_start.erase(event.index)
			if touches.is_empty(): had_multitouch = false
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() == 1:
			# The finger drags the scene on both axes (vertically it used to go the other way round);
			# the «invert the look» option turns either axis.
			var pan_delta = -event.relative.x*.065*24/view_focal()*look_sign().x
			angle = fposmod(angle+pan_delta,360)
			pitch += event.relative.y*.065*24/view_focal()*look_sign().y
			pan_velocity = clampf(pan_delta*40,-80,80)
		else:
			var ids = touches.keys()
			var other = ids[0] if ids[1] == event.index else ids[1]
			var old_distance: float = touches[event.index].distance_to(touches[other])
			var new_distance: float = event.position.distance_to(touches[other])
			if old_distance > 10: focal = clampf(focal*new_distance/old_distance,equipment.lens().min,equipment.lens().max)
			# (Two fingers used to drag the focus too: it moved while zooming. Focus has its − +.)
		touches[event.index] = event.position
		update_camera()

func smoke_test() -> void:
	assert(people.size() == (GRANDE_PEOPLE if scenario == "grande" else 21))
	assert(target.protected_target)
	var triangles = park.triangle_count
	for p in people:
		assert(p.primary_bone_count == 20)
		# 2.000 per pedestrian in the base pieces (1.900 until the trench coat, whose tails need the sides not to let the hips through); 60.000 for the Blender mannequins with wig and clothes (docs/futuro/18).
		assert(p.triangle_count <= (60000 if Person.detail == "hd" else 2000),Texts.get_text("presupuesto_por_viandante"))
		triangles += p.triangle_count
	# Meadow extras (hd only) and the pigeons count towards the scene budget too.
	for p in extras.extras:
		assert(p.ambient and p.colliders.is_empty(),"Meadow extras must have no colliders")
		triangles += p.triangle_count
	triangles += pigeons.triangle_count()
	if ducks: triangles += ducks.triangle_count()
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
			if not outer.is_empty() and arcade_level < 0:   # an arcade level keeps its subject
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
	if demo.has("hold-turn") and is_instance_valid(target):
		var his_way = signf(target.actual_velocity.dot(camera.global_basis.x))
		if not demo.has("held") and target.state == "CAMINANDO" and target.actual_velocity.length() > 2.0 and demo_time > 1.0:
			# A third of the frame ahead of him, and still.
			demo["held"] = his_way
			demo["hold-from"] = demo_time+float(demo["hold-turn"])
			angle = rad_to_deg(atan2(target.position.x,-target.position.z))+float(target.direction)*rad_to_deg(2.0*atan(36.0/(2.0*focal)))*.55
			pitch = -rad_to_deg(atan((camera.global_position.y-target.control_points()[1].y)/maxf(1.0,camera.global_position.distance_to(target.control_points()[1]))))
		if demo.has("held") and demo_time >= float(demo["hold-from"]): demo_keys["turn"] = float(demo["held"])
	if demo.has("clock") and not demo.has("clocked") and arcade_level >= 0:
		demo["clocked"] = true
		level_time = float(demo["clock"])
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
	if demo.has("expose") and academy and academy.active and academy.phase == "examen" and not demo.has("shot") and demo_time > 4.5 and fmod(demo_time,.45) < dt:
		# Exam 1 on video: the needle is brought back to the centre, one click at a time.
		if academy.exam_needle() < -.5 and t_index < Photo.DENOMINATORS.size()-1:
			t_index += 1
			refresh()
	if demo.has("strip-demo") and demo_time > 4.6:
		# Capture helper: the control in hand at work — choose one, change it, choose the next.
		var beat = int((demo_time-4.6)/.7)
		if beat != int(demo.get("strip-beat",-1)):
			demo["strip-beat"] = beat
			var script = ["next","up","up","next","down","down","next","up","next","up","up","down","down"]
			var act: String = script[beat%script.size()]
			if act == "next": select_control(1)
			else: change_control(1 if act == "up" else -1)
	if demo.has("shutter") and not demo.has("shot"):
		var wanted_t = Photo.DENOMINATORS.find(int(demo["shutter"]))
		if wanted_t >= 0 and t_index != wanted_t:
			t_index = wanted_t
			refresh()
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
	t_index = maxi(t_index,fastest_index())
	lens_slider.min_value = equipment.lens().min
	lens_slider.max_value = equipment.lens().max
	if equipment.film: iso_index = equipment.film_iso_index
	if not equipment.focus_mode in equipment.focus_modes(): equipment.focus_mode = equipment.focus_modes()[0]
	update_camera()

func option(parent: Control, values: Array, selected: int, rect: Rect2, callback: Callable) -> OptionButton:
	var control = OptionButton.new()
	var shown = finger_rect(rect,TOUCH_OPTION) if rect.size.y >= 40 else rect
	control.position = shown.position
	control.size = shown.size
	control.add_theme_font_size_override("font_size",20)
	if Glyphs.touch:
		# The list that drops down: taller rows and bigger letters, to pick one with a finger.
		control.get_popup().add_theme_font_size_override("font_size",24)
		control.get_popup().add_theme_constant_override("v_separation",22)
	for value in values: control.add_item(str(value))
	control.select(selected)
	# Choosing rebuilds the screen: the same list keeps the focus (gamepad and keyboard), instead of
	# jumping back to the screen's main button after every change.
	var choose = func(i):
		option_refocus = rect.position
		callback.call(i)
	control.item_selected.connect(choose)
	# ← → change the value in place, without opening the list (D-pad or arrows).
	control.gui_input.connect(func(event):
		var step = (1 if event.is_action_pressed("ui_right") else 0)-(1 if event.is_action_pressed("ui_left") else 0)
		if step == 0: return
		control.accept_event()
		var next = clampi(control.selected+step,0,control.item_count-1)
		if next != control.selected:
			control.select(next)
			choose.call(next))
	control.add_theme_stylebox_override("focus",UiStyle.box(Color.TRANSPARENT,8,UiStyle.SKY,3))
	parent.add_child(control)
	if option_refocus.is_equal_approx(rect.position):
		option_refocus = Vector2(-1,-1)
		get_tree().process_frame.connect(func(): if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus(),CONNECT_ONE_SHOT)
	return control

var option_refocus = Vector2(-1,-1)

var equipment_return = "INTRO"
func show_equipment() -> void:
	if mode != "EQUIPMENT": equipment_return = mode
	mode = "EQUIPMENT"
	var root = create_modal()
	label(root,Texts.get_text("equipo_titulo"),Rect2(75,25,1100,60),38)
	if arcade_level >= 0 and not sandbox:
		# The arcade level fixes the camera: only the interface and the graphics can change.
		label(root,Texts.get_text("arcade_equipo_fijo"),Rect2(75,100,1100,30),18,Color("b8d78c"))
		label(root,Texts.get_text("arcade_camara_d") % [equipment.CAMERAS[equipment.body],equipment.lens().name],Rect2(75,150,1100,30),20)
		if equipment_return == "INTRO": button(root,Texts.get_text("equipo_graficos_s") % graphics_preset,Rect2(75,630,340,55),show_graphics_settings)
		button(root,Texts.get_text("equipo_volver"),Rect2(880,630,320,55),restore_equipment_screen,true)
		return
	for i in 4:
		button(root,Texts.get_text("equipo_preajuste_%d" % (i+1)),Rect2(75+i*285,95,270,52),func(): equipment.preset(i); apply_equipment(); show_equipment())
	label(root,Texts.get_text("equipo_manual"),Rect2(75,166,1100,35),24)
	label(root,Texts.get_text("equipo_camara"),Rect2(75,225,200,35),20)
	option(root,equipment.CAMERAS,equipment.body,Rect2(330,220,700,45),func(i): equipment.body = i; equipment.lens_index = 0; equipment.film = equipment.film or i == 3; apply_equipment(); show_equipment())
	label(root,Texts.get_text("equipo_objetivo"),Rect2(75,285,250,35),20)
	option(root,equipment.LENSES[equipment.body].map(func(l): return l.name),equipment.lens_index,Rect2(330,280,700,45),func(i): equipment.lens_index = i; apply_equipment(); show_equipment())
	label(root,Texts.get_text("equipo_enfoque"),Rect2(75,345,200,35),20)
	option(root,equipment.focus_modes(),equipment.focus_modes().find(equipment.focus_mode),Rect2(330,340,700,45),func(i): equipment.focus_mode = equipment.focus_modes()[i]; apply_equipment(); show_equipment())
	label(root,Texts.get_text("equipo_exposicion"),Rect2(75,405,250,35),20)
	option(root,["M","P","A","S"].map(func(m): return Texts.get_text("equipo_modo_"+m.to_lower())),["M","P","A","S"].find(equipment.exposure_mode()),Rect2(330,400,700,45),func(i): equipment.set_exposure_mode(["M","P","A","S"][i]); apply_equipment(); show_equipment())
	label(root,Texts.get_text("equipo_soporte"),Rect2(75,465,200,35),20)
	option(root,[Texts.get_text("equipo_digital"),Texts.get_text("equipo_carrete")],1 if equipment.film else 0,Rect2(330,460,700,45),func(i): equipment.film = i == 1; apply_equipment(); show_equipment())
	if equipment.film:
		label(root,Texts.get_text("equipo_pelicula"),Rect2(75,525,250,35),20)
		option(root,Photo.ISOS.map(func(iso): return "ISO %d" % iso),equipment.film_iso_index,Rect2(330,520,700,45),func(i): equipment.film_iso_index = i; apply_equipment(); show_equipment())
	if equipment_return == "INTRO": button(root,Texts.get_text("equipo_graficos_s") % graphics_preset,Rect2(75,630,340,55),show_graphics_settings)
	button(root,Texts.get_text("equipo_usar"),Rect2(880,630,320,55),restore_equipment_screen,true)


# Same realistic mannequins in every profile; the procedural wood and cloth patterns (a few
# instructions per pixel) are the only thing the two lowest profiles skip.
func apply_mannequin_graphics_preset(preset: String) -> void:
	var mat = Person.mannequin_material()
	if mat is ShaderMaterial: mat.set_shader_parameter("textured",bool(Graphics.settings(preset).patterns))

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

# ---- What is new (shown once after an update) ----
# Newest first: [version, how many points its text has (novedades_<version>_<k>), whether it
# changed the default graphics (then the player is advised to reset the graphics options)].
# Two or three points per version, only what a player notices. A new release adds its row here
# and its texts in textos/es/menu.md.
const VERSION_NOTES = [["0.4.0",3,false],["0.3.4",3,false],["0.3.3",3,false],["0.3.2",3,false],["0.3.1",3,true],["0.3.0",3,false],["0.2.0",3,false]]
var news: Array = []

static var version_override = ""     # -- --version-as=0.3.1: to try the news and the update notice
static func version() -> String:
	return version_override if version_override != "" else str(ProjectSettings.get_setting("application/config/version","0"))

# ---- Is there a newer version on itch.io? ----
# Asked once per launch, in the real game, to itch's public «latest version of a channel» address
# (the one its own updater uses: no key, no account, nothing about the player is sent). If the
# channel of this platform has a later version than this one, the menu says so with a button
# that opens the game's page. No answer, no network or an odd reply: nothing happens. Not in the
# browser, where the page always serves the latest (and the browser would block the request).
const ITCH_TARGET = "geese-bumps/photohacks"
const ITCH_PAGE = "https://geese-bumps.itch.io/photohacks"
# (Not on Android: the APK asks for no permissions at all, internet included — tests/test_export.gd
# keeps it so — and adding one is the user's decision.)
const ITCH_CHANNELS = {"Windows":"windows","Linux":"linux","macOS":"mac"}
var newer_version = ""
signal newer_version_found
func check_update() -> void:
	var channel = str(ITCH_CHANNELS.get(OS.get_name(),""))
	if channel == "": return
	var request = HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(func(result, code, _headers, body):
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200: return
		var data = JSON.parse_string(body.get_string_from_utf8())
		if not (data is Dictionary) or not data.has("latest"): return
		if version_number(str(data.latest)) > version_number(version()):
			newer_version = str(data.latest)
			newer_version_found.emit())
	if request.request("https://itch.io/api/1/x/wharf/latest?target=%s&channel_name=%s" % [ITCH_TARGET,channel]) != OK: request.queue_free()

static func version_number(v: String) -> int:
	var parts = v.split("-")[0].split(".")
	var n = 0
	for k in 3: n = n*1000+(int(parts[k]) if k < parts.size() else 0)
	return n

# Which versions to tell about: the ones after the last one this player opened, up to this one.
# Someone who already had the game but from before this notice existed (there is a settings file,
# and no version in it) is told from 0.3.1 on; a new player, nothing.
func check_version() -> void:
	var config = ConfigFile.new()
	var had = config.load("user://interfaz.cfg") == OK
	var seen = str(config.get_value("interfaz","version_vista","0.3.0" if had else version()))
	news = VERSION_NOTES.filter(func(row): return version_number(row[0]) > version_number(seen) and version_number(row[0]) <= version_number(version()))
	if news.is_empty(): mark_version_seen()

func mark_version_seen() -> void:
	news = []
	if version_override != "": return
	var config = ConfigFile.new()
	config.load("user://interfaz.cfg")
	config.set_value("interfaz","version_vista",version())
	config.save("user://interfaz.cfg")

# The graphics as on a first launch on this machine: the profile for its hardware, 60 FPS, vsync.
func reset_graphics() -> void:
	var config = ConfigFile.new()
	if config.load(override_path()) == OK and config.has_section_key("paparazzi","graficos/perfil"):
		config.erase_section_key("paparazzi","graficos/perfil")
		config.save(override_path())
	if ProjectSettings.has_setting(PROFILE_SETTING): ProjectSettings.set_setting(PROFILE_SETTING,null)
	Graphics.display.limit = 60
	Graphics.display.vsync = true
	Graphics.save_display()
	Graphics.apply_display(get_window())
	if fps_limited: Graphics.apply_fps_limit()
	apply_graphics_preset(startup_profile())

func startup_profile() -> String:
	if ProjectSettings.has_setting(PROFILE_SETTING): return str(ProjectSettings.get_setting(PROFILE_SETTING))
	if OS.has_feature("web"): return "Bajo"
	if OS.has_feature("mobile"): return "Medio"
	# First launch on desktop: Ultra on a dedicated GPU, Medio otherwise (it was Alto until a
	# MacBook Air could not hold 60 FPS with it: a laptop without a dedicated GPU, and often
	# without a fan, starts light and the player raises it if the machine can take it).
	return "Ultra" if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU else "Medio"

func save_profile(preset: String) -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"): return
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
const RENDER_LINES = {"Bajo":1080,"Medio":1080,"Alto":1440}

func update_render_resolution() -> void:
	var factor = 1.0
	if ParkScene.forward_plus():
		var window = Vector2(get_window().size)
		factor = maxf(1.0,minf(window.x/1280.0,window.y/720.0))
		# Full screen with a chosen resolution: the 3D image is rendered at that height and scaled
		# to fill the screen (place_view() already scales the container to the view).
		var limit = Graphics.fullscreen_height()
		if limit > 0: factor = clampf(limit/720.0,1.0,factor)
		# A high-density screen (a Retina laptop, a 4K panel) has three or four times the pixels
		# of the same window elsewhere: the lighter profiles do not follow it beyond RENDER_LINES
		# (the profile's own scale applies on top). Ultra and Personalizado draw every pixel.
		var lines = int(RENDER_LINES.get(graphics_preset,0))
		if lines > 0: factor = minf(factor,maxf(1.0,lines/720.0))
	viewport.size = Vector2i(roundi(1280*factor),roundi(720*factor))
	viewport_container.stretch = false
	viewport_container.size = Vector2(viewport.size)
	render_factor = factor
	place_view()

func apply_graphics_preset(preset: String) -> void:
	graphics_preset = preset
	if park: park.apply_graphics_preset(preset)
	# FXAA smooths the mannequins' ink lines and the scene edges without the memory of MSAA (VRAM < 60 MiB).
	var g: Dictionary = Graphics.settings(preset)
	if is_instance_valid(viewport):
		var forward = ParkScene.forward_plus()
		var scale = float(g.scale) if forward else 1.0
		# Forward+: the profile's table decides (scripts/graphics.gd). Below 100 % an upscaler fills
		# the window (FSR 2 also antialiases); above it the scene is supersampled. gl_compatibility: FXAA.
		viewport.scaling_3d_scale = scale
		var upscaler = {"fsr1":Viewport.SCALING_3D_MODE_FSR,"bilinear":Viewport.SCALING_3D_MODE_BILINEAR}.get(g.upscaler,Viewport.SCALING_3D_MODE_FSR2)
		viewport.scaling_3d_mode = upscaler if forward and scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		# FSR 2 is temporal and does its own antialiasing: MSAA and TAA only at native or above.
		var temporal = forward and scale < 1.0 and upscaler == Viewport.SCALING_3D_MODE_FSR2
		viewport.msaa_3d = {2:Viewport.MSAA_2X,4:Viewport.MSAA_4X,8:Viewport.MSAA_8X}.get(int(g.msaa),Viewport.MSAA_DISABLED) if forward and not temporal else Viewport.MSAA_DISABLED
		viewport.use_taa = forward and bool(g.taa) and not temporal
		if forward: viewport.screen_space_aa = {"fxaa":Viewport.SCREEN_SPACE_AA_FXAA,"smaa":Viewport.SCREEN_SPACE_AA_SMAA}.get(g.screen_aa,Viewport.SCREEN_SPACE_AA_DISABLED)
		else: viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if preset != "Bajo" else Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.positional_shadow_atlas_size = int(g.lamp_atlas) if forward else 2048
		viewport.use_debanding = forward
		viewport.mesh_lod_threshold = float(g.lod)
		viewport.anisotropic_filtering_level = {2:Viewport.ANISOTROPY_2X,4:Viewport.ANISOTROPY_4X,8:Viewport.ANISOTROPY_8X,16:Viewport.ANISOTROPY_16X}.get(int(g.aniso),Viewport.ANISOTROPY_DISABLED)
		update_render_resolution()
	update_dof_pass()
	# Bajo skips the lens character, but the camera finders (07 §1) still need the shader.
	if is_instance_valid(viewport_container): viewport_container.material = lens_material
	if lens_material: lens_material.set_shader_parameter("lens_off",not bool(g.lens))
	update_lens_effects()
	apply_debug_off()
	apply_mannequin_graphics_preset(preset)
	pass
	if is_instance_valid(graphics_button_intro):
		graphics_button_intro.text = Texts.get_text("menu_graficos_s") % graphics_preset

func gfx_label(value: String) -> String:
	return Texts.get_text(value.trim_prefix("@")) if value.begins_with("@") else value

# Graphics screen (docs/futuro/23): the four profiles and Personalizado, where every parameter is
# set by hand; and the display (window mode, size, vsync), common to every profile.
func show_graphics_settings() -> void:
	if mode != "GRAPHICS": graphics_return = mode
	mode = "GRAPHICS"
	var root = create_modal()
	label(root,Texts.get_text("gfx_titulo"),Rect2(60,18,500,46),34)
	if not ParkScene.forward_plus():
		show_light_graphics(root)
		return
	var sub = label(root,Texts.get_text("gfx_subtitulo"),Rect2(60,62,1160,24),14,Color("b5c3ad"))
	label(root,Texts.get_text("gfx_perfil"),Rect2(60,96,200,18),12,Color("b8d78c"))
	var names = ["Bajo","Medio","Alto","Ultra",Graphics.CUSTOM]
	for i in names.size():
		var pname: String = names[i]
		var active = graphics_preset == pname
		button(root,("✓ " if active else "")+(Texts.get_text("gfx_personalizado") if Graphics.is_custom(pname) else pname),Rect2(60+i*232,116,220,44),func():
			if Graphics.is_custom(pname) and not Graphics.has_saved_custom(): Graphics.copy_to_custom(graphics_preset if not Graphics.is_custom(graphics_preset) else "Ultra")
			select_graphics_profile(pname)
			show_graphics_settings()
		,active)
	# Display: any profile.
	label(root,Texts.get_text("gfx_pantalla"),Rect2(60,172,200,18),12,Color("b8d78c"))
	var d = Graphics.display
	var yes_no = [Texts.get_text("gfx_si"),Texts.get_text("gfx_no")]
	var limits = Graphics.FPS_LIMITS.map(func(v): return Texts.get_text("gfx_no") if v == 0 else str(v))
	var limit_at = maxi(0,Graphics.FPS_LIMITS.find(int(d.get("limit",60))))
	if OS.has_feature("web") or OS.has_feature("mobile"):   # (no window to set in a browser or on a phone)
		label(root,Texts.get_text("gfx_limite"),Rect2(60,194,100,30),14)
		option(root,limits,limit_at,Rect2(160,190,84,36),func(i): set_display("limit",Graphics.FPS_LIMITS[i]))
		label(root,Texts.get_text("gfx_fps"),Rect2(264,194,60,30),14)
		option(root,yes_no,0 if d.get("fps",false) else 1,Rect2(324,190,76,36),func(i): set_display("fps",i == 0))
	else:
		# (No label for the first one: «Ventana», «Pantalla completa»… under «Pantalla» say it.)
		option(root,Graphics.WINDOW_MODES.map(func(c): return gfx_label(c[0])),maxi(0,Graphics.WINDOW_MODES.map(func(c): return c[1]).find(d.mode)),Rect2(60,190,300,36),func(i): set_display("mode",Graphics.WINDOW_MODES[i][1]))
		label(root,Texts.get_text("gfx_resolucion" if d.mode == "ventana" else "gfx_resolucion_imagen"),Rect2(382,194,153,30),14)
		# In a window: its size. In full screen: the resolution of the image (or the screen's own).
		var size_choices = Graphics.WINDOW_SIZES if d.mode != "ventana" else Graphics.WINDOW_SIZES.slice(1)
		option(root,size_choices.map(func(c): return gfx_label(c[0])),maxi(0,size_choices.map(func(c): return c[1]).find(d.size)),Rect2(536,190,154,36),func(i): set_display("size",size_choices[i][1]))
		label(root,Texts.get_text("gfx_vsync"),Rect2(702,194,92,30),14)
		option(root,yes_no,0 if d.vsync else 1,Rect2(794,190,76,36),func(i): set_display("vsync",i == 0))
		label(root,Texts.get_text("gfx_limite"),Rect2(882,194,92,30),14)
		option(root,limits,limit_at,Rect2(974,190,84,36),func(i): set_display("limit",Graphics.FPS_LIMITS[i]))
		label(root,Texts.get_text("gfx_fps"),Rect2(1070,194,58,30),14)
		option(root,yes_no,0 if d.get("fps",false) else 1,Rect2(1128,190,76,36),func(i): set_display("fps",i == 0))
	for o in [sub]: o.autowrap_mode = TextServer.AUTOWRAP_OFF
	var body = panel(root,Rect2(60,240,1160,372),Color(.075,.115,.085,.91))
	if not Graphics.is_custom(graphics_preset):
		# A profile: what it is and its values, read from the same table Personalizado edits.
		label(body,Texts.get_text("gfx_desc_"+graphics_preset),Rect2(24,16,1110,44),16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var g = Graphics.settings(graphics_preset)
		var k = 0
		for opt in Graphics.OPTIONS:
			var text_value = gfx_label(opt[2][Graphics.choice_index(opt,g[opt[0]])][0])
			if opt[0] == "sdfgi": text_value = gfx_label("@gfx_no") if ParkScene.sdfgi_cascades(graphics_preset) == 0 else str(ParkScene.sdfgi_cascades(graphics_preset))
			label(body,Texts.get_text(opt[1])+": "+text_value,Rect2(24+(k%2)*560,70+(k/2)*21,540,20),13,Color("b7c5ad"))
			k += 1
		if RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU and ParkScene.forward_plus():
			label(body,Texts.get_text("gfx_integrada"),Rect2(24,346,1110,20),13,UiStyle.WARN)
	else:
		# Personalizado: every parameter by hand, in a scrolling list of two columns.
		label(body,Texts.get_text("gfx_copiar"),Rect2(24,12,90,28),14)
		for i in 4:
			var base: String = names[i]
			button(body,base,Rect2(114+i*96,8,88,32),func():
				Graphics.copy_to_custom(base)
				select_graphics_profile(Graphics.CUSTOM)
				show_graphics_settings())
		label(body,Texts.get_text("gfx_aviso"),Rect2(520,14,620,24),13,UiStyle.WARN)
		var scroll = ScrollContainer.new()
		scroll.position = Vector2(16,48)
		scroll.size = Vector2(1132,316)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true   # the D-pad walks the list and it scrolls along
		body.add_child(scroll)
		var list = Control.new()
		scroll.add_child(list)
		var g = Graphics.settings(Graphics.CUSTOM)
		var y = 0.0
		var column = 0
		var group = ""
		for opt in Graphics.OPTIONS:
			if opt[3] != group:
				group = opt[3]
				if column == 1: y += 40
				column = 0
				label(list,Texts.get_text(group),Rect2(8,y+4,400,18),12,Color("b8d78c"))
				y += 24
			var x = 8+column*560
			label(list,Texts.get_text(opt[1]),Rect2(x,y+6,340,24),14)
			var key: String = opt[0]
			var choices: Array = opt[2]
			var ob = option(list,choices.map(func(c): return gfx_label(c[0])),Graphics.choice_index(opt,g[key]),Rect2(x+345,y,190,34),func(i):
				Graphics.set_custom(key,choices[i][1])
				apply_graphics_preset(Graphics.CUSTOM)
				if park: park.update_lamp_shadows())
			ob.add_theme_font_size_override("font_size",15)
			column += 1
			if column == 2:
				column = 0
				y += 40
		if column == 1: y += 40
		list.custom_minimum_size = Vector2(1110,y+8)
	button(root,Texts.get_text("gfx_volver"),Rect2(900,626,320,52),leave_graphics,true)

func leave_graphics() -> void:
	mode = graphics_return
	match graphics_return:
		"INTRO": intro()
		"RESULT": show_results()
		"BRIEFING": show_assignment()
		"EQUIPMENT": show_equipment()
		_: close_modal()
	refresh()

# The graphics screen of the light renderer (phone, tablet, browser): the Forward+ parameters of
# the desktop mean nothing there, so only what does something is offered, and big enough for a
# finger: the profile (shadows, smoothing, detail), the frame limit and the frame counter.
func show_light_graphics(root: Control) -> void:
	label(root,Texts.get_text("gfx_subtitulo_ligero"),Rect2(60,70,1160,52),18,Color("b5c3ad")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(root,Texts.get_text("gfx_perfil"),Rect2(60,150,200,22),15,Color("b8d78c"))
	var names = ["Bajo","Medio","Alto","Ultra"]
	if Graphics.is_custom(graphics_preset): graphics_preset = "Medio"
	for i in names.size():
		var pname: String = names[i]
		var active = graphics_preset == pname
		button(root,("✓ " if active else "")+pname,Rect2(60+i*292,180,276,76),func():
			select_graphics_profile(pname)
			show_graphics_settings()
		,active).add_theme_font_size_override("font_size",22)
	label(root,Texts.get_text("gfx_pantalla"),Rect2(60,300,200,22),15,Color("b8d78c"))
	var d = Graphics.display
	var limits = Graphics.FPS_LIMITS.map(func(v): return Texts.get_text("gfx_no") if v == 0 else str(v))
	label(root,Texts.get_text("gfx_limite"),Rect2(60,348,170,34),22)
	option(root,limits,maxi(0,Graphics.FPS_LIMITS.find(int(d.get("limit",60)))),Rect2(236,334,150,64),func(i): set_display("limit",Graphics.FPS_LIMITS[i])).add_theme_font_size_override("font_size",24)
	label(root,Texts.get_text("gfx_fps"),Rect2(450,348,110,34),22)
	option(root,[Texts.get_text("gfx_si"),Texts.get_text("gfx_no")],0 if d.get("fps",false) else 1,Rect2(560,334,130,64),func(i): set_display("fps",i == 0)).add_theme_font_size_override("font_size",24)
	button(root,Texts.get_text("gfx_volver"),Rect2(900,616,320,70),leave_graphics,true)

# Frames per second, top left over everything (Graphics.display.fps): the average of the last
# half second and its frame time.
var fps_counter: Label
var fps_time = 0.0
var fps_frames = 0
func update_fps_counter(dt: float) -> void:
	var show = bool(Graphics.display.get("fps",false))
	if not show:
		if is_instance_valid(fps_counter): fps_counter.visible = false
		return
	if not is_instance_valid(fps_counter):
		var layer = CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		frame_layer(layer)
		fps_counter = Label.new()
		# Upright along the left edge, half-way up: every corner holds something of some screen
		# (the HUD's title, its sliders, the chips of the finder).
		fps_counter.position = Vector2(3,600 if Glyphs.touch else 300)
		fps_counter.rotation = -PI/2
		fps_counter.add_theme_font_size_override("font_size",12)
		fps_counter.add_theme_color_override("font_color",Color(.6,1,.6))
		fps_counter.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
		fps_counter.add_theme_constant_override("shadow_offset_x",1)
		fps_counter.add_theme_constant_override("shadow_offset_y",1)
		fps_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(fps_counter)
	fps_counter.visible = true
	fps_time += dt
	fps_frames += 1
	if fps_time >= .5:
		fps_counter.text = "%d FPS · %.1f ms" % [roundi(fps_frames/fps_time),1000.0*fps_time/fps_frames]
		# On a phone, where the time goes (docs/futuro/26 C1): the scripts of a frame, the physics
		# and what is drawn. Read it out to know whether the CPU or the GPU holds the game back.
		if Glyphs.touch: fps_counter.text += " · CPU %.1f · fís %.1f · %d dib · %dk tri" % [Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)/1000)]
		fps_time = 0.0
		fps_frames = 0

var fps_limited = false
func set_display(key: String, value) -> void:
	Graphics.display[key] = value
	Graphics.save_display()
	if fps_limited: Graphics.apply_fps_limit()
	Graphics.apply_display(get_window())
	update_render_resolution.call_deferred()
	show_graphics_settings.call_deferred()

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
			if not play_sfx("anillo_enfoque",-2.0,randf_range(.94,1.06)): play_tone(1800, 0.015)
		set_manual_focus(INF if new_diop <= 0.0005 else 1.0/new_diop)

func adjust_focus(step: int) -> void:
	adjust_focus_delta(-step * 0.004)

func update_focus_aid(dt: float) -> void:
	if equipment.focus_mode != "MF" or mode != "SEARCH" or not eye_ready():
		focus_aid.visible = false
		if is_instance_valid(finder): finder.mf_coincidence = false
		return
	focus_aid.visible = not tlr_loupe
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
	var depth = Photo.dof(focal, aperture_value(), focus_distance)
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

# Light (EV) of whatever is under a point of the viewfinder: never the assignment's subject as
# such (docs/futuro/12 §2.1), only what the ray finds there, or the sky.
func ev_under(point: Vector2) -> float:
	var hit = point_hit(point)
	if hit.is_empty(): return park.sky_ev(time_of_day)
	# A person is read at the chest, where the photo is judged: with the sun low, the point under
	# the meter could be a leg in the shadow of a hedge while the chest was in the sun, and the
	# camera exposed for the shadow.
	if hit.collider.has_meta("person"):
		var who = hit.collider.get_meta("person")
		if is_instance_valid(who) and who.has_method("control_points"): return park.illumination_ev(who.control_points()[1],time_of_day,who)
	return park.illumination_ev(hit.position,time_of_day,null)

# Metering modes (docs/futuro/12 §3). Spot: under the active focus point. Centre-weighted: 75 % for
# the centre of the frame (the centre and a ring round it) and 25 % for the periphery. Matrix: 5 × 5
# zones, the zone of the active point counts 2.5 times and zones far brighter than the rest (the
# sky) count a quarter. With the exposure locked (AE-L) the reading stays as it was.
# How much the zone of the active focus point counts in the matrix (the other 24 count 1 each).
# It was 2.5; since matrix metering is the norm it is tied to the focus point, as the evaluative
# metering of a real camera is: three fifths of the reading are the subject. With 2.5, an
# automatic camera left a subject in the sun a whole stop too bright, and the Academy's exposure
# exam could not be passed by centring the needle. Spot is still the exact one, and the lesson
# on metering still shows the difference.
const MATRIX_SUBJECT = 144.0   # (six sevenths of the reading; 36 until 06-10-2026)
const MATRIX_SUBJECT_ACADEMY = 36.0   # (the lesson on metering shows how the modes differ)
func update_meter() -> void:
	if exposure_locked: return
	var active: Vector2 = finder.points()[finder.active]
	match equipment.metering:
		"ponderada":
			var total = .3*ev_under(view_point(Vector2(.5,.5)))
			for k in 4: total += .1125*ev_under(view_point(Vector2(.5,.5)+Vector2.from_angle(k*PI*.5+PI*.25)*Vector2(.14,.2)))
			for k in 8: total += .03125*ev_under(view_point(Vector2(.5,.5)+Vector2.from_angle(k*PI*.25)*Vector2(.4,.4)))
			measured_ev = total
		"matricial":
			var readings = []
			var weights = []
			var mean = 0.0
			for row in 5:
				for col in 5:
					var at = view_point(Vector2((col+.5)/5.0,(row+.5)/5.0))
					var cell = Rect2(finder.view.position+finder.view.size*Vector2(col/5.0,row/5.0),finder.view.size/5.0)
					# The zone of the focus point is read at the point itself: its centre could fall
					# beside a subject that is narrower than the zone, and read the background.
					readings.append(ev_under(active if cell.has_point(active) else at))
					weights.append((MATRIX_SUBJECT_ACADEMY if academy and academy.active else MATRIX_SUBJECT) if cell.has_point(active) else 1.0)
					mean += readings[-1]/25.0
			var total = 0.0
			var weight_sum = 0.0
			for k in readings.size():
				var w: float = weights[k]*(.25 if readings[k] > mean+3.0 else 1.0)
				total += readings[k]*w
				weight_sum += w
			measured_ev = total/weight_sum
		_:
			measured_ev = ev_under(active)

func view_point(fraction: Vector2) -> Vector2:
	return finder.view.position+finder.view.size*fraction

# AF-L / AE-L (docs/futuro/12 §4.1): focus and meter on what is under the active point, then keep
# both while recomposing; the next photo (or the key again) releases them.
var exposure_locked = false
var focus_locked = false
func toggle_lock() -> void:
	if mode != "SEARCH": return
	if exposure_locked or focus_locked:
		release_lock()
		notify_player(Texts.get_text("bloqueo_suelto"))
		refresh()
		return
	if equipment.focus_mode != "MF": autofocus()
	update_meter()
	if equipment.auto_exposure: auto_expose()
	exposure_locked = true
	focus_locked = equipment.focus_mode != "MF"
	notify_player(Texts.get_text("bloqueo_puesto") % [Texts.get_text("infinito") if is_inf(focus_distance) else Texts.get_text("2f_m") % focus_distance,measured_ev])
	if not play_sfx("bloqueo",-6.0): play_tone(1320,.06)
	refresh()

func release_lock() -> void:
	exposure_locked = false
	focus_locked = false

func next_metering() -> void:
	if mode != "SEARCH": return
	equipment.next_metering()
	play_sfx("medicion",-2.0)
	release_lock()
	update_meter()
	if equipment.auto_exposure: auto_expose()
	notify_player(Texts.get_text("fotometria_cambiada") % Texts.get_text("fotometria_"+equipment.metering))
	refresh()

# What the automatic exposure counts as a miss. Outside the Academy the thirds trim what is left
# (trim_exposure()), so anything within a third of a stop is as good as exact and the camera
# chooses among those by its preferences (hand-held shutter, low ISO, open aperture): counting
# every hundredth, the names of the stops (f/22 is not exactly f/22.6) decided, and the program
# went for f/22 at 1/60 s in full sun.
func exposure_miss(delta: float) -> float:
	return delta if academy and academy.active else maxf(0.0,delta-.34)

# Correct exposure for a given scene EV (same criteria as auto_expose()).
func expose_for(scene_ev: float) -> void:
	var target_ev = scene_ev-equipment.exposure_compensation()
	var best_cost = INF
	var stops = apertures()
	for n in stops.size():
		for t in range(fastest_index(),Photo.DENOMINATORS.size()):
			for iso in ([equipment.film_iso_index] if equipment.film else range(Photo.ISOS.size())):
				var delta = absf(Photo.ev(stops[n],1.0/Photo.DENOMINATORS[t],Photo.ISOS[iso],target_ev))
				var cost = exposure_miss(delta)*10 + maxf(0,focal/Photo.DENOMINATORS[t]-1)*2 + iso*.12 + n*.03
				if cost < best_cost:
					best_cost = cost
					n_index = n
					t_index = t
					iso_index = iso
	trim_exposure(target_ev)

func auto_expose() -> void:
	var target_ev = measured_ev-equipment.exposure_compensation()
	var best_cost = INF
	var stops = apertures()
	# Aperture or shutter priority: the player's choice stays, the camera sets the rest.
	var n_range = [n_index] if equipment.priority == "A" else range(stops.size())
	var t_range = [t_index] if equipment.priority == "S" else range(fastest_index(),Photo.DENOMINATORS.size())
	for n in n_range:
		for t in t_range:
			for iso in ([equipment.film_iso_index] if equipment.film else range(Photo.ISOS.size())):
				# (the dial the player holds may be on a third)
				var f_number = aperture_value() if equipment.priority == "A" else stops[n]
				var denominator = shutter_denominator() if equipment.priority == "S" else Photo.DENOMINATORS[t]
				var delta = absf(Photo.ev(f_number,1.0/denominator,Photo.ISOS[iso],target_ev))
				var cost = exposure_miss(delta)*10 + maxf(0,focal/denominator-1)*2 + iso*.12 + n*.03
				if cost < best_cost:
					best_cost = cost
					n_index = n
					t_index = t
					iso_index = iso
	trim_exposure(target_ev)

const LANES = [1.8,4.0,7.0,11.5]
const LANE_OFFSETS = [0.33,0.35,0.35,0.35]
const LANE_BOUNDS = [Vector2(1.05,2.7), Vector2(2.9,4.85), Vector2(6.1,7.9), Vector2(10.6,12.4)]
# Called once or twice per pedestrian per frame, it was the dearest thing in the navigation: it
# made a new shape, a new query and a new list of people every time, and measured everyone against
# the step. Now the shape and the query are reused (only the height changes), the list is made
# once per frame (everybody()) and whoever is too far for the step to reach is skipped before any
# geometry. The answers are the same ones (tools/measure_flow.gd gives the same figures).
var clear_shape: CapsuleShape3D
var clear_query: PhysicsShapeQueryParameters3D
var everybody_list: Array = []
var everybody_frame = -1
func everybody() -> Array:
	var frame = Engine.get_process_frames()
	if frame != everybody_frame or everybody_list.size() != people.size()+(1 if player_proxy else 0):
		everybody_frame = frame
		everybody_list = people+([player_proxy] if player_proxy else [])
		# Where each one was when this round began: a cheap first sieve for the loops that measure
		# everyone against everyone (nobody moves as much as NEAR_SLACK in one round).
		everybody_at.resize(everybody_list.size())
		for i in everybody_list.size(): everybody_at[i] = everybody_list[i].position
	return everybody_list
var everybody_at = PackedVector3Array()
const NEAR_SLACK = 1.0

func travel_clear(p: Pedestrian, from: Vector3, to: Vector3, static_check = true) -> bool:
	# A swept body volume avoids stepping through benches, trunks and other people.
	if static_check:
		if clear_shape == null:
			clear_shape = CapsuleShape3D.new()
			clear_shape.radius = .30
			clear_query = PhysicsShapeQueryParameters3D.new()
			clear_query.shape = clear_shape
			clear_query.collision_mask = 2
		clear_shape.height = p.height
		clear_query.transform = Transform3D(Basis.IDENTITY,from+Vector3.UP*(p.height*.5))
		clear_query.motion = to-from
		var space = viewport.world_3d.direct_space_state
		if not space.intersect_shape(clear_query,1).is_empty(): return false
		if space.cast_motion(clear_query)[0] < 1.0: return false
	# Nobody further than this from the start can be nearer than HARD_SPACE to any point of the step.
	var reach = HARD_SPACE+from.distance_to(to)+.01
	var reach_sq = reach*reach
	var list = everybody()
	var sieve = (reach+NEAR_SLACK)*(reach+NEAR_SLACK)
	for i in list.size():
		if from.distance_squared_to(everybody_at[i]) > sieve: continue
		var other = list[i]
		if other == p or not other.visible: continue
		if from.distance_squared_to(other.position) > reach_sq: continue
		var nearest = Geometry3D.get_closest_point_to_segment(other.position,from,to)
		var near_dist = nearest.distance_to(other.position)
		if near_dist < HARD_SPACE:
			var d_from = from.distance_to(other.position)
			var d_to = to.distance_to(other.position)
			if d_to >= d_from - 0.0005:
				continue
			return false
	return true

const HARD_SPACE = .52          # two people never come closer than this (centre to centre)
const LANE_CAPACITIES = [3, 7, 7, 6]
# Seconds until a runner of that path reaches the angle theta (INF if none will soon).
func runner_due(lane: int, theta: float) -> float:
	var due = INF
	for q in people:
		if not q.runner or not q.visible or q.state != "CAMINANDO" or q.lane != lane: continue
		var ahead = deg_to_rad(fposmod((theta-q.theta)*q.direction,360.0))*q.radius
		due = minf(due,ahead/maxf(q.v_fwd,1.0))
	return due

func try_change_lane(p: Pedestrian) -> bool:
	if p.destination_lane >= 0: return true
	# Runners keep to their path.
	if p.runner: return false
	var choices = range(LANES.size())
	choices.sort_custom(func(a,b): return absf(LANES[a]-p.radius) < absf(LANES[b]-p.radius))
	for lane in choices:
		if lane == p.lane or is_equal_approx(LANES[lane],p.radius): continue
		var in_lane = 0
		for other in people:
			if (other.lane == lane or other.destination_lane == lane) and other.visible: in_lane += 1
		if in_lane >= LANE_CAPACITIES[lane]: continue
		# Crossing a path takes a few seconds: not in front of a runner.
		if runner_due(lane,p.theta) < 7.0 or runner_due(p.lane,p.theta) < 4.0: continue
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
	label(root,Texts.get_text("encargo_titulo"),Rect2(65,40,1120,65),42)
	if arcade_level >= 0:
		label(root,Texts.get_text("arcade_nivel_d") % (arcade_level+1)+" · "+level_title(arcade_level),Rect2(65,115,1100,30),16,Color("b8d78c"))
	else:
		label(root,Texts.get_text("encargo_numero_d") % (assignment+1),Rect2(65,115,1100,30),16,Color("b8d78c"))
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
	if arcade_level >= 0:
		show_level_briefing(root)
		return
	rich_label(root,plain_bb(Texts.get_text("encargo_busca"))+"\n\n"+dotted(Array(casting.descriptors(target.traits))),Rect2(565,190,640,285),24)
	label(root,Texts.get_text("encargo_corredor") if target.runner else Texts.get_text("encargo_recuerda"),Rect2(565,505,635,65),18,Color("b8d78c")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(root,Texts.get_text("entrar_fase"),Rect2(750,625,455,60),begin_assignment,true)
	button(root,Texts.get_text("encargo_menu"),Rect2(565,625,165,60),intro)

# Arcade briefing: who, then the level's rules (camera, shots, time, pass mark, conditions).
func show_level_briefing(root: Control) -> void:
	var level: Dictionary = Arcade.LEVELS[arcade_level]
	rich_label(root,plain_bb(Texts.get_text("arcade_nivel_%d_texto" % (arcade_level+1)))+"\n[font_size=8] [/font_size]\n"+dotted(Array(casting.descriptors(target.traits))),Rect2(565,160,640,220),18)
	var rules = [Texts.get_text("arcade_camara_d") % [equipment.CAMERAS[equipment.body],equipment.lens().name],
		(Texts.get_text("arcade_un_disparo") if level.shots == 1 else Texts.get_text("arcade_disparos_d") % level.shots)+" · "+(Texts.get_text("arcade_tiempo_d") % level.limit if level.limit > 0 else Texts.get_text("arcade_sin_tiempo"))+" · "+Texts.get_text("arcade_nota_minima_d") % level.min]
	label(root,"\n".join(rules),Rect2(565,385,640,50),16,Color("b5c3ad")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(root,Texts.get_text("arcade_condiciones"),Rect2(565,442,640,24),15,Color("b8d78c"))
	var conds = []
	for key in level.cond: conds.append(Conditions.describe(key,level.cond[key]))
	if Arcade.clouds(arcade_level): conds.append(Texts.get_text("arcade_aviso_nubes"))
	if Arcade.manual_exposure(arcade_level) and not exposure_thirds: conds.append(Texts.get_text("arcade_aviso_tercios"))
	if level.cond.has("barrido") and not Glyphs.pad() and Glyphs.device != "tactil": conds.append(Texts.get_text("arcade_aviso_barrido"))
	rich_label(root,dotted(conds) if not conds.is_empty() else plain_bb(Texts.get_text("arcade_sin_condiciones")),Rect2(565,468,640,140),18)
	button(root,Texts.get_text("arcade_empezar"),Rect2(750,625,455,60),begin_assignment,true)
	button(root,Texts.get_text("arcade_niveles"),Rect2(565,625,165,60),show_arcade)

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
# The Academy plays itself from the first lesson to the last (or <first>-<last>) and the game
# closes: what the video of the whole Academy records.
func play_academy() -> void:
	academy_player = preload("res://scripts/academy_player.gd").new(academy)
	academy_player.page_seconds = float(academy_play.get_slice(":",0))
	var span = academy_play.get_slice(":",1) if ":" in academy_play else ""
	var first = int(span.get_slice("-",0)) if span != "" else 1
	var last = int(span.get_slice("-",1)) if "-" in span else (first if span != "" else academy.LESSONS)
	await academy_player.run(first,last)
	get_tree().quit()

func show_academy() -> void:
	if academy.active: academy.stop()
	mode = "ACADEMY"
	var root = create_modal()
	label(root,Texts.get_text("academia_titulo"),Rect2(75,30,1100,52),36,Color("e6ebdb"))
	var sub = label(root,Texts.get_text("academia_subtitulo"),Rect2(75,86,1100,50),18,Color("b7c5ad"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# One compact row per lesson, in a list that scrolls: the ten there are and the ones to come.
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(75,128)
	scroll.size = Vector2(1146,488 if Glyphs.touch else 498)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	root.add_child(scroll)
	var rows = Control.new()
	scroll.add_child(rows)
	var soon = 5
	# Under a finger the rows are tall enough to hit their buttons (the list scrolls by dragging).
	var st = 82 if Glyphs.touch else 49
	var rh = st-4
	var mid = (rh-45)/2
	var title_size = 22 if Glyphs.touch else 18
	for n in range(1,academy.LESSONS+1):
		var y = (n-1)*st
		panel(rows,Rect2(0,y,1130,rh),Color(.075,.115,.085,.95))
		label(rows,"%d" % n,Rect2(13,y+6+mid,44,34),24,Color("b8d78c")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label(rows,Texts.get_text(academy.lesson_key(n,"titulo")),Rect2(65,y+2+mid*.5,440,30),title_size,Color("e6ebdb"))
		label(rows,Texts.get_text(academy.lesson_key(n,"resumen")),Rect2(65,y+25+mid*1.5,440,22),15 if Glyphs.touch else 12,Color("a9b8a0"))
		var columns = [515,587,699,781]
		var marks: Array = academy.PHASES+["examen"]
		for k in marks.size():
			var ph: String = marks[k]
			var ok = academy.done(n,ph)
			label(rows,"%s %s" % [Texts.get_text("academia_hecho") if ok else Texts.get_text("academia_pendiente"),Texts.get_text("academia_fase_"+ph)],Rect2(columns[k],y+12+mid,112,22),13,Color("b8d78c") if ok else Color("8f9f86"))
		# First the lesson, then its exam — and no exam before the theory has been read.
		var started = academy.done(n,"teoria")
		var first = n == 1 if academy.practices_done() == 0 and not academy.done(1,"teoria") else (not started and (n == 1 or academy.done(n-1,"teoria")))
		button(rows,Texts.get_text("academia_repasar") if started else Texts.get_text("academia_empezar"),Rect2(865,y+6,118,rh-12),func(): close_modal(); academy.begin(n),first).add_theme_font_size_override("font_size",17 if Glyphs.touch else 14)
		var exam_button = button(rows,Texts.get_text("academia_examen_boton"),Rect2(993,y+6,127,rh-12),func(): close_modal(); academy.begin(n,"examen"))
		exam_button.add_theme_font_size_override("font_size",15 if Glyphs.touch else 13)
		exam_button.disabled = not started
		if not started: exam_button.focus_mode = Control.FOCUS_NONE
	for k in soon:
		var y = (academy.LESSONS+k)*st
		panel(rows,Rect2(0,y,1130,rh),Color(.075,.115,.085,.55))
		label(rows,"%d" % (academy.LESSONS+k+1),Rect2(13,y+6+mid,44,34),24,Color("8f9f86")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label(rows,Texts.get_text("academia_prox_%d" % (k+1)),Rect2(65,y+10+mid,640,26),18,Color("a9b8a0"))
		# A button that does nothing, so the D-pad and the arrows reach the row and the list follows.
		var later = button(rows,Texts.get_text("academia_proximamente"),Rect2(865,y+6,255,rh-12),func(): pass)
		later.add_theme_font_size_override("font_size",13)
		later.add_theme_color_override("font_color",Color("efaf83"))
	label(rows,Texts.get_text("academia_mucho_mas"),Rect2(65,(academy.LESSONS+soon)*st+8,640,26),18,Color("a9b8a0"))
	rows.custom_minimum_size = Vector2(1130,(academy.LESSONS+soon)*st+46)
	label(root,Texts.get_text("academia_progreso") % [academy.practices_done(),academy.LESSONS]+" · "+(Texts.get_text("academia_graduado") if academy.graduated() else Texts.get_text("academia_examenes_progreso") % [academy.exams_done(),academy.LESSONS]),Rect2(620,650,585,28),15,Color("a7c683"))
	button(root,Texts.get_text("academia_volver_menu"),Rect2(75,636,260,50),intro)
	button(root,Texts.get_text("academia_reiniciar"),Rect2(350,636,240,50),func(): academy.reset_progress(); show_academy())

func show_academy_result() -> void:
	var root = create_modal()
	play_sfx("revelado",-4.0)
	label(root,Texts.get_text("academia_resultado_titulo") % [academy.lesson,shot_serial],Rect2(25,24,1170,50),32)
	var notes: Array = academy.on_practice_photo(current_photo,current_result) if academy.phase == "practica" else []
	var pair: Array = academy.comparison_photos() if academy.phase == "practica" else []
	if pair.size() == 2:
		for i in 2:
			var shot: Dictionary = pair[i]
			photo_preview(root,shot.texture,shot.result,Rect2(25+i*418,100,408,230))
			# The two photos to compare, framed in sky blue: that is where to look.
			var ring = Panel.new()
			ring.position = Vector2(25+i*418,100)
			ring.size = Vector2(408,230)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.add_theme_stylebox_override("panel",UiStyle.box(Color.TRANSPARENT,4,UiStyle.SKY,3))
			root.add_child(ring)
			var e2: Dictionary = shot.result.evidence
			label(root,Texts.get_text("ficha_comparacion") % [e2.f,str(e2.n),roundi(1/e2.t),e2.d],Rect2(25+i*418,334,408,24),15,Color.WHITE)
		photo_preview(root,current_photo,current_result,Rect2(25,370,370,208))
	else:
		photo_preview(root,current_photo,current_result,Rect2(25,100,825,464))
	var e: Dictionary = current_result.evidence
	var info = Texts.get_text("ficha_foto") % [e.f,str(e.n),roundi(1/e.t),e.iso,e.scene_ev,current_result.delta,e.d,current_result.coc,current_result.drag]
	academy.make_label(root,Rect2(885,100,360,260),18,Color("e6e8dd"),true).text = info
	var task_text = ""
	if academy.phase == "examen":
		# The tutor's report (docs/futuro/06 §3): verdict and one line per criterion.
		var report: Dictionary = academy.on_exam_photo(current_result)
		task_text = Texts.get_text("academia_examen_mencion" if report.mention else ("academia_examen_aprobado" if report.passed else "academia_examen_suspenso")) % report.score+"\n"
		for line in report.lines: task_text += "\n%s %s" % [Texts.get_text("academia_ex_mas") if line[0] else Texts.get_text("academia_ex_menos"),line[1]]
		if report.passed and academy.graduated(): task_text += "\n\n"+Texts.get_text("academia_graduado")
	else:
		for k in academy.TASKS:
			task_text += "%s  %s\n" % [Texts.get_text("academia_hecho") if academy.tasks[k] else Texts.get_text("academia_pendiente"),Texts.get_text(academy.lesson_key(academy.lesson,"p%d" % (k+1)))]
		for note in notes: task_text += "\n"+note
	if academy.phase == "examen":
		# The tutor's report is what to read here: white on a sky-blue frame.
		var frame = Panel.new()
		frame.position = Vector2(873,360)
		frame.size = Vector2(384,258)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel",UiStyle.box(Color(UiStyle.SKY.r,UiStyle.SKY.g,UiStyle.SKY.b,.92).darkened(.12),10,Color.WHITE,2))   # filled: white reads on it in both themes
		root.add_child(frame)
	var report_label = academy.make_label(root,Rect2(885,370,360,240),15,Color("c9d4bf"),true)
	report_label.text = task_text
	if academy.phase == "examen": report_label.add_theme_color_override("font_color",Color.WHITE)
	button(root,Texts.get_text("academia_volver_menu"),Rect2(25,630,260,55),show_academy)
	button(root,Texts.get_text("academia_seguir"),Rect2(885,620,360,70),resume_search,true)

func show_sandbox_controls() -> void:
	if not sandbox: return
	mode = "SANDBOX_SETTINGS"
	var root = create_modal()
	label(root,Texts.get_text("sandbox_titulo"),Rect2(75,65,1100,60),38)
	label(root,Texts.get_text("sandbox_subtitulo"),Rect2(75,145,1100,40),23)
	label(root,Texts.get_text("sandbox_iluminacion"),Rect2(75,250,250,40),22)
	option(root,[Texts.get_text("intro_dia"),Texts.get_text("intro_dorada"),Texts.get_text("intro_azul"),Texts.get_text("intro_noche")],["day","golden","blue","night"].find(time_of_day),Rect2(350,245,650,48),func(i):
		time_of_day = ["day","golden","blue","night"][i]
		night = (time_of_day == "night")
		park.set_time_of_day(time_of_day)
		update_meter()
		refresh()
	)
	label(root,Texts.get_text("sandbox_nubes"),Rect2(75,335,250,40),22)
	option(root,[Texts.get_text("sandbox_despejado"),Texts.get_text("sandbox_nubes_movimiento")],1 if park.clouds_enabled else 0,Rect2(350,330,650,48),func(i): park.clouds_enabled = i == 1; park.update_weather(0))
	label(root,Texts.get_text("sandbox_personajes"),Rect2(75,420,250,40),22)
	option(root,[Texts.get_text("sandbox_en_movimiento"),Texts.get_text("sandbox_quietos")],1 if sandbox_paused else 0,Rect2(350,415,650,48),func(i): set_sandbox_pause(i == 1))
	button(root,Texts.get_text("sandbox_volver"),Rect2(75,620,260,60),intro)
	button(root,Texts.get_text("sandbox_probar"),Rect2(820,620,380,60),resume_search,true)

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
	# A lesson where the camera looks after the subject by itself (the runner of the lesson on
	# movement): the photo is of that person wherever it is in the frame, and in focus.
	var kept = academy.auto_subject() if academy and academy.active else null
	if kept != null:
		var kept_chest = kept.control_points()[1]
		var kept_at = camera.unproject_position(kept_chest)/Vector2(viewport.size)
		if not camera.is_position_behind(kept_chest) and kept_at.x > .04 and kept_at.x < .96 and kept_at.y > .0 and kept_at.y < 1.0:
			person = kept
			velocity = kept.actual_velocity
			distance = camera.global_position.distance_to(kept_chest)
			focus_distance = distance
	if person != null: pass
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
	return {"f":focal,"n":aperture_value(),"t":1.0/shutter_denominator(),"iso":iso_value(),"s":focus_distance,"d":distance,"v":perpendicular,"scene_ev":park.sky_ev(time_of_day) if hit.is_empty() else park.illumination_ev(hit.position,time_of_day,person),"head":Vector2(.5,.2),"feet":Vector2(.5,.8),"chest":Vector2(.5,.5),"in_front":true,"blockers":[],"motion_sign":signf(velocity.dot(camera.global_basis.x)),"film":equipment.film,"cloud_cover":park.cloud_cover,"seed":shot_serial+1,"person":person != null}

func show_sandbox_result() -> void:
	var root = create_modal()
	play_sfx("revelado",-4.0)
	label(root,Texts.get_text("sandbox_foto_d") % shot_serial,Rect2(25,30,1170,60),36)
	photo_preview(root,current_photo,current_result,Rect2(25,120,825,464))
	var e: Dictionary = current_result.evidence
	var info = Texts.get_text("ficha_sandbox") % [e.f,e.n,roundi(1/e.t),e.iso,Texts.get_text("equipo_carrete") if e.film else Texts.get_text("ficha_digital"),e.scene_ev,current_result.delta,e.d,current_result.coc,current_result.drag]
	label(root,info,Rect2(885,120,360,420),20).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if tutorial and tutorial.active:
		label(root,current_result.get("tutorial_note",""),Rect2(25,590,825,60),17,UiStyle.SKY_DEEP).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button(root,Texts.get_text("tutorial_continuar"),Rect2(885,620,360,75),resume_search,true)
		return
	label(root,"La foto conserva los ajustes del disparo. Prueba otro enfoque, exposición o equipo.",Rect2(25,584,825,50),17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(root,"Menú",Rect2(25,647,165,50),intro)
	button(root,"Cambiar equipo",Rect2(210,647,260,50),show_equipment)
	button(root,Texts.get_text("seguir_probando"),Rect2(885,620,360,75),resume_search,true)
