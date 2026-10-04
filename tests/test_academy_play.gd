extends SceneTree
# The Academy played for real, lesson by lesson (scripts/academy_player.gd): every practice is
# done task by task with the game's own controls and photos, and every exam is taken. Proves that
# each one can be passed with what its lesson teaches. With display:
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_academy_play.gd [-- --only=6]
const Main = preload("res://main.tscn")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var only = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = int(arg.trim_prefix("--only="))
	var game = Main.instantiate()
	root.add_child(game)
	for i in 40: await process_frame
	game.academy.progress_path = "user://academia_play_test.cfg"
	game.academy.load_progress()
	game.academy.reset_progress()
	var player = preload("res://scripts/academy_player.gd").new(game.academy)
	player.page_seconds = .3
	player.with_demo = false
	Engine.time_scale = 3.0
	await player.run(only if only > 0 else 1,only if only > 0 else game.academy.LESSONS)
	Engine.time_scale = 1.0
	for r in player.results:
		check(r.practice,"Practice of «%s» can be completed" % r.kind)
		var why = ", ".join(r.lines.filter(func(l): return not l[0]).map(func(l): return l[1]))
		check(r.exam,"Exam of «%s» can be passed (%s)" % [r.kind,why])
	check(player.results.size() == (1 if only > 0 else game.academy.LESSONS),"Every lesson was played")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://academia_play_test.cfg"))
	print("ACADEMY PLAY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
