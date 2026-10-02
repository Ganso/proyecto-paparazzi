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
# Smooth walking state (docs/NAVEGACION §2, «marcha suave»): forward speed along the path and
# radial speed, both changed with limited acceleration, and a preferred place in the lane.
var v_fwd = -1.0
var v_rad = 0.0
var pref_offset = 0.0
# Side (+1 outward, -1 inward) chosen to pass someone; kept for a while so it never flip-flops.
var pass_side = 0.0
var pass_timer = 0.0
var side_flip_cd = 0.0
var heading = 0.0
var heading_ready = false
# What the person is doing while stopped or seated ("", "mirar", "movil", "foto", "leer",
# "charla", "palomas"…) and who they talk to.
var activity = ""
var partner = null
# Pose blends driven by gait.gd: 0 standing … 1 seated, and the activity layer weight.
var seat = 0.0
var act_w = 0.0
var act_time = 0.0
var act_seed = 0.0
# Heading to turn to while stopped (NAN = keep), a pending smooth stop and the bench walked to.
var face_target = NAN
var pending_stop = {}
var bench_goal = -1
var sit_from = Vector2.ZERO
# Which of the two places of the bench (0 or 1), and where the head turns (radians, + left)
# to look at someone beside them.
var bench_slot = 0
var look_yaw = 0.0
var props = {}
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
# Ambient extras of the meadow (scripts/extras.gd): drawn only, never colliders or targets.
var ambient = false
# "banco" (bench-height seat) or "suelo" (sitting on the grass, legs stretched out).
var seat_kind = "banco"
# Way of walking (docs/futuro/15 P4): arm swing and shoulder sway as factors, extra elbow bend and
# torso lean in radians. Drawn per person from its seed; never named in a brief, never scored
# apart (the legs and the planted feet do not change).
var style = {"arm":1.0,"sway":1.0,"elbow":0.0,"lean":0.0}
# Walks a dog (scripts/dog.gd): the left hand holds the leash.
var has_dog = false
# The 20 bones of the universal rig; secondary chain bones come after them.
var primary_bone_count = 20
# Arm abduction at rest (radians). A shoulder bag on the right hip pushes that arm out a little.
var arm_out = {"I": .055, "D": .055}
var catalog_ref: Dictionary
var chains: Array = []
# Parsed once for everybody: each hd piece is hundreds of kilobytes of JSON.
static var piece_cache = {}

# The pieces are read and parsed in worker threads while the park is being built (main.gd calls
# preload_pieces() first thing): 35 MB of JSON that the first people to wear them used to wait for.
static var preload_paths: PackedStringArray = []
static var preload_results: Array = []
static var preload_task = -1
static func preload_pieces(folders: Array) -> void:
	if preload_task >= 0 or not piece_cache.is_empty(): return
	for folder in folders:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".json"): preload_paths.append(folder+"/"+file)
	if preload_paths.is_empty(): return
	preload_results.resize(preload_paths.size())
	preload_task = WorkerThreadPool.add_group_task(parse_piece,preload_paths.size(),-1,true)

static func parse_piece(index: int) -> void:
	preload_results[index] = JSON.parse_string(FileAccess.get_file_as_string(preload_paths[index]))

static func finish_preload() -> void:
	if preload_task < 0: return
	WorkerThreadPool.wait_for_group_task_completion(preload_task)
	preload_task = -1
	for i in preload_paths.size():
		if preload_results[i] != null: piece_cache[preload_paths[i]] = preload_results[i]
	preload_paths.clear()
	preload_results.clear()

func piece_resource(path: String) -> Dictionary:
	finish_preload()
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
	act_seed = float(seed_value%97)*1.37
	rng.seed = seed_value
	runner = t.get("runner",false)
	speed = rng.randf_range(2.6, 3.0) if runner else rng.randf_range(0.55, 0.85)
	stride *= 1.4 if runner else .8
	phase = rng.randf()*TAU
	# Its own generator: the sequence that decides speed, phase and activities is not shifted.
	var style_rng = RandomNumberGenerator.new()
	style_rng.seed = seed_value*7919+13
	style.arm = style_rng.randf_range(.9,1.1) if runner else style_rng.randf_range(.65,1.4)
	style.sway = style_rng.randf_range(.6,1.7)
	style.elbow = 0.0 if runner else style_rng.randf_range(0.0,.28)
	style.lean = 0.0 if runner else style_rng.randf_range(-.035,.02)
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
	var passes = ["both"] if detail != "hd" else (["visual"] if ambient else ["collision","visual"])
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

