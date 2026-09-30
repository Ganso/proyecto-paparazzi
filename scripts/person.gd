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
# Mesh detail (docs/futuro/17 fase 5): "hd" in Forward+ Ultra draws data/piezas_hd/ and rounder
# joints, but the colliders are always built from the base pieces, so scoring never changes.
static var detail = "lo"
# Build pass: "both" (base detail), "collision" (base pieces, no mesh) or "visual" (hd, no colliders).
var build_pass = "both"
# The 20 bones of the universal rig; secondary chain bones come after them.
var primary_bone_count = 20
# Arm abduction at rest (radians). A shoulder bag on the right hip pushes that arm out a little.
var arm_out = {"I": .055, "D": .055}
var catalog_ref: Dictionary
var chains: Array = []
var piece_cache = {}

func piece_resource(path: String) -> Dictionary:
	if not piece_cache.has(path): piece_cache[path] = JSON.parse_string(FileAccess.get_file_as_string(path))
	return piece_cache[path]

func selected_pieces(t: Dictionary, hd: bool) -> Array:
	var slots = {"cuerpo":0,"torso":t.upper,"piernas":t.lower,"cabeza":t.hair,"accesorio":t.get("accessory",0)}
	var out = []
	for piece in profile.piezas:
		if piece.indice == slots[piece.ranura]:
			var path: String = piece.recurso
			if hd:
				path = path.replace("res://data/piezas/","res://data/piezas_hd/")
				# With a skirt the shoulder bag rides high, above the skirt's flare (docs/futuro/18).
				var skirt = catalog_ref.piezas.piernas[t.lower].style == "skirt"
				var variant = path.replace(".json","_falda.json")
				if piece.ranura == "accesorio" and skirt and FileAccess.file_exists(variant): path = variant
			out.append(piece_resource(path))
	return out

func add_secondary_chains(t: Dictionary) -> void:
	for resource in selected_pieces(t,true):
		for chain in resource.get("chains",[]):
			var parent: String = chain.parent
			var points: Array = chain.points
			for k in points.size():
				var id = "%s.%d" % [chain.name,k]
				bone(id,parent,vector(points[k]))
				parent = id
			chains.append(chain)

# Secondary motion: each chain wavers with inertia and returns to its rest shape; the legs, torso
# and head are collision capsules so skirt and hair slide over them instead of passing through.
func build_spring_simulator() -> void:
	var sim = SpringBoneSimulator3D.new()
	sim.name = "Muelles"
	rig.add_child(sim)
	sim.setting_count = chains.size()
	for i in chains.size():
		var chain: Dictionary = chains[i]
		var n: int = chain.points.size()
		sim.set_root_bone_name(i,"%s.0" % chain.name)
		sim.set_end_bone_name(i,"%s.%d" % [chain.name,n-1])
		sim.set_stiffness(i,chain.get("stiffness",1.0))
		sim.set_drag(i,chain.get("drag",.4))
		sim.set_gravity(i,chain.get("gravity",0.0))
		sim.set_radius(i,chain.get("radius",.02))
	for spec in [["muslo.I",.075,.5],["muslo.D",.075,.5],["pierna.I",.055,.45],["pierna.D",.055,.45],["torax",.15,.3],["cabeza",.1,.1]]:
		if not bones.has(spec[0]): continue
		var capsule = SpringBoneCollisionCapsule3D.new()
		capsule.bone_name = spec[0]
		capsule.radius = spec[1]*joint/.045 if spec[0].begins_with("muslo") or spec[0].begins_with("pierna") else spec[1]*profile.hombros/.42
		capsule.height = spec[2]*nz/1.5
		# Capsules run along the bone (down the limb): offset to its middle.
		var child_offset = -capsule.height*.5+capsule.radius
		capsule.position_offset = Vector3(0,child_offset,0) if not spec[0] in ["torax","lumbar","caderas","cabeza"] else Vector3(0,capsule.height*.25,0)
		capsule.rotation_offset = Quaternion.IDENTITY
		sim.add_child(capsule)
# Colour zone of the shape being built; in hd it selects the procedural texture of the toon shader
# (wood, knit, twill, hair) through UV2 (docs/futuro/17 fase 5).
var current_zone = "piel"
const ZONE_TEXTURES = {"piel":0,"tela_a":1,"tela_b":2,"pelo":3}
var rng = RandomNumberGenerator.new()
var poi = -1
var bench_index = -1
var triangle_count = 0

