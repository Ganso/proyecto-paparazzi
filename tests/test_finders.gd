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
	root.add_child(game)
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
		check(FileAccess.file_exists("res://assets/audio/camara/%s.wav" % ["compacta","telemetrica","reflex","telemetrica"][body]),"Body %d: its shutter sound exists" % body)
		game.resume_search()
	# The classic interface is the full screen HUD, as before.
	game.set_interface("clasica")
	await frames(3)
	check(game.view_rect == screen and game.hud_top.all(func(n): return n.visible),"Classic interface: full screen and HUD always visible")
	# Leave the player's own choice as it was.
	if saved_interface != "":
		var f = FileAccess.open("user://interfaz.cfg",FileAccess.WRITE)
		f.store_string(saved_interface)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://interfaz.cfg"))
	print("FINDER TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
