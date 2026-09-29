class_name Park
extends Node3D
const Texts = preload("res://scripts/texts.gd")

var environment: WorldEnvironment
var sun: DirectionalLight3D
var lamps: Array[OmniLight3D] = []
var materials = {}
var benches: Array[Dictionary] = []
var triangle_count = 0
var current_graphics_preset = "Ultra"
var glass_color = Color(0.82, 0.92, 0.95, 0.32)
var bulb_color = Color("fff5c0")
var glass_material: StandardMaterial3D
var bulb_material: StandardMaterial3D

func init_lantern_materials() -> void:
	if glass_material == null:
		glass_material = StandardMaterial3D.new()
		glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_material.albedo_color = glass_color
		glass_material.roughness = 0.08
		glass_material.metallic_specular = 0.95
		glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[glass_color.to_html()] = glass_material

	if bulb_material == null:
		bulb_material = StandardMaterial3D.new()
		bulb_material.albedo_color = bulb_color
		bulb_material.roughness = 0.20
		bulb_material.metallic_specular = 0.5
		materials[bulb_color.to_html()] = bulb_material

func build_farola_mesh(parent: Node3D, with_collider: bool = true) -> void:
	init_lantern_materials()
	var col_label = Texts.get_text("una_farola") if with_collider else ""
	# 1. Base escalonada de fundición de hierro con moldura
	cylinder(.15, .16, Vector3.UP * .08, Color("28302d"), col_label, parent)
	cylinder(.11, .14, Vector3.UP * .23, Color("2e3633"), "", parent, .068)
	
	# 2. Fuste estriado esbelto con collarines ornamentales
	cylinder(.052, 2.15, Vector3.UP * 1.34, Color("323a37"), col_label, parent, .042)
	cylinder(.072, .04, Vector3.UP * 1.75, Color("3d4642"), "", parent)
	cylinder(.055, .08, Vector3.UP * 2.45, Color("2e3633"), "", parent, .11)
	
	# 3. Jaula del farol: repisa inferior cuadrangular y 4 pilastras de forja
	cube(Vector3(.34, .04, .34), Vector3.UP * 2.50, Color("262e2b"), "", parent)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			cube(Vector3(.022, .34, .022), Vector3(x * .13, 2.68, z * .13), Color("262e2b"), "", parent)
	
	# 4. Cuatro paneles de cristal transparente biselado
	cube(Vector3(.25, .31, .012), Vector3(0, 2.68, .13), glass_color, "", parent)
	cube(Vector3(.25, .31, .012), Vector3(0, 2.68, -.13), glass_color, "", parent)
	cube(Vector3(.012, .31, .25), Vector3(.13, 2.68, 0), glass_color, "", parent)
	cube(Vector3(.012, .31, .25), Vector3(-.13, 2.68, 0), glass_color, "", parent)
	
	# 5. Bombilla interior cálida y casquillo
	cylinder(.032, .05, Vector3.UP * 2.81, Color("76653f"), "", parent)
	cylinder(.038, .09, Vector3.UP * 2.69, bulb_color, "", parent, .02)
	
	# 6. Tejadillo piramidal y aguja superior
	cylinder(.20, .14, Vector3.UP * 2.92, Color("262e2b"), "", parent, .035)
	cylinder(.038, .07, Vector3.UP * 3.01, Color("343d39"), "", parent)
	cylinder(.014, .08, Vector3.UP * 3.07, Color("343d39"), "", parent)


func material(color: Color, roughness: float = 0.82, specular: float = 0.25) -> StandardMaterial3D:
	var key = color.to_html()
	if not materials.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic_specular = specular
		materials[key] = m
	return materials[key]

func prop(mesh: Mesh, pos: Vector3, color: Color, label = "", parent: Node3D = self) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	for surface in mesh.get_surface_count():
		var arrays = mesh.surface_get_arrays(surface)
		triangle_count += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size())/3
	if label != "":
		var body = StaticBody3D.new()
		body.collision_layer = 2
		body.set_meta("label",label)
		node.add_child(body)
		var collision = CollisionShape3D.new()
		collision.shape = mesh.create_convex_shape()
		body.add_child(collision)
	return node

func cube(size: Vector3, pos: Vector3, color: Color, label = "", parent: Node3D = self) -> MeshInstance3D:
	# Window panes need a front face, not six closed faces; spend geometry on people.
	if size.z < .03 and label == "":
		var pane = QuadMesh.new()
		pane.size = Vector2(size.x,size.y)
		return prop(pane,pos,color,label,parent)
	var mesh = BoxMesh.new()
	mesh.size = size
	return prop(mesh,pos,color,label,parent)

func cylinder(radius: float, height: float, pos: Vector3, color: Color, label = "", parent: Node3D = self, top = -1.0) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return prop(mesh,pos,color,label,parent)

