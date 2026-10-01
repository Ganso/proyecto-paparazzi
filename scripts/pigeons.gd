class_name Pigeons
extends Node3D
# Flocks of pigeons (docs/futuro/19_VIDA_EN_EL_PARQUE.md §4): they walk and peck on the lawns,
# hop away from people, fly off to the trees when a runner comes and gather around anyone
# tossing crumbs from a bench. Visual only: no colliders, so scoring never sees them. Three
# MultiMeshes (body, head, wings) draw every bird in three draw calls.

const FLOCK_HOMES = [Vector2(80.0, 5.55), Vector2(262.0, 5.55)]   # (azimuth °, radius m): lawn ring 5.1–6.0
const PER_FLOCK = 9
var homes: Array = FLOCK_HOMES        # (azimuth, radius) of each flock; the big park sets its own
const WALK_SPEED = .22
var rng = RandomNumberGenerator.new()
var birds: Array[Dictionary] = []
var flocks: Array[Dictionary] = []
var body_mm: MultiMesh
var head_mm: MultiMesh
var wing_mm: MultiMesh
# At night pigeons roost in the trees (main.gd sets it from the time of day).
var night = false

static func polar(theta: float, r: float) -> Vector3:
	return Vector3(sin(deg_to_rad(theta))*r,0,-cos(deg_to_rad(theta))*r)

func build(detail = "hd") -> void:
	# Desktop only: the Android scene (lo) is already at its 100.000-triangle budget.
	if detail != "hd": return
	rng.seed = 4242
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = .8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED   # the left wing is the right one mirrored
	body_mm = add_multimesh(body_mesh(),material,PER_FLOCK*homes.size())
	head_mm = add_multimesh(head_mesh(),material,PER_FLOCK*homes.size())
	wing_mm = add_multimesh(wing_mesh(),material,PER_FLOCK*homes.size()*2)
	for f in homes.size():
		var home = polar(homes[f].x,homes[f].y)
		flocks.append({"home":home,"center":home,"state":"suelo","timer":0.0,"feeder":null,"next":"suelo"})
		for i in PER_FLOCK:
			var pos = home+Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))*.9
			var tone = rng.randf_range(.8,1.15)
			birds.append({"flock":f,"pos":pos,"yaw":rng.randf()*TAU,"target":pos,"wait":rng.randf_range(0,3),
				"peck":0.0,"peck_t":rng.randf_range(1,4),"hop":0.0,"flap":0.0,"air":0.0,"from":pos,"to":pos,
				"fly_t":0.0,"fly_len":1.0,"phase":rng.randf()*TAU,"tint":Color(tone,tone,tone*1.02)})
	for i in birds.size():
		body_mm.set_instance_color(i,birds[i].tint)
		head_mm.set_instance_color(i,birds[i].tint)
		wing_mm.set_instance_color(i*2,birds[i].tint)
		wing_mm.set_instance_color(i*2+1,birds[i].tint)
	update(0.0,[])

func add_multimesh(mesh: Mesh, material: Material, count: int) -> MultiMesh:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	add_child(node)
	return mm

# ---- Geometry (bird facing -Z, feet at y = 0, about 0.3 m long and 0.2 m tall) ----
func blob(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, rings = 6, segments = 10, tilt = 0.0) -> void:
	var basis = Basis(Vector3.RIGHT,tilt)
	for r in rings:
		for s in segments:
			var quad = []
			for k in [[0,0],[1,0],[1,1],[0,1]]:
				var v = PI*float(r+k[0])/rings
				var u = TAU*float(s+k[1])/segments
				var n = Vector3(sin(v)*cos(u),cos(v),sin(v)*sin(u))
				quad.append([center+basis*(n*size*.5),(basis*(n/size)).normalized()])
			for idx in [0,1,2,0,2,3]:
				st.set_color(color)
				st.set_normal(quad[idx][1])
				st.add_vertex(quad[idx][0])

func body_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	blob(st,Vector3(0,.115,0),Vector3(.12,.12,.25),Color("78808b"),7,12,-.18)
	blob(st,Vector3(0,.175,-.09),Vector3(.058,.095,.058),Color("5f716d"),5,10)        # iridescent neck
	blob(st,Vector3(0,.1,.15),Vector3(.09,.025,.14),Color("5d6269"),3,8,.25)       # tail
	blob(st,Vector3(0,.108,.215),Vector3(.092,.02,.03),Color("2e3136"),3,8,.25)    # dark tail band
	for x in [-.025,.025]:
		blob(st,Vector3(x,.03,-.01),Vector3(.014,.06,.014),Color("c96a6a"),3,6)     # legs
		blob(st,Vector3(x,.005,-.03),Vector3(.02,.01,.05),Color("c96a6a"),2,6)
	return st.commit()

