class_name Park
extends Node3D
const Texts = preload("res://scripts/texts.gd")
const ParkAssets = preload("res://scripts/park_assets.gd")

var environment: WorldEnvironment
var sun: DirectionalLight3D
var lamps: Array[OmniLight3D] = []
var materials = {}
var benches: Array[Dictionary] = []
var triangle_count = 0
var current_graphics_preset = "Ultra"
# Mesh detail, fixed when the park is built: "hd" in Forward+ (Ultra), "lo" in gl_compatibility
# (docs/futuro/17). Colliders never depend on it, so scoring is the same in every profile.
var detail = "lo"
var glass_color = Color(0.82, 0.92, 0.95, 0.32)
var bulb_color = Color("fff5c0")
var glass_material: StandardMaterial3D
var bulb_material: StandardMaterial3D
var water_material: ShaderMaterial
var spray_material: ShaderMaterial
var windows_material: ShaderMaterial
# Lights of the meadow (bandstand and pond): lit at golden hour and night. They are not in
# `lamps`, so the exposure meter ignores them; they stand 20 m away from the lanes anyway.
var meadow_lights: Array[OmniLight3D] = []

func init_lantern_materials() -> void:
	if glass_material == null:
		glass_material = StandardMaterial3D.new()
		glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_material.albedo_color = glass_color
		glass_material.roughness = 0.08
		glass_material.metallic_specular = 0.95
		glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[glass_color.to_html()] = glass_material

	if spray_material == null:
		# Falling water of the fountain: animated translucent streaks (shaders/park_spray.gdshader).
		spray_material = ShaderMaterial.new()
		spray_material.shader = preload("res://shaders/park_spray.gdshader")
	if windows_material == null:
		windows_material = ShaderMaterial.new()
		windows_material.shader = preload("res://shaders/park_windows.gdshader")
	if water_material == null:
		# Rippling water (shaders/park_water.gdshader): in Forward+ Ultra it mirrors sky and trees through SSR.
		water_material = ShaderMaterial.new()
		water_material.shader = preload("res://shaders/park_water.gdshader")
	if bulb_material == null:
		bulb_material = StandardMaterial3D.new()
		bulb_material.albedo_color = bulb_color
		bulb_material.roughness = 0.20
		bulb_material.metallic_specular = 0.5
		materials[bulb_color.to_html()] = bulb_material

func build_farola_mesh(parent: Node3D, with_collider: bool = true) -> void:
	init_lantern_materials()
	if ParkAssets.available("farola"):
		collider_only = true
		cylinder(.15, .16, Vector3.UP * .08, Color("28302d"), Texts.get_text("una_farola") if with_collider else "", parent)
		cylinder(.052, 2.15, Vector3.UP * 1.34, Color("323a37"), Texts.get_text("una_farola") if with_collider else "", parent, .042)
		collider_only = false
		visual("farola", "", parent)
		return
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

# Colliders only: the primitive keeps its labelled StaticBody3D (photo rays, AF, meter) but draws
# nothing, because the visible mesh comes from Blender (visual()). Scoring never sees the LOD.
var collider_only = false

func prop(mesh: Mesh, pos: Vector3, color: Color, label = "", parent: Node3D = self) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	if collider_only:
		if label != "":
			var only_body = StaticBody3D.new()
			only_body.collision_layer = 2
			only_body.set_meta("label",label)
			node.add_child(only_body)
			var only_shape = CollisionShape3D.new()
			only_shape.shape = mesh.create_convex_shape()
			only_body.add_child(only_shape)
		node.mesh = null
		return node
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

# Visible mesh of a Blender prop at the detail level of this park ("hd" or "lo"). Colours and
# ambient occlusion come baked in its vertex colours; glass and bulbs keep their own materials.
# Far background that only hd draws (docs/futuro/17 §3): colliders are still built in every profile.
var hd_only = false

func visual(asset: String, variant: String, parent: Node3D, offset: Transform3D = Transform3D.IDENTITY) -> void:
	init_lantern_materials()
	if hd_only and detail != "hd": return
	var variants = ParkAssets.meshes(asset,detail)
	for role in variants.get(variant,{}):
		var mesh: Mesh = variants[variant][role]
		var node = MeshInstance3D.new()
		node.mesh = mesh
		node.transform = offset
		node.set_meta("baked",true)
		var own = {"glass":glass_material,"bulb":bulb_material,"water":water_material,"spray":spray_material,"windows":windows_material}
		node.material_override = own.get(role,vertex_color_material()) if role != "" else vertex_color_material()
		parent.add_child(node)
		for surface in mesh.get_surface_count():
			triangle_count += mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3

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

func ring(inner: float, outer: float, color: Color, y = 0.0, layer = -1) -> void:
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
		var piece = prop(st.commit(),center,color)
		piece.set_meta("ground",true)
		# Texture layer of shaders/park_ground.gdshader (used in hd): see GROUND_LAYERS.
		if layer >= 0: piece.set_meta("ground_layer",layer)


# Ground textures (tools/texturas/build_textures.py), in texture-array order, with their repeat size.
const GROUND_LAYERS = ["losas", "asfalto", "adoquin", "grava", "cesped"]
const GROUND_TILES = [2.4, 3.0, 1.8, 2.0, 3.0]
var ground_material_hd: ShaderMaterial