func ring(inner: float, outer: float, color: Color, y = 0.0) -> void:
	# 120 segments and radial steps of 0.6 m up to 19 m: the baked contact occlusion
	# (ground_occlusion) needs vertices under bushes, benches and trees. Coarser beyond.
	var radii = [inner]
	while radii[-1] < outer-.001:
		var r: float = radii[-1]
		radii.append(minf(outer,r+(.6 if r < 19.0 else 4.0+(r-19.0)*.3)))
	for sector in 12:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mid = (sector*10+5)*TAU/120
		var center = Vector3(sin(mid)*(inner+outer)*.5,0,cos(mid)*(inner+outer)*.5)
		for i in range(sector*10,(sector+1)*10):
			var a = i*TAU/120
			var b = (i+1)*TAU/120
			for k in radii.size()-1:
				var r0: float = radii[k]
				var r1: float = radii[k+1]
				var points = [Vector3(sin(a)*r0,y,cos(a)*r0),Vector3(sin(a)*r1,y,cos(a)*r1),Vector3(sin(b)*r1,y,cos(b)*r1),Vector3(sin(b)*r0,y,cos(b)*r0)]
				for j in [0,2,1,0,3,2]:
					st.set_normal(Vector3.UP)
					st.add_vertex(points[j]-center)
		# Shared vertices: same triangles, ~6 times fewer vertices to shade in merge_static_meshes().
		st.index()
		prop(st.commit(),center,color).set_meta("ground",true)


