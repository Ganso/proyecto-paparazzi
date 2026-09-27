class_name Park
extends Node3D
const Texts = preload("res://scripts/texts.gd")

var environment: WorldEnvironment
var sun: DirectionalLight3D
var lamps: Array[OmniLight3D] = []
var materials = {}
var benches: Array[Dictionary] = []
var triangle_count = 0

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
	for sector in 12:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mid = (sector*8+4)*TAU/96
		var center = Vector3(sin(mid)*(inner+outer)*.5,0,cos(mid)*(inner+outer)*.5)
		for i in range(sector*8,(sector+1)*8):
			var a = i*TAU/96
			var b = (i+1)*TAU/96
			var points = [Vector3(sin(a)*inner,y,cos(a)*inner),Vector3(sin(a)*outer,y,cos(a)*outer),Vector3(sin(b)*outer,y,cos(b)*outer),Vector3(sin(b)*inner,y,cos(b)*inner)]
			for j in [0,2,1,0,3,2]:
				st.set_normal(Vector3.UP)
				st.add_vertex(points[j]-center)
		prop(st.commit(),center,color)

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
	environment.environment.fog_sky_affect = 0.5
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
		var block = cube(Vector3(rng.randf_range(2,4),h,2.6),pos+Vector3.UP*h*.5,Color("94a5ac").lightened(snappedf(rng.randf_range(0,.2),.05)))
		block.rotation.y = -deg_to_rad(theta)
		for row in range(1,int(h/.65)):
			for col in [-1,0,1]: cube(Vector3(.3,.35,.025),Vector3(col*.65,-h*.5+row*.65,1.32),Color("b8c8cc"),"",block)
	for i in 30:
		var theta = i*12.0+4
		var root = Node3D.new()
		root.position = polar(theta,14.2)
		add_child(root)
		var variety = i%4
		var trunk_height = [2.6,3.8,2.0,3.0][variety]
		cylinder(.14+variety*.025,trunk_height,Vector3.UP*trunk_height*.5,Color("77604a"),Texts.get_text("un_arbol"),root)
		if variety == 1:
			for level in 3: cylinder(1.25-level*.25,1.8,Vector3.UP*(2.8+level*.8),Color("3c674d"),Texts.get_text("una_copa_de_arbol"),root,0)
			continue
		for j in 3:
			var foliage = SphereMesh.new()
			foliage.radius = [1.1,1.0,.8,1.3][variety]
			foliage.height = 3.1 if variety == 2 else 1.8
			foliage.radial_segments = 5
			foliage.rings = 2
			prop(foliage,Vector3((j-1)*.7,trunk_height+(.6 if j == 1 else 0),0),[Color("6e8745"),Color("3c674d"),Color("78984e"),Color("a58b47")][variety].lightened(j*.045),Texts.get_text("una_copa_de_arbol"),root)
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
		foliage.radial_segments = 5
		foliage.rings = 1
		var pos = polar(theta,13.4+rng.randf_range(-.25,.35))
		pos.y = foliage.height*.45
		var bush_colors = [Color("4d6836"),Color("5c7a3d"),Color("3e5c32"),Color("688047")]
		prop(foliage,pos,bush_colors[i%4].lightened(snappedf(rng.randf_range(0,.12),.04)),Texts.get_text("un_arbusto"))
	for i in 36:
		var theta = i*10.0+9.0+rng.randf_range(-1.5,1.5)
		var root = Node3D.new()
		root.position = polar(theta,15.6+rng.randf_range(-.4,.6))
		add_child(root)
		var variety = (i+2)%4
		var trunk_height = [3.2,4.4,2.8,3.8][variety]
		cylinder(.15+variety*.02,trunk_height,Vector3.UP*trunk_height*.5,Color("604d3b"),Texts.get_text("un_arbol"),root)
		if variety == 1:
			for level in 3:
				cylinder(1.4-level*.3,2.0,Vector3.UP*(3.0+level*.9),Color("32563f"),Texts.get_text("una_copa_de_arbol"),root,0)
			continue
		for j in 3:
			var foliage = SphereMesh.new()
			foliage.radius = [1.2,1.1,.9,1.4][variety]
			foliage.height = 3.3 if variety == 2 else 2.0
			foliage.radial_segments = 5
			foliage.rings = 2
			prop(foliage,Vector3((j-1)*.75,trunk_height+(.7 if j == 1 else 0),0),[Color("5f7a39"),Color("32563f"),Color("698941"),Color("8e773a")][variety].lightened(j*.04),Texts.get_text("una_copa_de_arbol"),root)
	for i in 60:
		var theta = i*6.0+2.0+rng.randf_range(-1.0,1.0)
		var foliage = SphereMesh.new()
		foliage.radius = rng.randf_range(.6,1.1)
		foliage.height = foliage.radius*rng.randf_range(1.4,1.9)
		foliage.radial_segments = 5
		foliage.rings = 1
		var pos = polar(theta,15.0+rng.randf_range(-.6,1.4))
		pos.y = foliage.height*.4
		var under_colors = [Color("39502b"),Color("4b6435"),Color("58723c")]
		prop(foliage,pos,under_colors[i%3].lightened(snappedf(rng.randf_range(0,.1),.05)),Texts.get_text("un_arbusto"))
	for i in 12:
		var theta = i*30.0+8
		var root = Node3D.new()
		root.position = polar(theta,0.8 if i%3 == 0 else 8.6)
		add_child(root)
		cylinder(.055,2.55,Vector3.UP*1.275,Color("4d5552"),Texts.get_text("una_farola"),root)
		cylinder(.12,.15,Vector3.UP*.075,Color("575c55"),Texts.get_text("una_farola"),root)
		cylinder(.19,.38,Vector3.UP*2.55,Color("efdeaf"),Texts.get_text("una_farola"),root,.12)
		cylinder(.24,.11,Vector3.UP*2.79,Color("505753"),Texts.get_text("una_farola"),root,.03)
		var light = OmniLight3D.new()
		light.position = Vector3(0,2.30,.24)
		light.shadow_enabled = true
		light.omni_range = 6
		light.light_color = Color("ffcd82")
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
		foliage.radial_segments = 5
		foliage.rings = 1
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

