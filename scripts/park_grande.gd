extends "res://scripts/park.gd"
# The big park (docs/futuro/01 Alternativa C, «parque grande»): a 120 × 90 m fenced park with a
# network of paths to walk freely: central plaza with the fountain, a tree-lined avenue north to
# south, east and west paths, four diagonals, a ring path inside the fence, the bandstand on a
# small plaza to the north-west and a playground to the south-east. It reuses the environment,
# lighting, weather, Blender props and ground textures of the classic park (park.gd); only the
# layout changes. Pedestrians walk the path graph (`nodes`, `edges`; scripts/crowd_graph.gd).
# Origin: centre of the plaza. North = −Z (azimuth 0°, as in the classic park).

const HALF = Vector2(60,45)           # fence (x, z half extents)
const RING = Vector2(52,37)           # ring path centre line
const PLAZA_R = 10.0
const BANDSTAND_POS = Vector3(-26,0,-31)
const PLAYGROUND_POS = Vector3(24,0,30)
const PLAYGROUND_R = 5.0

# Path graph: node positions and edges [a, b, width]. Walkers keep to the right of an edge.
var nodes = {}
var edges: Array = []
var neighbours = {}
# Paved strips (for the ground mesh, the grass and the lawn tests): [a, b, width, layer].
var strips: Array = []
var discs: Array = []                 # [centre, radius, layer]
var view_point = Vector3.ZERO         # where the photographer is (lamp shadows follow it)
var shadow_timer = 0.0

func ring_point(x: float, z: float) -> Vector3:
	return Vector3(x,0,z)

func build_layout() -> void:
	var ground = StaticBody3D.new()
	ground.set_meta("label",Texts.get_text("el_suelo"))
	add_child(ground)
	var ground_collision = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(260,.04,220)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -.025
	ground.add_child(ground_collision)
	define_paths()
	build_ground()
	var rng = RandomNumberGenerator.new()
	rng.seed = 1234
	if ParkAssets.available("torre"): build_skyline(rng)
	# Landmarks: the fountain in the plaza, the bandstand on its own small plaza.
	landmark("estanque",Texts.get_text("una_fuente"),Vector3.ZERO,0.0)
	add_fountain_jet(Vector3.ZERO)
	water_material.set_shader_parameter("center",Vector2(0,0))
	spray_material.set_shader_parameter("center",Vector2(0,0))
	landmark("quiosco",Texts.get_text("un_quiosco"),BANDSTAND_POS,atan2(-BANDSTAND_POS.x,-BANDSTAND_POS.z)+PI)
	meadow_light(BANDSTAND_POS+Vector3.UP*2.8,3.0,7.0)
	build_playground()
	build_fence()
	build_trees(rng)
	build_lamps()
	build_benches()

# ---- Paths and graph ----
func add_node(id: String, pos: Vector3) -> void:
	nodes[id] = pos
	neighbours[id] = []

func add_edge(a: String, b: String, width: float, layer: String, paved = true) -> void:
	edges.append([a,b,width])
	neighbours[a].append(b)
	neighbours[b].append(a)
	if paved: strips.append([nodes[a],nodes[b],width,GROUND_LAYERS.find(layer)])