func ground_material() -> ShaderMaterial:
	if ground_material_hd == null:
		ground_material_hd = ShaderMaterial.new()
		ground_material_hd.shader = preload("res://shaders/park_ground.gdshader")
		for map in ["color","normal","orm"]:
			var images: Array[Image] = []
			for name in GROUND_LAYERS:
				var image = Image.load_from_file("res://assets/texturas/%s_%s.webp" % [name,map])
				image.convert(Image.FORMAT_RGB8)
				image.generate_mipmaps()
				images.append(image)
			var array = Texture2DArray.new()
			array.create_from_images(images)
			ground_material_hd.set_shader_parameter({"color":"albedo_tex","normal":"normal_tex","orm":"orm_tex"}[map],array)
		var tiles = PackedFloat32Array(GROUND_TILES)
		tiles.resize(8)
		ground_material_hd.set_shader_parameter("tile_size",tiles)
	return ground_material_hd

# Bevelled stone kerb centred on a path edge (hd only; no collider, it stays below 0.3 m).
func curb(radius: float) -> void:
	var profile = [Vector2(-.07,0),Vector2(-.07,.045),Vector2(-.06,.06),Vector2(.06,.06),Vector2(.07,.045),Vector2(.07,0)]
	var segments = 360
	for sector in 12:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mid = (sector+.5)*TAU/12
		var center = Vector3(sin(mid)*radius,0,cos(mid)*radius)
		for i in range(sector*segments/12,(sector+1)*segments/12):
			var a = i*TAU/segments
			var b = (i+1)*TAU/segments
			for k in profile.size()-1:
				var p0: Vector2 = profile[k]
				var p1: Vector2 = profile[k+1]
				var quad = [Vector3(sin(a)*(radius+p0.x),p0.y,cos(a)*(radius+p0.x)),Vector3(sin(a)*(radius+p1.x),p1.y,cos(a)*(radius+p1.x)),Vector3(sin(b)*(radius+p1.x),p1.y,cos(b)*(radius+p1.x)),Vector3(sin(b)*(radius+p0.x),p0.y,cos(b)*(radius+p0.x))]
				# Outward-facing normal: up for the top, away from the kerb's centre line for the sides.
				var mid_offset = (p0+p1)*.5
				var edge = (p1-p0).normalized()
				var n2 = Vector2(edge.y,-edge.x)
				if n2.dot(mid_offset-Vector2(0,.03)) < 0: n2 = -n2
				var normal = Vector3(sin(a)*n2.x,n2.y,cos(a)*n2.x).normalized()
				var face = (quad[2]-quad[0]).cross(quad[1]-quad[0])
				var order = [0,2,1,0,3,2] if face.dot(normal) >= 0 else [0,1,2,0,2,3]
				for j in order:
					st.set_normal(normal)
					st.add_vertex(quad[j]-center)
		st.index()
		prop(st.commit(),center,Color("d8d2c4"))

# ---- Grass swaying in the wind (hd only, docs/futuro/17 fase 5) ----
# Tufts below 0.3 m (02 §10.3.2), so they never hide a pedestrian's scoring points; no colliders.
const GRASS_LAWNS = [Vector2(5.18,5.92), Vector2(8.08,10.42), Vector2(12.58,50.0)]
var grass_material: ShaderMaterial

func grass_density(radius: float) -> float:
	if radius < 11.0: return 110.0
	if radius < 16.0: return 60.0
	if radius < 25.0: return 22.0
	if radius < 35.0: return 9.0
	return 4.0

func grass_tuft_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	for blade in 5:
		var angle = blade*TAU/5+rng.randf_range(-.4,.4)
		var base = Vector3(cos(angle),0,sin(angle))*rng.randf_range(.005,.035)
		# Mown park lawn: 6–14 cm blades.
		var lean = Vector3(cos(angle),0,sin(angle))*rng.randf_range(.015,.04)
		var height = rng.randf_range(.06,.14)
		var side = Vector3(-sin(angle),0,cos(angle))*.006
		var mid = base+lean*.45+Vector3.UP*height*.55
		var top = base+lean+Vector3.UP*height
		var normal = (Vector3.UP*.3+Vector3(cos(angle),0,sin(angle))).normalized()
		var points = [base-side,base+side,mid+side*.7,mid-side*.7,top]
		var heights = [0.0,0.0,.55,.55,1.0]
		for tri in [[0,1,2],[0,2,3],[3,2,4]]:
			for k in tri:
				st.set_normal(normal)
				st.set_uv(Vector2(0,heights[k]))
				st.add_vertex(points[k])
	return st.commit()

var grass_nodes: Array[MultiMeshInstance3D] = []

# Share of the grass tufts drawn (the profile's density). Tufts are shuffled when built, so any
# prefix is an even thinning of the whole lawn.
func set_grass_fraction(fraction: float) -> void:
	for node in grass_nodes:
		var multimesh = node.multimesh
		multimesh.visible_instance_count = int(multimesh.instance_count*fraction)
		node.visible = fraction > 0.0

