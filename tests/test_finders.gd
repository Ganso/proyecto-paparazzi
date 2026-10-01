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
	for body in 3:
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
		game.controls_shown = true
		await frames(2)
		check(game.hud_top.all(func(n): return n.visible) and game.hud_bottom.all(func(n): return n.visible),"Body %d: Tab shows the controls" % body)
		game.controls_shown = false
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
	for body in 3:
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
	for body in 3:
		game.equipment.preset(body)
		game.apply_equipment()
		game.set_interface("camara")
		game.mode = "SEARCH"
		game.shots = 3
		await frames(3)
		await game.take_photo()
		check(game.mode == "RESULT","Body %d: shooting through the finder works" % body)
		if body == 1 and game.dof_allowed(): check(game.current_result.evidence.get("rendered_dof",false),"Rangefinder: the photo does get the depth of field")
		check(FileAccess.file_exists("res://assets/audio/camara/%s.wav" % ["compacta","telemetrica","reflex"][body]),"Body %d: its shutter sound exists" % body)
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
