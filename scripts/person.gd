class_name Pedestrian
extends Node3D

var traits: Dictionary
var profile: Dictionary
var actual_velocity = Vector3.ZERO
var destination_lane = -1
var lane_timer = 10.0
var lane = 1
var stuck_time = 0.0
var lane_change_blocked = 0.0
var theta = 120.0
var radius = 4.0
var gait
var runner = false
var speed = 1.1
var direction = 1.0
var phase = 0.0
var state = "CAMINANDO"
var state_time = 0.0
var protected_target = false
var rig: Skeleton3D
var bones = {}
var rests: Array[Transform3D] = []
var mesh: ArrayMesh
var skin: Skin
var batches = {}
var height = 1.75
var nz = 1.51
var stride = 1.461
var joint = .045
var hip_y = .82
var colliders = {}
var rng = RandomNumberGenerator.new()
var poi = -1
var bench_index = -1
var triangle_count = 0

func setup(t: Dictionary, catalog: Dictionary, seed_value: int) -> void:
	traits = t
	profile = catalog.perfiles[t.profile]
	height = profile.altura
	nz = height-height/profile.relacion_cabeza
	stride = profile.zancada
	joint = profile.radio
	hip_y = nz*.542
	rng.seed = seed_value
	runner = t.get("runner",false)
	speed = rng.randf_range(2.6, 3.0) if runner else rng.randf_range(0.55, 0.85)
	stride *= 1.4 if runner else .8
	phase = rng.randf()*TAU
	rig = Skeleton3D.new()
	rig.name = "Rig"
	add_child(rig)
	make_rig()
	rig.reset_bone_poses()
	mesh = ArrayMesh.new()
	skin = Skin.new()
	for i in rests.size(): skin.add_bind(i, rests[i].affine_inverse())
	var colors = {
		"piel":Color(catalog.tonos_piel[t.skin]),
		"acento":Color("eee9dc"),
		"accesorio":Color(catalog.tonos_ropa[t.get("accessory_color","rojo")].rgb),
		"tela_a":Color(catalog.tonos_ropa[t.upper_color].rgb),
		"tela_b":Color(catalog.tonos_ropa[t.lower_color].rgb),
		"pelo":Color(catalog.tonos_pelo[t.hair_color].rgb)
	}
	var slots = {"cuerpo":0,"torso":t.upper,"piernas":t.lower,"cabeza":t.hair,"accesorio":t.get("accessory",0)}
	for piece in profile.piezas:
		if piece.indice == slots[piece.ranura]:
			var resource: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(piece.recurso))
			for shape in resource.geometry: build_shape(shape,colors)

	finish_mesh()
	gait = preload("res://scripts/gait.gd").new(self)
func bone(id: String, parent: String, world: Vector3) -> void:
	var i = rig.get_bone_count()
	rig.add_bone(id)
	bones[id] = i
	var transform = Transform3D(Basis.IDENTITY,world)
	if parent != "":
		var p: int = bones[parent]
		rig.set_bone_parent(i,p)
		rig.set_bone_rest(i,rests[p].affine_inverse()*transform)
	else: rig.set_bone_rest(i,transform)
	rests.append(transform)

func make_rig() -> void:
	bone("raiz","",Vector3.ZERO)
	bone("caderas","raiz",Vector3(0,hip_y,0))
	var leg_x: float = profile.hombros*.22
	for side in ["I","D"]:
		var x = leg_x*(-1 if side == "I" else 1)
		bone("muslo."+side,"caderas",Vector3(x,hip_y,0))
		bone("pierna."+side,"muslo."+side,Vector3(x,nz*.323,0))
		bone("pie."+side,"pierna."+side,Vector3(x,nz*.03,0))
	bone("lumbar","caderas",Vector3(0,nz*.692,0))
	bone("torax","lumbar",Vector3(0,nz*.808,0))
	bone("cuello","torax",Vector3(0,nz*.965,0))
	bone("cabeza","cuello",Vector3(0,nz,0))
	for side in ["I","D"]:
		var x: float = (profile.hombros*.5-joint)*(-1 if side == "I" else 1)
		bone("clavicula."+side,"torax",Vector3(x*.65,nz*.929,0))
		bone("brazo."+side,"clavicula."+side,Vector3(x,nz*.929,0))
		bone("antebrazo."+side,"brazo."+side,Vector3(x,nz*(.929-.215),0))
		bone("mano."+side,"antebrazo."+side,Vector3(x,nz*(.929-.215-.169),0))

