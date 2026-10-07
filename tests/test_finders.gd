extends SceneTree
# Realistic camera finders (docs/futuro/07 §1): each body frames the image without cropping it,
# clicks land where they look, the HUD folds away and comes back, and nothing of the finder changes
# the photo or its score. Needs a display:
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_finders.gd
const Main = preload("res://main.tscn")
const Photo = preload("res://scripts/photography.gd")
var checks = 0
var failures = 0
var game

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func frames(n = 3) -> void:
	for i in n: await process_frame

func run() -> void:
	var saved_interface = FileAccess.get_file_as_string("user://interfaz.cfg") if FileAccess.file_exists("user://interfaz.cfg") else ""
	game = Main.instantiate()
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"   # (never the player's album)
	root.add_child(game)
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"   # (never the player's progress)
	game.exposure_thirds = false   # (not the player's option)
	await frames(10)
	game.start_session("day")
	game.begin_assignment()
	game.mode = "SEARCH"
	var screen = Rect2(0,0,1280,720)
	for body in 4:
		game.equipment.preset(body)
		game.apply_equipment()
		game.set_interface("camara")
		await frames(4)
		var r: Rect2 = game.view_rect
		check(screen.encloses(r),"Body %d: the image fits on screen" % body)
		check(absf(r.size.x/r.size.y-16.0/9.0) < .002,"Body %d: 16:9, the photo is never cropped" % body)
		check(r.size.x < 1280,"Body %d: the camera interface frames the image with its body" % body)
		game.focus_distance = 40.0
		await frames(4)
		var centre_pixel = game.image_position(r.get_center()+game.view_shift)
		check(centre_pixel.distance_to(Vector2(game.viewport.size)*.5) < 1.0,"Body %d: the centre of the finder is the centre of the photo" % body)
		var pts = game.finder.points()
		check(r.grow(1).has_point(pts[0]-game.view_shift) and r.grow(1).has_point(pts[8]-game.view_shift),"Body %d: AF points inside the image" % body)
		check(game.hud_top.all(func(n): return not n.visible),"Body %d: HUD bars folded away in the camera interface" % body)
		# One interface everywhere: Tab no longer unfolds the classic bars, it takes the next control.
		var tab = InputEventKey.new()
		tab.physical_keycode = KEY_TAB
		tab.keycode = KEY_TAB
		tab.pressed = true
		var controls: Array = game.selectable_controls()
		var in_hand: String = game.current_control()
		game._unhandled_input(tab)
		await frames(2)
		check(game.hud_top.all(func(n): return not n.visible) and game.hud_bottom.all(func(n): return not n.visible),"Body %d: the classic bars never show over the camera" % body)
		check(controls.size() < 2 or game.current_control() == controls[(controls.find(in_hand)+1)%controls.size()],"Body %d: Tab takes the next control in hand" % body)
	# TLR: the waist-level finder is mirrored, so a point on the left of the finder is on the right
	# of the photo; the finder shows only the central square (docs/futuro/21 §3).
	game.equipment.preset(3)
	game.apply_equipment()
	await frames(3)
	var rt: Rect2 = game.view_rect
	check(game.image_position(rt.position+Vector2(10,rt.size.y*.5)).x > game.viewport.size.x*.95,"TLR: the finder is mirrored left to right")
	check(game.lens_material.get_shader_parameter("mirror") and game.lens_material.get_shader_parameter("square"),"TLR: mirrored square ground glass")
	game.equipment.preset(0)
	game.apply_equipment()
	await frames(2)
	check(not game.lens_material.get_shader_parameter("mirror"),"Other bodies are not mirrored")
	# Chromatic aberration (docs/futuro/07 §6): by lens, focal length and aperture; the photo keeps
	# what it was taken with and the rangefinder's finder shows none.
	game.equipment.preset(0)
	game.apply_equipment()
	game.focal = 24.0
	game.n_index = 0
	var compact_open = game.lens_strengths(24.0).y
	game.n_index = game.apertures().size()-1
	var compact_closed = game.lens_strengths(24.0).y
	game.n_index = 0
	check(compact_open > compact_closed and compact_open > .8,"Compact zoom wide open at 24 mm: strong fringes, weaker stopped down (%.2f → %.2f)" % [compact_open,compact_closed])
	check(game.lens_strengths(120.0).y < compact_open,"Less at the long end")
	game.equipment.preset(2)
	game.equipment.lens_index = 2
	game.apply_equipment()
	check(game.lens_strengths(50.0).y < compact_open*.4,"A prime shows much less than the compact's zoom")
	game.equipment.preset(1)
	game.apply_equipment()
	game.set_interface("camara")
	game.update_lens_effects()
	check(game.lens_material.get_shader_parameter("chromatic_aberration") == 0.0,"The rangefinder's finder shows no lens aberration")
	check(game.lens_strengths(35.0).y > 0.0,"…but its photo does")
	game.equipment.preset(0)
	game.apply_equipment()
	game.focal = 24.0
	game.camera_raised = false
	game.raise_anim = 0.0
	game.update_lens_effects()
	check(game.lens_material.get_shader_parameter("chromatic_aberration") == 0.0,"Camera lowered: you look with your own eyes, no aberration")
	game.camera_raised = true
	game.raise_anim = 1.0
	game.update_lens_effects()
	check(game.lens_material.get_shader_parameter("chromatic_aberration") > 0.0,"Camera at the eye: the lens shows its aberration")
	game.equipment.preset(0)
	game.apply_equipment()
	await frames(2)
	# Parallax of the rangefinder: grows at close range and is undone when mapping clicks.
	game.equipment.preset(1)
	game.apply_equipment()
	game.focus_distance = 1.0
	await frames(4)
	check(game.view_shift.x > 5 and game.view_shift.y > 5,"Rangefinder: close focus shifts the frame down and right (%s)" % str(game.view_shift))
	var far_shift = game.view_shift
	game.focus_distance = 30.0
	await frames(4)
	check(game.view_shift.length() < far_shift.length()*.1,"Rangefinder: almost no parallax far away")
	check(not game.dof_active(),"Rangefinder: the finder itself shows no depth-of-field blur")
	if game.dof_allowed(): check(game.dof_pass.visible,"Rangefinder: the pass still runs (it repairs non-finite pixels)")
	# The photo and its score do not depend on the interface.
	for body in 4:
		game.equipment.preset(body)
		game.apply_equipment()
		game.angle = 120.0
		game.pitch = -2.0
		game.focal = game.equipment.lens().min
		game.focus_distance = 6.0
		game.set_sandbox_pause(true)
		var scores = []
		for interface in ["clasica","camara"]:
			game.set_interface(interface)
			game.update_camera()
			await frames(4)
			await physics_frame
			var evidence = game.capture_evidence()
			scores.append(Photo.evaluate(evidence).score)
		check(scores[0] == scores[1],"Body %d: same score with the classic and the camera interface (%s)" % [body,str(scores)])
	game.set_sandbox_pause(false)
	# A real shot through each finder: the blackout and the shutter sound are interface only.
	for body in 4:
		game.equipment.preset(body)
		game.apply_equipment()
		game.set_interface("camara")
		game.mode = "SEARCH"
		game.shots = 3
		await frames(3)
		await game.take_photo()
		check(game.mode == "RESULT","Body %d: shooting through the finder works" % body)
		if body == 1 and game.dof_allowed(): check(game.current_result.evidence.get("rendered_dof",false),"Rangefinder: the photo does get the depth of field")
		check(game.sfx.has(["obturador_compacta","obturador_telemetrica","obturador_reflex","obturador_tlr"][body]),"Body %d: its shutter sound exists" % body)
		game.resume_search()
	# The classic interface is the full screen HUD, as before.
	game.set_interface("clasica")
	await frames(3)
	check(game.view_rect == screen and game.hud_top.all(func(n): return n.visible),"Classic interface: full screen and HUD always visible")
	# The virtual shutter (docs/SIMULACION_FOTOGRAFICA.md §9): the photo as the mean of many frames.
	# Under a test it is one frame unless asked; here, twelve.
	var MainScript = preload("res://scripts/main.gd")
	check(game.photo_samples_cap() == 1,"Tests take their photos with one frame")
	game.set_interface("camara")
	game.start_session("day",true)
	game.equipment.preset(2)
	game.equipment.set_exposure_mode("P")
	game.apply_equipment()
	game.resume_search()
	game.sandbox_paused = true
	game.focal = 50.0
	game.update_camera()
	await frames(6)
	await game.take_photo()
	var plain: Image = game.current_photo.get_image()
	check(not game.current_result.evidence.get("exposed",false),"One frame: the photo is the plain frame, developed afterwards")
	game.resume_search()
	await frames(3)
	MainScript.photo_samples_override = 12
	var camera_before = [game.camera.position,game.angle,game.pitch,game.camera.fov,game.park.environment.environment.tonemap_exposure,DisplayServer.window_get_vsync_mode(),Engine.max_fps]
	await game.take_photo()
	var exposed: Image = game.current_photo.get_image()
	var ev: Dictionary = game.current_result.evidence
	check(ev.get("exposed",false) and int(ev.get("samples",0)) >= 8 and int(ev.samples) <= 12,"Twelve frames at most, eight at least (%d)" % int(ev.get("samples",0)))
	check(not game.exposing and not game.curtain.visible,"The shutter is closed again")
	check(game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and game.camera.keep_aspect == Camera3D.KEEP_WIDTH,"The camera is back to its own projection")
	var camera_after = [game.camera.position,game.angle,game.pitch,game.camera.fov,game.park.environment.environment.tonemap_exposure,DisplayServer.window_get_vsync_mode(),Engine.max_fps]
	check(camera_before[0].is_equal_approx(camera_after[0]) and is_equal_approx(camera_before[1],camera_after[1]) and is_equal_approx(camera_before[3],camera_after[3]),"…where it was (a still camera)")
	check(is_equal_approx(camera_before[4],camera_after[4]) and camera_before[5] == camera_after[5] and camera_before[6] == camera_after[6],"The scene's exposure, the vsync and the frame cap are as they were")
	var developed = game.photo_material(game.current_result)
	check(developed.get_shader_parameter("coc_pixels") == 0.0 and developed.get_shader_parameter("exposure") == 0.0 and developed.get_shader_parameter("motion") == Vector2.ZERO and developed.get_shader_parameter("shake") == Vector2.ZERO,"The develop pass adds no blur nor exposure to an exposed photo")
	# A still scene, well exposed: the mean of the frames is the same picture as the single frame.
	var same_size = plain.get_size() == exposed.get_size()
	var apart = 0.0
	var light = [0.0,0.0]
	if same_size:
		var cells = 0
		for y in range(8,plain.get_height()-8,24):
			for x in range(8,plain.get_width()-8,24):
				var a = plain.get_pixel(x,y)
				var b = exposed.get_pixel(x,y)
				apart += absf(a.get_luminance()-b.get_luminance())
				light[0] += a.get_luminance()
				light[1] += b.get_luminance()
				cells += 1
		apart /= cells
		light[0] /= cells
		light[1] /= cells
	check(same_size and light[1] > .08 and absf(light[1]-light[0]) < .06 and apart < .08,"A still, well exposed scene comes out as the single frame did (light %.3f against %.3f, %.3f apart)" % [light[1],light[0],apart])
	MainScript.photo_samples_override = -1
	game.sandbox_paused = false
	game.set_interface("clasica")
	# Leave the player's own choice as it was.
	if saved_interface != "":
		var f = FileAccess.open("user://interfaz.cfg",FileAccess.WRITE)
		f.store_string(saved_interface)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://interfaz.cfg"))
	print("FINDER TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