func build_grass() -> void:
	grass_material = ShaderMaterial.new()
	grass_material.shader = preload("res://shaders/park_grass.gdshader")
	var tuft = grass_tuft_mesh()
	tuft.surface_set_material(0,grass_material)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9091
	var bandstand = polar(BANDSTAND.x,BANDSTAND.y)
	var pond = polar(POND.x,POND.y)
	var buckets = {}
	for lawn in GRASS_LAWNS:
		var r = lawn.x
		while r < lawn.y:
			var r1 = minf(r+.5,lawn.y)
			var count = int(PI*(r1*r1-r*r)*grass_density(r))
			for n in count:
				var theta = rng.randf()*TAU
				var radius = sqrt(rng.randf_range(r*r,r1*r1))
				var pos = Vector3(sin(theta)*radius,0,-cos(theta)*radius)
				if pos.distance_to(bandstand) < 3.0 or pos.distance_to(pond) < 4.4: continue
				var key = sector_key(pos)
				if not buckets.has(key): buckets[key] = []
				var basis = Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(1,rng.randf_range(.7,1.25),1)*rng.randf_range(.8,1.2))
				var shade = rng.randf_range(.82,1.12)
				buckets[key].append([Transform3D(basis,pos),Color(shade*rng.randf_range(.95,1.08),shade,shade*rng.randf_range(.85,1.0))])
			r = r1
	var per_tuft = tuft.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3
	var shuffle = RandomNumberGenerator.new()
	shuffle.seed = 4242
	for key in buckets:
		# Deterministic shuffle so that a density prefix thins every ring evenly.
		var list: Array = buckets[key]
		for k in range(list.size()-1,0,-1):
			var j = shuffle.randi_range(0,k)
			var tmp = list[k]
			list[k] = list[j]
			list[j] = tmp
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = tuft
		multimesh.instance_count = buckets[key].size()
		for k in buckets[key].size():
			multimesh.set_instance_transform(k,buckets[key][k][0])
			multimesh.set_instance_color(k,buckets[key][k][1])
		var node = MultiMeshInstance3D.new()
		node.name = "Hierba_"+key.replace(":","_")
		node.multimesh = multimesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		grass_nodes.append(node)
		triangle_count += multimesh.instance_count*per_tuft

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
	var asset = TREE_ASSETS[species % 4]
	if ParkAssets.available(asset):
		# Blender tree (docs/futuro/17 fase 3). Colliders come from its "lo" mesh, the same in every
		# profile, so golden-hour shadows on lane 3 score identically in Bajo and Ultra.
		root.scale = Vector3(r_scale, h_scale, r_scale)
		var variant = str(tree_seed % 4)
		var lo: Dictionary = ParkAssets.meshes(asset,"lo").get(variant,{})
		for role in lo:
			collider(lo[role], Texts.get_text("un_arbol") if role == "trunk" else Texts.get_text("una_copa_de_arbol"), root)
		visual(asset, variant, root)
		return root
	
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

const TREE_ASSETS = ["arbol_platano", "arbol_cipres", "arbol_tilo", "arbol_arce"]
# Meadow beyond the fence (outside the playable zone, docs/futuro/17 fase 4).
const BANDSTAND = Vector2(120.0, 24.0)   # (azimuth in degrees, radius in m)
const POND = Vector2(245.0, 21.0)

func in_view_opening(theta: float) -> bool:
	for feature in [BANDSTAND, POND]:
		if absf(angle_difference(deg_to_rad(theta),deg_to_rad(feature.x))) < deg_to_rad(20): return true
	return false

# Fence bays left open as gates (±7.5° around each landmark: three bays).
func gate_bay(theta: float) -> bool:
	for feature in [BANDSTAND, POND]:
		if absf(angle_difference(deg_to_rad(theta),deg_to_rad(feature.x))) < deg_to_rad(7.6): return true
	return false

func meadow_light(pos: Vector3, energy: float, reach: float) -> void:
	var light = OmniLight3D.new()
	light.position = pos
	light.omni_range = reach
	light.light_color = Color("ffcb7a")
	light.set_meta("energy",energy)
	light.visible = false
	add_child(light)
	meadow_lights.append(light)

func facing_center(pos: Vector3) -> float:
	return atan2(-pos.x,-pos.z)

# Blender prop with a labelled collider from its "lo" mesh (the same in every profile).
func landmark(asset: String, label: String, pos: Vector3, rotation_y: float) -> void:
	var root = Node3D.new()
	root.position = pos
	root.rotation.y = rotation_y
	add_child(root)
	var lo: Dictionary = ParkAssets.meshes(asset,"lo").get("",{})
	if lo.has(""): collider(lo[""],label,root)
	visual(asset,"",root)

func build_meadow(rng: RandomNumberGenerator) -> void:
	var bandstand = polar(BANDSTAND.x,BANDSTAND.y)
	var pond = polar(POND.x,POND.y)
	landmark("quiosco",Texts.get_text("un_quiosco"),bandstand,facing_center(bandstand))
	landmark("estanque",Texts.get_text("un_estanque"),pond,facing_center(pond)+PI*.5)
	# Ripples and falling streaks are centred on the fountain axis.
	water_material.set_shader_parameter("center",Vector2(pond.x,pond.z))
	spray_material.set_shader_parameter("center",Vector2(pond.x,pond.z))
	# Bandstand: central lantern and garland under the eaves.
	meadow_light(bandstand+Vector3.UP*2.8,3.0,7.0)
	meadow_light(bandstand+Vector3.UP*3.3+(Vector3.ZERO-bandstand).normalized()*1.6,1.2,5.0)
	# Three lamps behind the pond, lighting water and fountain from the far side.
	var outward = pond.normalized()
	var side = outward.cross(Vector3.UP)
	for k in [-1.0,0.0,1.0]:
		var lamp = Node3D.new()
		lamp.position = pond+outward*(3.6-absf(k)*.6)+side*k*3.6
		add_child(lamp)
		build_farola_mesh(lamp,false)
		meadow_light(lamp.position+Vector3.UP*2.69,1.6,7.5)
	# Scattered trees in small groups across the lawn, clear of the landmarks.
	var placed = 0
	var attempt = 0
	while placed < 44 and attempt < 600:
		attempt += 1
		var theta = rng.randf_range(0,360)
		var pos = polar(theta,rng.randf_range(18.5,36.0))
		if pos.distance_to(bandstand) < 6.5 or pos.distance_to(pond) < 6.0: continue
		if in_view_opening(theta) and pos.length() < 30.0: continue
		hd_only = (placed+placed/4)%4 != 0   # every species still drawn
		build_tree(placed%4, pos, 3000 + placed * 53, rng.randf_range(1.0,1.3))
		hd_only = false
		placed += 1
	# Far tree belt framing the lawn in front of the skyline: two staggered rows.
	# In lo (Android) one tree in three of this row is drawn (and one in four of the scattered
	# meadow trees above), to stay within 100.000 triangles; the colliders are all there in every
	# profile.
	for i in 60:
		var theta = i*6.0+rng.randf_range(-2.0,2.0)
		hd_only = i%3 != 0
		build_tree((i*3)%4, polar(theta,rng.randf_range(39.0,44.0)), 4000 + i * 29, rng.randf_range(1.2,1.5))
	hd_only = false
	# The second row and the shrub clusters are drawn only in hd, to keep the mobile profiles within
	# 100.000 triangles. Their colliders exist in every profile: beyond the lanes, they never hide a
	# pedestrian, and at 46–52 m even the golden-hour sun passes above them.
	hd_only = true
	for i in 54:
		var theta = i*(360.0/54)+3.3+rng.randf_range(-2.0,2.0)
		build_tree((i*3+1)%4, polar(theta,rng.randf_range(46.0,52.0)), 5000 + i * 37, rng.randf_range(1.35,1.7))
	# Shrub clusters at the foot of the meadow trees and the far belt.
	for i in 70:
		var theta = rng.randf_range(0,360)
		var pos = polar(theta,rng.randf_range(17.0,45.0))
		if pos.distance_to(bandstand) < 4.5 or pos.distance_to(pond) < 5.0: continue
		var radius = rng.randf_range(.5,1.0)
		bush(radius,radius*rng.randf_range(1.3,1.8),pos+Vector3.UP*radius*.6,Color("4d6836"),i)
	hd_only = false

