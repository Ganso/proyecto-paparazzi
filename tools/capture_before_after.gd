extends SceneTree
# Before and after of the photo (docs/SIMULACION_FOTOGRAFICA.md §9): each scene is set once and
# developed twice from the same instant — as the game did until 07-10-2026 (one frame worked over
# afterwards: Main.legacy) and with the virtual shutter and the glass. tools/capture_before_after.sh
# runs it in both renderers and cuts the video.
#   ~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1920x1080 --script tools/capture_before_after.gd -- --out=<folder>
# Writes <n>_<scene>_antes.png, <n>_<scene>_despues.png and escenas.txt (title and settings).
const MainScript = preload("res://scripts/main.gd")
const Photo = preload("res://scripts/photography.gd")
const Conditions = preload("res://scripts/conditions.gd")
const Arcade = preload("res://scripts/arcade.gd")
var game
var out = "res://build/antes_despues"
var index = 0
var listing = ""

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

# The plain image through the develop pass, as the result screen and the album show it.
func develop(image: Image, result: Dictionary) -> Image:
	var room = SubViewport.new()
	room.size = image.get_size()
	room.disable_3d = true
	room.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(room)
	var print_rect = TextureRect.new()
	print_rect.texture = ImageTexture.create_from_image(image)
	print_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	print_rect.size = Vector2(image.get_size())
	print_rect.material = game.photo_material(result)
	room.add_child(print_rect)
	await frames(3)
	await RenderingServer.frame_post_draw
	var developed = room.get_texture().get_image()
	room.queue_free()
	return developed

func both(name: String, title: String, omega = 0.0, cond = {}) -> void:
	await physics_frame
	var e: Dictionary = game.capture_sandbox_evidence() if game.sandbox else game.capture_evidence()
	e["camera_omega"] = omega
	e["ca"] = float(game.equipment.lens().get("ca",.5))
	e["stops"] = 2.0*log(game.aperture_value()/game.equipment.apertures(game.focal)[0])/log(2.0)
	game.lens_evidence(e)
	# Before: one frame (with the finder's own blur where the profile draws it), developed the old way.
	if game.dof_allowed() and not game.dof_blur: game.set_dof_blur(true)
	var old: Dictionary = e.duplicate(true)
	old["rendered_dof"] = game.dof_active()
	var old_result = Conditions.judge(old,cond)
	old_result["evidence"] = old
	await frames(2)
	await RenderingServer.frame_post_draw
	var plain: Image = game.viewport.get_texture().get_image()
	MainScript.legacy = true
	var before = await develop(crop(plain),old_result)
	MainScript.legacy = false
	# After: the virtual shutter from that same instant.
	var result = Conditions.judge(e,cond)
	result["evidence"] = e
	var exposed: Image = await game.expose_photo(e,result,omega,game.photo_samples(e,result))
	var after = await develop(crop(exposed),result)
	index += 1
	var base = ProjectSettings.globalize_path(out).path_join("%02d_%s" % [index,name])
	before.save_png(base+"_antes.png")
	after.save_png(base+"_despues.png")
	var settings = "%d mm · f/%s · 1/%d s · ISO %d" % [roundi(e.f),str(e.n),roundi(1.0/e.t),e.iso]
	listing += "%02d_%s|%s|%s\n" % [index,name,title,settings]
	print("ESCENA %02d %s · %s · %d muestras" % [index,name,settings,int(e.get("samples",1))])
	game.update_dof_pass()

func crop(image: Image) -> Image:
	if not game.equipment.tlr(): return image
	var side = image.get_height()
	return image.get_region(Rect2i((image.get_width()-side)/2,0,side,side))

# A level's own subject, running, framed at `focal`; the shutter chosen and the rest by the camera.
func runner_scene(level: int, focal: float, shutter: int) -> Node:
	game.intro()
	game.start_level(level)
	await frames(3)
	game.begin_assignment()
	game.ui.visible = false
	var r = game.target
	for i in 1200:
		await process_frame
		if r.state == "CAMINANDO" and r.actual_velocity.length() > 2.4: break
	game.focal = focal
	game.t_index = Photo.DENOMINATORS.find(shutter)
	game.aim_at(r,1.0)
	game.update_camera()
	await frames(2)
	game.focus_distance = game.camera.global_position.distance_to(r.control_points()[0])
	# (metered on the runner himself, as the levels do)
	game.measured_ev = game.park.illumination_ev(r.control_points()[1],game.time_of_day,r)
	game.auto_expose()
	game.refresh()
	return r