func build_tree(species: int, pos: Vector3, tree_seed: int, scale_factor: float = 1.0, parent: Node3D = self) -> Node3D:
	var tree_rng = RandomNumberGenerator.new()
	tree_rng.seed = tree_seed
	
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = tree_rng.randf_range(0.0, TAU)
	root.rotation.x = tree_rng.randf_range(-0.035, 0.035)
	root.rotation.z = tree_rng.randf_range(-0.035, 0.035)
	parent.add_child(root)
	
	var h_scale = scale_factor * tree_rng.randf_range(0.88, 1.14)
	var r_scale = scale_factor * tree_rng.randf_range(0.90, 1.12)
	
	match species % 4:
		0:
			# Roble / Plátano de sombra (Quercus / Platanus)
			# Copa ancha en cúpula, tronco robusto con cuello radicular y ramas secundarias
			var bark_color = Color("5c4837")
			var foliage_palette = [Color("486b33"), Color("577a3d"), Color("3d5a2a")]
			var trunk_r = 0.20 * r_scale
			var trunk_h = 2.4 * h_scale
			# Cuello radicular y fuste
			cylinder(trunk_r * 1.45, 0.35 * h_scale, Vector3.UP * (0.175 * h_scale), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 1.05)
			cylinder(trunk_r, trunk_h, Vector3.UP * (trunk_h * 0.5), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 0.8)
			# Ramas secundarias
			var b1 = cylinder(trunk_r * 0.45, 0.85 * h_scale, Vector3(0.25 * r_scale, trunk_h * 0.82, 0.1 * r_scale), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 0.3)
			b1.rotation = Vector3(0.3, 0.2, -0.6)
			var b2 = cylinder(trunk_r * 0.42, 0.80 * h_scale, Vector3(-0.22 * r_scale, trunk_h * 0.88, -0.15 * r_scale), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 0.28)
			b2.rotation = Vector3(-0.4, -0.3, 0.55)
			# Cúpula central y 4 racimos perimetrales 3D
			var central_mesh = SphereMesh.new()
			central_mesh.radius = 1.30 * r_scale
			central_mesh.height = 1.85 * h_scale
			central_mesh.radial_segments = 7
			central_mesh.rings = 3
			prop(central_mesh, Vector3(0, trunk_h + 0.85 * h_scale, 0), foliage_palette[1], Texts.get_text("una_copa_de_arbol"), root)
			for k in 4:
				var angle = k * (PI * 0.5) + tree_rng.randf_range(-0.25, 0.25)
				var dist = (0.75 + tree_rng.randf_range(-0.1, 0.12)) * r_scale
				var f_pos = Vector3(cos(angle) * dist, trunk_h + (0.42 + tree_rng.randf_range(-0.1, 0.15)) * h_scale, sin(angle) * dist)
				var leaf = SphereMesh.new()
				leaf.radius = (0.95 + tree_rng.randf_range(-0.08, 0.10)) * r_scale
				leaf.height = (1.40 + tree_rng.randf_range(-0.1, 0.15)) * h_scale
				leaf.radial_segments = 7
				leaf.rings = 3
				var col = foliage_palette[0] if k % 2 == 0 else foliage_palette[2]
				prop(leaf, f_pos, col, Texts.get_text("una_copa_de_arbol"), root)
		1:
			# Ciprés / Álamo piramidal (Cupressus / Populus nigra)
			# Esbelto, columnar, tono verde oscuro azulado, masas ovoides escalonadas
			var bark_color = Color("4b3e32")
			var leaf_dark = Color("274434")
			var leaf_mid = Color("315340")
			var leaf_top = Color("3b614b")
			var trunk_r = 0.15 * r_scale
			var trunk_h = 3.6 * h_scale
			cylinder(trunk_r * 1.35, 0.3 * h_scale, Vector3.UP * (0.15 * h_scale), bark_color, Texts.get_text("un_arbol"), root)
			cylinder(trunk_r, trunk_h, Vector3.UP * (trunk_h * 0.5), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 0.7)
			var tiers = [
				{"y": 1.25, "r": 0.88, "h": 1.5, "c": leaf_dark},
				{"y": 2.20, "r": 0.82, "h": 1.6, "c": leaf_dark},
				{"y": 3.15, "r": 0.68, "h": 1.5, "c": leaf_mid},
				{"y": 4.05, "r": 0.48, "h": 1.4, "c": leaf_top}
			]
			for t in tiers:
				var sm = SphereMesh.new()
				sm.radius = t["r"] * r_scale
				sm.height = t["h"] * h_scale
				sm.radial_segments = 7
				sm.rings = 3
				var off_x = tree_rng.randf_range(-0.06, 0.06) * r_scale
				var off_z = tree_rng.randf_range(-0.06, 0.06) * r_scale
				prop(sm, Vector3(off_x, t["y"] * h_scale, off_z), t["c"], Texts.get_text("una_copa_de_arbol"), root)
			cylinder(0.24 * r_scale, 0.85 * h_scale, Vector3.UP * (4.65 * h_scale), leaf_top, Texts.get_text("una_copa_de_arbol"), root, 0.02)
		2:
			# Tilo / Castaño (Tilia / Castanea)
			# Copa globosa densa y equilibrada, verde tilo luminoso
			var bark_color = Color("634f3c")
			var fol_light = Color("6fa040")
			var fol_mid = Color("608e36")
			var fol_deep = Color("517a2d")
			var trunk_r = 0.18 * r_scale
			var trunk_h = 2.1 * h_scale
			cylinder(trunk_r * 1.4, 0.3 * h_scale, Vector3.UP * (0.15 * h_scale), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 1.05)
			cylinder(trunk_r, trunk_h, Vector3.UP * (trunk_h * 0.5), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 0.85)
			var dome = SphereMesh.new()
			dome.radius = 1.15 * r_scale
			dome.height = 1.75 * h_scale
			dome.radial_segments = 7
			dome.rings = 3
			prop(dome, Vector3(0, trunk_h + 0.85 * h_scale, 0), fol_light, Texts.get_text("una_copa_de_arbol"), root)
			for k in 3:
				var angle = k * (TAU / 3.0) + tree_rng.randf_range(-0.2, 0.2)
				var dist = 0.65 * r_scale
				var f_pos = Vector3(cos(angle) * dist, trunk_h + (0.5 + tree_rng.randf_range(-0.08, 0.1)) * h_scale, sin(angle) * dist)
				var ball = SphereMesh.new()
				ball.radius = (0.90 + tree_rng.randf_range(-0.06, 0.08)) * r_scale
				ball.height = (1.45 + tree_rng.randf_range(-0.08, 0.1)) * h_scale
				ball.radial_segments = 7
				ball.rings = 3
				prop(ball, f_pos, fol_mid if k == 0 else fol_deep, Texts.get_text("una_copa_de_arbol"), root)
		3:
			# Arce dorado otoñal (Acer)
			# Asimetría con rama lateral extendida y nubes horizontales de oro y ámbar
			var bark_color = Color("564333")
			var leaf_gold = Color("c48d35")
			var leaf_amber = Color("af7629")
			var leaf_sienna = Color("975d20")
			var trunk_r = 0.16 * r_scale
			var trunk_h = 2.5 * h_scale
			cylinder(trunk_r * 1.35, 0.28 * h_scale, Vector3.UP * (0.14 * h_scale), bark_color, Texts.get_text("un_arbol"), root)
			cylinder(trunk_r, trunk_h, Vector3.UP * (trunk_h * 0.5), bark_color, Texts.get_text("un_arbol"), root, trunk_r * 0.75)
			var b_angle = tree_rng.randf_range(0.0, TAU)
			var branch_dir = Vector3(cos(b_angle), 0.35, sin(b_angle)).normalized()
			var b_pos = Vector3.UP * (trunk_h * 0.72) + branch_dir * (0.45 * r_scale)
			var br = cylinder(trunk_r * 0.45, 0.9 * h_scale, b_pos, bark_color, Texts.get_text("un_arbol"), root, trunk_r * 0.25)
			br.rotation = Vector3(branch_dir.z * 0.6, b_angle, -branch_dir.x * 0.6)
			var low_cloud = SphereMesh.new()
			low_cloud.radius = 0.85 * r_scale
			low_cloud.height = 1.05 * h_scale
			low_cloud.radial_segments = 7
			low_cloud.rings = 3
			prop(low_cloud, b_pos + branch_dir * (0.45 * r_scale) + Vector3.UP * (0.2 * h_scale), leaf_amber, Texts.get_text("una_copa_de_arbol"), root)
			var mid_cloud = SphereMesh.new()
			mid_cloud.radius = 1.15 * r_scale
			mid_cloud.height = 1.40 * h_scale
			mid_cloud.radial_segments = 7
			mid_cloud.rings = 3
			prop(mid_cloud, Vector3(0, trunk_h + 0.6 * h_scale, 0), leaf_gold, Texts.get_text("una_copa_de_arbol"), root)
			var top_cloud = SphereMesh.new()
			top_cloud.radius = 0.80 * r_scale
			top_cloud.height = 1.10 * h_scale
			top_cloud.radial_segments = 7
			top_cloud.rings = 3
			prop(top_cloud, Vector3(-cos(b_angle) * 0.25 * r_scale, trunk_h + 1.35 * h_scale, -sin(b_angle) * 0.25 * r_scale), leaf_sienna, Texts.get_text("una_copa_de_arbol"), root)
			
	return root

func polar(theta: float, radius: float) -> Vector3:
	return Vector3(sin(deg_to_rad(theta))*radius,0,-cos(deg_to_rad(theta))*radius)