func build_skyline(rng: RandomNumberGenerator) -> void:
	for i in 30:
		var theta = i*12.0+rng.randf_range(-4,4)
		var pos = polar(theta,rng.randf_range(110.0,160.0))
		var root = Node3D.new()
		root.position = pos
		root.rotation.y = facing_center(pos)+rng.randf_range(-.4,.4)
		root.scale = Vector3.ONE*rng.randf_range(1.0,1.5)
		add_child(root)
		visual("torre",str(rng.randi_range(0,5)),root)

# Labelled collider from a mesh, with no visible geometry.
func collider(mesh: Mesh, label: String, parent: Node3D) -> void:
	var body = StaticBody3D.new()
	body.collision_layer = 2
	body.set_meta("label",label)
	parent.add_child(body)
	var shape = CollisionShape3D.new()
	shape.shape = mesh.create_convex_shape()
	body.add_child(shape)

# Bush: collider from the old ellipsoid (same volume in every profile) and a Blender bush scaled
# to it. The bush asset has radius 1 and ~1.55 m of height, standing on the ground.
func bush(radius: float, height: float, pos: Vector3, color: Color, variant: int) -> void:
	var foliage = SphereMesh.new()
	foliage.radius = radius
	foliage.height = height
	foliage.radial_segments = 7
	foliage.rings = 2
	collider_only = ParkAssets.available("arbusto")
	prop(foliage,pos,color,Texts.get_text("un_arbusto"))
	if collider_only:
		var ground_pos = Vector3(pos.x,0,pos.z)
		var basis = Basis(Vector3.UP,variant*1.7).scaled(Vector3(radius,height/1.55,radius))
		visual("arbusto",str(variant%6),self,Transform3D(basis,ground_pos))
	collider_only = false

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
	ring(0,2.8,Color("c5bdac"),0,GROUND_LAYERS.find("losas"))
	ring(2.8,5.1,Color("858580"),.006,GROUND_LAYERS.find("asfalto"))
	ring(5.1,6.0,Color("8d9f60"),0,GROUND_LAYERS.find("cesped"))
	ring(6.0,8.0,Color("b8b29c"),.005,GROUND_LAYERS.find("adoquin"))
	ring(8.0,10.5,Color("829459"),0,GROUND_LAYERS.find("cesped"))
	ring(10.5,12.5,Color("b8b29c"),.005,GROUND_LAYERS.find("grava"))
	ring(12.5,50,Color("81925c"),0,GROUND_LAYERS.find("cesped"))
	# City streets under the skyline.
	ring(50,200,Color("7d7d78"),0,GROUND_LAYERS.find("asfalto"))
	if detail == "hd":
		# Stone kerbs between paths and lawns: 6 cm high, below the 0.3 m of 02 §10.3.2.
		for r in [2.8,5.1,6.0,8.0,10.5,12.5]: curb(r)
	else:
		for r in [2.8,5.1,6.0,8.0]: ring(r,r+.035,Color("dfd8c5"),.012)
	var rng = RandomNumberGenerator.new()
	rng.seed = 403
	if ParkAssets.available("torre"):
		build_skyline(rng)
	else:
		for i in 36:
			var theta = i*10.0
			var pos = polar(theta,21+rng.randf_range(0,6))
			var h = rng.randf_range(5,12)
			var block = cube(Vector3(rng.randf_range(2,4),h,2.6),pos+Vector3.UP*h*.5,Color("a3b7c7").lightened(snappedf(rng.randf_range(0,.2),.05)))
			block.rotation.y = -deg_to_rad(theta)
			for row in range(1,int(h/.65)):
				for col in [-1,0,1]: cube(Vector3(.3,.35,.025),Vector3(col*.65,-h*.5+row*.65,1.32),Color("d3e0e6"),"",block)
	var meadow = ParkAssets.available("quiosco")
	for i in 30:
		var theta = i*12.0+4
		# Openings in the tree line towards the bandstand and the pond (docs/futuro/17 fase 4).
		if meadow and in_view_opening(theta): continue
		var pos = polar(theta,14.2)
		var variety = i%4
		build_tree(variety, pos, 1000 + i * 47, 1.0)
	var fence_assets = ParkAssets.available("verja_tramo")
	for i in 72:
		var pos = polar(i*5,12.8)
		# Gates in front of the bandstand and the pond: no bays there, a pillar on each side.
		var gate = fence_assets and ParkAssets.available("quiosco") and gate_bay(i*5.0)
		var gate_edge = fence_assets and ParkAssets.available("quiosco") and not gate and (gate_bay(i*5.0+5.0) or gate_bay(i*5.0-5.0))
		if gate: continue
		collider_only = fence_assets
		cylinder(.024,1.1,pos+Vector3.UP*.55,Color("394844"),Texts.get_text("una_verja"))
		var bar = cube(Vector3(1.15,.035,.035),pos+Vector3.UP*.8,Color("394844"))
		bar.rotation.y = -deg_to_rad(i*5)
		collider_only = false
		if fence_assets:
			# One 5° bay per post, with a stone pillar instead of the post every 30°.
			var bay = Node3D.new()
			bay.position = pos
			bay.rotation.y = -deg_to_rad(i*5)
			add_child(bay)
			visual("verja_tramo","",bay)
			if i%6 == 0 or gate_edge: visual("verja_pilar","",bay)
	# Masa densa de arbolado y arbustos de fondo tras la verja para cerrar el escenario
	for i in 84:
		var theta = i*(360.0/84.0)+rng.randf_range(-1.2,1.2)
		var radius = rng.randf_range(.55,.95)
		var height = radius*rng.randf_range(1.6,2.2)
		var pos = polar(theta,13.4+rng.randf_range(-.25,.35))
		pos.y = height*.45
		if meadow and in_view_opening(theta): continue
		var bush_colors = [Color("4d6836"),Color("5c7a3d"),Color("3e5c32"),Color("688047")]
		bush(radius,height,pos,bush_colors[i%4].lightened(snappedf(rng.randf_range(0,.12),.04)),i)
	if meadow:
		build_meadow(rng)
	else:
		for i in 36:
			var theta = i*10.0+9.0+rng.randf_range(-1.5,1.5)
			var pos = polar(theta,15.6+rng.randf_range(-.4,.6))
			var variety = (i+2)%4
			build_tree(variety, pos, 2000 + i * 31, 1.15)
	for i in (0 if meadow else 60):
		var theta = i*6.0+2.0+rng.randf_range(-1.0,1.0)
		var radius = rng.randf_range(.6,1.1)
		var height = radius*rng.randf_range(1.4,1.9)
		var pos = polar(theta,15.0+rng.randf_range(-.6,1.4))
		pos.y = height*.4
		var under_colors = [Color("39502b"),Color("4b6435"),Color("58723c")]
		bush(radius,height,pos,under_colors[i%3].lightened(snappedf(rng.randf_range(0,.1),.05)),i+3)
	for i in 12:
		var theta = i*30.0+8
		var root = Node3D.new()
		# Inner lamps at 2.6 m: in the gap between lanes 0 (≤ 2.4 m) and 1 (≥ 2.9 m), out of the way
		# of most framings (they used to stand 0.8 m from the camera).
		root.position = polar(theta,2.6 if i%3 == 0 else 8.6)
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
		benches.append({"theta":theta,"radius":bench_radius,"occupied":false,"seats":[null,null],"root":root})
		material(Color("2a3230"), 0.55, 0.45) # Cast iron legs
		material(Color("8f6136"), 0.42, 0.45) # Varnished teak slats
		collider_only = ParkAssets.available("banco")
		for x in [-.65,.65]:
			cube(Vector3(.07,.46,.48),Vector3(x,.23,.15),Color("2a3230"),Texts.get_text("un_banco"),root)
		for j in 3:
			cube(Vector3(1.65,.045,.11),Vector3(0,.47,j*.15),Color("8f6136"),Texts.get_text("un_banco"),root)
			cube(Vector3(1.65,.095,.045),Vector3(0,.66+j*.13,.4),Color("8f6136"),Texts.get_text("un_banco"),root)
		if collider_only:
			collider_only = false
			visual("banco","",root)
	for i in 70:
		var radius = rng.randf_range(.25,.5)
		var height = radius*1.5
		var pos = polar(i*5.14,9.2+rng.randf_range(-.3,.3))
		pos.y = height*.4
		bush(radius,height,pos,Color("617b43").lightened(snappedf(rng.randf_range(0,.15),.05)),i+1)
	for i in 12:
		var pos = polar(i*30+16,5.55)
		collider_only = ParkAssets.available("papelera")
		cylinder(.25,.7,pos+Vector3.UP*.35,Color("425d57"),"una papelera")
		if collider_only: visual("papelera","",self,Transform3D(Basis.IDENTITY,pos))
		var planter = polar(i*30+25,9.7)
		collider_only = ParkAssets.available("jardinera")
		cube(Vector3(.9,.35,.7),planter+Vector3.UP*.175,Color("a78366"),"una jardinera")
		for j in 5:
			cylinder(.09,.14,planter+Vector3((j-2)*.15,.43,0),[Color("d6ac4b"),Color("b45c78"),Color("e8dac0")][i%3])
		if collider_only: visual("jardinera",str(i%3),self,Transform3D(Basis.IDENTITY,planter))
		collider_only = false
	merge_static_meshes()
	# The source meshes now live inside the merged sectors: free their GPU buffers.
	ParkAssets.cache.clear()
	if detail == "hd": build_grass()
	build_clouds()
	build_sky_clouds()
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
			# Forward+ Ultra keeps the meadow and the lit skyline readable at night.
			var open_meadow = ParkAssets.available("quiosco")
			environment.environment.fog_depth_begin = 15.0 if open_meadow else 4.0
			environment.environment.fog_depth_end = 120.0 if open_meadow else 34.0