func define_paths() -> void:
	var corners = {"NE":Vector3(RING.x,0,-RING.y),"SE":Vector3(RING.x,0,RING.y),"SW":Vector3(-RING.x,0,RING.y),"NW":Vector3(-RING.x,0,-RING.y)}
	var mids = {"N":Vector3(0,0,-RING.y),"E":Vector3(RING.x,0,0),"S":Vector3(0,0,RING.y),"W":Vector3(-RING.x,0,0)}
	for k in corners: add_node("C"+k,corners[k])
	for k in mids: add_node("R"+k,mids[k])
	# Plaza: one node where each radial meets it, joined round the fountain.
	var order = ["N","NE","E","SE","S","SW","W","NW"]
	for k in order:
		var far = mids[k] if mids.has(k) else corners[k]
		add_node("P"+k,far.normalized()*(PLAZA_R-1.8))
	for i in order.size():
		add_edge("P"+order[i],"P"+order[(i+1)%order.size()],2.4,"losas",false)
	discs.append([Vector3.ZERO,PLAZA_R,GROUND_LAYERS.find("losas")])
	# Radials: avenue N–S, paths E–W, four diagonals (split for the bandstand and playground spurs).
	add_edge("PN","RN",4.0,"adoquin")
	add_edge("PS","RS",4.0,"adoquin")
	add_edge("PE","RE",3.0,"asfalto")
	add_edge("PW","RW",3.0,"asfalto")
	add_edge("PNE","CNE",2.6,"asfalto")
	add_edge("PSW","CSW",2.6,"asfalto")
	var nw_dir = corners["NW"].normalized()
	var db = nw_dir*(BANDSTAND_POS.x/nw_dir.x)
	add_node("DB",db)
	add_edge("PNW","DB",2.6,"asfalto")
	add_edge("DB","CNW",2.6,"asfalto")
	add_node("SB",BANDSTAND_POS+Vector3(0,0,6.2))
	add_edge("DB","SB",2.4,"losas")
	discs.append([BANDSTAND_POS,6.5,GROUND_LAYERS.find("losas")])
	var se_dir = corners["SE"].normalized()
	var dp = se_dir*(PLAYGROUND_POS.x/se_dir.x)
	add_node("DP",dp)
	add_edge("PSE","DP",2.6,"asfalto")
	add_edge("DP","CSE",2.6,"asfalto")
	add_node("SP",PLAYGROUND_POS+Vector3(0,0,-PLAYGROUND_R-.6))
	add_edge("DP","SP",2.4,"losas")
	discs.append([PLAYGROUND_POS,PLAYGROUND_R,GROUND_LAYERS.find("grava")])
	# Ring path inside the fence.
	var loop = ["CNE","RE","CSE","RS","CSW","RW","CNW","RN"]
	for i in loop.size(): add_edge(loop[i],loop[(i+1)%loop.size()],3.0,"grava")
	for k in corners: discs.append([corners[k],2.2,GROUND_LAYERS.find("grava")])
	for k in mids: discs.append([mids[k],2.6,GROUND_LAYERS.find("grava")])

# Distance from a point to the nearest paved surface (≤ 0 on a path or a plaza).
func path_distance(p: Vector3) -> float:
	var q = Vector3(p.x,0,p.z)
	var best = INF
	for s in strips:
		var c = Geometry3D.get_closest_point_to_segment(q,s[0],s[1])
		best = minf(best,c.distance_to(q)-s[2]*.5)
	for d in discs: best = minf(best,d[0].distance_to(q)-d[1])
	return best

func inside_fence(p: Vector3, margin = 0.0) -> bool:
	return absf(p.x) < HALF.x-margin and absf(p.z) < HALF.y-margin

# ---- Ground: a lawn grid and the paved strips and discs on top (textured in hd) ----
func build_ground() -> void:
	# Lawn tiles of 20 m with 2 m cells inside and around the fence (the baked contact occlusion
	# needs vertices), then a coarse skirt out to the skyline.
	for tx in range(-4,4):
		for tz in range(-3,3):
			var origin = Vector3(tx*20.0,0,tz*20.0)
			ground_patch(origin,Vector2(20,20),10,Color("81925c"),GROUND_LAYERS.find("cesped"),0.0)
	for t in [[Vector3(-200,0,-200),Vector2(400,140)],[Vector3(-200,0,60),Vector2(400,140)],[Vector3(-200,0,-60),Vector2(120,120)],[Vector3(80,0,-60),Vector2(120,120)]]:
		ground_patch(t[0],t[1],4,Color("7d8a5a"),GROUND_LAYERS.find("cesped"),-.01)
	for s in strips: strip(s[0],s[1],s[2],s[3])
	for d in discs: disc(d[0],d[1],d[2])

func ground_patch(origin: Vector3, size: Vector2, cells: int, color: Color, layer: int, y: float) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre = origin+Vector3(size.x*.5,0,size.y*.5)
	for i in cells:
		for j in cells:
			var x0 = origin.x+size.x*i/cells
			var x1 = origin.x+size.x*(i+1)/cells
			var z0 = origin.z+size.y*j/cells
			var z1 = origin.z+size.y*(j+1)/cells
			var pts = [Vector3(x0,y,z0),Vector3(x1,y,z0),Vector3(x1,y,z1),Vector3(x0,y,z1)]
			for k in [0,1,2,0,2,3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[k]-centre)
	st.index()
	var piece = prop(st.commit(),centre,color)
	piece.set_meta("ground",true)
	if layer >= 0: piece.set_meta("ground_layer",layer)

