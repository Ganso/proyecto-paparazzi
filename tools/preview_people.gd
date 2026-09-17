extends SceneTree
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = Node3D.new()
	root.add_child(world)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("d9d7c9")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cbd6df")
	env.environment.ambient_light_energy = .35
	world.add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,145,0)
	light.light_energy = .65
	light.shadow_enabled = true
	world.add_child(light)
	var ground = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(200,200)
	ground.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("c5c2b2")
	ground.material_override = mat
	world.add_child(ground)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.position = Vector3(0,1.85,-6)
	world.add_child(camera)
	camera.look_at(Vector3(0,.88,0))
	camera.current = true
	var cast = Cast.new()
	var styles = [[0,2,0,0,"burdeos","vaquero","castaño"],[1,1,1,3,"beige","rojo","pelirrojo"],[2,3,0,4,"negro","vaquero","moreno"],[3,0,2,1,"rojo","vaquero","castaño"],[1,0,3,2,"gris","azul marino","castaño"],[0,1,0,5,"verde","beige","moreno"]]
	for i in styles.size():
		var s = styles[i]
		var t = {"profile":s[0],"upper":s[1],"lower":s[2],"hair":s[3],"upper_color":s[4],"lower_color":s[5],"hair_color":s[6],"skin":"clara"}
		var p = Person.new()
		world.add_child(p)
		p.setup(t,cast.catalog,17+i)
		p.position.x = (2.5-i)*.73
		p.rotation.y = -.35 if i%2 == 0 else .4
		p.state = "DETENIDO"
		p.animate(0)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var filename = "/tmp/paparazzi-personajes.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): filename = arg.trim_prefix("--output=")
	root.get_texture().get_image().save_png(filename)
	print("PREVIEW: "+filename)
	quit()