func build() -> void:
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	add_child(environment)
	var sky = Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("87b2c5")
	sky_mat.sky_horizon_color = Color("d4e1dc")
	sky_mat.ground_horizon_color = Color("c5d4c9")
	sky.sky_material = sky_mat
	environment.environment.sky = sky
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Perspectiva aérea y profundidad de planos (Distance Fog & Tonemapping)
	environment.environment.fog_enabled = true
	environment.environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.environment.fog_light_color = Color("c5d4c9")
	environment.environment.fog_depth_begin = 8.0
	environment.environment.fog_depth_end = 22.0
	environment.environment.fog_depth_curve = 1.0
	environment.environment.fog_sky_affect = 0.3
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment.tonemap_exposure = 0.88
	environment.environment.tonemap_white = 1.4
	# Ajustes HDR de compresión de rango y contraste suave
	environment.environment.adjustment_enabled = true
	environment.environment.adjustment_contrast = 0.98
	environment.environment.adjustment_saturation = 1.05
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-72,-35,0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35
	sun.shadow_blur = 1.5
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	var ground = StaticBody3D.new()
	ground.set_meta("label",Texts.get_text("el_suelo"))
	add_child(ground)
	var ground_collision = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(90,.04,90)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -.025
	ground.add_child(ground_collision)
	ring(0,2.8,Color("c5bdac"))
	ring(2.8,5.1,Color("858580"),.006)
	ring(5.1,6.0,Color("8d9f60"))
	ring(6.0,8.0,Color("b8b29c"),.005)
	ring(8.0,10.5,Color("829459"))
	ring(10.5,12.5,Color("b8b29c"),.005)
	ring(12.5,45,Color("81925c"))
	for r in [2.8,5.1,6.0,8.0]: ring(r,r+.035,Color("dfd8c5"),.012)
	var rng = RandomNumberGenerator.new()
	rng.seed = 403
	for i in 36:
		var theta = i*10.0
		var pos = polar(theta,21+rng.randf_range(0,6))
		var h = rng.randf_range(5,12)
		var block = cube(Vector3(rng.randf_range(2,4),h,2.6),pos+Vector3.UP*h*.5,Color("a3b7c7").lightened(snappedf(rng.randf_range(0,.2),.05)))
		block.rotation.y = -deg_to_rad(theta)
		for row in range(1,int(h/.65)):
			for col in [-1,0,1]: cube(Vector3(.3,.35,.025),Vector3(col*.65,-h*.5+row*.65,1.32),Color("d3e0e6"),"",block)
	for i in 30:
		var theta = i*12.0+4
		var pos = polar(theta,14.2)
		var variety = i%4
		build_tree(variety, pos, 1000 + i * 47, 1.0)
	for i in 72:
		var pos = polar(i*5,12.8)
		cylinder(.024,1.1,pos+Vector3.UP*.55,Color("394844"),Texts.get_text("una_verja"))
		var bar = cube(Vector3(1.15,.035,.035),pos+Vector3.UP*.8,Color("394844"))
		bar.rotation.y = -deg_to_rad(i*5)
	# Masa densa de arbolado y arbustos de fondo tras la verja para cerrar el escenario
	for i in 84:
		var theta = i*(360.0/84.0)+rng.randf_range(-1.2,1.2)
		var foliage = SphereMesh.new()
		foliage.radius = rng.randf_range(.55,.95)
		foliage.height = foliage.radius*rng.randf_range(1.6,2.2)
		foliage.radial_segments = 7
		foliage.rings = 2
		var pos = polar(theta,13.4+rng.randf_range(-.25,.35))
		pos.y = foliage.height*.45
		var bush_colors = [Color("4d6836"),Color("5c7a3d"),Color("3e5c32"),Color("688047")]
		prop(foliage,pos,bush_colors[i%4].lightened(snappedf(rng.randf_range(0,.12),.04)),Texts.get_text("un_arbusto"))
	for i in 36:
		var theta = i*10.0+9.0+rng.randf_range(-1.5,1.5)
		var pos = polar(theta,15.6+rng.randf_range(-.4,.6))
		var variety = (i+2)%4
		build_tree(variety, pos, 2000 + i * 31, 1.15)
	for i in 60:
		var theta = i*6.0+2.0+rng.randf_range(-1.0,1.0)
		var foliage = SphereMesh.new()
		foliage.radius = rng.randf_range(.6,1.1)
		foliage.height = foliage.radius*rng.randf_range(1.4,1.9)
		foliage.radial_segments = 6
		foliage.rings = 2
		var pos = polar(theta,15.0+rng.randf_range(-.6,1.4))
		pos.y = foliage.height*.4
		var under_colors = [Color("39502b"),Color("4b6435"),Color("58723c")]
		prop(foliage,pos,under_colors[i%3].lightened(snappedf(rng.randf_range(0,.1),.05)),Texts.get_text("un_arbusto"))
	for i in 12:
		var theta = i*30.0+8
		var root = Node3D.new()
		root.position = polar(theta,0.8 if i%3 == 0 else 8.6)
		add_child(root)
		build_farola_mesh(root, true)
		var light = OmniLight3D.new()
		light.position = Vector3(0, 2.69, 0)
		light.shadow_enabled = true
		light.omni_range = 6.0
		light.light_color = Color("ffcd82")
		light.light_energy = 0.0
		root.add_child(light)
		lamps.append(light)
	for i in 4:
		var theta = i*90.0+35
		var bench_radius = 4.85
		var root = Node3D.new()
		root.position = polar(theta,bench_radius)
		root.rotation.y = PI-deg_to_rad(theta)
		add_child(root)
		benches.append({"theta":theta,"radius":bench_radius,"occupied":false,"root":root})
		material(Color("2a3230"), 0.55, 0.45) # Cast iron legs
		material(Color("8f6136"), 0.42, 0.45) # Varnished teak slats
		for x in [-.65,.65]:
			cube(Vector3(.07,.46,.48),Vector3(x,.23,.15),Color("2a3230"),Texts.get_text("un_banco"),root)
		for j in 3:
			cube(Vector3(1.65,.045,.11),Vector3(0,.47,j*.15),Color("8f6136"),Texts.get_text("un_banco"),root)
			cube(Vector3(1.65,.095,.045),Vector3(0,.66+j*.13,.4),Color("8f6136"),Texts.get_text("un_banco"),root)
	for i in 70:
		var foliage = SphereMesh.new()
		foliage.radius = rng.randf_range(.25,.5)
		foliage.height = foliage.radius*1.5
		foliage.radial_segments = 6
		foliage.rings = 2
		var pos = polar(i*5.14,9.2+rng.randf_range(-.3,.3))
		pos.y = foliage.height*.4
		prop(foliage,pos,Color("617b43").lightened(snappedf(rng.randf_range(0,.15),.05)),Texts.get_text("un_arbusto"))
	for i in 12:
		var pos = polar(i*30+16,5.55)
		cylinder(.25,.7,pos+Vector3.UP*.35,Color("425d57"),"una papelera")
		var planter = polar(i*30+25,9.7)
		cube(Vector3(.9,.35,.7),planter+Vector3.UP*.175,Color("a78366"),"una jardinera")
		for j in 5:
			cylinder(.09,.14,planter+Vector3((j-2)*.15,.43,0),[Color("d6ac4b"),Color("b45c78"),Color("e8dac0")][i%3])
	build_diorama_base()
	merge_static_meshes()
	build_clouds()
	set_night(false)
	apply_graphics_preset("Ultra")


