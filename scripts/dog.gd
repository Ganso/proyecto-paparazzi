extends Node3D
# A dog on a leash (docs/futuro/19_VIDA_EN_EL_PARQUE.md §3): trots beside its owner on the
# keep-right side, sniffs around while the owner stands, lies down in front of the bench while
# the owner sits. Parts (body, head, tail, four legs) built from primitives and animated by code.
# In the playable lanes it has a labelled collider on layer 1 only: photo rays see it (it hides
# what it hides), navigation (mask 2) does not.
const Texts = preload("res://scripts/texts.gd")

var walker: Node3D
var rng = RandomNumberGenerator.new()
var size = 1.0
var velocity = Vector3.ZERO
var heading = 0.0
var phase = 0.0
var sniff = 0.0
var wander = Vector3.ZERO
var wander_t = 0.0
var lie = 0.0
var parts = {}
var leash: MeshInstance3D
var with_collider = true
var clock = 0.0

func setup(owner_node: Node3D, seed_value: int, coat: Color, collider = true) -> void:
	walker = owner_node
	with_collider = collider
	rng.seed = seed_value
	size = rng.randf_range(.8,1.1)
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = .85
	var dark = coat.darkened(.45)
	var light_c = coat.lightened(.35)
	var body = part("cuerpo",Vector3(0,.4,0)*size,material)
	blob(body,Vector3.ZERO,Vector3(.24,.24,.56)*size,coat)
	blob(body,Vector3(0,-.04,-.04)*size,Vector3(.19,.16,.36)*size,light_c)
	blob(body,Vector3(0,.05,-.25)*size,Vector3(.2,.24,.18)*size,coat)          # chest / shoulders
	blob(body,Vector3(0,.1,-.3)*size,Vector3(.16,.05,.1)*size,Color("b3342e")) # collar
	var head = part("cabeza",Vector3(0,.55,-.33)*size,material)
	blob(head,Vector3(0,.04,-.04)*size,Vector3(.17,.16,.2)*size,coat)
	blob(head,Vector3(0,.0,-.16)*size,Vector3(.09,.08,.14)*size,light_c)       # snout
	blob(head,Vector3(0,.02,-.235)*size,Vector3(.04,.035,.03)*size,Color("1c1a19"))  # nose
	for x in [-.055,.055]:
		blob(head,Vector3(x*size,.13*size,.0),Vector3(.05,.1,.035)*size,dark)       # ears
		blob(head,Vector3(x*.7*size,.07*size,-.1*size),Vector3(.02,.02,.02)*size,Color("1c1a19"))
	var tail = part("cola",Vector3(0,.47,.24)*size,material)
	blob(tail,Vector3(0,.05,.08)*size,Vector3(.05,.05,.22)*size,coat,-.8)
	for id in ["pata.DI","pata.DD","pata.TI","pata.TD"]:
		var x = (-.075 if id.ends_with("I") else .075)*size
		var z = (-.2 if id.begins_with("pata.D") else .19)*size
		var leg = part(id,Vector3(x,.34*size,z),material)
		blob(leg,Vector3(0,-.16,0)*size,Vector3(.065,.34,.07)*size,coat)
		blob(leg,Vector3(0,-.32,-.015)*size,Vector3(.07,.04,.09)*size,dark)
	leash = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = .006
	cyl.bottom_radius = .006
	cyl.height = 1.0
	cyl.radial_segments = 5
	leash.mesh = cyl
	var leash_material = StandardMaterial3D.new()
	leash_material.albedo_color = Color("b3342e")
	leash.material_override = leash_material
	leash.top_level = true
	add_child(leash)
	if with_collider:
		var bodyc = StaticBody3D.new()
		bodyc.collision_layer = 1
		bodyc.collision_mask = 0
		bodyc.set_meta("label",Texts.get_text("un_perro"))
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(.24,.5,.8)*size
		shape.shape = box
		shape.position = Vector3(0,.33,-.08)*size
		bodyc.add_child(shape)
		add_child(bodyc)
	for id in parts: parts[id].mesh = parts[id].get_meta("st").commit()
	var start = target_spot()
	position = start
	heading = walker.rotation.y

