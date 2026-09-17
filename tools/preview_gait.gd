extends SceneTree
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
var pedestrians: Array = []
var ground_markers: Array = []
var output = "/tmp/paparazzi-gait"
var frame_count = 48
var realtime = false
func _initialize() -> void:
	call_deferred("run")
func make_panel(rect: Rect2, running: bool, front: bool) -> void:
	var container = SubViewportContainer.new()
	container.position = rect.position
	container.size = rect.size
	container.stretch = true
	root.add_child(container)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(rect.size)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world = Node3D.new()
	viewport.add_child(world)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c7d0d4")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = .22
	env.environment.ambient_light_color = Color.WHITE
	world.add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,145,0)
	light.shadow_enabled = true
	light.light_energy = .55
	world.add_child(light)
	var cast = Cast.new()
	var t = cast.generate(running)
	t.profile = 0
	t.accessory = 0
	t.hair = 4
	t.upper = 4 if running else 0
	t.lower = 4 if running else 2
	t.upper_color = "rojo"
	t.lower_color = "azul marino"
	var p = Person.new()
	world.add_child(p)
	p.setup(t,cast.catalog,20)
	p.speed = 3.0 if running else 1.2
	p.phase = 0
	p.animate(0)
	pedestrians.append(p)
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(30,30)
	var ground = MeshInstance3D.new()
	ground.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("abb7b1")
	ground.material_override = mat
	world.add_child(ground)
	var marker_root = Node3D.new()
	world.add_child(marker_root)
	for i in range(-14,15):
		var marker = MeshInstance3D.new()
		var bar = BoxMesh.new()
		bar.size = Vector3(2,.005,.012)
		marker.mesh = bar
		marker.position = Vector3(0,.003,i*.25)
		marker_root.add_child(marker)
	ground_markers.append(marker_root)
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.25
	camera.position = Vector3(.12,1.15,-5) if front else Vector3(5,1.15,.12)
	camera.look_at(Vector3(0,.87,0))
	camera.current = true
	var caption = Label.new()
	caption.text = ("CARRERA" if running else "MARCHA")+ (" · frontal" if front else " · perfil")
	caption.position = rect.position+Vector2(15,12)
	caption.add_theme_color_override("font_color",Color("172b27"))
	caption.add_theme_font_size_override("font_size",20)
	root.add_child(caption)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--realtime": realtime = true
		if arg.begins_with("--frames="): frame_count = int(arg.trim_prefix("--frames="))
	DirAccess.make_dir_recursive_absolute(output)
	make_panel(Rect2(0,0,640,360),false,false)
	make_panel(Rect2(640,0,640,360),false,true)
	make_panel(Rect2(0,360,640,360),true,false)
	make_panel(Rect2(640,360,640,360),true,true)
	for f in frame_count:
		for i in pedestrians.size():
			var p = pedestrians[i]
			var elapsed = float(f)/frame_count*(pedestrians[0].stride/pedestrians[0].speed*7)
			p.phase = fposmod(elapsed*p.speed/p.stride*TAU,TAU) if realtime else float(f)/frame_count*TAU
			p.animate(0)
			ground_markers[i].position.z = fposmod(elapsed*p.speed if realtime else float(f)/frame_count*p.stride,.25)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/%03d.png" % f)
	print("GAIT PREVIEW: "+output)
	quit()
