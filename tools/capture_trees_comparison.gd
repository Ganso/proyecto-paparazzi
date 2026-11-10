extends SceneTree

const MainScene = preload("res://main.tscn")
const ParkAssets = preload("res://scripts/park_assets.gd")
const ParkScene = preload("res://scripts/park.gd")

var tag = "antes"
var out_dir = "docs/evidencias/comparativas"

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	await capture_studio("arbol_platano", 0, Vector3(0, 2.0, 4.2), Vector3(0, 1.8, 0))
	await capture_studio("arbol_tilo", 0, Vector3(0, 1.8, 4.0), Vector3(0, 1.6, 0))
	await capture_studio("arbol_cipres", 0, Vector3(0, 2.4, 5.2), Vector3(0, 2.2, 0))
	await capture_park()
	
	print("CAPTURE TREES COMPARISON FINISHED: tag=" + tag)
	quit()

func capture_studio(asset: String, variant: int, cam_pos: Vector3, cam_target: Vector3) -> void:
	var vp = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.own_world_3d = true
	var world = World3D.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1e262c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9ec5e8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = env
	vp.world_3d = world
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	
	var scene = Node3D.new()
	vp.add_child(scene)
	
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 45, 0)
	sun.light_color = Color("fff2dc")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	scene.add_child(sun)
	
	var cam = Camera3D.new()
	scene.add_child(cam)
	cam.position = cam_pos
	cam.look_at(cam_target)
	cam.fov = 40.0
	
	# Load tree meshes
	var variants = ParkAssets.meshes(asset, "hd")
	var v_data = variants.get(str(variant), {})
	for role in v_data:
		var mi = MeshInstance3D.new()
		mi.mesh = v_data[role]
		var mat = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = 0.82
		mat.metallic_specular = 0.25
		mi.material_override = mat
		scene.add_child(mi)
	
	await frames(5)
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	var filename = "%s/%s_%s.png" % [out_dir, asset, tag]
	img.save_png(filename)
	print("Saved studio: " + filename)
	vp.queue_free()
	await frames(2)

func capture_park() -> void:
	# Using main scene for full park rendering
	var game = MainScene.instantiate()
	root.add_child(game)
	await frames(10)
	game.start_session("golden", true)
	await frames(25)
	# Frame trees near quiosco / ring
	game.camera_omega = 0.0
	game.angle = 120.0
	game.pitch = 2.0
	game.focal = 50.0
	game.update_camera()
	await frames(15)
	await RenderingServer.frame_post_draw
	var img = game.viewport.get_texture().get_image()
	var filename = "%s/arbol_parque_dorada_%s.png" % [out_dir, tag]
	img.save_png(filename)
	print("Saved park: " + filename)
	game.queue_free()
	await frames(2)
