extends SceneTree
# Evidence of the interface (docs/futuro/20): every screen in the light style.
#   ~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1600x900 --script tools/capture_screens.gd [-- --out=<dir>]
const Main = preload("res://main.tscn")
var out_dir = "res://docs/evidencias/interfaz"
var game

func _initialize() -> void: call_deferred("run")

func shot(name: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir.path_join(name+".png")))
	print("SCREEN: "+name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	game = Main.instantiate()
	root.add_child(game)
	for i in 40: await process_frame
	await shot("01_menu")
	game.show_equipment()
	await shot("02_equipo")
	game.show_graphics_settings()
	await shot("03_graficos")
	game.intro()
	game.start_session("day")
	await shot("04_encargo")
	game.begin_assignment()
	game.set_interface("clasica")
	await shot("05_busqueda_clasica")
	game.show_help()
	await shot("06_ayuda")
	game.resume_search()
	await game.take_photo()
	await shot("07_resultado")
	game.intro()
	game.start_session("day",true)
	game.show_sandbox_controls()
	await shot("09_sandbox")
	game.resume_search()
	await game.take_photo()
	await shot("10_sandbox_resultado")
	game.set_interface("camara")
	game.resume_search()
	quit()