func set_time_of_day(tod: String) -> void:
	time_of_day = tod
	is_night = (tod == "night")
	var is_golden = (tod == "golden")
	if is_night:
		sun.rotation_degrees = Vector3(-72,-35,0)
		sun.light_energy = .035
		sun.light_color = Color("9caed4")
		sun.shadow_blur = 1.5
		environment.environment.ambient_light_color = Color("394568")
		environment.environment.ambient_light_energy = .14
		environment.environment.fog_light_color = Color("192139")
		environment.environment.fog_depth_begin = 7.0
		environment.environment.fog_depth_end = 20.0
		environment.environment.tonemap_exposure = 0.95
		var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
		sky_mat.sky_top_color = Color("060d21")
		sky_mat.sky_horizon_color = Color("192139")
		sky_mat.ground_horizon_color = Color("192139")
		sky_mat.ground_bottom_color = Color("060d15")
		for light in lamps:
			light.light_energy = 2.2
			light.light_color = Color("ffcd82")
	elif is_golden:
		# Spectacular low-angle golden hour lighting (pitch -15 deg, azimuth -48 deg)
		sun.rotation_degrees = Vector3(-15,-48,0)
		sun.light_energy = 2.2
		sun.light_color = Color("ffa544")
		sun.shadow_blur = 2.2
		environment.environment.ambient_light_color = Color("4a5e7e")
		environment.environment.ambient_light_energy = .24
		environment.environment.fog_light_color = Color("e58b3e")
		environment.environment.fog_depth_begin = 10.0
		environment.environment.fog_depth_end = 28.0
		environment.environment.tonemap_exposure = 0.94
		var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
		sky_mat.sky_top_color = Color("18355e")
		sky_mat.sky_horizon_color = Color("ed8234")
		sky_mat.ground_horizon_color = Color("b55e24")
		sky_mat.ground_bottom_color = Color("2e1c12")
		# Incipient twilight illumination on park lampposts
		for light in lamps:
			light.light_energy = 0.90
			light.light_color = Color("ffcb74")
	else:
		sun.rotation_degrees = Vector3(-72,-35,0)
		sun.light_energy = 1.4
		sun.light_color = Color("fff0d7")
		sun.shadow_blur = 1.5
		environment.environment.ambient_light_color = Color("c6d6df")
		environment.environment.ambient_light_energy = .16
		environment.environment.fog_light_color = Color("c5d4c9")
		environment.environment.fog_depth_begin = 8.0
		environment.environment.fog_depth_end = 22.0
		environment.environment.tonemap_exposure = 0.88
		var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
		sky_mat.sky_top_color = Color("87b2c5")
		sky_mat.sky_horizon_color = Color("d4e1dc")
		sky_mat.ground_horizon_color = Color("c5d4c9")
		sky_mat.ground_bottom_color = Color("738064")
		for light in lamps: light.light_energy = 0
	update_weather(0)

func set_night(night: bool) -> void:
	set_time_of_day("night" if night else "day")

func merge_static_meshes() -> void:
	var groups = {}
	var nodes = find_children("*","MeshInstance3D",true,false)
	for node in nodes:
		var color_key = node.material_override.albedo_color.to_html()
		var cell = Vector2i(floori(node.global_position.x/6),floori(node.global_position.z/6))
		var key = color_key+":"+str(cell)
		if not groups.has(key):
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = st
		for surface in node.mesh.get_surface_count():
			groups[key].append_from(node.mesh,surface,node.global_transform)
	for node in nodes: node.mesh = null
	for key in groups:
		var node = MeshInstance3D.new()
		node.mesh = groups[key].commit()
		node.material_override = materials[key.split(":")[0]]
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
		sun.light_energy = .035
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