func setup(t: Dictionary, catalog: Dictionary, seed_value: int) -> void:
	traits = t
	catalog_ref = catalog
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
	primary_bone_count = rig.get_bone_count()
	if detail == "hd" and catalog.piezas.accesorio[t.get("accessory",0)].style == "bag": arm_out["D"] = .2
	# hd pieces may bring secondary bone chains (hair, skirt, scarf, bag) that SpringBoneSimulator3D
	# swings (docs/futuro/18): they are added before the skin binds are built.
	if detail == "hd": add_secondary_chains(t)
	rig.reset_bone_poses()
	mesh = ArrayMesh.new()
	skin = Skin.new()
	for i in rests.size(): skin.add_bind(i, rests[i].affine_inverse())
	var colors = {
		"piel":Color(catalog.tonos_madera[catalog.madera_por_tono[t.skin]]),
		"acento":Color("eee9dc"),
		"accesorio":Color(catalog.tonos_ropa[t.get("accessory_color","rojo")].rgb),
		"tela_a":Color(catalog.tonos_ropa[t.upper_color].rgb),
		"tela_b":Color(catalog.tonos_ropa[t.lower_color].rgb),
		"pelo":Color(catalog.tonos_pelo[t.hair_color].rgb),
		"calzado":Color(catalog.tonos_calzado[shoe_color(t,catalog)])
	}
	var passes = ["both"] if detail != "hd" else ["collision","visual"]
	for pass_name in passes:
		build_pass = pass_name
		var resources = selected_pieces(t,pass_name == "visual")
		# Body parts a garment covers are not drawn (docs/futuro/18): smooth-skinned cloth bends at
		# the joints while the rigid wood does not, so hidden wood would poke through.
		var hidden = {}
		for resource in resources:
			for part in resource.get("hides",[]): hidden[part] = true
		for resource in resources:
			for shape in resource.geometry:
				if hidden.has(shape.get("part","")): continue
				build_shape(shape,colors)
	build_pass = "both"

	finish_mesh()
	if not chains.is_empty(): build_spring_simulator()
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

# Derived from the traits instead of the RNG, so casting and navigation sequences stay unchanged
# and the briefing portrait always matches its target.
static func shoe_color(t: Dictionary, catalog: Dictionary) -> String:
	var shoes: Array = catalog.tonos_calzado.keys()
	if t.has("shoe_color"): return t.shoe_color
	# Dress trousers only take dark leather tones.
	if catalog.piezas.piernas[t.lower].get("style","") == "formal": shoes = ["negro","marrón"]
	return shoes[posmod(hash("%d|%s|%s|%s" % [t.profile,t.upper_color,t.lower_color,t.hair_color]),shoes.size())]

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
	# Shoulders get an extra ring: with two they end in a peak above the sleeve.
	primitive.rings = 3 if id.begins_with("brazo.") else 2
	if build_pass == "visual":
		# Round ball joints in hd: 16–20 sides and 8 rings instead of 6–8 and 2–3.
		primitive.radial_segments = primitive.radial_segments*5/2
		primitive.rings = primitive.rings*3+1
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
	primitive.radial_segments = 14 if build_pass == "visual" else 6
	primitive.rings = 1
	var basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	append_primitive(primitive,id,Transform3D(basis,(a+b)*.5),color)

func append_primitive(primitive: Mesh, id: String, tr: Transform3D, color: Color, with_collision = true) -> void:
	if build_pass == "visual": with_collision = false
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
	if build_pass == "collision": return
	var key = color.to_html()+current_zone
	if not batches.has(key): batches[key] = {"v":PackedVector3Array(),"n":PackedVector3Array(),"i":PackedInt32Array(),"b":PackedInt32Array(),"w":PackedFloat32Array(),"color":color,"u":PackedVector2Array(),"u2":PackedVector2Array()}
	var batch: Dictionary = batches[key]
	var arrays = primitive.surface_get_arrays(0)
	var offset: int = batch.v.size()
	var transform: Transform3D = rests[bones[id]]*tr
	var normal_matrix = transform.basis.inverse().transposed()
	# UVs for the procedural patterns in every detail level; the profile decides if they are drawn.
	var textured = true
	var zone_code = ZONE_TEXTURES.get(current_zone,4)*100+bones[id]
	for j in arrays[Mesh.ARRAY_VERTEX].size():
		if textured:
			# Position in the bone's own space: the texture sticks to the piece while it moves.
			var local = tr*arrays[Mesh.ARRAY_VERTEX][j]
			batch.u.append(Vector2(local.x,local.y))
			batch.u2.append(Vector2(local.z,zone_code))
		batch.v.append(transform*arrays[Mesh.ARRAY_VERTEX][j])
		batch.n.append((normal_matrix*arrays[Mesh.ARRAY_NORMAL][j]).normalized())
		batch.b.append_array(PackedInt32Array([bones[id],0,0,0]))
		batch.w.append_array(PackedFloat32Array([1,0,0,0]))
	for index in arrays[Mesh.ARRAY_INDEX]: batch.i.append(index+offset)