func apply_graphics_preset(preset: String) -> void:
	current_graphics_preset = preset
	if environment == null or sun == null: return
	apply_preset_values(preset)
	update_lamp_shadows()
	# Night: presets overwrite the time-of-day exposure and fog, so night adjusts after them.
	# Brighter exposure and a closer blue haze keep the park readable around the lamps.
	if is_night:
		environment.environment.tonemap_exposure *= 1.25
		environment.environment.tonemap_white = 4.0
		if environment.environment.fog_enabled:
			environment.environment.fog_depth_begin = 4.0
			environment.environment.fog_depth_end = 34.0

# Night lamp shadows are re-rendered every frame (people move) and cost ~100 draw calls each in
# gl_compatibility, so the profile decides how many cast them: Ultra all 12, Alto the 4 inner ones
# (lanes 0-1), Medio and Bajo none. Golden-hour lamps never do: the low sun dominates.
func update_lamp_shadows() -> void:
	for i in lamps.size():
		var inner = i % 3 == 0
		lamps[i].shadow_enabled = is_night and (current_graphics_preset == "Ultra" or (current_graphics_preset == "Alto" and inner))

func apply_preset_values(preset: String) -> void:
	match preset:
		"Bajo":
			sun.shadow_enabled = false
			sun.directional_shadow_max_distance = 20.0
			environment.environment.fog_enabled = false
			environment.environment.adjustment_enabled = false
			environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		"Medio":
			sun.shadow_enabled = true
			sun.shadow_blur = .6
			sun.directional_shadow_max_distance = 30.0
			sun.directional_shadow_blend_splits = false
			environment.environment.fog_enabled = true
			environment.environment.fog_depth_begin = 9.0
			environment.environment.fog_depth_end = 48.0
			environment.environment.adjustment_enabled = false
			environment.environment.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
		"Alto":
			sun.shadow_enabled = true
			sun.shadow_blur = .8
			sun.directional_shadow_max_distance = 38.0
			sun.directional_shadow_blend_splits = true
			sun.shadow_bias = 0.02
			sun.shadow_normal_bias = .7
			environment.environment.fog_enabled = true
			environment.environment.fog_depth_begin = 8.0
			environment.environment.fog_depth_end = 40.0
			environment.environment.adjustment_enabled = true
			environment.environment.adjustment_contrast = 1.0
			environment.environment.adjustment_saturation = 1.1
			environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
		"Ultra", _:
			sun.shadow_enabled = true
			sun.shadow_blur = .8
			sun.directional_shadow_max_distance = 48.0
			sun.directional_shadow_blend_splits = true
			sun.shadow_bias = 0.015
			sun.shadow_normal_bias = .6
			environment.environment.fog_enabled = true
			environment.environment.fog_depth_begin = 8.0
			environment.environment.fog_depth_end = 40.0
			environment.environment.fog_depth_curve = 1.0
			environment.environment.fog_sky_affect = 0.3
			environment.environment.adjustment_enabled = true
			environment.environment.adjustment_contrast = 1.03
			environment.environment.adjustment_saturation = 1.14
			environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
			environment.environment.tonemap_exposure = 0.90
			environment.environment.tonemap_white = 1.45

