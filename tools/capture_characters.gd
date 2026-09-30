extends SceneTree
# Evidence sheets of the character models (docs/evidencias/personajes_modelado/): every garment,
# hairstyle, accessory and body profile in four views, joint close-ups in motion and walk/run
# cycles to spot clipping. Uses Ultra's hd mannequins, so run it with Forward+:
#   ~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 800x1000 --script tools/capture_characters.gd
# Optional: -- --only=torsos,cabezas  --out=<dir>
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")

const VIEWS = [["frente", 0.0], ["3/4", 40.0], ["perfil", 90.0], ["espalda", 180.0]]
const CELL = Vector2i(400, 500)
# Framing: [centre height (m), orthographic height (m)].
const FRAMES = {"cuerpo": [0.9, 2.0], "torso": [1.3, 1.05], "piernas": [0.52, 1.15], "cabeza": [1.62, 0.5], "nino": [0.62, 1.45]}

var cast = Cast.new()
var world: Node3D
var camera: Camera3D
var caption: Label
var people: Array = []
var out_dir = "res://docs/evidencias/personajes_modelado"
var only: PackedStringArray = []

func _initialize() -> void:
	call_deferred("run")

func base_traits() -> Dictionary:
	return {"profile": 0, "upper": 0, "lower": 0, "hair": 0, "skin": "clara", "hair_color": "castaño",
		"upper_color": "rojo", "lower_color": "azul marino", "accessory": 0, "accessory_color": "amarillo", "runner": false}

func setup_world() -> void:
	Person.detail = "hd"
	var material = Person.mannequin_material()
	material.set_shader_parameter("textured", true)
	world = Node3D.new()
	root.add_child(world)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6fa3cf")
	sky_material.sky_horizon_color = Color("dce8ea")
	sky_material.ground_horizon_color = Color("c5d4c9")
	sky_material.ground_bottom_color = Color("738064")
	sky.sky_material = sky_material
	env.environment.sky = sky
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c9cfc8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = .5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment.tonemap_exposure = .9
	env.environment.tonemap_white = 1.45
	env.environment.ssao_enabled = true
	env.environment.ssao_radius = .5
	env.environment.ssao_intensity = 1.6
	world.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 1.2
	sun.light_color = Color("fff0d7")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12
	world.add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -30, 0)
	fill.light_energy = .25
	world.add_child(fill)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color("a9ada2")
	ground.material_override = ground_material
	world.add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(camera)
	camera.current = true
	var layer = CanvasLayer.new()
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(14, 10)
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_color", Color("1d2320"))
	layer.add_child(caption)

func clear_people() -> void:
	for p in people: p.queue_free()
	people.clear()

func spawn(traits: Dictionary, x = 0.0) -> Node3D:
	var p = Person.new()
	world.add_child(p)
	p.setup(traits, cast.catalog, 31)
	p.position = Vector3(x, 0, 0)
	people.append(p)
	return p

# kind: "reposo", "marcha", "carrera" or "sentado"; phase in radians of the gait cycle.
func pose(p, kind: String, phase = 0.0) -> void:
	match kind:
		"marcha", "carrera":
			p.state = "CAMINANDO"
			p.speed = 2.8 if kind == "carrera" else .75
			p.phase = phase
		"sentado":
			p.state = "SENTADO"
		_:
			p.state = "DETENIDO"
	p.animate(0)

func frame(key: String, target_x = 0.0) -> void:
	var f: Array = FRAMES[key]
	camera.size = f[1]
	camera.position = Vector3(target_x, f[0], -6)
	camera.look_at(Vector3(target_x, f[0], 0))

func settle() -> void:
	# Turning a person between views swings its springs (hair, skirt): reset them and let them rest.
	for p in people:
		var sim = p.rig.get_node_or_null("Muelles")
		if sim and sim.has_method("reset"): sim.reset()

func shot(text: String, still = true) -> Image:
	caption.text = text
	if still:
		settle()
		for k in 45: await process_frame
	for k in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return image