# The sandbox with a body and a lens, looking somewhere, with the aperture or the shutter chosen.
func free_scene(tod: String, body: int, lens: int, focal: float, look: float, pitch: float, mode: String, value: float, at_sun = false) -> void:
	game.intro()
	game.start_session(tod,true)
	game.equipment.preset(body)
	game.equipment.lens_index = lens
	game.equipment.set_exposure_mode(mode)
	game.apply_equipment()
	game.resume_search()
	game.ui.visible = false
	game.focal = focal
	var sun: Vector3 = game.park.sun.global_basis.z
	game.angle = look+(rad_to_deg(atan2(sun.x,-sun.z)) if at_sun else 0.0)
	game.pitch = pitch
	game.update_camera()
	if mode == "A": game.n_index = maxi(0,game.apertures().find(value))
	else: game.t_index = Photo.DENOMINATORS.find(int(value))
	await frames(20)
	game.update_meter()
	game.auto_expose()
	game.refresh()

# Someone of the bench path, walking, in the middle of the frame and in focus.
func aim_at_walker(lane: int) -> void:
	var who = null
	for p in game.people:
		if p.visible and p.state == "CAMINANDO" and not p.runner and p.lane == lane: who = p
	if who == null: return
	for i in 12:
		game.aim_at(who,1.0)
		await process_frame
	game.update_camera()
	game.focus_distance = game.camera.global_position.distance_to(who.control_points()[0])
	game.update_meter()
	game.auto_expose()
	game.refresh()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Arcade.SAVE = "user://arcade_pruebas.cfg"
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"
	MainScript.photo_samples_override = 64
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.exposure_thirds = false
	await frames(40)
	# 1 · The pan: the camera turning with the runner at 1/30 s.
	var r = await runner_scene(25,85.0,30)
	var d = game.camera.global_position.distance_to(r.control_points()[1])
	await both("barrido","Barrido siguiendo al corredor",r.actual_velocity.dot(game.camera.global_basis.x)/d,{"barrido":true})
	# 2 · The same runner with the camera still: the trail.
	r = await runner_scene(26,50.0,30)
	await both("estela","Corredor a 1/30 s con la cámara quieta",0.0,{"estela":true})
	# 3 · Frozen, for reference: 1/1000 s.
	r = await runner_scene(9,135.0,1000)
	await both("congelado","Corredor congelado a 1/1000 s",0.0,{"congelado":true})
	# 4 · The hand: a telephoto at 1/15 s.
	await free_scene("day",2,4,105.0,125.0,-3.0,"S",15)
	await both("trepidacion","Trepidación: 105 mm a pulso a 1/15 s")
	# 5 · Depth of field: someone near with the fast telephoto wide open.
	await free_scene("day",2,4,105.0,125.0,-3.0,"A",1.8)
	await aim_at_walker(1)
	await both("fondo","Fondo desenfocado: 105 mm a f/1,8")
	# 6 · Two stops over and two under.
	await free_scene("day",2,0,35.0,125.0,-4.0,"M",0)
	game.expose_for(game.measured_ev)
	game.t_index = mini(game.t_index+2,Photo.DENOMINATORS.size()-1)
	await both("quemada","Dos pasos sobreexpuesta")
	await free_scene("day",2,0,35.0,125.0,-4.0,"M",0)
	game.expose_for(game.measured_ev)
	game.t_index = maxi(game.t_index-2,game.fastest_index())
	game.n_index = mini(game.n_index+1,game.apertures().size()-1)
	await both("oscura","Subexpuesta")
	# 7 · The sun in the frame.
	await free_scene("golden",2,0,24.0,0.0,6.0,"A",8.0,true)
	await both("sol","El sol en el encuadre, a la hora dorada")
	# 8 · The lamps at night with the aperture closed.
	await free_scene("night",2,0,28.0,125.0,2.0,"A",16.0)
	await both("estrellas","Farolas de noche a f/16")
	# 9 · Straight lines at 24 mm.
	await free_scene("day",2,0,24.0,125.0,-2.0,"A",8.0)
	await both("lineas","Líneas rectas a 24 mm")
	# 10 · High ISO at night, and film.
	await free_scene("night",2,2,50.0,125.0,-2.0,"A",2.8)
	await both("ruido","De noche a ISO alto: el ruido del sensor")
	await free_scene("blue",3,0,50.0,125.0,-2.0,"M",0)
	game.expose_for(game.measured_ev)
	await both("pelicula","La TLR con carrete: el grano")
	var f = FileAccess.open(ProjectSettings.globalize_path(out).path_join("escenas.txt"),FileAccess.WRITE)
	f.store_string(listing)
	f.close()
	quit()
