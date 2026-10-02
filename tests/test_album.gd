extends SceneTree
# Photo album (scripts/album.gd): a developed photo is saved with its data, listed newest first,
# shown in the album screen, deleted on request and pruned to the newest MAX. With display.
const Main = preload("res://main.tscn")
const Album = preload("res://scripts/album.gd")
const Arcade = preload("res://scripts/arcade.gd")
const Texts = preload("res://scripts/texts.gd")
var checks = 0
var failures = 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func clean() -> void:
	var path = ProjectSettings.globalize_path(Album.DIR)
	if DirAccess.dir_exists_absolute(path):
		for f in DirAccess.get_files_at(path): DirAccess.remove_absolute(path+"/"+f)
		DirAccess.remove_absolute(path)

func run() -> void:
	Album.DIR = "user://album_test"
	Arcade.SAVE = "user://arcade_album_test.cfg"
	clean()
	check(Album.list().is_empty(),"An album that does not exist yet is empty")
	var game = Main.instantiate()
	root.add_child(game)
	for i in 30: await process_frame
	check(not game.badges_count(),"A test run is not the real game: it would never write to the player's album")
	game.start_level(0)
	for i in 3: await process_frame
	game.begin_assignment()
	for i in 20: await process_frame
	game.aim_at(game.target,1.0)
	for i in 5: await process_frame
	await game.take_photo()
	for i in 5: await process_frame
	check(Album.list().is_empty(),"Taking a photo in a test saves nothing by itself")
	var file = await game.save_to_album(game.current_photo,game.current_result)
	var photos = Album.list()
	check(photos.size() == 1 and photos[0].file == file and FileAccess.file_exists(Album.DIR+"/"+file),"The developed photo is saved as a file")
	check(int(photos[0].score) == game.current_result.score and is_equal_approx(float(photos[0].f),game.current_result.evidence.f) and str(photos[0].where) == Texts.get_text("album_nivel") % 1,"…with its score, its settings and where it was taken")
	var image = Album.load_image(file)
	check(image != null and image.get_width() == 1280 and image.get_height() == 720,"It is a 1280 × 720 picture")
	var lit = 0
	for k in 40:
		var c = image.get_pixel(40+k*30,360)
		if c.r+c.g+c.b > .15: lit += 1
	check(lit > 10,"…and not a black frame (%d of 40 samples lit)" % lit)
	game.show_album()
	await process_frame
	check(game.mode == "ALBUM" and game.modal.find_children("*","TextureRect",true,false).size() == 1,"The album screen shows its thumbnail")
	game.show_album_photo(0)
	await process_frame
	check(game.modal.find_children("*","Button",true,false).any(func(b): return b.text == Texts.get_text("album_borrar")),"A photo opens large, with the button to delete it")
	Album.remove(file)
	check(Album.list().is_empty() and not FileAccess.file_exists(Album.DIR+"/"+file),"Deleting removes the file and its entry")
	# Only the newest MAX are kept.
	var tiny = Image.create(8,8,false,Image.FORMAT_RGB8)
	for k in Album.MAX+3: Album.add(tiny,{"score":80+k%20})
	photos = Album.list()
	check(photos.size() == Album.MAX and int(photos[0].order) == Album.MAX+3 and int(photos[-1].order) == 4,"The album keeps the newest %d, newest first" % Album.MAX)
	game.show_album(99)
	await process_frame
	check(game.album_page == ceili(Album.MAX/8.0)-1,"The album pages through them")
	for key in ["menu_album","album_titulo","album_subtitulo","album_vacio","album_borrar","album_volver","album_abrir_carpeta","album_pagina"]:
		check(Texts.get_text(key) != key,"Text %s" % key)
	clean()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	print("ALBUM TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