# Night lamp shadows are re-rendered every frame (people move) and cost ~100 draw calls each in
# gl_compatibility, so the profile decides how many cast them: Ultra all 12, Alto the 4 inner ones
# (lanes 0-1), Medio and Bajo none. Golden-hour lamps never do: the low sun dominates.
func update_lamp_shadows() -> void:
	for i in lamps.size():
		var inner = i % 3 == 0
		lamps[i].shadow_enabled = is_night and (current_graphics_preset == "Ultra" or (current_graphics_preset == "Alto" and inner))

# ---- Colour grading per time of day (Alto and Ultra, docs/futuro/17 postprocesado) ----
# A 33³ LUT built in code: split toning (tint of shadows and highlights), a gentle S curve and
# saturation. Day: cool shadows, warm highlights. Golden hour: teal-violet shadows, amber
# highlights. Night: blue shadows, warm lamplight, slightly desaturated.
const GRADES = {
	"day": {"shadows": Vector3(-.012,.0,.028), "highlights": Vector3(.022,.012,-.012), "contrast": .16, "saturation": 1.06},
	"golden": {"shadows": Vector3(-.02,.006,.04), "highlights": Vector3(.05,.02,-.03), "contrast": .2, "saturation": 1.08},
	"night": {"shadows": Vector3(-.012,.0,.045), "highlights": Vector3(.04,.02,-.02), "contrast": .1, "saturation": .9},
}
var grading_luts = {}