func head_mesh() -> Mesh:
	# Pivot at the base of the neck, so pecking is a rotation about X.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	blob(st,Vector3(0,.045,-.02),Vector3(.055,.056,.064),Color("6c7580"),5,10)
	blob(st,Vector3(0,.04,-.062),Vector3(.014,.012,.03),Color("3a3434"),2,6)
	blob(st,Vector3(0,.047,-.047),Vector3(.02,.012,.012),Color("e8e4dc"),2,6)       # cere
	for x in [-.022,.022]: blob(st,Vector3(x,.053,-.035),Vector3(.012,.012,.012),Color("d9722a"),2,6)
	return st.commit()

func wing_mesh() -> Mesh:
	# Right wing, hinged at the shoulder (origin), extending +X and back.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	blob(st,Vector3(.1,0,.035),Vector3(.21,.02,.09),Color("9aa1a9"),3,10)
	blob(st,Vector3(.08,-.004,.05),Vector3(.12,.02,.025),Color("3a3e44"),2,8)       # wing bars
	blob(st,Vector3(.19,-.002,.05),Vector3(.1,.016,.07),Color("4a4f56"),2,8)        # primaries
	return st.commit()

# ---- Behaviour ----
func update(dt: float, people: Array, dogs: Array = []) -> void:
	if body_mm == null: return
	# Dogs make the birds hop away too (walk_bird only needs a position).
	if not dogs.is_empty(): people = people+dogs
	for f in flocks.size():
		update_flock(f,dt,people)
	for i in birds.size():
		var b = birds[i]
		var flock = flocks[b.flock]
		if flock.state == "suelo": walk_bird(b,flock,dt,people)
		else: fly_bird(b,flock,dt)
		write(i,b)

func update_flock(f: int, dt: float, people: Array) -> void:
	var flock = flocks[f]
	flock.timer -= dt
	# Crumbs: the nearest flock goes to someone tossing them from a bench.
	var feeder = null
	for p in people:
		if "activity" in p and p.activity == "palomas" and p.state == "SENTADO" and p.act_w > .5:
			var spot = p.position+p.global_basis*Vector3(0,0,-.85)
			var nearest = true
			for g in flocks.size():
				if g != f and flocks[g].center.distance_to(spot) < flock.center.distance_to(spot) and flocks[g].feeder == null: nearest = false
			if nearest and (flock.feeder == null or flock.feeder == p): feeder = p
	if night:
		if flock.state == "suelo":
			flock.feeder = null
			take_off(flock,roost(flock),"posada")
		elif flock.state == "posada": flock.timer = 5.0
		return
	match flock.state:
		"suelo":
			# A runner going by scares the whole flock only now and then (rolled once per pass);
			# otherwise the birds in the way just hop aside.
			var scared = false
			var passing: Dictionary = flock.get("passing",{})
			for p in people:
				if not ("runner" in p) or not p.runner: continue
				var d = Vector2(p.position.x-flock.center.x,p.position.z-flock.center.z).length()
				if d < 2.2 and p.state == "CAMINANDO" and not passing.has(p):
					passing[p] = true
					if rng.randf() < .3: scared = true
				elif d > 4.0: passing.erase(p)
			flock.passing = passing
			if scared:
				take_off(flock,roost(flock),"posada")
			elif feeder != null and flock.feeder == null:
				flock.feeder = feeder
				take_off(flock,feeder.position+feeder.global_basis*Vector3(0,0,-.85),"suelo")
			elif feeder == null and flock.feeder != null:
				flock.feeder = null
				take_off(flock,flock.home,"suelo")
		"posada":
			if flock.timer <= 0: take_off(flock,flock.feeder.position+flock.feeder.global_basis*Vector3(0,0,-.85) if is_instance_valid(flock.feeder) and flock.feeder.activity == "palomas" else flock.home,"suelo")
		"vuelo":
			if flock.timer <= 0:
				flock.state = flock.next
				flock.timer = rng.randf_range(8,16)

# A perch in the tree curtain behind the lawn.
func roost(flock: Dictionary) -> Vector3:
	return Vector3(flock.home.x,0,flock.home.z).normalized()*rng.randf_range(13.5,15.5)+Vector3.UP*rng.randf_range(4.5,6.5)

# Jump straight to the roost (a session that starts at night, or a capture).
func settle_night() -> void:
	for flock in flocks:
		var perch = roost(flock)
		flock.center = perch
		flock.state = "posada"
		flock.timer = 5.0
		flock.feeder = null
		flock.next = "posada"
		for b in birds:
			if flocks[b.flock] == flock:
				b.pos = perch+Vector3(rng.randf_range(-1.5,1.5),rng.randf_range(-.4,.4),rng.randf_range(-1.5,1.5))
				b.from = b.pos
				b.to = b.pos
				b.fly_t = 1.0
				b.fly_len = 1.0
				b.air = 0.0

