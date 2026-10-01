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
	check(latency < 50,"Pan input under 50 ms (%.1f ms)" % latency)
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
	game.park.set_time_of_day("night")
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
	check(not UiStyle.dark and UiStyle.INK == Color("0e1924"),"Light theme by default")
	UiStyle.set_dark(true)
	check(UiStyle.lum(UiStyle.INK) > .85 and UiStyle.lum(UiStyle.SURFACE) < .2,"Dark theme: light ink on dark surfaces")
	check(UiStyle.lum(UiStyle.text_color(Color("0e1924"))) > .85,"Dark theme maps dark text to light")
	UiStyle.set_dark(false)
	check(UiStyle.INK == Color("0e1924") and UiStyle.SURFACE == Color(1,1,1),"Light theme restored")
	game.intro()
	await process_frame
	check(game.modal.theme_buttons.size() == 2,"Main menu shows the theme selector")
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
	check(game.target.runner and not game.equipment.auto_exposure and game.equipment.body == 2,"Level 10 sets a running subject and manual SLR")
	check(game.briefing.text.contains("congelado"),"The search line lists the level's conditions")
	# TLR: waist level, square photo measured on the square, film, manual focus.
	game.start_level(15)
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
	game.show_arcade()
	await process_frame
	check(game.mode == "ARCADE","The level select screen opens")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	print("GAME TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