func set_time_of_day(tod: String) -> void:
	time_of_day = tod
	is_night = (tod == "night")
	var is_golden = (tod == "golden")
	if is_night:
		sun.rotation_degrees = Vector3(-72,-35,0)
		sun.light_energy = MOONLIGHT
		sun.light_color = Color("9caed4")
		environment.environment.ambient_light_color = Color("394568")
		environment.environment.ambient_light_energy = .42
		# The night sky is almost black: take the ambient from its colour, not from the sky.
		environment.environment.ambient_light_sky_contribution = 0.0
		environment.environment.fog_light_color = Color("192139")
		environment.environment.tonemap_exposure = 0.95
		var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
		sky_mat.sky_top_color = Color("060d21")
		sky_mat.sky_horizon_color = Color("192139")
		sky_mat.ground_horizon_color = Color("192139")
		sky_mat.ground_bottom_color = Color("060d15")
		for light in lamps:
			light.light_energy = 2.2
			light.light_color = Color("ffcd82")
			light.visible = true
		if bulb_material:
			bulb_material.emission_enabled = true
			bulb_material.emission = Color("ffcd82")
			bulb_material.emission_energy_multiplier = 4.5
	elif is_golden:
		# Spectacular low-angle golden hour lighting (pitch -15 deg, azimuth -48 deg)
		sun.rotation_degrees = Vector3(-15,-48,0)
		sun.light_energy = 2.2
		sun.light_color = Color("ffa544")
		# Shadows at sunset are lit by the blue sky: a clear ambient keeps the long shadows readable.
		environment.environment.ambient_light_color = Color("9aaed0")
		environment.environment.ambient_light_energy = .55
		environment.environment.ambient_light_sky_contribution = 0.0
		environment.environment.fog_light_color = Color("e58b3e")
		environment.environment.tonemap_exposure = 0.94
		var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
		sky_mat.sky_top_color = Color("18355e")
		sky_mat.sky_horizon_color = Color("ed8234")
		sky_mat.ground_horizon_color = Color("b55e24")
		sky_mat.ground_bottom_color = Color("2e1c12")
		# Incipient twilight illumination on park lampposts
		# Twilight lamps cast no shadows (see update_lamp_shadows()).
		for light in lamps:
			light.light_energy = 0.90
			light.light_color = Color("ffcb74")
			light.visible = true
		if bulb_material:
			bulb_material.emission_enabled = true
			bulb_material.emission = Color("ffcb74")
			bulb_material.emission_energy_multiplier = 2.0
	else:
		sun.rotation_degrees = Vector3(-72,-35,0)
		sun.light_energy = 1.4
		sun.light_color = Color("fff0d7")
		environment.environment.ambient_light_color = Color("c6d6df")
		environment.environment.ambient_light_energy = .22
		environment.environment.ambient_light_sky_contribution = 1.0
		environment.environment.fog_light_color = Color("cddcdd")
		environment.environment.tonemap_exposure = 0.88
		var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
		sky_mat.sky_top_color = Color("6fa3cf")
		sky_mat.sky_horizon_color = Color("dce8ea")
		sky_mat.ground_horizon_color = Color("c5d4c9")
		sky_mat.ground_bottom_color = Color("738064")
		# Hidden, not just at zero energy: gl_compatibility still draws a pass per lit object.
		# illumination_ev() reads light_energy and its own rays, so the meter is unaffected.
		for light in lamps:
			light.light_energy = 0
			light.visible = false
		if bulb_material: bulb_material.emission_enabled = false
	update_weather(0)
	apply_graphics_preset(current_graphics_preset)

func set_night(night: bool) -> void:
	set_time_of_day("night" if night else "day")

# Opaque props become vertex colours of a few merged surfaces (docs/futuro/16), split into
# 12 sectors × 3 radial bands so frustum culling still skips what the camera is not facing.
# The park keeps smooth shading: toon bands and ink lines are reserved for the mannequins.
const SECTOR_DEGREES = 30.0
const BAND_LIMITS = [9.0, 17.0]
# Thinner pieces (ground, glass, grilles) get no foot darkening and cast no ground occlusion.
const THIN_LIMIT = .03
var park_material: StandardMaterial3D

func vertex_color_material() -> StandardMaterial3D:
	if park_material == null:
		park_material = StandardMaterial3D.new()
		park_material.vertex_color_use_as_albedo = true
		# Colours are written already converted to linear in append_node().
		park_material.vertex_color_is_srgb = false
		park_material.roughness = .82
		park_material.metallic_specular = .25
	return park_material

func sector_key(pos: Vector3) -> String:
	var radius = Vector2(pos.x,pos.z).length()
	var band = 0 if radius < BAND_LIMITS[0] else (1 if radius < BAND_LIMITS[1] else 2)
	return "%d:%d" % [band,int(fposmod(rad_to_deg(atan2(pos.x,-pos.z)),360.0)/SECTOR_DEGREES)]

# Baked contact occlusion on the ground: every prop standing low darkens the ground under and
# around its footprint (trees also under their crowns). Occluders are bucketed in a 3 m grid.
const OCCLUSION_CELL = 3.0
var occluders = {}

func label_of(node: Node) -> String:
	for child in node.get_children():
		if child is StaticBody3D: return str(child.get_meta("label",""))
	return ""

func add_occluder(node: MeshInstance3D) -> void:
	var box: AABB = node.global_transform*node.mesh.get_aabb()
	var half = maxf(box.size.x,box.size.z)*.5
	# Skip the flat ground, anything high above it and huge pieces (buildings, diorama plinth).
	if box.size.y < THIN_LIMIT or half > 3.0 or box.position.y > 4.5: return
	var center = box.get_center()
	var occluder = Vector4(center.x,center.z,half*1.6+.15,.35*(1.0-clampf(box.position.y/4.5,0.0,1.0)))
	var r = occluder.z
	for cx in range(floori((center.x-r)/OCCLUSION_CELL),floori((center.x+r)/OCCLUSION_CELL)+1):
		for cz in range(floori((center.z-r)/OCCLUSION_CELL),floori((center.z+r)/OCCLUSION_CELL)+1):
			var cell = Vector2i(cx,cz)
			if not occluders.has(cell): occluders[cell] = []
			occluders[cell].append(occluder)