func save_sheet(name: String, cells: Array, columns: int) -> void:
	var rows = int(ceil(cells.size() / float(columns)))
	var sheet = Image.create(CELL.x * columns + (columns - 1) * 4, CELL.y * rows + (rows - 1) * 4, false, Image.FORMAT_RGB8)
	sheet.fill(Color.WHITE)
	for i in cells.size():
		var image: Image = cells[i]
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % columns) * (CELL.x + 4), (i / columns) * (CELL.y + 4)))
	var path = ProjectSettings.globalize_path(out_dir.path_join(name + ".png"))
	sheet.save_png(path)
	print("SHEET: " + path)

# One row per catalogue piece of `slot`, four views each.
func catalogue_sheet(name: String, slot: String, trait_key: String, framing: String, tweak: Callable) -> void:
	var cells = []
	var pieces: Array = cast.catalog.piezas[slot]
	for index in pieces.size():
		clear_people()
		var t = base_traits()
		t[trait_key] = index
		tweak.call(t, pieces[index])
		var p = spawn(t)
		pose(p, "reposo")
		frame(framing)
		for view in VIEWS:
			p.rotation.y = deg_to_rad(view[1])
			cells.append(await shot("%s · %s" % [pieces[index].id, view[0]]))
	save_sheet(name, cells, VIEWS.size())