func ellipsoid(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var primitive = SphereMesh.new()
	primitive.radius = .5
	primitive.height = 1
	primitive.radial_segments = 7 if id == "cabeza" else 8 if id.begins_with("brazo.") else 6
	primitive.rings = 2
	append_primitive(primitive,id,Transform3D(Basis.from_scale(size),pos),color)

func box(id: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var primitive = BoxMesh.new()
	primitive.size = size
	append_primitive(primitive,id,Transform3D(Basis.IDENTITY,pos),color)

func segment(id: String, a: Vector3, b: Vector3, ra: float, rb: float, color: Color) -> void:
	var primitive = CylinderMesh.new()
	primitive.bottom_radius = ra
	primitive.top_radius = rb
	primitive.height = a.distance_to(b)
	primitive.radial_segments = 6
	primitive.rings = 1
	var basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	append_primitive(primitive,id,Transform3D(basis,(a+b)*.5),color)

func append_primitive(primitive: Mesh, id: String, tr: Transform3D, color: Color, with_collision = true) -> void:
	if with_collision and not colliders.has(id):
		var attachment = BoneAttachment3D.new()
		attachment.bone_name = id
		rig.add_child(attachment)
		var body = StaticBody3D.new()
		body.set_meta("person",self)
		body.set_meta("label","un viandante en primer plano")
		attachment.add_child(body)
		colliders[id] = body
	if with_collision:
		var collision = CollisionShape3D.new()
		var shape = ConvexPolygonShape3D.new()
		var collision_points = PackedVector3Array()
		for vertex in primitive.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: collision_points.append(tr*vertex)
		shape.points = collision_points
		collision.shape = shape
		colliders[id].add_child(collision)
	var key = color.to_html()
	if not batches.has(key): batches[key] = {"v":PackedVector3Array(),"n":PackedVector3Array(),"i":PackedInt32Array(),"b":PackedInt32Array(),"w":PackedFloat32Array(),"color":color}
	var batch: Dictionary = batches[key]
	var arrays = primitive.surface_get_arrays(0)
	var offset: int = batch.v.size()
	var transform: Transform3D = rests[bones[id]]*tr
	var normal_matrix = transform.basis.inverse().transposed()
	for j in arrays[Mesh.ARRAY_VERTEX].size():
		batch.v.append(transform*arrays[Mesh.ARRAY_VERTEX][j])
		batch.n.append((normal_matrix*arrays[Mesh.ARRAY_NORMAL][j]).normalized())
		batch.b.append_array(PackedInt32Array([bones[id],0,0,0]))
		batch.w.append_array(PackedFloat32Array([1,0,0,0]))
	for index in arrays[Mesh.ARRAY_INDEX]: batch.i.append(index+offset)

func finish_mesh() -> void:
	# One draw surface per person: vertex colors preserve the four named color zones.
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var bone_indices = PackedInt32Array()
	var weights = PackedFloat32Array()
	var colors = PackedColorArray()
	for batch in batches.values():
		var offset = vertices.size()
		vertices.append_array(batch.v)
		normals.append_array(batch.n)
		bone_indices.append_array(batch.b)
		weights.append_array(batch.w)
		for index in batch.i: indices.append(index+offset)
		for vertex in batch.v: colors.append(batch.color)
	triangle_count = indices.size()/3
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_BONES] = bone_indices
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1
	mesh.surface_set_material(0,mat)
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.skin = skin
	instance.skeleton = NodePath("../Rig")
	instance.custom_aabb = AABB(Vector3(-1,-.7,-1),Vector3(2,height+1,2))
	add_child(instance)
	batches.clear()

func pose_bone(id: String, angle: float) -> void:
	rig.set_bone_pose_rotation(bones[id],Quaternion(Vector3.RIGHT,angle))

func animate(delta: float, traveled_distance = -1.0) -> void:
	gait.pose(delta,traveled_distance)

func place() -> void:
	position = Vector3(sin(deg_to_rad(theta))*radius,0,-cos(deg_to_rad(theta))*radius)
	rotation.y = -deg_to_rad(theta)-direction*PI*.5

func control_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for id in ["cabeza","torax","caderas","pierna.I","pierna.D"]:
		var point: Vector3 = rig.get_bone_global_pose(bones[id]).origin
		if id == "cabeza": point.y += height/profile.relacion_cabeza*.5
		result.append(global_transform*point)
	return result

func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func build_shape(shape: Dictionary, colors: Dictionary) -> void:
	var color: Color = colors[shape.color]
	color = color.darkened(shape.get("darken",0)).lightened(shape.get("lighten",0))
	match shape.type:
		"mesh": build_contoured_mesh(shape,color)
		"ellipsoid": ellipsoid(shape.bone,vector(shape.position),vector(shape.size),color)
		"box": box(shape.bone,vector(shape.position),vector(shape.size),color)
		"segment": segment(shape.bone,vector(shape.a),vector(shape.b),shape.radius_a,shape.radius_b,color)

func build_contoured_mesh(shape: Dictionary, color: Color) -> void:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	for v in shape.vertices: vertices.append(vector(v))
	for n in shape.normals: normals.append(vector(n))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(shape.indices)
	var part = ArrayMesh.new()
	part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	append_primitive(part,shape.bone,Transform3D.IDENTITY,color,shape.get("collision",true))