# The body that carries the colliders of a bone (made on first use).
func collider_body(id: String) -> StaticBody3D:
	if not colliders.has(id):
		var attachment = BoneAttachment3D.new()
		attachment.bone_name = id
		rig.add_child(attachment)
		var body = StaticBody3D.new()
		body.set_meta("person",self)
		body.set_meta("label","un viandante en primer plano")
		attachment.add_child(body)
		colliders[id] = body
	return colliders[id]

func collision_node(shape: Shape3D) -> CollisionShape3D:
	var collision = CollisionShape3D.new()
	collision.shape = shape
	return collision

func append_primitive(primitive: Mesh, id: String, tr: Transform3D, color: Color, with_collision = true) -> void:
	if build_pass == "visual" or ambient: with_collision = false
	if with_collision:
		var shape = ConvexPolygonShape3D.new()
		var collision_points = PackedVector3Array()
		for vertex in primitive.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: collision_points.append(tr*vertex)
		shape.points = collision_points
		collider_body(id).add_child(collision_node(shape))
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

# Blender pieces of this person, appended natively, and [vertex count, colour] of each.
var skinned_tool: SurfaceTool
var skinned_ranges: Array = []

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
		var shades: PackedFloat32Array = batch.get("s",PackedFloat32Array())
		var known = shades.size()
		for j in batch.v.size():
			var shade = shades[j] if j < known and shades[j] > 0.0 else occlusion(batch.v[j],batch.n[j])
			colors.append(Color(batch.color.r*shade,batch.color.g*shade,batch.color.b*shade,batch.color.a))
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
	if skinned_tool != null:
		# Tint the Blender pieces (their colour so far is only the occlusion) and add the primitives.
		var skinned = skinned_tool.commit_to_arrays()
		var tinted: PackedColorArray = skinned[Mesh.ARRAY_COLOR]
		var k = 0
		for entry in skinned_ranges:
			var tint: Color = entry[1]
			for j in entry[0]:
				var shade = tinted[k].r
				tinted[k] = Color(tint.r*shade,tint.g*shade,tint.b*shade,tint.a)
				k += 1
		skinned[Mesh.ARRAY_COLOR] = tinted
		if not vertices.is_empty():
			var rest = ArrayMesh.new()
			rest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var joined = SurfaceTool.new()
			joined.create_from_arrays(skinned)
			joined.append_from(rest,0,Transform3D.IDENTITY)
			skinned = joined.commit_to_arrays()
		arrays = skinned
		skinned_tool = null
		skinned_ranges.clear()
	triangle_count = arrays[Mesh.ARRAY_INDEX].size()/3
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

# Out of the scene for a while (the Academy clears the inner path): drawn nowhere and invisible to
# the camera's rays too, so it cannot catch the AF, the meter or a photo's occlusion test.
func set_hidden(value: bool) -> void:
	visible = not value
	for body in colliders.values(): body.collision_layer = 0 if value else 1

func animate(delta: float, traveled_distance = -1.0) -> void:
	gait.pose(delta,traveled_distance)
	update_props()
	update_skirt_springs()