func take_off(flock: Dictionary, destination: Vector3, next: String) -> void:
	var start = flock.center
	flock.center = destination
	flock.state = "vuelo"
	flock.next = next
	var longest = 0.0
	for b in birds:
		if flocks[b.flock] != flock: continue
		b.from = b.pos
		var scatter = Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))*(.8 if next == "suelo" else 1.6)
		b.to = destination+scatter
		if next == "suelo": b.to.y = 0
		b.fly_t = -rng.randf_range(0,.5)
		b.fly_len = maxf(1.2,b.from.distance_to(b.to)/rng.randf_range(4.5,6.0))
		b.target = b.to
		longest = maxf(longest,b.fly_len-b.fly_t)
	flock.timer = longest
	var _unused = start

func walk_bird(b: Dictionary, flock: Dictionary, dt: float, people: Array) -> void:
	b.air = move_toward(b.air,0.0,dt*2)
	b.flap = move_toward(b.flap,0.0,dt*3)
	var flee = Vector3.ZERO
	for p in people:
		var away = Vector3(b.pos.x-p.position.x,0,b.pos.z-p.position.z)
		if away.length() < .75: flee += away.normalized()*(.75-away.length())
	if flee.length() > .01:
		b.target = b.pos+flee.normalized()*.6
		b.wait = 0.0
		if b.hop <= 0: b.hop = .35
	b.wait -= dt
	var to = b.target-b.pos
	to.y = 0
	if to.length() < .03:
		if b.wait <= 0:
			var feeding = flock.feeder != null
			b.target = flock.center+Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))*(.55 if feeding else .9)
			b.target.y = 0
			b.wait = rng.randf_range(.5,2.5) if feeding else rng.randf_range(1,5)
	else:
		var speed = WALK_SPEED*(2.6 if b.hop > 0 else 1.0)
		b.pos += to.normalized()*minf(to.length(),speed*dt)
		b.yaw = lerp_angle(b.yaw,atan2(-to.x,-to.z),minf(1.0,dt*8))
	b.pos.y = 0
	if b.hop > 0:
		b.hop -= dt
		b.pos.y = sin(PI*clampf(b.hop/.35,0,1))*.07
	b.peck_t -= dt
	if b.peck_t <= 0 and to.length() < .03:
		b.peck = .45
		b.peck_t = rng.randf_range(.8,3.0) if flock.feeder != null else rng.randf_range(1.5,5.0)
	b.peck = maxf(0.0,b.peck-dt)
	b.phase += dt*(9.0 if to.length() > .03 else 0.0)

func fly_bird(b: Dictionary, flock: Dictionary, dt: float) -> void:
	b.fly_t += dt
	var u = clampf(b.fly_t/b.fly_len,0,1)
	if b.fly_t < 0: u = 0
	var lift = sin(PI*u)*clampf(b.from.distance_to(b.to)*.25,.8,3.0)
	var p = b.from.lerp(b.to,smoothstep(0,1,u))
	p.y += lift
	var d = b.to-b.from
	if d.length() > .01 and u < 1: b.yaw = lerp_angle(b.yaw,atan2(-d.x,-d.z),minf(1.0,dt*6))
	b.pos = p
	b.air = move_toward(b.air,1.0 if u > 0 and u < 1 else 0.0,dt*4)
	b.flap += dt*(22.0 if u < .85 else 12.0)
	if u >= 1 and flock.next == "suelo": b.pos.y = 0

func write(i: int, b: Dictionary) -> void:
	var basis = Basis(Vector3.UP,b.yaw)
	var bob = sin(b.phase)*.012
	var pitch = -.25*b.air
	var body_basis = basis*Basis(Vector3.RIGHT,pitch)
	var origin: Vector3 = b.pos
	body_mm.set_instance_transform(i,Transform3D(body_basis,origin))
	var peck = sin(PI*clampf(b.peck/.45,0,1))*1.1
	var neck = body_basis*Vector3(0,.2,-.105+bob)
	head_mm.set_instance_transform(i,Transform3D(body_basis*Basis(Vector3.RIGHT,-peck),origin+neck))
	# Right wing basis (the left one is its mirror image): folded along the flank, or spread and
	# beating in flight.
	var beat = sin(b.flap)*.9
	var fold_x = Vector3(.12,.06,1).normalized()
	var fold_z = (Vector3(.2,-1,0)-fold_x*Vector3(.2,-1,0).dot(fold_x)).normalized()
	var folded = Basis(fold_x,fold_z.cross(fold_x),fold_z)
	var spread = Basis(Vector3.BACK,beat+.1)*Basis(Vector3.UP,-.15)
	var wing = Basis(folded.get_rotation_quaternion().slerp(spread.get_rotation_quaternion(),b.air))
	var mirror = Basis.from_scale(Vector3(-1,1,1))
	var shoulder = Vector3(.045,.155,-.05)
	wing_mm.set_instance_transform(i*2,Transform3D(body_basis*wing,origin+body_basis*shoulder))
	wing_mm.set_instance_transform(i*2+1,Transform3D(body_basis*mirror*wing,origin+body_basis*(mirror*shoulder)))

func triangle_count() -> int:
	var total = 0
	if body_mm == null: return 0
	for mm in [body_mm,head_mm,wing_mm]:
		total += mm.mesh.surface_get_array_len(0)/3*mm.instance_count
	return total
