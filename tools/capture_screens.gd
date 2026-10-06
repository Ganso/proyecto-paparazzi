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
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"   # (never the player's album)
	root.add_child(game)
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"   # (never the player's progress)
	for i in 40: await process_frame
	# --tercios: only the screens of the thirds of a stop (the switch is set in memory, not saved).
	if "--tercios" in OS.get_cmdline_user_args():
		await thirds()
		quit()
		return
	await shot("01_menu")
	game.show_equipment()
	await shot("02_equipo")
	game.show_graphics_settings()
	await shot("03_graficos")
	game.show_badges()
	await shot("03b_insignias")
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
	# Arcade (docs/futuro/21): level select, a TLR level's briefing, its finder, a photo and the end.
	game.show_arcade()
	await shot("11_arcade")
	game.start_level(20)
	await shot("12_nivel_encargo")
	game.set_interface("camara")
	game.begin_assignment()
	for i in 30: await process_frame
	await shot("13_tlr_visor")
	game.tlr_loupe = true
	game.update_finder_shader()
	await shot("14_tlr_lupa")
	game.tlr_loupe = false
	game.update_finder_shader()
	game.set_interface("clasica")
	await shot("15_tlr_clasica")
	await game.take_photo()
	await shot("16_tlr_resultado")
	game.end_level()
	await shot("17_fin_nivel")
	# Menu of five modes, tutorial, controls with keyboard and with pad, pause (docs/futuro/22).
	for k in 6:
		game.intro()
		game.modal.current = k
		game.modal.build_card()
		await shot("18_menu_%d_%s" % [k+1,game.modal.MODES[k]])
	game.start_tutorial()
	game.tutorial.next()
	await shot("19_tutorial")
	game.show_help()
	await shot("20_ayuda_teclado")
	var G = preload("res://scripts/input_glyphs.gd")
	G.device = "mando"
	game.show_help()
	await shot("21_ayuda_mando")
	G.device = "teclado"
	game.resume_search()
	game.show_pause()
	await shot("22_pausa")
	game.leave_phase()
	game.set_interface("camara")
	await thirds()
	quit()

# Thirds of a stop: the switch in Opciones, the finders with third values, and the three places
# that advise it (tutorial, the Academy's exposure lesson and the briefing of a manual level).
func thirds() -> void:
	var G = preload("res://scripts/input_glyphs.gd")
	game.exposure_thirds = true
	game.intro()
	game.modal.current = 4
	game.modal.build_card()
	await shot("23_opciones_tercios")
	game.set_interface("camara")
	for body in [1,2,3]:
		game.start_session("day",true)
		game.equipment.preset(body)
		game.equipment.set_exposure_mode("M")
		game.apply_equipment()
		game.resume_search()
		game.selected_control = "n"
		for i in 4: game.change_parameter("n",1)
		for i in 2: game.change_parameter("t",1)
		for i in 4: game.change_parameter("iso",1)
		for i in 30: await process_frame
		await shot("24_visor_tercios_%d" % body)
	game.exposure_thirds = false
	game.intro()
	game.start_tutorial()
	game.tutorial.step = game.tutorial.STEPS.find("tercios")
	for device in ["teclado","mando"]:
		G.device = device
		game.tutorial.enter_step()
		await shot("25_tutorial_tercios_"+device)
	G.device = "teclado"
	game.tutorial.stop()
	game.intro()
	game.academy.progress_path = OS.get_cache_dir().path_join("photohacks_capturas_academia.cfg")   # (not the player's progress)
	game.academy.begin(4,"practica")
	for i in 20: await process_frame
	game.academy.tasks = [true,true,true]
	for i in 40: await process_frame
	await shot("26_academia_tercios")
	game.academy.stop()
	game.intro()
	game.start_level(18)
	await shot("27_arcade_aviso_tercios")
	game.intro()