# Seated, the skirt follows the thighs as far as the knees and hangs down from there. Its chains
# are children of the thighs, so they already lie along them; left alone they stuck out stiffly
# past the knees, and loosened (an earlier attempt) they dropped straight from the hips, behind
# the legs. Now their last third is bent down by the amount of sitting: the springs keep the pose
# as their target, so the cloth still sways a little (docs/futuro/19).
const SKIRT_BEND = [0.0,0.0,-1.25,-.3,0.0]     # radians per joint of a chain, fully seated
const SKIRT_BEND_BACK = [0.0,0.0,0.0,.25,0.0]
const SKIRT_TUCK = .06                         # metres behind the thigh axis where the back of the skirt lies, seated
func update_skirt_springs() -> void:
	if chains.is_empty() or (seat <= 0.0 and skirt_seated <= 0.0): return
	skirt_seated = seat
	var e = smoothstep(0,1,seat)
	for chain in chains:
		if not str(chain.name).begins_with("falda"): continue
		# The chains behind the hip end up under the thigh, on the seat: they hardly bend at the knee
		# (bent like the front ones, they hung behind the calves in shreds).
		var back = vector(chain.points[0]).z > 0.0
		var bend: Array = SKIRT_BEND_BACK if back else SKIRT_BEND
		if back:
			# Their root hangs behind the hip; with the thigh forward that is *below* it, inside the
			# seat. Seated, the root moves up against the underside of the thigh.
			var root = bones.get("%s.0" % chain.name,-1)
			if root >= 0:
				var rest: Vector3 = rig.get_bone_rest(root).origin
				rig.set_bone_pose_position(root,Vector3(rest.x,rest.y,lerpf(rest.z,minf(rest.z,SKIRT_TUCK),e)))
		for k in mini(chain.points.size(),bend.size()):
			if bend[k] == 0.0: continue
			var id = bones.get("%s.%d" % [chain.name,k],-1)
			if id >= 0: rig.set_bone_pose_rotation(id,Quaternion(Vector3.RIGHT,bend[k]*e))
var skirt_seated = -1.0

# ---- Hand-held props (docs/futuro/19_VIDA_EN_EL_PARQUE.md) ----
# Small objects shown while an activity is on: built on first use from primitives, attached to
# the hand bones, visual only (no colliders, so scoring never sees them).
const PROP_FOR = {"movil": ["telefono"], "leer": ["periodico"], "foto": ["camara"], "cafe": ["cafe"], "palomas": ["pan","migas"]}
static var prop_materials = {}
static var prop_meshes = {}
# Phone screen glow by time of day (park.gd::set_time_of_day): 0 day … 1 night. The screen is
# emissive and a tiny light (no shadows, 0.5 m) lights the face from below.
static var screen_glow = .2

func update_props() -> void:
	if build_pass == "collision" or rig == null: return
	var wanted: Array = PROP_FOR.get(activity,[]) if act_w > .3 else []
	for key in props: props[key].visible = key in wanted
	for key in wanted:
		if not props.has(key): props[key] = make_prop(key)
	if props.has("periodico") and props.periodico.visible:
		var paper: Node3D = props.periodico.get_meta("sheet")
		var hands = (global_transform*rig.get_bone_global_pose(bones["mano.D"]).origin+global_transform*rig.get_bone_global_pose(bones["mano.I"]).origin)*.5
		paper.global_transform = Transform3D(global_basis*Basis(Vector3.RIGHT,-.35),hands+global_basis*Vector3(0,.07,-.035))
	if props.has("migas"):
		# Crumbs leave the hand at the end of each toss (same cycle as gait.gd "palomas").
		var cycle = fposmod(act_time+act_seed,3.6)/3.6
		props.migas.get_meta("particles").emitting = props.migas.visible and cycle > .2 and cycle < .36
	if props.has("telefono") and props.telefono.visible:
		var light: OmniLight3D = props.telefono.get_meta("light")
		light.light_energy = lerpf(.04,.16,screen_glow)*smoothstep(.3,1.0,act_w)
		prop_materials["pantalla"].emission_energy_multiplier = lerpf(.35,.55,screen_glow)

static func prop_material(key: String, color: Color, rough = .6, emission = Color.BLACK) -> StandardMaterial3D:
	if not prop_materials.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		if emission != Color.BLACK:
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = .6
		prop_materials[key] = m
	return prop_materials[key]