func strip(a: Vector3, b: Vector3, width: float, layer: int) -> void:
	var dir = (b-a).normalized()
	var side = Vector3(-dir.z,0,dir.x)*width*.5
	var length = a.distance_to(b)
	var steps = maxi(1,int(ceil(length/1.5)))
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre = (a+b)*.5
	for i in steps:
		var p0 = a+dir*length*i/steps
		var p1 = a+dir*length*(i+1)/steps
		for k in 2:
			var s0 = -1.0+k
			var s1 = s0+1.0
			var pts = [p0+side*s0,p1+side*s0,p1+side*s1,p0+side*s1]
			# Wind the triangles so they face up whatever the direction of the strip.
			var order = [0,2,1,0,3,2] if (pts[2]-pts[0]).cross(pts[1]-pts[0]).y < 0 else [0,1,2,0,2,3]
			for m in order:
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[m]+Vector3.UP*.006-centre)
	st.index()
	var piece = prop(st.commit(),centre,Color("b8b29c"))
	piece.set_meta("ground",true)
	piece.set_meta("ground_layer",layer)

func disc(centre: Vector3, radius: float, layer: int) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings = maxi(2,int(radius/1.2))
	var segments = 48
	for r in rings:
		var r0 = radius*r/rings
		var r1 = radius*(r+1)/rings
		for i in segments:
			var a0 = TAU*i/segments
			var a1 = TAU*(i+1)/segments
			var pts = [Vector3(sin(a0)*r0,.008,cos(a0)*r0),Vector3(sin(a0)*r1,.008,cos(a0)*r1),Vector3(sin(a1)*r1,.008,cos(a1)*r1),Vector3(sin(a1)*r0,.008,cos(a1)*r0)]
			for m in [0,2,1,0,3,2]:
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[m])
	st.index()
	var piece = prop(st.commit(),centre,Color("c5bdac"))
	piece.set_meta("ground",true)
	piece.set_meta("ground_layer",layer)

# ---- Grass: on the lawns inside and around the fence, not on paths ----
func grass_samples(rng: RandomNumberGenerator, _bandstand: Vector3, _pond: Vector3) -> Dictionary:
	var buckets = {}
	var area = Rect2(-HALF.x-6,-HALF.y-6,(HALF.x+6)*2,(HALF.y+6)*2)
	var count = int(area.size.x*area.size.y*5.0)
	for n in count:
		var pos = Vector3(rng.randf_range(area.position.x,area.end.x),0,rng.randf_range(area.position.y,area.end.y))
		if path_distance(pos) < .25: continue
		if pos.distance_to(BANDSTAND_POS) < 3.0: continue
		var key = sector_key(pos)
		if not buckets.has(key): buckets[key] = []
		var basis = Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(1,rng.randf_range(.7,1.25),1)*rng.randf_range(.8,1.2))
		var shade = rng.randf_range(.82,1.12)
		buckets[key].append([Transform3D(basis,pos),Color(shade*rng.randf_range(.95,1.08),shade,shade*rng.randf_range(.85,1.0))])
	return buckets

# Merge sectors: a 20 m grid (the classic polar sectors are centred on the photographer).
func sector_key(pos: Vector3) -> String:
	return "%d:%d" % [int(floor(pos.x/20.0)),int(floor(pos.z/20.0))]

# ---- Fence: straight runs of the classic bays, with pillars ----
func build_fence() -> void:
	var bay = 1.117
	var sides = [[Vector3(-HALF.x,0,-HALF.y),Vector3(HALF.x,0,-HALF.y)],[Vector3(HALF.x,0,-HALF.y),Vector3(HALF.x,0,HALF.y)],
		[Vector3(HALF.x,0,HALF.y),Vector3(-HALF.x,0,HALF.y)],[Vector3(-HALF.x,0,HALF.y),Vector3(-HALF.x,0,-HALF.y)]]
	var fence_assets = ParkAssets.available("verja_tramo")
	for side in sides:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var dir = (b-a).normalized()
		var count = int(a.distance_to(b)/bay)
		var rot = atan2(-dir.z,dir.x)
		# One collider per side (thin box), the visible bays from Blender.
		var wall = StaticBody3D.new()
		wall.collision_layer = 2
		wall.set_meta("label",Texts.get_text("una_verja"))
		add_child(wall)
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(a.distance_to(b),1.2,.12)
		shape.shape = box
		shape.position = (a+b)*.5+Vector3.UP*.6
		shape.rotation.y = rot
		wall.add_child(shape)
		for i in count:
			var pos = a+dir*(i+.5)*bay
			if fence_assets:
				var node = Node3D.new()
				node.position = pos
				node.rotation.y = rot
				add_child(node)
				visual("verja_tramo","",node)
				if i%8 == 0: visual("verja_pilar","",node)
			else:
				cube(Vector3(bay,.035,.035),pos+Vector3.UP*.8,Color("394844"))

