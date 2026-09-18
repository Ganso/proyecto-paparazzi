extends SceneTree

const MainScene = preload("res://main.tscn")
const Cast = preload("res://scripts/casting.gd")
const Person = preload("res://scripts/person.gd")
const ParkScene = preload("res://scripts/park.gd")

var scratch_dir = "docs/evidencias/scratch"
var docs_dir = "docs/evidencias"

func _initialize() -> void:
	call_deferred("start")

func wait_frames(count: int = 5) -> void:
	for i in count:
		await process_frame

func capture_viewport_to(vp: Viewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(path)

func start() -> void:
	print("=== INICIANDO CAPTURA AUTOMÁTICA DE EVIDENCIAS ===")
	DirAccess.make_dir_recursive_absolute(scratch_dir)
	DirAccess.make_dir_recursive_absolute(docs_dir + "/estados")
	DirAccess.make_dir_recursive_absolute(docs_dir + "/sheets")
	DirAccess.make_dir_recursive_absolute(docs_dir + "/personajes")
	DirAccess.make_dir_recursive_absolute(docs_dir + "/animaciones")

	var gdignore_path = docs_dir + "/.gdignore"
	if not FileAccess.file_exists(gdignore_path):
		var f = FileAccess.open(gdignore_path, FileAccess.WRITE)
		f.store_string("")
		f.close()

	await phase_1_game_states()
	await phase_2_spritesheets_and_lineup()
	await phase_3_animations()

	print(">> Fase en motor Godot terminada con éxito. Cerrando proceso Godot...")
	quit(0)

# -------------------------------------------------------------
# FASE 1: ESTADOS DEL JUEGO
# -------------------------------------------------------------
func phase_1_game_states() -> void:
	print(">> FASE 1: Capturando estados del juego...")
	var game = MainScene.instantiate()
	root.add_child(game)
	await wait_frames(12)

	# 01. Inicio / Intro
	await capture_viewport_to(root, docs_dir + "/estados/01_inicio.png")
	print("   [✓] 01_inicio.png capturado")

	# Iniciar sesión y pasar a Briefing
	game.equipment.preset(2) # Réflex
	game.start_session(false)
	await wait_frames(8)

	# 02. Briefing con retrato 3D y descripción
	await capture_viewport_to(root, docs_dir + "/estados/02_briefing.png")
	print("   [✓] 02_briefing.png capturado")

	# Entrar a SEARCH
	game.begin_assignment()
	await wait_frames(8)

	# 03. Visor réflex con 9 colimadores y exposímetro
	await capture_viewport_to(root, docs_dir + "/estados/03_visor_reflex.png")
	print("   [✓] 03_visor_reflex.png capturado")

	# 04. Vista diurna de gran angular (28mm equivalente)
	game.focal = 28.0
	game.apply_equipment()
	game.finder.visible = false
	await wait_frames(6)
	await capture_viewport_to(root, docs_dir + "/estados/04_parque_dia.png")
	game.finder.visible = true
	print("   [✓] 04_parque_dia.png capturado")

	# 05. Nubes y caída de EV
	game.park.cloud_cover = 0.85
	game.park.weather_time = 7.3
	game.park.update_weather(0.1)
	game.update_meter()
	await wait_frames(6)
	await capture_viewport_to(root, docs_dir + "/estados/05_nubes_ev.png")
	print("   [✓] 05_nubes_ev.png capturado")

	# 06. Parque de noche con farolas encendidas
	game.park.set_night(true)
	game.night = true
	game.update_meter()
	await wait_frames(6)
	await capture_viewport_to(root, docs_dir + "/estados/06_parque_noche.png")
	print("   [✓] 06_parque_noche.png capturado")

	# 07. Revelado / Resultado de foto
	game.night = false
	game.park.set_night(false)
	game.take_photo()
	await wait_frames(8)
	await capture_viewport_to(root, docs_dir + "/estados/07_revelado.png")
	print("   [✓] 07_revelado.png capturado")

	game.queue_free()
	await wait_frames(4)

# -------------------------------------------------------------
# HELPERS DE CREACIÓN DE PROPS PARA ESTUDIO 3D
# -------------------------------------------------------------
func build_banco(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	for x in [-.65, .65]:
		park.cube(Vector3(.07, .46, .48), Vector3(x, .23, .15), Color("48514a"), "", b)
	for j in 3:
		park.cube(Vector3(1.65, .045, .13), Vector3(0, .47, j * .14), Color("ac8250"), "", b)
		park.cube(Vector3(1.65, .105, .045), Vector3(0, .66 + j * .13, .4), Color("ac8250"), "", b)
	b.rotation_degrees.y = 25

func build_farola(park: ParkScene, parent: Node3D) -> void:
	var f = Node3D.new()
	parent.add_child(f)
	park.cylinder(.055, 2.55, Vector3.UP * 1.275, Color("4d5552"), "", f)
	park.cylinder(.12, .15, Vector3.UP * .075, Color("575c55"), "", f)
	park.cylinder(.19, .38, Vector3.UP * 2.55, Color("efdeaf"), "", f, .12)
	park.cylinder(.24, .11, Vector3.UP * 2.79, Color("505753"), "", f, .03)

func build_papelera(park: ParkScene, parent: Node3D) -> void:
	var p = Node3D.new()
	parent.add_child(p)
	park.cylinder(.25, .7, Vector3.UP * .35, Color("425d57"), "", p)

func build_jardinera(park: ParkScene, parent: Node3D) -> void:
	var j = Node3D.new()
	parent.add_child(j)
	park.cube(Vector3(.9, .35, .7), Vector3.UP * .175, Color("a78366"), "", j)
	for idx in 5:
		park.cylinder(.09, .14, Vector3((idx - 2) * .15, .43, 0), Color("d6ac4b"), "", j)
	j.rotation_degrees.y = 20

func build_fuente(park: ParkScene, parent: Node3D) -> void:
	var f = Node3D.new()
	parent.add_child(f)
	park.cylinder(.6, .3, Vector3.UP * .15, Color("8a908a"), "", f)
	park.cylinder(.2, .8, Vector3.UP * .5, Color("767d76"), "", f)
	park.cylinder(.4, .15, Vector3.UP * .9, Color("9ea59e"), "", f)

func build_verja(park: ParkScene, parent: Node3D) -> void:
	var v = Node3D.new()
	parent.add_child(v)
	park.cylinder(.05, 1.2, Vector3.UP * .6, Color("3a403d"), "", v)
	park.cylinder(.05, 1.2, Vector3(0.6, .6, 0), Color("3a403d"), "", v)
	park.cylinder(.05, 1.2, Vector3(-0.6, .6, 0), Color("3a403d"), "", v)
	park.cube(Vector3(1.4, .04, .04), Vector3(0, .3, 0), Color("3a403d"), "", v)
	park.cube(Vector3(1.4, .04, .04), Vector3(0, .9, 0), Color("3a403d"), "", v)

func build_arbol_grande(park: ParkScene, parent: Node3D) -> void:
	var a = Node3D.new()
	parent.add_child(a)
	park.cylinder(.3, 2.4, Vector3.UP * 1.2, Color("574332"), "", a)
	var foliage = SphereMesh.new()
	foliage.radius = 1.3
	foliage.height = 2.4
	foliage.radial_segments = 6
	foliage.rings = 2
	park.prop(foliage, Vector3(0, 3.0, 0), Color("476231"), "", a)

func build_arbol_medio(park: ParkScene, parent: Node3D) -> void:
	var a = Node3D.new()
	parent.add_child(a)
	park.cylinder(.18, 1.8, Vector3.UP * .9, Color("624d3a"), "", a)
	var foliage = SphereMesh.new()
	foliage.radius = .9
	foliage.height = 1.7
	foliage.radial_segments = 5
	foliage.rings = 2
	park.prop(foliage, Vector3(0, 2.2, 0), Color("557739"), "", a)

func build_seto(park: ParkScene, parent: Node3D) -> void:
	var s = Node3D.new()
	parent.add_child(s)
	park.cube(Vector3(1.8, 1.4, 0.7), Vector3.UP * 0.7, Color("354e28"), "", s)

func build_arbusto(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	var foliage = SphereMesh.new()
	foliage.radius = .5
	foliage.height = .75
	foliage.radial_segments = 6
	foliage.rings = 2
	park.prop(foliage, Vector3.UP * .35, Color("617b43"), "", b)

func build_mata_flores(park: ParkScene, parent: Node3D, c: Color) -> void:
	var m = Node3D.new()
	parent.add_child(m)
	park.cylinder(.3, .15, Vector3.UP * .075, Color("4c6338"), "", m)
	for k in 4:
		park.cylinder(.06, .12, Vector3((k - 1.5) * .1, .15, 0), c, "", m)

func build_cam_compacta(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	park.cube(Vector3(.22, .14, .07), Vector3.ZERO, Color("2b3036"), "", b)
	park.cylinder(.045, .06, Vector3(0, 0, .04), Color("15181b"), "", b)
	park.cylinder(.025, .03, Vector3(.07, .05, -.035), Color("7a8590"), "", b)
	b.rotation_degrees = Vector3(15, 30, 0)

func build_cam_telemetrica(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	park.cube(Vector3(.28, .17, .09), Vector3.ZERO, Color("30353c"), "", b)
	park.cube(Vector3(.28, .04, .09), Vector3(0, .09, 0), Color("969ea8"), "", b)
	park.cylinder(.06, .12, Vector3(0, -.01, .07), Color("202428"), "", b)
	park.cylinder(.02, .03, Vector3(.09, .12, -.02), Color("b0b8c2"), "", b)
	b.rotation_degrees = Vector3(15, 30, 0)

func build_cam_reflex(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	park.cube(Vector3(.32, .20, .12), Vector3.ZERO, Color("1b1e22"), "", b)
	park.cube(Vector3(.12, .10, .11), Vector3(0, .12, 0), Color("1b1e22"), "", b)
	park.cylinder(.08, .16, Vector3(0, -.01, .10), Color("121417"), "", b)
	park.cylinder(.03, .04, Vector3(.11, .11, -.02), Color("2d333b"), "", b)
	b.rotation_degrees = Vector3(15, 30, 0)

func build_teleobjetivo(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	park.cylinder(.08, .32, Vector3.ZERO, Color("d8deda"), "", b)
	park.cylinder(.078, .08, Vector3(0, .05, 0), Color("22252a"), "", b)
	park.cylinder(.078, .06, Vector3(0, -.08, 0), Color("22252a"), "", b)
	b.rotation_degrees = Vector3(45, 45, 0)

func build_objetivo_fijo(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	park.cylinder(.07, .11, Vector3.ZERO, Color("1c1f24"), "", b)
	park.cylinder(.068, .04, Vector3(0, .01, 0), Color("2b313a"), "", b)
	b.rotation_degrees = Vector3(45, 45, 0)

func build_carrete(park: ParkScene, parent: Node3D) -> void:
	var b = Node3D.new()
	parent.add_child(b)
	park.cylinder(.05, .12, Vector3.ZERO, Color("262a2e"), "", b)
	park.cylinder(.02, .16, Vector3.ZERO, Color("d19e34"), "", b)
	park.cube(Vector3(.07, .08, .01), Vector3(.05, 0, .03), Color("1e2226"), "", b)
	b.rotation_degrees = Vector3(20, 35, 0)

# -------------------------------------------------------------
# FASE 2: SPRITESHEETS Y LINEUP EN VIEWPORT DE ESTUDIO
# -------------------------------------------------------------
func phase_2_spritesheets_and_lineup() -> void:
	print(">> FASE 2: Renderizando assets individuales y lineup en estudio 3D...")

	var vp = SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var studio_root = Node3D.new()
	vp.add_child(studio_root)

	var light1 = DirectionalLight3D.new()
	light1.rotation_degrees = Vector3(-35, 40, 0)
	light1.light_energy = 1.3
	studio_root.add_child(light1)

	var light2 = DirectionalLight3D.new()
	light2.rotation_degrees = Vector3(25, -140, 0)
	light2.light_energy = 0.4
	light2.light_color = Color("c0d5e8")
	studio_root.add_child(light2)

	var cam = Camera3D.new()
	cam.position = Vector3(0, 1.1, 2.5)
	cam.current = true
	studio_root.add_child(cam)

	var casting = Cast.new()
	var park = ParkScene.new()
	studio_root.add_child(park)

	# 2.1 Mobiliario
	var mob_configs = [
		{"name": "banco_madera", "y": 0.35, "dist": 2.2, "func": "build_banco"},
		{"name": "farola_forja", "y": 1.4, "dist": 3.4, "func": "build_farola"},
		{"name": "papelera", "y": 0.4, "dist": 1.5, "func": "build_papelera"},
		{"name": "jardinera", "y": 0.35, "dist": 1.8, "func": "build_jardinera"},
		{"name": "fuente", "y": 0.5, "dist": 2.2, "func": "build_fuente"},
		{"name": "verja_perimetral", "y": 0.6, "dist": 2.2, "func": "build_verja"}
	]
	for item in mob_configs:
		var container = Node3D.new()
		studio_root.add_child(container)
		cam.position = Vector3(0, item.y, item.dist)
		cam.look_at(Vector3(0, item.y, 0))
		call(item.func, park, container)
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/mob_" + item.name + ".png")
		container.queue_free()
		await wait_frames(2)

	# 2.2 Vegetación
	var veg_configs = [
		{"name": "arbol_grande", "y": 2.2, "dist": 5.2, "func": "build_arbol_grande"},
		{"name": "arbol_medio", "y": 1.7, "dist": 4.0, "func": "build_arbol_medio"},
		{"name": "seto_denso", "y": 0.8, "dist": 2.5, "func": "build_seto"},
		{"name": "arbusto_redondo", "y": 0.5, "dist": 1.8, "func": "build_arbusto"}
	]
	for item in veg_configs:
		var container = Node3D.new()
		studio_root.add_child(container)
		cam.position = Vector3(0, item.y, item.dist)
		cam.look_at(Vector3(0, item.y, 0))
		call(item.func, park, container)
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/veg_" + item.name + ".png")
		container.queue_free()
		await wait_frames(2)

	# Flores
	for f_item in [{"name": "mata_flores", "col": Color("e0b445")}, {"name": "mata_rosas", "col": Color("c8526d")}]:
		var container = Node3D.new()
		studio_root.add_child(container)
		cam.position = Vector3(0, 0.35, 1.5)
		cam.look_at(Vector3(0, 0.35, 0))
		build_mata_flores(park, container, f_item.col)
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/veg_" + f_item.name + ".png")
		container.queue_free()
		await wait_frames(2)

	park.queue_free()

	# 2.3 Prendas de Torso y Piernas
	var torso_pieces = casting.catalog.piezas.torso
	for i in torso_pieces.size():
		var person = Person.new()
		studio_root.add_child(person)
		var t = {"profile":0,"upper":i,"lower":0,"hair":0,"skin":"media","hair_color":"castaño","upper_color":"rojo","lower_color":"azul marino","accessory":0,"accessory_color":"negro","runner":false}
		person.setup(t, casting.catalog, 100)
		cam.position = Vector3(0, 1.25, 1.4)
		cam.look_at(Vector3(0, 1.25, 0))
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/torso_" + str(i) + ".png")
		person.queue_free()
		await wait_frames(2)

	var leg_pieces = casting.catalog.piezas.piernas
	for i in leg_pieces.size():
		var person = Person.new()
		studio_root.add_child(person)
		var t = {"profile":0,"upper":0,"lower":i,"hair":0,"skin":"media","hair_color":"castaño","upper_color":"blanco","lower_color":"vaquero","accessory":0,"accessory_color":"negro","runner":false}
		person.setup(t, casting.catalog, 100)
		cam.position = Vector3(0, 0.65, 1.5)
		cam.look_at(Vector3(0, 0.65, 0))
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/legs_" + str(i) + ".png")
		person.queue_free()
		await wait_frames(2)

	# 2.4 Accesorios y Cabezas
	var head_pieces = casting.catalog.piezas.cabeza
	for i in head_pieces.size():
		var person = Person.new()
		studio_root.add_child(person)
		var t = {"profile":0,"upper":0,"lower":0,"hair":i,"skin":"clara","hair_color":"rubio","upper_color":"verde","lower_color":"vaquero","accessory":0,"accessory_color":"negro","runner":false}
		person.setup(t, casting.catalog, 100)
		cam.position = Vector3(0, 1.6, 0.8)
		cam.look_at(Vector3(0, 1.6, 0))
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/head_" + str(i) + ".png")
		person.queue_free()
		await wait_frames(2)

	var acc_pieces = casting.catalog.piezas.accesorio
	for i in acc_pieces.size():
		var person = Person.new()
		studio_root.add_child(person)
		var t = {"profile":0,"upper":0,"lower":0,"hair":0,"skin":"clara","hair_color":"castaño","upper_color":"blanco","lower_color":"vaquero","accessory":i,"accessory_color":"rojo","runner":false}
		person.setup(t, casting.catalog, 100)
		cam.position = Vector3(0, 1.35, 1.2)
		cam.look_at(Vector3(0, 1.35, 0))
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/acc_" + str(i) + ".png")
		person.queue_free()
		await wait_frames(2)

	# 2.5 Equipamiento y Cámaras
	var park_eq = ParkScene.new()
	studio_root.add_child(park_eq)
	var equip_configs = [
		{"name": "compacta", "func": "build_cam_compacta"},
		{"name": "telemetrica", "func": "build_cam_telemetrica"},
		{"name": "reflex", "func": "build_cam_reflex"},
		{"name": "teleobjetivo", "func": "build_teleobjetivo"},
		{"name": "objetivo_fijo", "func": "build_objetivo_fijo"},
		{"name": "carrete_35mm", "func": "build_carrete"}
	]
	for item in equip_configs:
		var container = Node3D.new()
		studio_root.add_child(container)
		cam.position = Vector3(0, 0, 0.75)
		cam.look_at(Vector3.ZERO)
		call(item.func, park_eq, container)
		await wait_frames(4)
		await capture_viewport_to(vp, scratch_dir + "/equip_" + item.name + ".png")
		container.queue_free()
		await wait_frames(2)
	park_eq.queue_free()

	# 2.6 Lineup de Personajes Representativos
	print(">> Renderizando lineup panorámico de personajes...")
	vp.size = Vector2i(1920, 800)
	cam.position = Vector3(0, 1.05, 4.5)
	cam.look_at(Vector3(0, 1.0, 0))

	var lineup_nodes: Array[Node3D] = []
	var x_positions = [-2.5, -1.5, -0.5, 0.5, 1.5, 2.5]
	var char_configs = [
		{"profile":3, "upper":0, "lower":1, "hair":1, "skin":"clara", "hair_color":"rubio", "upper_color":"rojo", "lower_color":"azul marino", "accessory":0, "runner":false, "rot":-15.0},
		{"profile":1, "upper":1, "lower":2, "hair":2, "skin":"media", "hair_color":"castaño", "upper_color":"negro", "lower_color":"gris", "accessory":0, "runner":false, "rot":-10.0},
		{"profile":0, "upper":0, "lower":0, "hair":0, "skin":"morena", "hair_color":"moreno", "upper_color":"blanco", "lower_color":"vaquero", "accessory":0, "runner":false, "rot":0.0},
		{"profile":2, "upper":3, "lower":3, "hair":6, "skin":"media", "hair_color":"castaño", "upper_color":"beige", "lower_color":"negro", "accessory":2, "runner":false, "rot":25.0},
		{"profile":0, "upper":4, "lower":5, "hair":5, "skin":"oscura", "hair_color":"moreno", "upper_color":"amarillo", "lower_color":"negro", "accessory":0, "runner":true, "rot":35.0},
		{"profile":1, "upper":4, "lower":5, "hair":3, "skin":"clara", "hair_color":"pelirrojo", "upper_color":"verde", "lower_color":"azul marino", "accessory":0, "runner":true, "rot":-30.0}
	]

	for i in char_configs.size():
		var cfg = char_configs[i]
		var person = Person.new()
		studio_root.add_child(person)
		lineup_nodes.append(person)
		person.position = Vector3(x_positions[i], 0, 0)
		person.rotation_degrees.y = cfg.rot
		var t = {
			"profile": cfg.profile,
			"upper": cfg.upper,
			"lower": cfg.lower,
			"hair": cfg.hair,
			"skin": cfg.skin,
			"hair_color": cfg.hair_color,
			"upper_color": cfg.upper_color,
			"lower_color": cfg.lower_color,
			"accessory": cfg.accessory,
			"accessory_color": "rojo",
			"runner": cfg.runner
		}
		person.setup(t, casting.catalog, 100 + i)

	await wait_frames(12)
	await capture_viewport_to(vp, docs_dir + "/personajes/personajes_lineup.png")
	print("   [✓] personajes_lineup.png capturado")

	for node in lineup_nodes:
		node.queue_free()

	vp.queue_free()
	await wait_frames(3)

# -------------------------------------------------------------
# FASE 3: ANIMACIONES Y SECUENCIAS
# -------------------------------------------------------------
func phase_3_animations() -> void:
	print(">> FASE 3: Grabando secuencias cinemáticas para GIFs anim_caminar, anim_correr y anim_clima_luz...")

	var vp = SubViewport.new()
	vp.size = Vector2i(480, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var studio = Node3D.new()
	vp.add_child(studio)

	var light1 = DirectionalLight3D.new()
	light1.rotation_degrees = Vector3(-35, 40, 0)
	light1.light_energy = 1.3
	studio.add_child(light1)

	var light2 = DirectionalLight3D.new()
	light2.rotation_degrees = Vector3(25, -140, 0)
	light2.light_energy = 0.4
	light2.light_color = Color("c0d5e8")
	studio.add_child(light2)

	var cam = Camera3D.new()
	studio.add_child(cam)
	cam.position = Vector3(1.8, 1.0, 1.8)
	cam.look_at(Vector3(0, 0.9, 0))
	var casting = Cast.new()

	# 3.1 Caminata (Marcha pausada - muestreo de fase analítica para bucle cerrado C^0 continuo)
	var walker = Person.new()
	studio.add_child(walker)
	var t_walk = {"profile":0,"upper":0,"lower":0,"hair":0,"skin":"media","hair_color":"castaño","upper_color":"blanco","lower_color":"vaquero","accessory":0,"accessory_color":"negro","runner":false}
	walker.setup(t_walk, casting.catalog, 100)
	var frames_walk = 30
	for f in frames_walk:
		walker.phase = TAU * float(f) / float(frames_walk)
		walker.animate(0)
		await wait_frames(2)
		await capture_viewport_to(vp, "%s/walk_%03d.png" % [scratch_dir, f])
	walker.queue_free()
	print("   [✓] Secuencia de caminata grabada (30 frames, loop continuo)")

	# 3.2 Carrera (Fase aérea atlética - muestreo de fase analítica para bucle cerrado)
	var runner = Person.new()
	studio.add_child(runner)
	var t_run = {"profile":0,"upper":4,"lower":5,"hair":5,"skin":"media","hair_color":"moreno","upper_color":"amarillo","lower_color":"negro","accessory":0,"accessory_color":"negro","runner":true}
	runner.setup(t_run, casting.catalog, 101)
	var frames_run = 24
	for f in frames_run:
		runner.phase = TAU * float(f) / float(frames_run)
		runner.animate(0)
		await wait_frames(2)
		await capture_viewport_to(vp, "%s/run_%03d.png" % [scratch_dir, f])
	runner.queue_free()
	print("   [✓] Secuencia de carrera grabada (24 frames, loop continuo)")

	# 3.3 Clima y Luz (Transición de sol a sombra y farolas)
	var park_env = ParkScene.new()
	studio.add_child(park_env)
	var farola_node = Node3D.new()
	studio.add_child(farola_node)
	build_farola(park_env, farola_node)
	farola_node.position = Vector3(0, 0, 0)

	var lamp_light = OmniLight3D.new()
	lamp_light.position = Vector3(0, 2.3, 0.24)
	lamp_light.light_color = Color("ffcd82")
	lamp_light.light_energy = 0.0
	studio.add_child(lamp_light)

	cam.position = Vector3(1.5, 1.4, 2.2)
	cam.look_at(Vector3(0, 1.3, 0))

	var frames_weather = 36
	for f in frames_weather:
		var progress = float(f) / float(frames_weather)
		if progress < 0.5:
			var p = progress * 2.0
			light1.light_energy = lerpf(1.3, 0.3, p)
			light1.light_color = Color("fff0d7").lerp(Color("9caed4"), p)
			lamp_light.light_energy = 0.0
		else:
			var p = (progress - 0.5) * 2.0
			light1.light_energy = lerpf(0.3, 0.03, p)
			lamp_light.light_energy = lerpf(0.0, 3.5, p)
		await wait_frames(1)
		await capture_viewport_to(vp, "%s/weather_%03d.png" % [scratch_dir, f])

	park_env.queue_free()
	farola_node.queue_free()
	lamp_light.queue_free()
	print("   [✓] Secuencia de clima y luz grabada (36 frames)")

	vp.queue_free()
	await wait_frames(3)

