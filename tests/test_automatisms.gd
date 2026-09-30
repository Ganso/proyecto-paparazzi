extends SceneTree
# Automatisms never know who the assignment is about (docs/futuro/12 §2.1, fase 0): matrix AF and
# the automatic exposure pick the same point and reading whoever the target is.
# Needs a display: ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_automatisms.gd
const Main = preload("res://main.tscn")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	for i in 10: await process_frame
	game.start_session("day")
	game.begin_assignment()
	game.mode = "SEARCH"
	game.equipment.focus_mode = "AF matricial"
	game.equipment.auto_exposure = true
	var tested = 0
	for view in [60.0,120.0,200.0,300.0]:
		game.angle = view
		game.pitch = -4.0
		game.focal = game.equipment.lens().min
		game.update_camera()
		for i in 3: await physics_frame
		await process_frame
		var visible_people = game.people.filter(func(p): return game.camera.is_position_in_frustum(p.position+Vector3.UP))
		if visible_people.size() < 2: continue
		var picks = []
		var readings = []
		for candidate in visible_people.slice(0,3):
			game.target = candidate
			game.select_matrix_point()
			game.update_meter()
			picks.append(game.finder.active)
			readings.append(snappedf(game.measured_ev,.001))
		tested += 1
		check(picks.all(func(v): return v == picks[0]),"Matrix AF picks the same point whoever the target is (view %d°: %s)" % [view,str(picks)])
		check(readings.all(func(v): return v == readings[0]),"The meter reads the same whoever the target is (view %d°)" % view)
	check(tested >= 2,"Enough views with several people to compare (%d)" % tested)
	print("AUTOMATISMS TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