# ---- Trees and bushes ----
var tree_spots: Array[Vector3] = []     # where the trees stand (perches for the pigeons)
func build_trees(rng: RandomNumberGenerator) -> void:
	var placed: Array[Vector3] = tree_spots
	var free_spot = func(pos: Vector3, clearance: float) -> bool:
		if path_distance(pos) < clearance: return false
		if pos.distance_to(BANDSTAND_POS) < 9.0 or pos.distance_to(PLAYGROUND_POS) < PLAYGROUND_R+2.5: return false
		for q in placed: if q.distance_to(pos) < 4.2: return false
		return true
	# The avenue: plane trees on both sides every 7 m.
	var n = 0
	for side in [-1.0,1.0]:
		for z in range(-35,36,7):
			if absf(z) < 13: continue
			var pos = Vector3(side*3.6,0,z)
			build_tree(0,pos,6000+n*13,rng.randf_range(1.05,1.2))
			placed.append(pos)
			n += 1
	# Groves: denser to the south-west, sparse in the north-east meadow.
	var quads = [[Rect2(4,-HALF.y+5,HALF.x-9,HALF.y-9),10],[Rect2(-HALF.x+4,4,HALF.x-8,HALF.y-8),34],[Rect2(-HALF.x+4,-HALF.y+4,HALF.x-8,HALF.y-8),18],[Rect2(4,4,HALF.x-8,HALF.y-8),16]]
	for q in quads:
		var rect: Rect2 = q[0]
		var target: int = q[1]
		var made = 0
		var tries = 0
		while made < target and tries < 900:
			tries += 1
			var pos = Vector3(rng.randf_range(rect.position.x,rect.end.x),0,rng.randf_range(rect.position.y,rect.end.y))
			if not free_spot.call(pos,3.4): continue
			build_tree(rng.randi_range(0,3),pos,7000+n*29,rng.randf_range(.95,1.3))
			placed.append(pos)
			n += 1
			made += 1
	# Bushes along the inside of the fence and at the foot of some trees.
	var bush_colors = [Color("4d6836"),Color("5c7a3d"),Color("3e5c32"),Color("688047")]
	var b = 0
	for i in 150:
		var t = i/150.0
		var perimeter = 2*(HALF.x*2+HALF.y*2)
		var d = t*perimeter
		var pos: Vector3
		var inset = 2.2+rng.randf_range(-.4,.6)
		if d < HALF.x*2: pos = Vector3(-HALF.x+d,0,-HALF.y+inset)
		elif d < HALF.x*2+HALF.y*2: pos = Vector3(HALF.x-inset,0,-HALF.y+(d-HALF.x*2))
		elif d < HALF.x*4+HALF.y*2: pos = Vector3(HALF.x-(d-HALF.x*2-HALF.y*2),0,HALF.y-inset)
		else: pos = Vector3(-HALF.x+inset,0,HALF.y-(d-HALF.x*4-HALF.y*2))
		if path_distance(pos) < 1.2: continue
		var radius = rng.randf_range(.55,1.0)
		var height = radius*rng.randf_range(1.5,2.1)
		bush(radius,height,pos+Vector3.UP*height*.45,bush_colors[b%4].lightened(snappedf(rng.randf_range(0,.12),.04)),b)
		b += 1
	# A belt of trees outside the fence closes the view; far rows only in hd (as the classic park).
	for i in 70:
		var t = i/70.0
		var perimeter = 2*(HALF.x*2+HALF.y*2)+16*4
		var d = t*perimeter
		var ex = HALF.x+6
		var ez = HALF.y+6
		var pos: Vector3
		if d < ex*2: pos = Vector3(-ex+d,0,-ez)
		elif d < ex*2+ez*2: pos = Vector3(ex,0,-ez+(d-ex*2))
		elif d < ex*4+ez*2: pos = Vector3(ex-(d-ex*2-ez*2),0,ez)
		else: pos = Vector3(-ex,0,ez-(d-ex*4-ez*2))
		pos += Vector3(rng.randf_range(-1.5,1.5),0,rng.randf_range(-1.5,1.5))
		hd_only = i%2 == 1
		build_tree(i%4,pos,8000+i*17,rng.randf_range(1.2,1.5))
	hd_only = false

