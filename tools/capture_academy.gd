extends SceneTree
# Evidence captures of the Academy (docs/futuro/06): menu, one theory page per lesson, each demo
# with its photos, the practices and a practice result with the side-by-side comparison.
#   ~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1600x900 --script tools/capture_academy.gd [-- --out=<dir>]
const Main = preload("res://main.tscn")
var out_dir = "res://docs/evidencias/academia"
var game
var academy

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path = ProjectSettings.globalize_path(out_dir.path_join(name+".png"))
	root.get_texture().get_image().save_png(path)
	print("ACADEMY SHOT: "+path)

func wait(seconds: float) -> void:
	var start = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < seconds*1000: await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	game = Main.instantiate()
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"   # (never the player's album)
	root.add_child(game)
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"   # (never the player's progress)
	game.exposure_thirds = false   # (not the player's option)
	for i in 30: await process_frame
	academy = game.academy
	academy.progress_path = "user://academia_evidencias.cfg"
	academy.reset_progress()
	# Theory pages (one per lesson) and the menu with some progress.
	var pages = {1:1, 2:2, 3:1, 4:2, 5:3}
	for n in range(1,academy.LESSONS+1):
		academy.begin(n)
		academy.page = pages[n]-1
		academy.update_panel()
		academy.mark(n,"teoria")
		await wait(1.5)
		await shot("%02d_leccion%d_teoria" % [n*10,n])
	# Demos, captured when their photos are in the panel.
	for n in range(1,academy.LESSONS+1):
		academy.begin(n,"demo")
		var start = Time.get_ticks_msec()
		while not academy.demo_done and Time.get_ticks_msec()-start < 40000: await process_frame
		await shot("%02d_leccion%d_demostracion" % [n*10+1,n])
	# Practices: the tutor panel with its tasks and hints.
	for n in range(1,academy.LESSONS+1):
		academy.begin(n,"practica")
		await wait(1.5)
		await shot("%02d_leccion%d_practica" % [n*10+2,n])
	# Lesson 5 result: a 28 mm photo close and a 135 mm photo far, side by side.
	academy.begin(5,"practica")
	await wait(1.0)
	var near = academy.subject   # the practice places someone close, on the inner path
	game.clear_sector([0,1,2,3],[near],40.0,true)
	game.set_sandbox_pause(true)
	academy.set_lens(3,28.0)
	academy.frame_goal = {"who":near,"x":.5,"y":.3,"snap":true}
	await wait(2.0)
	var pn = academy.point_on(near,4.0)
	game.finder.active = pn if pn >= 0 else 4
	await game.take_photo()
	for i in 5: await process_frame
	game.resume_search()
	near.set_hidden(true)
	game.set_sandbox_pause(false)
	var far = academy.stand_person(3,game.angle,11.6)
	game.clear_sector([0,1,2,3],[far],40.0,true)
	game.set_sandbox_pause(true)
	academy.set_lens(5,135.0)
	academy.frame_goal = {"who":far,"x":.5,"y":.3,"snap":true}
	await wait(2.0)
	var pf = academy.point_on(far,4.0)
	game.finder.active = pf if pf >= 0 else 4
	await game.take_photo()
	await wait(1.0)
	await shot("53_leccion5_resultado_diptico")
	game.resume_search()
	academy.exit_lesson()
	await wait(.5)
	await shot("00_menu")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://academia_evidencias.cfg"))
	quit()