func ground_occlusion(p: Vector3) -> float:
	var shade = 1.0
	for o in occluders.get(Vector2i(floori(p.x/OCCLUSION_CELL),floori(p.z/OCCLUSION_CELL)),[]):
		var t = Vector2(p.x-o.x,p.z-o.y).length()/o.z
		if t < 1.0: shade *= 1.0-o.w*(1.0-smoothstep(.35,1.0,t))
	return maxf(shade,.55)

func append_node(group: Dictionary, node: MeshInstance3D) -> void:
	var xf: Transform3D = node.global_transform
	var normal_basis = xf.basis.inverse().transposed()
	var extent = node.mesh.get_aabb().size*xf.basis.get_scale()
	var thin = minf(extent.x,minf(extent.y,extent.z)) < THIN_LIMIT
	var base: Color = node.material_override.albedo_color
	var ground = node.has_meta("ground")
	var label = label_of(node)
	var foliage = label == Texts.get_text("una_copa_de_arbol") or label == Texts.get_text("un_arbusto")
	# Crown volume: faces looking in towards the trunk axis (or the bush centre) or down are darker.
	var axis: Vector3 = node.get_parent().global_position if node.get_parent() != self else (node.global_transform*node.mesh.get_aabb()).get_center()
	for surface in node.mesh.get_surface_count():
		var arrays = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var offset = group.v.size()
		for k in vertices.size():
			var world = xf*vertices[k]
			var normal = (normal_basis*normals[k]).normalized()
			# Baked occlusion: darker at the foot of props and on faces looking down.
			var shade = 1.0
			if ground:
				shade = ground_occlusion(world)
			elif foliage:
				var out = Vector2(world.x-axis.x,world.z-axis.z).normalized()
				var facing = .55*normal.y+.45*(normal.x*out.x+normal.z*out.y)
				shade = lerpf(.72,1.0,smoothstep(-.7,.5,facing))
			else:
				shade = 1.0-.2*maxf(0.0,-normal.y)
			if not thin: shade *= lerpf(.72,1.0,clampf(world.y/.4,0.0,1.0))
			group.v.append(world)
			group.n.append(normal)
			group.c.append(Color(base.r*shade,base.g*shade,base.b*shade))
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null or indices.is_empty():
			for k in vertices.size(): group.i.append(offset+k)
		else:
			for k in indices: group.i.append(offset+k)

func merge_static_meshes() -> void:
	var groups = {}
	for node in find_children("*","MeshInstance3D",true,false):
		if node.mesh != null and not node.has_meta("ground") and node.material_override != glass_material and node.material_override != bulb_material:
			add_occluder(node)
	for node in find_children("*","MeshInstance3D",true,false):
		if node.mesh == null: continue
		# Lantern glass (transparent) and bulbs (night emission) keep their own materials.
		var key = "glass" if node.material_override == glass_material else ("bulb" if node.material_override == bulb_material else sector_key(node.global_position))
		if not groups.has(key): groups[key] = {"v":PackedVector3Array(),"n":PackedVector3Array(),"c":PackedColorArray(),"i":PackedInt32Array()}
		append_node(groups[key],node)
		# Colliders stay as children of the emptied node, so photo rays and labels are unchanged.
		node.mesh = null
	for key in groups:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = groups[key].v
		arrays[Mesh.ARRAY_NORMAL] = groups[key].n
		arrays[Mesh.ARRAY_COLOR] = groups[key].c
		arrays[Mesh.ARRAY_INDEX] = groups[key].i
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node = MeshInstance3D.new()
		node.name = "Parque_"+key.replace(":","_")
		node.mesh = mesh
		node.material_override = glass_material if key == "glass" else (bulb_material if key == "bulb" else vertex_color_material())
		add_child(node)

# Incident light in EV, calibrated for the same sun/range/energy as the render.
# Rays use the real occluders, excluding only the sampled person's own geometry.
func light_visible(point: Vector3, toward: Vector3, person = null) -> bool:
	var direction = (toward-point).normalized()
	var query = PhysicsRayQueryParameters3D.create(point+direction*.06,toward)
	if person != null:
		var excluded: Array[RID] = []
		for body in person.colliders.values(): excluded.append(body.get_rid())
		query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func illumination_ev(point: Vector3, tod_or_night: Variant, person = null) -> float:
	var mode_str = str(tod_or_night)
	var mode_name = "night" if (mode_str == "true" or mode_str == "night") else ("golden" if mode_str == "golden" else "day")
	var intensity = pow(2.0, 2.0 if mode_name == "night" else (9.5 if mode_name == "golden" else 11.0))
	var toward_sun = point + sun.global_basis.z * 80
	if mode_name != "night" and light_visible(point, toward_sun, person):
		var sun_ev = 13.9 if mode_name == "golden" else 14.7
		intensity += pow(2.0, sun_ev) * sun_transmission()
	if mode_name == "night" or mode_name == "golden":
		for light in lamps:
			var distance = point.distance_to(light.global_position)
			if distance < light.omni_range and light_visible(point, light.global_position, person):
				var falloff = pow(maxf(0, 1 - pow(distance / light.omni_range, 4)), 2) / maxf(.25, distance * distance)
				intensity += 150 * light.light_energy * falloff
	return log(intensity) / log(2.0)