# ---- Lamps along the paths and round the plaza ----
func build_lamps() -> void:
	var spots: Array[Vector3] = []
	# No lamp in front of a bench or beside it (two of the plaza's stood right before its benches):
	# the six of the plaza go between the benches, and any other within 2.2 m of one is dropped.
	var seats = bench_spots().map(func(b): return b[0])
	for k in 6:
		spots.append(Vector3(sin(k*TAU/6),0,-cos(k*TAU/6))*(PLAZA_R-.6))
	for e in edges:
		var a: Vector3 = nodes[e[0]]
		var b: Vector3 = nodes[e[1]]
		if a.length() < PLAZA_R and b.length() < PLAZA_R: continue
		var dir = (b-a).normalized()
		var side = Vector3(-dir.z,0,dir.x)
		var length = a.distance_to(b)
		var count = int(length/16.0)
		for i in count:
			var pos = a+dir*(length*(i+.5)/count)+side*(e[2]*.5+.55)*(1 if i%2 == 0 else -1)
			if pos.length() < PLAZA_R+1.0: continue
			if spots.any(func(q): return q.distance_to(pos) < 6.0): continue
			spots.append(pos)
	var clear: Array[Vector3] = []
	for q in spots:
		if not seats.any(func(b): return b.distance_to(q) < 2.2): clear.append(q)
	spots = clear
	for pos in spots:
		var root = Node3D.new()
		root.position = pos
		add_child(root)
		build_farola_mesh(root,true)
		var light = OmniLight3D.new()
		light.position = Vector3(0,2.69,0)
		light.shadow_enabled = false
		light.omni_range = 6.0
		light.light_color = Color("ffcd82")
		light.light_energy = 0.0
		root.add_child(light)
		lamps.append(light)

# Night shadows only for the lamps nearest the photographer (there are dozens).
func update_lamp_shadows() -> void:
	var limit = [0,3,6][int(Graphics.settings(current_graphics_preset).lamp_shadows)]
	var sorted = lamps.duplicate()
	sorted.sort_custom(func(a,b): return a.global_position.distance_squared_to(view_point) < b.global_position.distance_squared_to(view_point))
	for i in sorted.size():
		sorted[i].shadow_enabled = is_night and i < limit

func follow_view(pos: Vector3, dt: float) -> void:
	view_point = pos
	shadow_timer -= dt
	if shadow_timer <= 0:
		shadow_timer = 1.0
		if is_night: update_lamp_shadows()

# ---- Benches by the paths (two seats each, facing the path) ----
# Where the benches go: [position, facing] (also used to keep the lamps clear of them).
func bench_spots() -> Array:
	var spots = []
	# Round the plaza, facing the fountain.
	for k in 4:
		var a = k*TAU/4+TAU/8
		var pos = Vector3(sin(a),0,-cos(a))*(PLAZA_R-.35)
		spots.append([pos,-pos.normalized()])
	# Along the avenue and the east and west paths, alternating sides.
	for z in [-30,-20,20,30]:
		var side = 1.0 if (z/10)%2 == 0 else -1.0
		spots.append([Vector3(side*2.6,0,z),Vector3(-side,0,0)])
	for x in [-40,-24,24,40]:
		var side = 1.0 if (x/8)%2 == 0 else -1.0
		spots.append([Vector3(x,0,side*2.1),Vector3(0,0,-side)])
	# By the bandstand and the playground (parents watching).
	spots.append([BANDSTAND_POS+Vector3(4.2,0,4.2),Vector3(-1,0,-1).normalized()])
	spots.append([PLAYGROUND_POS+Vector3(-PLAYGROUND_R-.5,0,0),Vector3(1,0,0)])
	spots.append([PLAYGROUND_POS+Vector3(PLAYGROUND_R+.5,0,0),Vector3(-1,0,0)])
	return spots