# Newsprint drawn by code: the outside of the open paper on the top half of the image (back page on
# the left, front page with its masthead on the right) and the inside spread on the bottom half.
static func newspaper_material() -> StandardMaterial3D:
	if not prop_materials.has("periodico"):
		var img = Image.create(512,512,false,Image.FORMAT_RGB8)
		var paper = Color("f3f0e6")
		var ink = Color("3b3a37")
		var text = Color("8f8c85")
		img.fill(paper)
		var rng = RandomNumberGenerator.new()
		rng.seed = 7
		for half in 2:
			for page in 2:
				var x0 = page*256+14
				var y0 = half*256+12
				var top = y0
				if half == 0 and page == 1:
					# Front page: masthead between two rules, date line, big headline.
					img.fill_rect(Rect2i(x0,y0,228,2),ink)
					img.fill_rect(Rect2i(x0+34,y0+7,160,18),ink)
					img.fill_rect(Rect2i(x0,y0+30,228,2),ink)
					img.fill_rect(Rect2i(x0,y0+36,228,1),text)
					img.fill_rect(Rect2i(x0,y0+44,200,9),ink)
					img.fill_rect(Rect2i(x0,y0+57,150,9),ink)
					top = y0+74
				else:
					# Page header and a headline.
					img.fill_rect(Rect2i(x0,y0,228,1),text)
					img.fill_rect(Rect2i(x0,y0+8,120+int(rng.randf_range(0,80)),7),ink)
					top = y0+24
				# A photograph (grey block with a darker shape) somewhere on the page.
				var photo = Rect2i(x0+(0 if rng.randf() < .5 else 118),top,110,64)
				img.fill_rect(photo,Color("a9adb0"))
				img.fill_rect(Rect2i(photo.position.x+12,photo.position.y+26,60,38),Color("7d8286"))
				img.fill_rect(Rect2i(photo.position.x+62,photo.position.y+10,26,26),Color("c9ccce"))
				# Four narrow columns of text: short strokes with gaps, like words, not solid lines.
				for col in 4:
					var cx = x0+col*58
					var y = top
					while y < half*256+244:
						var inside_photo = cx+50 > photo.position.x and cx < photo.end.x and y < photo.end.y+4
						if not inside_photo:
							var x = cx
							while x < cx+50:
								var word = int(rng.randf_range(4,13))
								img.fill_rect(Rect2i(x,y,mini(word,cx+50-x),1),text)
								x += word+2
						y += 4 if rng.randf() > .06 else 9   # a gap now and then: paragraphs
		# The fold shows as a faint shadow down the middle.
		for half in 2: img.fill_rect(Rect2i(254,half*256,4,256),Color("dedacd"))
		img.generate_mipmaps()
		var m = StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.roughness = .95
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		prop_materials["periodico"] = m
	return prop_materials["periodico"]

# An open newspaper: two pages meeting at a fold, opened in a V towards the reader (+z), each page
# bulging a little and drooping at its upper outer corner. Inside and outside are separate faces
# with their own half of the texture (a flat box showed the print as planks of wood).
static func newspaper_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width = .21
	var height = .30
	var open = .42
	var columns = 6
	var rows = 4
	for side in [-1.0,1.0]:
		for face in 2:   # 0 inside (towards the reader), 1 outside
			var grid = []
			for j in rows+1:
				var row = []
				for i in columns+1:
					var t = float(i)/columns
					var up = float(j)/rows
					var droop = t*t*up*up
					var pos = Vector3(side*width*t*cos(open),(up-.5)*height-droop*.035,width*t*sin(open)-sin(t*PI)*.014+droop*.05)
					var u = .5+side*t*.5 if face == 0 else .5-side*t*.5
					var normal = Vector3(-side*sin(open),0,cos(open))*(1.0 if face == 0 else -1.0)
					row.append([pos,Vector2(u,(1.0-up)*.5+(.5 if face == 0 else 0.0)),normal])
				grid.append(row)
			for j in rows:
				for i in columns:
					var quad = [grid[j][i],grid[j][i+1],grid[j+1][i+1],grid[j+1][i]]
					# Counter-clockwise seen from the face's own side.
					var order = [0,1,2,0,2,3] if (side > 0) == (face == 1) else [0,2,1,0,3,2]
					for k in order:
						st.set_normal(quad[k][2])
						st.set_uv(quad[k][1])
						st.add_vertex(quad[k][0])
	return st.commit()

func prop_part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot = Vector3.ZERO) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node