func grading_lut(tod: String) -> ImageTexture3D:
	if grading_luts.has(tod): return grading_luts[tod]
	var grade: Dictionary = GRADES.get(tod,GRADES["day"])
	var n = 33
	var layers: Array[Image] = []
	for b in n:
		var image = Image.create(n,n,false,Image.FORMAT_RGB8)
		for g in n:
			for r in n:
				var c = Vector3(r,g,b)/float(n-1)
				var luma = c.dot(Vector3(.2126,.7152,.0722))
				c += grade.shadows*(1.0-smoothstep(0.0,.55,luma))+grade.highlights*smoothstep(.45,1.0,luma)
				var curved = Vector3(smoothstep(0.0,1.0,c.x),smoothstep(0.0,1.0,c.y),smoothstep(0.0,1.0,c.z))
				c = c.lerp(curved,grade.contrast)
				luma = c.dot(Vector3(.2126,.7152,.0722))
				c = Vector3(luma,luma,luma).lerp(c,grade.saturation)
				image.set_pixel(r,g,Color(clampf(c.x,0,1),clampf(c.y,0,1),clampf(c.z,0,1)))
		layers.append(image)
	var lut = ImageTexture3D.new()
	lut.create(Image.FORMAT_RGB8,n,n,n,false,layers)
	grading_luts[tod] = lut
	return lut

static func forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

# Forward+ only (Ultra, docs/futuro/17 §2.1): dynamic GI that follows the time of day, short-range
# screen-space occlusion and bounce, sun penumbra, bloom and a light volumetric haze. In
# gl_compatibility these properties do not exist in the renderer, so they stay off.
# Forward+ effects per profile (docs/futuro/17 §2.1): every desktop profile renders the same scene
# and the lower ones only drop the costliest effects. In gl_compatibility none exist.
const EFFECTS = {
	"Ultra": {"sdfgi": 4, "ssao": true, "ssil": true, "ssr": true, "volumetric": true, "penumbra": true, "atlas": 4096, "grass": 1.0},
	"Alto": {"sdfgi": 4, "ssao": true, "ssil": false, "ssr": false, "volumetric": true, "penumbra": true, "atlas": 4096, "grass": .7},
	"Medio": {"sdfgi": 3, "ssao": true, "ssil": false, "ssr": false, "volumetric": false, "penumbra": false, "atlas": 2048, "grass": .45},
	"Bajo": {"sdfgi": 0, "ssao": false, "ssil": false, "ssr": false, "volumetric": false, "penumbra": false, "atlas": 2048, "grass": .2},
}

func apply_forward_effects(preset: String) -> void:
	var env = environment.environment
	var fx: Dictionary = EFFECTS.get(preset,EFFECTS["Ultra"])
	var forward = forward_plus()
	env.sdfgi_enabled = forward and fx.sdfgi > 0
	env.ssao_enabled = forward and fx.ssao
	env.ssil_enabled = forward and fx.ssil
	env.ssr_enabled = forward and fx.ssr
	env.volumetric_fog_enabled = forward and fx.volumetric
	env.glow_enabled = forward
	sun.light_angular_distance = .6 if forward and fx.penumbra else 0.0
	if forward: RenderingServer.directional_shadow_atlas_set_size(fx.atlas,true)
	set_grass_fraction(fx.grass if forward else 0.0)
	if not forward: return
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = maxi(fx.sdfgi,1)
	env.sdfgi_min_cell_size = .15
	# Moderate bounce: at full strength the lawn tinted white columns and ceilings green.
	env.sdfgi_energy = .7
	env.sdfgi_bounce_feedback = .25
	env.ssao_radius = .8
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssil_radius = 3.0
	env.ssil_intensity = .45
	env.glow_intensity = .35
	env.glow_bloom = .03
	# Only lamps and bulbs (emission > 2) bloom: the mannequins' small varnish highlights flickered.
	env.glow_hdr_threshold = 2.2
	env.volumetric_fog_density = .0022
	env.volumetric_fog_albedo = env.fog_light_color
	env.volumetric_fog_anisotropy = .55
	env.volumetric_fog_length = 64.0
	env.volumetric_fog_sky_affect = 0.0