func build_benches() -> void:
	for s in bench_spots():
		var pos: Vector3 = s[0]
		var face: Vector3 = s[1]
		var root = Node3D.new()
		root.position = pos
		root.rotation.y = atan2(-face.x,-face.z)
		add_child(root)
		benches.append({"pos":pos,"face":face,"occupied":false,"seats":[null,null],"root":root})
		collider_only = ParkAssets.available("banco")
		for x in [-.65,.65]:
			cube(Vector3(.07,.46,.48),Vector3(x,.23,.15),Color("2a3230"),Texts.get_text("un_banco"),root)
		for j in 3:
			cube(Vector3(1.65,.045,.11),Vector3(0,.47,j*.15),Color("8f6136"),Texts.get_text("un_banco"),root)
			cube(Vector3(1.65,.095,.045),Vector3(0,.66+j*.13,.4),Color("8f6136"),Texts.get_text("un_banco"),root)
		if collider_only:
			collider_only = false
			visual("banco","",root)
		# A bin beside each bench.
		var bin_pos = pos+root.basis*Vector3(1.25,0,.25)
		collider_only = ParkAssets.available("papelera")
		cylinder(.25,.7,bin_pos+Vector3.UP*.35,Color("425d57"),Texts.get_text("una_papelera"))
		if collider_only: visual("papelera","",self,Transform3D(Basis.IDENTITY,bin_pos))
		collider_only = false

# World position of seat 0/1 of a bench, and the spot in front where a walker stops to sit.
func seat_position(bench: Dictionary, slot: int) -> Vector3:
	var root: Node3D = bench.root
	return root.global_transform*Vector3((slot*2-1)*.42,0,.12)

func seat_front(bench: Dictionary, slot: int) -> Vector3:
	var root: Node3D = bench.root
	return root.global_transform*Vector3((slot*2-1)*.42,0,-.25-.33)

# ---- Playground: swings, slide and a sandpit (simple primitives with colliders) ----
func build_playground() -> void:
	var p = PLAYGROUND_POS
	var steel = Color("c2462f")
	var wood = Color("b5874f")
	# Swing frame.
	var sw = p+Vector3(-1.6,0,0)
	for x in [-1.5,1.5]:
		for z in [-.7,.7]:
			var leg = cylinder(.05,2.3,sw+Vector3(x,1.15,z*.55),steel,Texts.get_text("un_columpio"))
			leg.rotation.x = -z*.45
	var beam = cylinder(.055,3.1,sw+Vector3(0,2.2,0),steel,Texts.get_text("un_columpio"))
	beam.rotation.z = PI*.5
	# The left swing is built by extras.gd on desktop: it swings with a child on it.
	for x in ([.7] if detail == "hd" else [-.7,.7]):
		cube(Vector3(.45,.05,.2),sw+Vector3(x,.48,0),Color("303030"))
		for k in [-.18,.18]:
			cylinder(.008,1.7,sw+Vector3(x+k,1.35,0),Color("8a8a8a"))
	# Slide: ladder, platform and the chute.
	var sl = p+Vector3(2.0,0,.6)
	for x in [-.35,.35]:
		cylinder(.04,1.6,sl+Vector3(x,.8,-.8),steel,Texts.get_text("un_tobogan"))
		cylinder(.04,1.6,sl+Vector3(x,.8,-.2),steel,Texts.get_text("un_tobogan"))
	cube(Vector3(.8,.08,.7),sl+Vector3(0,1.55,-.5),wood,Texts.get_text("un_tobogan"))
	var chute = cube(Vector3(.55,.05,2.4),sl+Vector3(0,.85,.85),Color("e8c33a"),Texts.get_text("un_tobogan"))
	chute.rotation.x = .62      # down and away from the platform (it sloped the wrong way)
	for k in 5: cube(Vector3(.7,.04,.04),sl+Vector3(0,.3+k*.3,-.82),steel)
	# Sandpit border.
	for k in 8:
		var a = k*TAU/8
		# Eight boards round the sand, each along its side of the octagon (they pointed outwards,
		# like a star).
		var seg = cube(Vector3(1.08,.22,.18),p+Vector3(-1.2,0,-2.2)+Vector3(sin(a),0,cos(a))*1.2+Vector3.UP*.11,wood)
		seg.rotation.y = a