func make_prop(key: String) -> Node3D:
	var attach = BoneAttachment3D.new()
	attach.bone_name = "mano.I" if key == "pan" else "mano.D"
	rig.add_child(attach)
	var side = -1.0 if key == "pan" else 1.0
	# Hand frame: fingers along -Y, palm facing the body's centre line (-X for the right hand).
	var holder = Node3D.new()
	holder.position = Vector3(-.02*side,-.075,0)
	attach.add_child(holder)
	match key:
		"telefono":
			var body = BoxMesh.new()
			body.size = Vector3(.009,.15,.072)
			prop_part(holder,body,prop_material("telefono",Color("1c1d21"),.35),Vector3.ZERO)
			var screen = BoxMesh.new()
			screen.size = Vector3(.002,.135,.062)
			prop_part(holder,screen,prop_material("pantalla",Color("20303c"),.15,Color("7fa7c9")),Vector3(-.0055,0,0))
			var light = OmniLight3D.new()
			light.light_color = Color("cfe3ff")
			light.omni_range = .45
			light.omni_attenuation = 0.0   # no inverse-square: at 1–2 cm from the clothes it blew out into a white blob
			light.shadow_enabled = false
			light.light_specular = 0.0   # a varnished head under a tiny close light flared into a glow blob
			light.position = Vector3(-.06,0,0)
			holder.add_child(light)
			attach.set_meta("light",light)
		"periodico":
			# Held open between both hands, facing the reader (placed every frame in update_props()).
			if not prop_meshes.has("periodico"): prop_meshes["periodico"] = newspaper_mesh()
			var paper = prop_part(holder,prop_meshes["periodico"],newspaper_material(),Vector3.ZERO)
			paper.top_level = true
			attach.set_meta("sheet",paper)
		"camara":
			var body = BoxMesh.new()
			body.size = Vector3(.075,.12,.05)
			prop_part(holder,body,prop_material("camara",Color("202224"),.45),Vector3(-.02,.0,-.02))
			var lens = CylinderMesh.new()
			lens.top_radius = .028
			lens.bottom_radius = .031
			lens.height = .06
			prop_part(holder,lens,prop_material("objetivo",Color("111213"),.3),Vector3(-.02,.0,-.07),Vector3(PI*.5,0,0))
		"cafe":
			var cup = CylinderMesh.new()
			cup.top_radius = .04
			cup.bottom_radius = .031
			cup.height = .11
			cup.radial_segments = 16
			prop_part(holder,cup,prop_material("vaso",Color("f2efe8"),.7),Vector3(-.035,.0,0),Vector3(PI,0,0))
			var sleeve = CylinderMesh.new()
			sleeve.top_radius = .037
			sleeve.bottom_radius = .034
			sleeve.height = .04
			sleeve.radial_segments = 16
			prop_part(holder,sleeve,prop_material("funda",Color("8a5a36"),.9),Vector3(-.035,.0,0),Vector3(PI,0,0))
			var lid = CylinderMesh.new()
			lid.top_radius = .036
			lid.bottom_radius = .041
			lid.height = .012
			lid.radial_segments = 16
			prop_part(holder,lid,prop_material("tapa",Color("2b2b2b"),.5),Vector3(-.035,-.06,0),Vector3(PI,0,0))
		"migas":
			var crumbs = CPUParticles3D.new()
			crumbs.amount = 14
			crumbs.lifetime = .9
			crumbs.local_coords = false
			crumbs.emitting = false
			var crumb = BoxMesh.new()
			crumb.size = Vector3(.012,.008,.012)
			crumbs.mesh = crumb
			crumbs.material_override = prop_material("miga",Color("e9dcc0"),.9)
			crumbs.direction = Vector3(0,.3,-1)
			crumbs.spread = 25.0
			crumbs.initial_velocity_min = .6
			crumbs.initial_velocity_max = 1.3
			crumbs.gravity = Vector3(0,-9.8,0)
			holder.add_child(crumbs)
			attach.set_meta("particles",crumbs)
		"pan":
			var bag = BoxMesh.new()
			bag.size = Vector3(.045,.1,.075)
			prop_part(holder,bag,prop_material("bolsa",Color("b98d5a"),.95),Vector3(.02,-.02,0))
	return attach

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
	var zone_base = ZONE_TEXTURES.get(current_zone,4)*100
	# The converted piece is kept as a mesh inside the parsed JSON, one per bone numbering (secondary
	# chains shift the indices), with its baked occlusion as vertex colour. Each person wearing it
	# appends it natively (SurfaceTool.append_from) and tints its vertices in finish_mesh().
	var mapped = PackedInt32Array()
	for bone_name in names: mapped.append(bones[bone_name])
	if not shape.has("_built"): shape["_built"] = {}
	var built = shape["_built"].get(mapped)
	if built == null:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		var v_out = PackedVector3Array()
		var n_out = PackedVector3Array()
		var c_out = PackedColorArray()
		var u_out = PackedVector2Array()
		var u2_out = PackedVector2Array()
		var b_out = PackedInt32Array()
		var w_out = PackedFloat32Array()
		# Inverse rest of each bone once, not per vertex; plain indexing instead of helper calls:
		# this loop runs over every vertex of every piece the first time somebody wears it.
		var inverse_rests = {}
		var count: int = vertices.size()
		v_out.resize(count)
		n_out.resize(count)
		c_out.resize(count)
		u_out.resize(count)
		u2_out.resize(count)
		b_out.resize(count*4)
		w_out.resize(count*4)
		var ground_span = .3*height
		for k in count:
			var raw: Array = vertices[k]
			var v = Vector3(raw[0],raw[1],raw[2])
			var k4 = k*4
			var w0: float = weights[k4]
			var w1: float = weights[k4+1]
			var w2: float = weights[k4+2]
			var w3: float = weights[k4+3]
			var best = 0
			var best_w = w0
			if w1 > best_w:
				best = 1
				best_w = w1
			if w2 > best_w:
				best = 2
				best_w = w2
			if w3 > best_w: best = 3
			var b0: int = mapped[joints[k4]]
			var b1: int = mapped[joints[k4+1]]
			var b2: int = mapped[joints[k4+2]]
			var b3: int = mapped[joints[k4+3]]
			var dominant: int = [b0,b1,b2,b3][best]
			if not inverse_rests.has(dominant): inverse_rests[dominant] = rests[dominant].affine_inverse()
			# Position in the dominant bone's space: the procedural pattern sticks to the piece.
			var local: Vector3 = inverse_rests[dominant]*v
			u_out[k] = Vector2(local.x,local.y)
			u2_out[k] = Vector2(local.z,zone_base+dominant)
			v_out[k] = v
			raw = normals[k]
			var n = Vector3(raw[0],raw[1],raw[2]).normalized()
			n_out[k] = n
			# occlusion(), inlined.
			var shade = 1.0-minf(clampf(-n.y,0.0,1.0)*.28+clampf(-n.x*signf(v.x),0.0,1.0)*clampf((absf(v.x)-.03)/.08,0.0,1.0)*.18+clampf(1.0-v.y/ground_span,0.0,1.0)*.15,.4)
			c_out[k] = Color(shade,shade,shade)
			b_out[k4] = b0
			b_out[k4+1] = b1
			b_out[k4+2] = b2
			b_out[k4+3] = b3
			w_out[k4] = w0
			w_out[k4+1] = w1
			w_out[k4+2] = w2
			w_out[k4+3] = w3
		arrays[Mesh.ARRAY_VERTEX] = v_out
		arrays[Mesh.ARRAY_NORMAL] = n_out
		arrays[Mesh.ARRAY_COLOR] = c_out
		arrays[Mesh.ARRAY_TEX_UV] = u_out
		arrays[Mesh.ARRAY_TEX_UV2] = u2_out
		arrays[Mesh.ARRAY_BONES] = b_out
		arrays[Mesh.ARRAY_WEIGHTS] = w_out
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(shape.indices)
		built = {"mesh":ArrayMesh.new(),"count":v_out.size()}
		built.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		shape["_built"][mapped] = built
	if skinned_tool == null:
		skinned_tool = SurfaceTool.new()
		skinned_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	skinned_tool.append_from(built.mesh,0,Transform3D.IDENTITY)
	skinned_ranges.append([built.count,color])

func build_contoured_mesh(shape: Dictionary, color: Color) -> void:
	if build_pass == "collision":
		# Only the hull is needed, and it is the same for everybody wearing the piece: no mesh is
		# built (it went to the GPU just to be read back) and the convex shape is shared.
		if shape.get("collision",true):
			if not shape.has("_convex"):
				var points = PackedVector3Array()
				for v in shape.vertices: points.append(vector(v))
				var convex = ConvexPolygonShape3D.new()
				convex.points = points
				shape["_convex"] = convex
			collider_body(shape.bone).add_child(collision_node(shape["_convex"]))
		return
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

