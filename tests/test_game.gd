extends SceneTree
const Main = preload("res://main.tscn")
var game
var checks = 0
var failures = 0
var output = "/tmp" if DirAccess.dir_exists_absolute("/tmp") else OS.get_cache_dir()   # Windows has no /tmp
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
	game.look_invert = "no"   # (whatever the player has chosen in Options: the checks below assume the default)
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
	check(latency < 50,"Pan input under 50 ms (%.1f ms)" % latency)
	press.position = drag.position
	press.pressed = false
	Input.parse_input_event(press)
	await frames(1)
	game.pan_velocity = 0
	old_angle = game.angle
	var Glyphs = preload("res://scripts/input_glyphs.gd")
	Glyphs.touch = true   # (as on a phone: the finger looks on both axes, the mouse only pans)
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = game.view_rect.get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	await frames(1)
	var touch_drag = InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = game.view_rect.get_center()+Vector2(0,60)
	touch_drag.relative = Vector2(0,60)
	var old_pitch = game.pitch
	Input.parse_input_event(touch_drag)
	await frames(1)
	check(abs(game.angle-old_angle) < .01 and game.pitch > old_pitch+1,"Vertical drag tilts without horizontal pan (the finger drags the scene: down looks up; angle %.3f → %.3f, pitch %.2f → %.2f, %.0f mm)" % [old_angle,game.angle,old_pitch,game.pitch,game.focal])
	Glyphs.touch = false
	Glyphs.device = "teclado"
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
	game.t_index = 8
	game.n_index = game.apertures().size()-1
	game.focal = 105
	game.update_camera()
	await game.take_photo()
	check(game.current_result.movement == 0,"Long exposure degrades movement")
	check(game.best.score >= first_score,"Best shot retained")
	await screenshot("movida")
	# Scripted sessions (no level) chain assignments; the arcade replaced the five-job session.
	game.finish_assignment()
	check(game.assignment == 1 and game.shots == 3 and game.mode == "BRIEFING","Next assignment replenishes shots")
	game.begin_assignment()
	print("SESSION VIDEO MEMORY: %.2f MiB, textures %.2f, buffers %.2f, photo %s" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.0,game.current_photo.get_size()])
	# Per-profile budget (docs/futuro/17 §3): 60 MB in gl_compatibility, 8 GiB for Ultra in Forward+.
	var vram_limit = 8.0*1073741824.0 if RenderingServer.get_current_rendering_method() == "forward_plus" else 60000000.0
	check(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) <= vram_limit,"Session graphics memory within the profile budget")
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
	# Graphics presets verification (docs/futuro/02, 2.8.4)
	# Every desktop profile runs in Forward+ with the hd scene; gl_compatibility (Android fallback)
	# builds lo and never starts in Ultra (docs/futuro/17 §2.1).
	var forward = RenderingServer.get_current_rendering_method() == "forward_plus"
	check(forward or game.graphics_preset != "Ultra","Startup profile fits the renderer (%s)" % game.graphics_preset)
	check(game.park.detail == ("hd" if forward else "lo"),"Park mesh detail follows the renderer")
	game.apply_graphics_preset("Ultra")
	check(game.park.sun.shadow_enabled and game.park.sun.directional_shadow_max_distance == 48.0,"Ultra activates extended soft filtered shadows")
	check(game.park.environment.environment.tonemap_mode == Environment.TONE_MAPPER_ACES,"Ultra uses ACES tone mapper")
	game.apply_graphics_preset("Bajo")
	check(game.graphics_preset == "Bajo","Switched to Bajo preset")
	# Lower profiles are performance subsets of Ultra: same tone curve, grading and haze.
	var env = game.park.environment.environment
	check(env.tonemap_mode == Environment.TONE_MAPPER_ACES and env.fog_enabled and env.adjustment_color_correction != null,"Bajo keeps Ultra's tone curve, haze and colour grading")
	if forward:
		check(not env.sdfgi_enabled and not env.ssao_enabled and not env.volumetric_fog_enabled,"Bajo drops SDFGI, SSAO and volumetric fog")
		check(game.viewport.scaling_3d_scale < 1.0 and game.viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2,"Bajo renders fewer pixels, upscaled with FSR 2")
		check(game.park.grass_nodes.is_empty() or game.park.grass_nodes[0].multimesh.visible_instance_count < game.park.grass_nodes[0].multimesh.instance_count,"Bajo thins the grass")
	game.apply_graphics_preset("Ultra")
	check(game.graphics_preset == "Ultra","Restored to Ultra preset")
	# Integrated GPUs render SDFGI wrong (washed-out park): they get Bajo's calibrated ambient instead.
	if forward:
		var discrete = RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
		check(env.sdfgi_enabled == discrete,"SDFGI only on a dedicated GPU")
		check(discrete or is_equal_approx(env.ambient_light_energy,game.park.base_ambient*game.park.NO_GI_AMBIENT.get(game.park.time_of_day,1.0)),"Without SDFGI the ambient is the calibrated one")
	check(game.park.sun.shadow_enabled and game.park.environment.environment.fog_enabled,"Ultra restores shadows and atmospheric fog")
	# Merged park (docs/futuro/16): few surfaces, vertex colours with baked occlusion, smooth shading.
	var park_surfaces = game.park.get_children().filter(func(n): return n is MeshInstance3D and n.mesh != null)
	# 36 sectors plus glass, bulbs and pond water; hd adds the 36 sectors of textured ground (docs/futuro/17).
	var hd = game.park.detail == "hd"
	var surface_limit = 80 if hd else 40
	check(park_surfaces.size() <= surface_limit,"Park merged into at most %d surfaces (%d)" % [surface_limit,park_surfaces.size()])
	var opaque_surfaces = park_surfaces.filter(func(n): return n.material_override == game.park.park_material)
	var own_materials = [game.park.glass_material,game.park.bulb_material,game.park.water_material,game.park.spray_material,game.park.windows_material]
	var ground_surfaces = park_surfaces.filter(func(n): return n.material_override == game.park.ground_material_hd)
	check(opaque_surfaces.size() + ground_surfaces.size() == park_surfaces.filter(func(n): return not n.material_override in own_materials).size(),"Opaque park surfaces share the vertex-colour material (ground: textured material in hd)")
	check(ground_surfaces.is_empty() != hd,"Textured ground only in hd (%d surfaces)" % ground_surfaces.size())
	check(game.park.park_material is StandardMaterial3D and game.park.park_material.vertex_color_use_as_albedo and game.park.park_material.next_pass == null,"Park keeps smooth shading without ink outline")
	if hd:
		# Blender mannequins (docs/futuro/18): rigid wood, smooth-skinned clothes; weights sum to 1.
		var arrays = game.target.mesh.surface_get_arrays(0)
		var w: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var blended = 0
		var normalised = true
		for k in range(0,w.size(),4):
			if w[k] < .999: blended += 1
			normalised = normalised and absf(w[k]+w[k+1]+w[k+2]+w[k+3]-1.0) < .01
		check(normalised and blended > 0,"hd clothes blend bones at the joints (%d vertices)" % blended)
	check(game.Person.mannequin_material().shader.resource_path.ends_with("mannequin_pbr.gdshader") and game.Person.mannequin_material().next_pass == null,"Mannequins: realistic material without outline in every profile")
	var coloured = true
	for node in opaque_surfaces:
		var arrays = node.mesh.surface_get_arrays(0)
		coloured = coloured and arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size()
	check(coloured,"Park surfaces carry per-vertex colours")
	var ground_shades = []
	for x in [0.0,4.85,9.2,13.4]: ground_shades.append(game.park.ground_occlusion(game.park.polar(35.0,x)))
	check(ground_shades.min() < 1.0 and ground_shades.min() >= .45,"Baked contact occlusion darkens the ground near props")
	var labelled = game.park.find_children("*","StaticBody3D",true,false).filter(func(b): return b.has_meta("label"))
	check(labelled.size() > 100,"Park colliders and labels survive the merge (%d)" % labelled.size())
	game.apply_graphics_preset("Bajo")
	check(game.viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED,"Bajo adds no screen-space antialiasing pass")
	game.apply_graphics_preset("Ultra")
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		check(game.viewport.msaa_3d == Viewport.MSAA_4X,"Ultra in Forward+ smooths edges with MSAA 4x")
	else:
		check(game.viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA,"Ultra smooths edges with FXAA")
	game.park.set_time_of_day("day")
	check(game.park.lamps.all(func(l): return not l.visible),"Lamps are hidden by day")
	await frames(4)
	var day_draw_calls = RenderingServer.viewport_get_render_info(game.viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("DAY DRAW CALLS: %d" % day_draw_calls)
	check(day_draw_calls <= 300,"Day draw calls within budget (%d <= 300)" % day_draw_calls)
	# The sky (shaders/park_sky.gdshader): stars and moon only at night, afterglow at dusk.
	var sky_mat = game.park.environment.environment.sky.sky_material
	check(sky_mat is ShaderMaterial and sky_mat.shader.resource_path.ends_with("park_sky.gdshader"),"The park uses its own sky shader")
	check(sky_mat.get_shader_parameter("stars") == 0.0 and sky_mat.get_shader_parameter("moon") == 0.0 and sky_mat.get_shader_parameter("glow") == 0.0,"Day sky: no stars, moon or afterglow")
	for dusk in ["golden","blue"]:
		game.park.set_time_of_day(dusk)
		check(sky_mat.get_shader_parameter("glow") > 0.0 and sky_mat.get_shader_parameter("moon") == 0.0,"%s sky: afterglow over the horizon" % dusk)
	game.park.set_time_of_day("night")
	check(sky_mat.get_shader_parameter("stars") == 1.0 and sky_mat.get_shader_parameter("moon") == 1.0,"Night sky: stars and moon")
	check(sky_mat.get_shader_parameter("moon_direction").y > .3 and sky_mat.get_shader_parameter("moon_direction").y < .75,"The moon hangs where it can be seen")
	check(game.park.lamps.all(func(l): return l.visible and l.shadow_enabled),"Ultra night: all lamps cast shadows")
	game.apply_graphics_preset("Alto")
	check(game.park.lamps.filter(func(l): return l.shadow_enabled).size() == 4,"Alto night: only the 4 inner lamps cast shadows")
	game.apply_graphics_preset("Medio")
	check(game.park.lamps.all(func(l): return not l.shadow_enabled),"Medio night: no lamp shadows")
	game.apply_graphics_preset("Ultra")
	game.park.set_time_of_day("day")
	game.show_graphics_settings()
	await frames(2)
	check(game.mode == "GRAPHICS","Graphics settings modal opens")
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	game._unhandled_input(esc)
	check(game.mode != "GRAPHICS","ESC exits graphics settings modal")
	# Interface theme (docs/futuro/20): light by default, dark palette swaps and comes back intact.
	var UiStyle = preload("res://scripts/ui_style.gd")
	# The player's saved theme (user://interfaz.cfg) may be the dark one: test from the light palette.
	var saved_dark = UiStyle.dark
	UiStyle.set_dark(false)
	check(not UiStyle.dark and UiStyle.INK == Color("0e1924"),"Light theme palette")
	UiStyle.set_dark(true)
	check(UiStyle.lum(UiStyle.INK) > .85 and UiStyle.lum(UiStyle.SURFACE) < .2,"Dark theme: light ink on dark surfaces")
	check(UiStyle.lum(UiStyle.text_color(Color("0e1924"))) > .85,"Dark theme maps dark text to light")
	UiStyle.set_dark(false)
	check(UiStyle.INK == Color("0e1924") and UiStyle.SURFACE == Color(1,1,1),"Light theme restored")
	UiStyle.set_dark(saved_dark)
	game.intro()
	await process_frame
	game.modal.current = game.modal.MODES.find("opciones")
	game.modal.build_card()
	await process_frame
	check(game.modal.card.get_children().any(func(c): return c is Button and c.text.begins_with("Tema")),"The options card has the theme switch")
	# Arcade (docs/futuro/21): levels fix the equipment, spend shots, run the clock and end.
	var Arcade = preload("res://scripts/arcade.gd")
	Arcade.SAVE = "user://arcade_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	game.start_level(0)
	check(game.arcade_level == 0 and game.shots == 5 and game.mode == "BRIEFING" and game.equipment.body == 0 and game.equipment.auto_exposure,"Level 1: automatic compact and 5 shots")
	game.begin_assignment()
	await game.take_photo()
	check(game.mode == "RESULT" and game.shots == 4,"An arcade photo spends one of the level's shots")
	game.end_level()
	check(game.mode == "LEVEL_END" and game.level_over,"The level ends on demand")
	game.start_level(3)
	game.begin_assignment()
	game.level_time = .02
	await frames(4)
	check(game.mode == "LEVEL_END","The time limit ends the level")
	game.start_level(9)
	check(game.target.runner and game.equipment.exposure_mode() == "S" and game.equipment.body == 2,"Level 10 sets a running subject and the SLR in shutter priority")
	check(game.briefing.text.contains("congelado"),"The search line lists the level's conditions")
	# No level picks someone its lens cannot frame as it asks (a child far away with a 50 mm).
	var unfit = []
	for n in Arcade.LEVELS.size():
		if Arcade.LEVELS[n].scenario != "clasico": continue
		for k in 6:
			game.start_level(n)
			# (level 24's runners are all far for the TLR: there the one who comes out tallest)
			var others = game.people.filter(func(p): return p.runner == game.target.runner and p.visible and (p.runner or p.lane in [1,2]) and game.subject_fits(p,p.lane))
			if not game.subject_fits(game.target,game.target.lane) and not others.is_empty(): unfit.append("%d (%.2f m, path %d)" % [n+1,game.target.height,game.target.lane])
	check(unfit.is_empty(),"Every level's subject can be framed with the level's lens: %s" % str(unfit))
	game.start_level(29)
	var small = game.people.filter(func(p): return p.height < 1.3)
	check(not small.is_empty() and not game.subject_fits(small[0],2) and game.subject_fits(small[0],1),"Level 30 (50 mm, half the frame): a child fits on the bench path, not on the third one")
	var thirds_option = game.exposure_thirds
	game.exposure_thirds = false
	game.start_level(16)
	check(game.thirds_on() and not game.exposure_thirds,"Level 17 (an exposure to the quarter of a stop) is played in thirds, whatever the option says")
	game.start_level(22)
	check(game.target.lane == 1 and str(game.time_of_day) == "golden" and game.equipment.film_iso_index == 0,"Level 23: the TLR's portrait at the golden hour, on ISO 100 film, of someone on the bench path (where its lens can blur the background)")
	game.start_level(0)
	check(not game.thirds_on(),"…and the other levels follow the option")
	game.exposure_thirds = thirds_option
	# Levels about what people do, where they are and the light (06-10-2026).
	game.start_level(12)
	check(game.target.lane == 1 and game.target.bench_goal >= 0 and game.activity_on_duty(game.target),"«Lo que hace»: the subject heads for a bench to do something")
	game.start_level(13)
	game.begin_assignment()
	await frames(3)
	var place_e = game.capture_evidence()
	check(place_e.places.has("quiosco") and place_e.has("backlight") and place_e.has("sunlit") and place_e.has("activity"),"The evidence knows the landmarks, the sun and what the subject is doing")
	check(game.target.lane == 2,"«Todo nítido»: the subject walks the third path, towards the bandstand")
	game.start_level(17)
	check(game.equipment.metering == "puntual" and game.equipment.exposure_mode() == "A","«A contraluz»: spot metering and aperture priority")
	game.start_level(0)
	check(game.equipment.metering == game.equipment.DEFAULT_METERING,"…and the next level is back to the usual metering")
	# TLR: waist level, square photo measured on the square, film, manual focus.
	game.start_level(20)
	check(game.equipment.tlr() and game.equipment.film and game.equipment.focus_mode == "MF","Level 16: TLR with film and manual focus")
	check(is_equal_approx(game.camera.position.y,1.1),"The TLR is held at the waist (1.10 m)")
	game.begin_assignment()
	await frames(3)
	await game.take_photo()
	check(game.current_photo.get_width() == game.current_photo.get_height(),"The TLR photo is square")
	check(game.current_result.evidence.get("square",false) and game.current_result.has("conditions"),"TLR evidence is measured on the square")
	game.equipment.preset(2)
	game.apply_equipment()
	check(is_equal_approx(game.camera.position.y,1.6),"Other bodies return to eye level")
	# TLR in the sandbox: 12 frames and the crank between shots.
	game.equipment.preset(3)
	game.apply_equipment()
	game.start_session("day",true)
	await game.take_photo()
	check(game.tlr_frames == 11 and not game.tlr_wound,"A TLR frame is spent and the film needs winding")
	game.resume_search()
	await game.take_photo()
	check(game.tlr_frames == 11,"No shot without winding the crank")
	game.wind_film()
	check(game.tlr_wound,"The crank winds the film")
	game.tlr_frames = 0
	game.tlr_wound = true
	await game.take_photo()
	game.wind_film()
	check(game.tlr_frames == 12,"A finished roll is replaced by a new one of 12")
	game.equipment.preset(0)
	game.apply_equipment()
	# One manual control at a time: aperture priority keeps the player's aperture, the camera sets
	# the rest; slower walkers where focus and exposure are manual (docs/futuro/21 §5).
	game.start_level(7)
	game.begin_assignment()
	check(game.equipment.exposure_mode() == "A","Level 7: aperture priority")
	game.n_index = 0
	game.auto_expose()
	check(game.n_index == 0,"Aperture priority keeps the chosen aperture")
	var t_before = game.t_index
	game.exposure_thirds = false   # (the player's option must not change the test)
	game.change_parameter("t",1)
	game.change_parameter("n",1)
	check(game.n_index == 1 and game.t_index == t_before or game.equipment.priority == "A","The aperture dial works, the shutter is the camera's")
	game.start_level(9)
	check(game.equipment.exposure_mode() == "S","Level 10: shutter priority")
	game.start_level(10)
	check(is_equal_approx(game.walk_pace,.6),"Level 11: walkers slower for manual focus")
	game.start_level(0)
	check(is_equal_approx(game.walk_pace,1.0),"Level 1: normal pace")
	# On-screen help: on by default, F1 toggles it and the choice is kept.
	var saved_cfg = FileAccess.get_file_as_string("user://interfaz.cfg") if FileAccess.file_exists("user://interfaz.cfg") else ""
	game.begin_assignment()
	var was = game.control_help.enabled
	game.control_help.set_enabled(not was)
	var cfg = ConfigFile.new()
	cfg.load("user://interfaz.cfg")
	check(bool(cfg.get_value("interfaz","ayuda",true)) == (not was),"The on-screen help switch is remembered")
	game.control_help.set_enabled(true)
	check(game.control_help.rows().any(func(r): return r[3] == "auto") and game.control_help.rows().size() >= 8,"The help lists the camera's controls")
	if saved_cfg != "":
		var f = FileAccess.open("user://interfaz.cfg",FileAccess.WRITE)
		f.store_string(saved_cfg)
	# The mouse moves the view the way it goes, on both axes.
	game.dragging = true
	game.dragged = true
	var angle_before = game.angle
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(30,0)
	motion.position = Vector2(640,360)
	game._unhandled_input(motion)
	check(angle_difference(deg_to_rad(angle_before),deg_to_rad(game.angle)) > 0,"Moving the mouse right turns the view right")
	game.dragging = false
	# Classic park: lower the camera to search with a wide view, raise it to shoot (docs/futuro/21 §8).
	game.start_level(7)
	game.begin_assignment()
	var aim = game.angle
	game.toggle_raise()
	await create_timer(.6).timeout
	check(not game.eye_ready() and game.camera.fov > 60.0 and not game.finder.visible,"Camera lowered: a wide view to search, no finder")
	await game.take_photo()
	check(game.mode == "SEARCH","No photo with the camera lowered")
	game.toggle_raise()
	await create_timer(.6).timeout
	check(game.eye_ready() and game.camera.fov < 30.0 and absf(angle_difference(deg_to_rad(aim),deg_to_rad(game.angle))) < .05,"Back at the eye with the telephoto, looking the same way (%s, fov %.0f, %.1f→%.1f)" % [game.eye_ready(),game.camera.fov,aim,game.angle])
	check(not game.target.runner,"The subject of a level that is not about runners never runs")
	# References while searching (docs/futuro/22 §7): the subject in miniature, framing guides,
	# movement said in shutter speeds.
	game.start_level(4)
	game.begin_assignment()
	await frames(3)
	check(is_instance_valid(game.portrait) and game.portrait.visible and game.portrait_of == game.target,"The subject turns in miniature at the top left")
	check(game.finder.golden,"A golden-section level draws its guides")
	game.start_level(0)
	game.begin_assignment()
	check(not game.finder.golden and game.finder.thirds,"Other levels draw the thirds")
	var Photo = preload("res://scripts/photography.gd")
	check(Photo.needed_shutter(2.8,70.0,8.0) == 1000 and Photo.needed_shutter(2.8,135.0,8.0) == 2000 and Photo.needed_shutter(2.8,200.0,3.0) == -1 and Photo.needed_shutter(0.7,50.0,5.0) > 0,"The shutter needed to freeze a subject")
	var Conditions = preload("res://scripts/conditions.gd")
	var frozen = Conditions.check({"f":70.0,"n":2.8,"t":1.0/250,"s":8.0,"d":8.0,"v":2.8,"head":Vector2(.5,.2),"feet":Vector2(.5,.8),"chest":Vector2(.5,.5)},{"congelado":true})[0]
	check(not frozen.ok and frozen.text.contains("1/1000") and frozen.text.contains("1/250"),"Freezing explained in shutter speeds (%s)" % frozen.text)
	# Graphics (docs/futuro/23): the profiles are tables, Personalizado is edited by hand and kept.
	var Graphics = preload("res://scripts/graphics.gd")
	Graphics.SAVE = "user://graficos_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Graphics.SAVE))
	Graphics.custom = {}
	for name in ["Bajo","Medio","Alto","Ultra"]:
		var table = Graphics.settings(name)
		var fx = game.park.EFFECTS[name]
		check(int(table.sdfgi) == fx.sdfgi and (int(table.ssao) >= 0) == fx.ssao and table.ssil == fx.ssil and table.ssr == fx.ssr and table.volumetric == fx.volumetric and int(table.shadow_atlas) == fx.atlas and is_equal_approx(table.grass,fx.grass),"Profile %s: its table matches the documented effects" % name)
	check(Graphics.OPTIONS.all(func(o): return Graphics.PRESETS["Ultra"].has(o[0]) and o[2].size() >= 2),"Every option edits a parameter of the table")
	game.apply_graphics_preset("Bajo")
	check(game.viewport.anisotropic_filtering_level == Viewport.ANISOTROPY_2X,"Bajo filters the ground textures at 2×")
	game.apply_graphics_preset("Ultra")
	check(game.viewport.anisotropic_filtering_level == Viewport.ANISOTROPY_16X,"Ultra filters the ground textures at 16×")
	Graphics.copy_to_custom("Ultra")
	Graphics.set_custom("scale",1.5)
	Graphics.set_custom("msaa",8)
	Graphics.set_custom("lamp_shadows",0)
	Graphics.custom = {}
	check(is_equal_approx(Graphics.settings("Personalizado").scale,1.5) and int(Graphics.settings("Personalizado").msaa) == 8,"Personalizado is saved and loaded back")
	game.apply_graphics_preset("Personalizado")
	if game.ParkScene.forward_plus():
		check(is_equal_approx(game.viewport.scaling_3d_scale,1.5) and game.viewport.msaa_3d == Viewport.MSAA_8X,"Personalizado goes beyond Ultra: supersampling and MSAA 8×")
		game.park.set_time_of_day("night")
		game.park.update_lamp_shadows()
		check(game.park.lamps.all(func(l): return not l.shadow_enabled),"Personalizado: lamp shadows off by hand")
		game.park.set_time_of_day("day")
	game.apply_graphics_preset("Ultra")
	if game.ParkScene.forward_plus(): check(is_equal_approx(game.viewport.scaling_3d_scale,1.0) and game.viewport.msaa_3d == Viewport.MSAA_4X,"Back to Ultra restores its values")
	Graphics.display = {"mode":"ventana","size":"1600x900","vsync":true}
	Graphics.save_display()
	Graphics.display = {"mode":"completa","size":"1280x720","vsync":false}
	check(Graphics.load_display() and Graphics.display.mode == "ventana" and Graphics.display.size == "1600x900","The display settings are kept")
	# Full screen with a chosen resolution limits the 3D image's height; a window never does.
	Graphics.display = {"mode":"completa","size":"1280x720","vsync":true,"fps":false}
	check(Graphics.fullscreen_height() == 720,"Full screen: the image resolution can be chosen")
	Graphics.display = {"mode":"completa","size":"nativa","vsync":true,"fps":false}
	check(Graphics.fullscreen_height() == 0,"Full screen: native resolution by default")
	Graphics.display = {"mode":"ventana","size":"1600x900","vsync":true,"fps":false}
	check(Graphics.fullscreen_height() == 0,"A window renders at its own size")
	Graphics.display["fps"] = true
	await create_timer(.7).timeout
	check(is_instance_valid(game.fps_counter) and game.fps_counter.visible and game.fps_counter.text.contains("FPS"),"The FPS counter shows when asked")
	Graphics.display["fps"] = false
	await frames(3)
	check(not game.fps_counter.visible,"…and hides again")
	game.show_graphics_settings()
	await process_frame
	check(game.mode == "GRAPHICS","The graphics screen opens")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Graphics.SAVE))
	Graphics.custom = {}
	game.show_arcade()
	await process_frame
	check(game.mode == "ARCADE","The level select screen opens")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	print("GAME TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