var clouds: Node3D
var cloud_material: StandardMaterial3D
var weather_time = 0.0
var cloud_cover = 0.0
var clouds_enabled = true
# Cold moonlight keeps the night park readable in toon shading (dark albedos times ambient
# alone render black). illumination_ev() ignores the sun at night, so the meter is unaffected.
const MOONLIGHT = .32
var is_night = false
var time_of_day: String = "day"

func build_clouds() -> void:
	clouds = Node3D.new()
	add_child(clouds)
	cloud_material = StandardMaterial3D.new()
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 9:
		var cloud = Node3D.new()
		cloud.position = Vector3((i%3-1)*23,22+(i%2)*3,(i/3-1)*22)
		clouds.add_child(cloud)
		for puff in 4:
			var mesh = SphereMesh.new()
			mesh.radius = 3.0+puff*.3
			mesh.height = 3.0
			mesh.radial_segments = 8
			mesh.rings = 3
			var node = MeshInstance3D.new()
			node.mesh = mesh
			node.material_override = cloud_material
			node.position = Vector3((puff-1.5)*3.2,sin(puff*2)*.5,cos(puff)*1.5)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(node)
			triangle_count += mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	update_weather(0)

func update_weather(dt: float) -> void:
	weather_time += dt
	var phase = fposmod(weather_time,18.0)
	# A cloud front crosses the sun in ~1 second, stays, then clears again.
	cloud_cover = smoothstep(6.0,7.2,phase)*(1-smoothstep(11.0,12.2,phase)) if clouds_enabled else 0.0
	if is_night:
		sun.light_energy = MOONLIGHT
	elif time_of_day == "golden":
		sun.light_energy = 2.2 * sun_transmission()
	else:
		sun.light_energy = 1.4 * sun_transmission()
	if is_instance_valid(clouds):
		clouds.visible = clouds_enabled
		clouds.position.x = (phase-9.0)*4.5
		if is_night:
			cloud_material.albedo_color = Color("202c45")
		elif time_of_day == "golden":
			cloud_material.albedo_color = Color("f09e60").darkened(cloud_cover*.18)
		else:
			cloud_material.albedo_color = Color("edf0ed").darkened(cloud_cover*.22)

func sun_transmission() -> float:
	return lerpf(1.0,.09,cloud_cover)

func sky_ev(tod_or_night: Variant) -> float:
	var mode_str = str(tod_or_night)
	var mode_name = "night" if (mode_str == "true" or mode_str == "night") else ("golden" if mode_str == "golden" else "day")
	if mode_name == "night": return 3.0
	elif mode_name == "golden": return 12.8 + log(sun_transmission()) / log(2.0)
	return 15.0 + log(sun_transmission()) / log(2.0)

func build_diorama_base() -> void:
	# Circular mahogany wooden plinth with stepped moulding and engraved brass plaque
	# Emulates a handcrafted 1:18 architectural studio model (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md §3.3 E & 8.4 Tarea 2.3.3)
	var mahogany = Color("231209")
	material(mahogany, 0.36, 0.60)
	material(Color("d4af37"), 0.26, 0.85) # Brass plaque
	material(Color("b89628"), 0.35, 0.70) # Brass inner recess
	material(Color("f0d368"), 0.20, 0.90) # Brass rivets
	var rim_segments = 48
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile = [
		Vector2(17.8, -0.01),
		Vector2(17.9, 0.08),
		Vector2(18.2, 0.16),
		Vector2(18.7, 0.14),
		Vector2(19.2, -0.25)
	]
	for seg in rim_segments:
		var a1 = deg_to_rad(seg * (360.0 / rim_segments))
		var a2 = deg_to_rad((seg + 1) * (360.0 / rim_segments))
		for p in profile.size() - 1:
			var r1 = profile[p].x
			var y1 = profile[p].y
			var r2 = profile[p + 1].x
			var y2 = profile[p + 1].y
			var v1 = Vector3(sin(a1) * r1, y1, -cos(a1) * r1)
			var v2 = Vector3(sin(a2) * r1, y1, -cos(a2) * r1)
			var v3 = Vector3(sin(a2) * r2, y2, -cos(a2) * r2)
			var v4 = Vector3(sin(a1) * r2, y2, -cos(a1) * r2)
			var norm = ((v2 - v1).cross(v4 - v1)).normalized()
			st.set_normal(norm)
			st.add_vertex(v1)
			st.add_vertex(v2)
			st.add_vertex(v3)
			st.add_vertex(v1)
			st.add_vertex(v3)
			st.add_vertex(v4)
	prop(st.commit(), Vector3.ZERO, mahogany, "", self)

	# Brass exhibition plaque at the primary entrance azimuth (theta = 120 deg)
	var plaque_theta = 120.0
	var plaque_pos = polar(plaque_theta, 18.9) + Vector3.UP * -0.04
	var plaque_root = Node3D.new()
	plaque_root.position = plaque_pos
	plaque_root.rotation.y = PI - deg_to_rad(plaque_theta)
	add_child(plaque_root)
	cube(Vector3(1.20, 0.32, 0.025), Vector3(0, 0, 0), Color("d4af37"), Texts.get_text("un_elemento_del_parque"), plaque_root)
	cube(Vector3(1.10, 0.24, 0.030), Vector3(0, 0, 0.005), Color("b89628"), "", plaque_root)
	for sx in [-0.52, 0.52]:
		for sy in [-0.11, 0.11]:
			cylinder(0.016, 0.038, Vector3(sx, sy, 0.01), Color("f0d368"), "", plaque_root)