# Every profile shares Ultra's look (colour pipeline, tone curve, grading and haze); lower
# profiles only drop cost: shadow quality and reach, and the Forward+ effects (docs/futuro/17 §2.1).
func apply_preset_values(preset: String) -> void:
	var env = environment.environment
	var meadow = ParkAssets.available("quiosco")
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# A brighter golden hour: the low sun alone left the park too dark.
	env.tonemap_exposure = 0.90 * (1.2 if time_of_day == "golden" else 1.0)
	env.tonemap_white = 1.45
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.03
	env.adjustment_saturation = 1.14
	env.adjustment_color_correction = grading_lut(time_of_day)
	env.fog_enabled = true
	env.fog_depth_begin = 30.0 if meadow else 8.0
	env.fog_depth_end = 220.0 if meadow else 40.0
	env.fog_depth_curve = 1.4 if meadow else 1.0
	env.fog_sky_affect = 0.3
	# Vertex colours hold sRGB values in every profile.
	if park_material: park_material.vertex_color_is_srgb = true
	match preset:
		"Bajo":
			sun.shadow_enabled = false
		"Medio":
			sun.shadow_enabled = true
			sun.shadow_blur = .8
			sun.directional_shadow_max_distance = 30.0
			sun.directional_shadow_blend_splits = false
			sun.shadow_bias = 0.02
			sun.shadow_normal_bias = .7
		"Alto":
			sun.shadow_enabled = true
			sun.shadow_blur = .8
			sun.directional_shadow_max_distance = 38.0
			sun.directional_shadow_blend_splits = true
			sun.shadow_bias = 0.02
			sun.shadow_normal_bias = .7
		"Ultra", _:
			sun.shadow_enabled = true
			sun.shadow_blur = .8
			sun.directional_shadow_max_distance = 48.0
			sun.directional_shadow_blend_splits = true
			sun.shadow_bias = 0.015
			sun.shadow_normal_bias = .6
	apply_forward_effects(preset)
	# Without SDFGI (Bajo) the flat ambient reaches every shaded face that SDFGI would occlude: it is
	# scaled per time of day to keep Ultra's exposure (calibrated on the same shot).
	var no_gi = forward_plus() and EFFECTS.get(preset,{}).get("sdfgi",4) == 0
	env.ambient_light_energy = base_ambient*(NO_GI_AMBIENT.get(time_of_day,1.0) if no_gi else 1.0)
	# gl_compatibility renders the same scene noticeably brighter than Forward+ (and without SSAO or
	# SDFGI shadowing), so its exposure is scaled to match Ultra's image (measured on the same shot).
	if not forward_plus(): env.tonemap_exposure *= LO_EXPOSURE

func set_time_of_day(tod: String) -> void:
	time_of_day = tod
	Pedestrian.screen_glow = {"day":0.0,"golden":.45,"night":1.0}.get(tod,0.0)
	is_night = (tod == "night")
	var is_golden = (tod == "golden")
	if is_night:
		sun.rotation_degrees = Vector3(-72,-35,0)
		sun.light_energy = MOONLIGHT
		sun.light_color = Color("9caed4")
		environment.environment.ambient_light_color = Color("394568")
		base_ambient = .42
		environment.environment.ambient_light_energy = base_ambient
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
		sun.light_energy = 2.6
		sun.light_color = Color("ffa544")
		# Shadows at sunset are lit by the blue sky: a clear ambient keeps the long shadows readable.
		environment.environment.ambient_light_color = Color("9aaed0")
		base_ambient = .7
		environment.environment.ambient_light_energy = base_ambient
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
		base_ambient = .22
		environment.environment.ambient_light_energy = base_ambient
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
	update_meadow_lights(tod)
	update_weather(0)
	apply_graphics_preset(current_graphics_preset)

# Bandstand garland, pond lamps and lit skyline windows follow the time of day.
func update_meadow_lights(tod: String) -> void:
	var level = {"night":1.0,"golden":.55}.get(tod,0.0)
	for light in meadow_lights:
		light.visible = level > 0
		light.light_energy = float(light.get_meta("energy"))*level
	if windows_material: windows_material.set_shader_parameter("lit",{"night":1.0,"golden":.35}.get(tod,0.0))

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
		# Colours are sRGB values (as the mannequins'), converted by the engine.
		park_material.vertex_color_is_srgb = true
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
	# Skip the flat ground, anything high above it and huge pieces (buildings).
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
	var base: Color = node.material_override.albedo_color if node.material_override is StandardMaterial3D else Color.WHITE
	var baked = node.has_meta("baked")
	var ground = node.has_meta("ground")
	# Textured ground (hd): RGB = contact occlusion only, alpha = texture layer / 10.
	var ground_layer = int(node.get_meta("ground_layer",-1)) if detail == "hd" else -1
	var label = label_of(node)
	var foliage = label == Texts.get_text("una_copa_de_arbol") or label == Texts.get_text("un_arbusto")
	# Crown volume: faces looking in towards the trunk axis (or the bush centre) or down are darker.
	var axis: Vector3 = node.get_parent().global_position if node.get_parent() != self else (node.global_transform*node.mesh.get_aabb()).get_center()
	for surface in node.mesh.get_surface_count():
		var arrays = node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors = arrays[Mesh.ARRAY_COLOR]
		var offset = group.v.size()
		for k in vertices.size():
			if baked:
				# Blender already baked colour and occlusion (linear); the park material reads sRGB values.
				group.v.append(xf*vertices[k])
				group.n.append((normal_basis*normals[k]).normalized())
				group.c.append(colors[k].linear_to_srgb() if colors != null else Color.WHITE)
				continue
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
			if ground_layer >= 0: group.c.append(Color(shade,shade,shade,ground_layer/10.0))
			else: group.c.append(Color(base.r*shade,base.g*shade,base.b*shade))
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null or indices.is_empty():
			for k in vertices.size(): group.i.append(offset+k)
		else:
			for k in indices: group.i.append(offset+k)