func wants(name: String) -> bool:
	return only.is_empty() or name in only

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	setup_world()
	if wants("torsos"):
		await catalogue_sheet("01_torsos", "torso", "upper", "torso", func(t, piece):
			if piece.get("sport", false):
				t.lower = 5
				t.runner = true)
	if wants("piernas"):
		await catalogue_sheet("02_piernas", "piernas", "lower", "piernas", func(t, piece):
			if piece.get("sport", false):
				t.upper = 4
				t.runner = true)
	if wants("cabezas"):
		await catalogue_sheet("03_cabezas", "cabeza", "hair", "cabeza", func(t, piece): t.upper_color = "gris")
	if wants("accesorios"):
		await catalogue_sheet("04_accesorios", "accesorio", "accessory", "torso", func(t, piece): t.upper_color = "gris")
	if wants("perfiles"):
		var cells = []
		for profile in 4:
			clear_people()
			var t = base_traits()
			t.profile = profile
			var p = spawn(t)
			pose(p, "reposo")
			frame("nino" if cast.catalog.perfiles[profile].id == "nino" else "cuerpo")
			for view in VIEWS:
				p.rotation.y = deg_to_rad(view[1])
				cells.append(await shot("%s · %s" % [cast.catalog.perfiles[profile].id, view[0]]))
		save_sheet("05_perfiles", cells, VIEWS.size())
	if wants("articulaciones"):
		# Joints at the extremes of the stride, where sleeves, trousers and skirts clip most.
		var cells = []
		var outfits = [["camiseta + bermudas", {"upper": 0, "lower": 2}], ["americana + falda", {"upper": 2, "lower": 3}], ["sudadera + pantalón", {"upper": 3, "lower": 0}]]
		var zooms = [["hombro y codo", 1.35, .55], ["cadera y rodilla", .72, .6], ["tobillo y pie", .16, .4]]
		for outfit in outfits:
			for phase in [0.0, PI * .5]:
				clear_people()
				var t = base_traits()
				t.merge(outfit[1], true)
				var p = spawn(t)
				pose(p, "marcha", phase)
				p.rotation.y = deg_to_rad(70)
				for zoom in zooms:
					camera.size = zoom[2]
					camera.position = Vector3(0, zoom[1], -6)
					camera.look_at(Vector3(0, zoom[1], 0))
					cells.append(await shot("%s · %s · fase %d°" % [outfit[0], zoom[0], int(rad_to_deg(phase))]))
		save_sheet("06_articulaciones", cells, 3)
	if wants("movimiento"):
		var cells = []
		var cycles = [["marcha · americana + falda", {"upper": 2, "lower": 3, "hair": 2}, "marcha"], ["marcha · camisa + pantalón de vestir", {"upper": 1, "lower": 1, "hair": 6}, "marcha"], ["carrera · deportiva + mallas", {"upper": 4, "lower": 5, "hair": 3, "runner": true}, "carrera"]]
		for cycle in cycles:
			for step in 4:
				clear_people()
				var t = base_traits()
				t.merge(cycle[1], true)
				var p = spawn(t)
				pose(p, cycle[2], step * TAU / 4.0)
				p.rotation.y = deg_to_rad(90)
				frame("cuerpo")
				cells.append(await shot("%s · %d/4" % [cycle[0], step + 1]))
		save_sheet("07_movimiento", cells, 4)
	if wants("sentado"):
		var cells = []
		for outfit in [{"upper": 2, "lower": 3}, {"upper": 3, "lower": 0}, {"upper": 0, "lower": 2}]:
			clear_people()
			var t = base_traits()
			t.merge(outfit, true)
			var p = spawn(t)
			pose(p, "sentado")
			frame("cuerpo")
			for view in [VIEWS[1], VIEWS[2]]:
				p.rotation.y = deg_to_rad(view[1])
				cells.append(await shot("sentado · %s · %s" % [cast.catalog.piezas.torso[outfit.upper].id, view[0]]))
		save_sheet("08_sentado", cells, 2)
	if wants("dinamica"):
		# Secondary motion: walk (really moving through the world, as the springs need), then stop
		# dead. One frame every 0.2 s of simulated time at 60 Hz.
		var cells = []
		var cases = [["melena + falda", {"upper": 0, "lower": 3, "hair": 2}], ["coleta + camisa", {"upper": 1, "lower": 0, "hair": 3}], ["bandolera", {"upper": 0, "lower": 0, "hair": 0, "accessory": 2}], ["bandolera + falda", {"upper": 0, "lower": 3, "hair": 2, "accessory": 2}]]
		for case in cases:
			clear_people()
			var t = base_traits()
			t.merge(case[1], true)
			var p = spawn(t)
			p.rotation.y = deg_to_rad(90)
			p.state = "CAMINANDO"
			p.speed = 1.1
			var dt = 1.0 / 60.0
			for step in 150:
				if step == 90: p.state = "DETENIDO"
				var moving = p.state == "CAMINANDO"
				var d = p.speed * dt if moving else 0.0
				p.position += -p.global_basis.z * d
				p.animate(dt, d)
				camera.size = 2.0
				camera.position = Vector3(p.position.x, 0.95, -6)
				camera.look_at(Vector3(p.position.x, 0.95, 0))
				await process_frame
				if step % 12 == 0 and step >= 24:
					cells.append(await shot("%s · %.1f s%s" % [case[0], step * dt, " · parada" if step >= 90 else ""], false))
		save_sheet("09_dinamica", cells, 5)
	if wants("actividades"):
		# Activities of the park life (docs/futuro/19): upper-body poses and hand-held props.
		var cells = []
		var cases = [["móvil (de pie)", "movil", "reposo", 0.0], ["móvil (sentado)", "movil", "sentado", 0.0], ["periódico", "leer", "sentado", 0.0], ["café", "cafe", "reposo", 0.0], ["foto", "foto", "reposo", 3.0], ["palomas", "palomas", "sentado", 0.9], ["charla", "charla", "reposo", 5.0], ["mirar", "mirar", "reposo", 0.0], ["saludo", "charla", "reposo", 0.4], ["estirar", "estirar", "reposo", 1.7]]
		for case in cases:
			clear_people()
			var t = base_traits()
			t.merge({"upper": 1, "lower": 0, "hair": 1}, true)
			var p = spawn(t)
			p.activity = case[1]
			p.act_seed = 0.0
			p.act_time = case[3]
			pose(p, case[2])
			frame("cuerpo")
			for view in [VIEWS[1], VIEWS[2]]:
				p.rotation.y = deg_to_rad(view[1])
				p.animate(0)
				cells.append(await shot("%s · %s" % [case[0], view[0]]))
		save_sheet("10_actividades", cells, 4)
	quit()