# Ambient occlusion baked into the vertex colours (no render cost): undersides, the inner faces
# of arms and thighs, and the lowest part of the legs read darker, which gives the flat colour
# zones volume. Uses the rest pose, where y is the height above the ground.
func occlusion(v: Vector3, n: Vector3) -> float:
	var down = clampf(-n.y,0,1)*.28
	var inner = clampf(-n.x*signf(v.x),0,1)*clampf((absf(v.x)-.03)/.08,0,1)*.18
	var ground = clampf(1-v.y/(.3*height),0,1)*.15
	return 1-minf(down+inner+ground,.4)

# Toon shading plus ink outline (next_pass), shared by every person: one material, two passes.
static var shared_material: ShaderMaterial
const OUTLINE = false

static func mannequin_material() -> ShaderMaterial:
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		# Realistic varnished wood and cloth in every profile (the toon bands were retired on
		# 30-09-2026: the lower profiles only drop cost, never change the look).
		shared_material.shader = preload("res://shaders/mannequin_pbr.gdshader")
		# The ink outline (cel_outline.gdshader) is off since the realistic style (30-09-2026): its
		# inverted hull produced invalid pixels on thin pieces (hat brims) that flashed in the glow.
		if OUTLINE:
			var outline = ShaderMaterial.new()
			outline.shader = preload("res://shaders/cel_outline.gdshader")
			shared_material.next_pass = outline
	return shared_material

func finish_mesh() -> void:
	# One draw surface per person: vertex colors preserve the four named color zones.
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var bone_indices = PackedInt32Array()
	var weights = PackedFloat32Array()
	var colors = PackedColorArray()
	var uv = PackedVector2Array()
	var uv2 = PackedVector2Array()
	for batch in batches.values():
		uv.append_array(batch.u)
		uv2.append_array(batch.u2)
		var offset = vertices.size()
		vertices.append_array(batch.v)
		normals.append_array(batch.n)
		bone_indices.append_array(batch.b)
		weights.append_array(batch.w)
		for index in batch.i: indices.append(index+offset)
		for j in batch.v.size():
			var shade = occlusion(batch.v[j],batch.n[j])
			colors.append(Color(batch.color.r*shade,batch.color.g*shade,batch.color.b*shade,batch.color.a))
	triangle_count = indices.size()/3
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_BONES] = bone_indices
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,mannequin_material())
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
	current_zone = shape.color
	var color: Color = colors[shape.color]
	color = color.darkened(shape.get("darken",0)).lightened(shape.get("lighten",0))
	# Alpha only flags shapes the ink outline must skip (cel_outline.gdshader); the surface is opaque.
	if not shape.get("outline",true): color.a = 0
	match shape.type:
		"mesh": build_contoured_mesh(shape,color)
		"skinned": build_skinned_mesh(shape,color)
		"ellipsoid": ellipsoid(shape.bone,vector(shape.position),vector(shape.size),color)
		"box": box(shape.bone,vector(shape.position),vector(shape.size),color)
		"segment": segment(shape.bone,vector(shape.a),vector(shape.b),shape.radius_a,shape.radius_b,color)

# Pieces modelled in Blender (tools/blender/build_characters.py, docs/futuro/18): vertices already in
# model space at rest, with up to four bones per vertex. Wood stays rigid (one bone); clothes and
# hair blend two to four bones across the joints, so they bend instead of splitting or clipping.
func build_skinned_mesh(shape: Dictionary, color: Color) -> void:
	var names: Array = shape.bone_names
	var joints: Array = shape.joints
	var weights: Array = shape.weights
	var vertices: Array = shape.vertices
	var normals: Array = shape.normals
	var key = color.to_html()+current_zone
	if not batches.has(key): batches[key] = {"v":PackedVector3Array(),"n":PackedVector3Array(),"i":PackedInt32Array(),"b":PackedInt32Array(),"w":PackedFloat32Array(),"color":color,"u":PackedVector2Array(),"u2":PackedVector2Array()}
	var batch: Dictionary = batches[key]
	var offset: int = batch.v.size()
	var zone_base = ZONE_TEXTURES.get(current_zone,4)*100
	for k in vertices.size():
		var v = vector(vertices[k])
		var best = 0
		for j in 4:
			if weights[k*4+j] > weights[k*4+best]: best = j
		var dominant: int = bones[names[joints[k*4+best]]]
		# Position in the dominant bone's space: the procedural pattern sticks to the piece.
		var local = rests[dominant].affine_inverse()*v
		batch.u.append(Vector2(local.x,local.y))
		batch.u2.append(Vector2(local.z,zone_base+dominant))
		batch.v.append(v)
		batch.n.append(vector(normals[k]).normalized())
		for j in 4:
			batch.b.append(bones[names[joints[k*4+j]]])
			batch.w.append(weights[k*4+j])
	for index in shape.indices: batch.i.append(index+offset)

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