func merge_static_meshes() -> void:
	var groups = {}
	for node in find_children("*","MeshInstance3D",true,false):
		if node.mesh != null and not node.has_meta("ground") and not node.material_override in [glass_material,bulb_material,water_material,spray_material,windows_material]:
			add_occluder(node)
	for node in find_children("*","MeshInstance3D",true,false):
		if node.mesh == null: continue
		# Lantern glass (transparent) and bulbs (night emission) keep their own materials.
		var own_key = {glass_material:"glass",bulb_material:"bulb",water_material:"water",spray_material:"spray",windows_material:"windows"}
		var key = own_key.get(node.material_override,sector_key(node.global_position))
		if detail == "hd" and node.has_meta("ground_layer"): key = "suelo:" + key
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
		var own = {"glass":glass_material,"bulb":bulb_material,"water":water_material,"spray":spray_material,"windows":windows_material}
		if own.has(key): node.material_override = own[key]
		elif key.begins_with("suelo:"): node.material_override = ground_material()
		else: node.material_override = vertex_color_material()
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
# Ambient energy of the time of day; the profile scales it (apply_preset_values()).
var base_ambient = .22
const LO_EXPOSURE = 0.72
const NO_GI_AMBIENT = {"day": .55, "golden": .1, "night": .3}

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
	update_sky_clouds(dt)
	var phase = fposmod(weather_time,WEATHER_CYCLE)
	# A cloud front crosses the sun in ~1 second, stays, then clears again.
	# A cloud front now and then (every 45 s), crossing the sun in half a second and gone in 3 s.
	cloud_cover = smoothstep(6.0,6.5,phase)*(1-smoothstep(8.5,9.0,phase)) if clouds_enabled else 0.0
	if is_night:
		sun.light_energy = MOONLIGHT
	elif time_of_day == "golden":
		sun.light_energy = 2.6 * sun_transmission()
	else:
		sun.light_energy = 1.4 * sun_transmission()
	if is_instance_valid(clouds):
		# The cloud front is felt, not seen: the near puffs looked like missiles low in the sky.
		clouds.visible = false
		clouds.position.x = (phase-7.5)*9.0
		if is_night:
			cloud_material.albedo_color = Color("202c45")
		elif time_of_day == "golden":
			cloud_material.albedo_color = Color("f09e60").darkened(cloud_cover*.18)
		else:
			cloud_material.albedo_color = Color("edf0ed").darkened(cloud_cover*.22)

const WEATHER_CYCLE = 45.0
var sky_clouds: Node3D
var sky_cloud_material: StandardMaterial3D

# Far clouds drifting slowly across the sky, only decoration: they never cover the sun.
func build_sky_clouds() -> void:
	sky_clouds = Node3D.new()
	add_child(sky_clouds)
	sky_cloud_material = StandardMaterial3D.new()
	# Lit by the sun (rounded tops, greyer bases) and self-lit enough to stay bright white.
	sky_cloud_material.roughness = 1.0
	sky_cloud_material.metallic_specular = 0.0
	sky_cloud_material.emission_enabled = true
	sky_cloud_material.emission_energy_multiplier = .55
	# Beyond the depth fog: without this they vanish into the haze.
	sky_cloud_material.disable_fog = true
	var rng = RandomNumberGenerator.new()
	rng.seed = 777
	for i in 16:
		var cloud = Node3D.new()
		var angle = i*TAU/16+rng.randf_range(-.15,.15)
		var radius = rng.randf_range(170,260)
		cloud.position = Vector3(sin(angle)*radius,rng.randf_range(85,135),cos(angle)*radius)
		cloud.rotation.y = angle
		sky_clouds.add_child(cloud)
		var puffs = rng.randi_range(4,7)
		for k in puffs:
			var mesh = SphereMesh.new()
			mesh.radius = rng.randf_range(7,13)
			mesh.height = mesh.radius*rng.randf_range(.8,1.1)
			mesh.radial_segments = 12
			mesh.rings = 6
			var node = MeshInstance3D.new()
			node.mesh = mesh
			node.material_override = sky_cloud_material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Cumulus: big puffs in the middle, smaller ones at the ends, flat base.
			var middle = 1.0-absf(k-(puffs-1)*.5)/(puffs*.5)
			node.position = Vector3((k-(puffs-1)*.5)*rng.randf_range(8,11),mesh.radius*.35*middle,rng.randf_range(-5,5))
			node.scale = Vector3(1.3,.75+.35*middle,1)
			cloud.add_child(node)
			triangle_count += mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3

func update_sky_clouds(dt: float) -> void:
	if not is_instance_valid(sky_clouds): return
	sky_clouds.rotation.y += dt*deg_to_rad(.35)
	var tint = Color(1,1,1)
	if is_night: tint = Color("2a3450")
	elif time_of_day == "golden": tint = Color("f3b07a")
	sky_cloud_material.albedo_color = tint
	sky_cloud_material.emission = tint*(.25 if is_night else 1.0)

func sun_transmission() -> float:
	return lerpf(1.0,.09,cloud_cover)

func sky_ev(tod_or_night: Variant) -> float:
	var mode_str = str(tod_or_night)
	var mode_name = "night" if (mode_str == "true" or mode_str == "night") else ("golden" if mode_str == "golden" else "day")
	if mode_name == "night": return 3.0
	elif mode_name == "golden": return 12.8 + log(sun_transmission()) / log(2.0)
	return 15.0 + log(sun_transmission()) / log(2.0)
