extends Node3D
# Ducks on the pond of the meadow (docs/futuro/19_VIDA_EN_EL_PARQUE.md §9): three mallards swim
# round the fountain, bob on the water and dabble now and then; at night they stop and tuck the
# head back. Ambient like the pigeons and the extras: beyond the fence, desktop (hd) only, no
# colliders, never a target and never part of the score.
const COUNT = 3
const PATH = Vector2(2.45,1.6)      # semi-axes of their lap, inside the water (3.05 × 1.85 m)
const WATER = .2                    # height of the water above the ground
var ducks: Array[Dictionary] = []
var clock = 0.0
var night = false
var triangles = 0

func build(pond: Vector3, heading: float) -> void:
	position = pond
	rotation.y = heading
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = .8
	var rng = RandomNumberGenerator.new()
	rng.seed = 4107
	for i in COUNT:
		var drake = i != 1          # two drakes and a hen
		var body = MeshInstance3D.new()
		body.mesh = body_mesh(drake)
		body.material_override = material
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
		var head = MeshInstance3D.new()
		head.mesh = head_mesh(drake)
		head.material_override = material
		head.position = Vector3(0,.085,-.115)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(head)
		for mesh in [body.mesh,head.mesh]: triangles += mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3
		ducks.append({"body":body,"head":head,"angle":i*TAU/COUNT+rng.randf_range(-.35,.35),"speed":rng.randf_range(.17,.23),"pace":1.0,
			"lane":rng.randf_range(.9,1.06),"dabble":0.0,"next":rng.randf_range(3,9),"seed":rng.randf_range(0,TAU)})
	update(0.0)

static func blob(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, rings = 5, segments = 10, tilt = 0.0) -> void:
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

# Forward is −z; the origin floats at the water line.
func body_mesh(drake: bool) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flank = Color("b9b4a8") if drake else Color("8d6f4c")
	blob(st,Vector3(0,.035,0),Vector3(.17,.13,.33),flank,6,12)
	blob(st,Vector3(0,.045,-.1),Vector3(.14,.12,.15),Color("5b3a2b") if drake else Color("7c5f40"),5,10)   # breast
	blob(st,Vector3(0,.085,.03),Vector3(.13,.05,.22),Color("8b8478") if drake else Color("6f573a"),4,10)   # folded wings
	blob(st,Vector3(0,.075,.165),Vector3(.08,.035,.1),Color("26282b") if drake else Color("5d4a33"),3,8,.5) # tail, tipped up
	return st.commit()

# Pivot at the base of the neck: dabbling is a rotation about X.
func head_mesh(drake: bool) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head = Color("1f5a3c") if drake else Color("8d6f4c")
	blob(st,Vector3(0,.03,0),Vector3(.055,.09,.055),head,4,8)                                 # neck
	if drake: blob(st,Vector3(0,.012,0),Vector3(.06,.014,.06),Color("e9e6dc"),2,8)             # white collar
	blob(st,Vector3(0,.085,-.012),Vector3(.072,.066,.085),head,5,10)
	blob(st,Vector3(0,.075,-.07),Vector3(.036,.017,.06),Color("d6a21e") if drake else Color("b8762a"),3,8)   # bill
	for x in [-.03,.03]: blob(st,Vector3(x,.095,-.03),Vector3(.01,.01,.01),Color("15130f"),2,6)
	return st.commit()

func update(dt: float) -> void:
	clock += dt
	for d in ducks:
		# At night they drift to a stop; by day they paddle on, slower while dabbling.
		d.pace = move_toward(d.pace,0.0 if night else (.35 if d.dabble > 0 else 1.0),dt*.5)
		d.angle += d.speed*d.pace*dt
		var p = Vector3(cos(d.angle)*PATH.x,0,sin(d.angle)*PATH.y)*d.lane
		var tangent = Vector3(-sin(d.angle)*PATH.x,0,cos(d.angle)*PATH.y)
		var body: MeshInstance3D = d.body
		body.position = p+Vector3.UP*(WATER+sin(clock*1.9+d.seed)*.006)
		body.rotation = Vector3(sin(clock*1.3+d.seed)*.03,atan2(-tangent.x,-tangent.z),sin(clock*1.7+d.seed*2.0)*.04)
		d.next -= dt
		if d.next <= 0 and not night:
			d.dabble = 1.4
			d.next = 6.0+fmod(d.seed*7.3+clock,7.0)
		d.dabble = maxf(0.0,d.dabble-dt)
		var dip = sin(PI*clampf(d.dabble/1.4,0,1))
		var head: MeshInstance3D = d.head
		# Dabbling: bill down into the water. Asleep: head turned back over the wing.
		var asleep = 1.0-d.pace if night else 0.0
		head.rotation = Vector3(-dip*1.25,asleep*2.5,0)
		head.position = Vector3(0,.085-asleep*.02,-.115+asleep*.03)

func triangle_count() -> int:
	return triangles