func part(id: String, pivot: Vector3, material: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	node.set_meta("st",st)
	node.material_override = material
	node.position = pivot
	add_child(node)
	parts[id] = node
	return node

func blob(node: MeshInstance3D, center: Vector3, dims: Vector3, color: Color, tilt = 0.0) -> void:
	var st: SurfaceTool = node.get_meta("st")
	var basis = Basis(Vector3.RIGHT,tilt)
	var rings = 6
	var segments = 10
	for r in rings:
		for s in segments:
			var quad = []
			for k in [[0,0],[1,0],[1,1],[0,1]]:
				var v = PI*float(r+k[0])/rings
				var u = TAU*float(s+k[1])/segments
				var n = Vector3(sin(v)*cos(u),cos(v),sin(v)*sin(u))
				quad.append([center+basis*(n*dims*.5),(basis*(n/dims)).normalized()])
			for idx in [0,1,2,0,2,3]:
				st.set_color(color)
				st.set_normal(quad[idx][1])
				st.add_vertex(quad[idx][0])

# Where the dog wants to be: at the owner's right, a little behind; in front of a bench seat.
func target_spot() -> Vector3:
	var b: Basis = walker.global_basis
	if walker.state == "SENTADO" or walker.state == "LEVANTANDO":
		return walker.global_position+b*Vector3(.35,0,-.75)
	return walker.global_position+b*Vector3(.42,0,.15)

func update(dt: float) -> void:
	if walker == null: return
	clock += dt
	var walking = walker.state == "CAMINANDO"
	var goal = target_spot()
	if not walking and walker.state == "DETENIDO":
		# Sniffing around within the leash.
		wander_t -= dt
		if wander_t <= 0:
			wander_t = rng.randf_range(1.5,4.0)
			wander = Vector3(rng.randf_range(-.6,.6),0,rng.randf_range(-.6,.6))
		goal += wander
	var to = goal-position
	to.y = 0
	var speed = clampf(to.length()*2.2,0.0,1.9)
	if to.length() < .05: speed = 0.0
	var desired = to.normalized()*speed if to.length() > .001 else Vector3.ZERO
	velocity = velocity.move_toward(desired,dt*3.0)
	position += velocity*dt
	position.y = 0
	var v = velocity.length()
	if v > .08: heading = lerp_angle(heading,atan2(-velocity.x,-velocity.z),minf(1.0,dt*6))
	elif walker.state == "SENTADO": heading = lerp_angle(heading,walker.rotation.y+PI*.5,minf(1.0,dt*2))
	rotation.y = heading
	phase += dt*v*9.0/size
	sniff = move_toward(sniff,1.0 if (not walking and v < .3 and walker.state == "DETENIDO") else 0.0,dt*1.5)
	lie = move_toward(lie,1.0 if walker.state == "SENTADO" and walker.seat > .9 and v < .1 else 0.0,dt*.8)
	animate(v)
	var hand: Vector3 = walker.global_transform*walker.rig.get_bone_global_pose(walker.bones["mano.I"]).origin
	var collar = global_transform*(Vector3(0,.5,-.3)*size)
	collar.y -= lie*.2*size
	var mid = (hand+collar)*.5
	var d = collar-hand
	leash.global_transform = Transform3D(Basis(Quaternion(Vector3.UP,d.normalized())).scaled(Vector3(1,d.length(),1)),mid)

func animate(v: float) -> void:
	var trot = clampf(v/.6,0,1)
	var swing = sin(phase)*.55*trot
	var down = lie*.24*size
	parts["pata.DI"].rotation.x = swing
	parts["pata.TD"].rotation.x = swing
	parts["pata.DD"].rotation.x = -swing
	parts["pata.TI"].rotation.x = -swing
	for id in ["pata.DI","pata.DD"]: parts[id].rotation.x = lerpf(parts[id].rotation.x,-1.35,lie)
	for id in ["pata.TI","pata.TD"]: parts[id].rotation.x = lerpf(parts[id].rotation.x,1.25,lie)
	for id in ["pata.DI","pata.DD","pata.TI","pata.TD"]: parts[id].position.y = .34*size-down*.6
	var bob = absf(sin(phase))*.02*trot
	parts.cuerpo.position.y = .4*size+bob-down
	parts.cabeza.position.y = .55*size+bob-down-.18*sniff*size
	parts.cabeza.rotation.x = -.7*sniff+.05*sin(phase*.5)
	parts.cabeza.rotation.y = .25*sin(clock*1.1)*(sniff+lie*.5)
	parts.cola.position.y = .47*size+bob-down
	parts.cola.rotation.y = sin(clock*12.0)*(.5 if v < .3 else .2)
