extends Node3D
# Ambient extras of the meadow (docs/futuro/19_VIDA_EN_EL_PARQUE.md §5): people strolling
# round the bandstand and the pond, a picnic, tourists taking photos, someone reading on the
# grass. They live beyond the fence (r > 12.8 m), have no colliders and are not in main.people,
# so they are never a target, never block a shot and never change the score. Desktop (hd) only:
# the Android scene keeps its 100.000-triangle budget.
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
const BANDSTAND = Vector2(120.0, 24.0)
const POND = Vector2(245.0, 21.0)

var extras: Array = []
var dogs: Array = []
# Picnic, tourist and ball game go home at night (set_time_of_day()).
var day_only: Array[Node3D] = []
var kid: Pedestrian
var ball: MeshInstance3D
var ball_velocity = Vector3.ZERO
var ball_area = Vector3.ZERO
var kick_pause = 0.0
var cast = Cast.new()
var rng = RandomNumberGenerator.new()

static func polar(theta: float, r: float) -> Vector3:
	return Vector3(sin(deg_to_rad(theta))*r,0,-cos(deg_to_rad(theta))*r)

# Heading (rotation.y) that makes a person at `from` face `to`.
static func facing(from: Vector3, to: Vector3) -> float:
	var d = to-from
	return atan2(-d.x,-d.z)

func build(detail: String) -> void:
	if detail != "hd": return
	rng.seed = 1906
	cast.rng.seed = 1906
	var bandstand = polar(BANDSTAND.x,BANDSTAND.y)
	var pond = polar(POND.x,POND.y)
	# Strollers: loops round each landmark, all walking the same way, spaced out.
	for k in 3: add_walker(bandstand,6.2,k*TAU/3.0,1.0)
	for k in 2: add_walker(pond,5.6,k*PI+.6,-1.0)
	add_walker(pond,6.6,2.2,1.0)
	# The last pond stroller walks a dog (no collider out here).
	var owner_node = extras[extras.size()-1]
	owner_node.has_dog = true
	var dog = preload("res://scripts/dog.gd").new()
	add_child(dog)
	dog.setup(owner_node,91,Color("2b2622"),false)
	dogs.append(dog)
	# Picnic in front of the bandstand: blanket, basket and two people on the grass.
	var picnic = polar(116.5,18.4)   # inside the open bays of the fence (the pillars stand at ±7.5° from 120°)
	add_blanket(picnic,facing(picnic,bandstand))
	var side = (bandstand-picnic).normalized().cross(Vector3.UP)
	day_only.append(add_still(picnic+side*.45,facing(picnic+side*.45,picnic-side*.6),"suelo","cafe"))
	day_only.append(add_still(picnic-side*.5,facing(picnic-side*.5,picnic+side*.6),"suelo","leer"))
	# Two friends chatting and a tourist photographing the bandstand.
	var chat = polar(129.0,19.0)
	var chat_side = chat.normalized().cross(Vector3.UP)*.55
	add_still(chat+chat_side,facing(chat+chat_side,chat-chat_side),"","charla")
	add_still(chat-chat_side,facing(chat-chat_side,chat+chat_side),"","charla")
	var tourist = polar(122.0,17.4)
	day_only.append(add_still(tourist,facing(tourist,bandstand),"","foto"))
	# By the pond: a child watching the water, someone on the phone on the grass, a reader.
	var watcher = pond+(Vector3.ZERO-pond).normalized()*3.9+(Vector3.ZERO-pond).normalized().cross(Vector3.UP)*1.2
	add_still(watcher,facing(watcher,pond),"","mirar",true)
	var lounger = polar(237.0,16.6)
	add_still(lounger,facing(lounger,pond)+.8,"suelo","movil")
	var reader = polar(254.5,16.9)
	add_still(reader,facing(reader,pond)-.6,"suelo","leer")
	# A child kicking a ball about, to the right of the bandstand.
	add_ball_game(polar(137.0,17.0))

# ---- Playground of the big park (docs/futuro/19 §10): there are always children playing ----
# One on a swing (the seat really swings), one going up the ladder and down the slide in a loop,
# one in the sandpit and three running round the playground. Ambient like the rest: no colliders,
# never a target. At night they go home.
var swing_pivot: Node3D
var swing_time = 0.0
var slider: Pedestrian
var slide_origin = Vector3.ZERO
var slide_time = 0.0
# The slide, as park_grande.gd::build_playground() builds it (metres from its base, +z down the
# chute): five rungs 0.3 m apart on the ladder at z = −0.82, the platform's top at 1.59 m from
# z = −0.77 (just past the ladder) to −0.15, and the chute from (1.547, −0.127) down to (0.153, 1.827).
const RUNG_Z = -.82
const RUNG_STEP = .3
const RUNGS = 5
const PLATFORM_Y = 1.59
const CHUTE_TOP = Vector3(0,1.547,-.127)
const CHUTE_DIR = Vector3(0,-.581,.814)
const CHUTE_UP = Vector3(0,.814,.581)
const CHUTE_SLOPE = .62
const CHUTE_LEN = 2.4
const PLATFORM_EDGE = -.77
const TOE_REACH = .17                   # the toes on the rung, the body this far behind it
const HAND_RUNGS = 3                    # the hands hold three rungs above the feet (0.9 m)
# Phases of the loop and their seconds: walk to the ladder, climb, cross the platform, sit, slide,
# get up, walk round.
const SLIDE_PHASES = [["subir",3.4],["plataforma",1.1],["sentarse",.7],["bajar",1.15],["levantarse",.8],["volver",6.2]]

func build_playground(center: Vector3, detail: String) -> void:
	if detail != "hd": return
	rng.seed = 2209
	cast.rng.seed = 2209
	# Swing: seat and ropes hang from a pivot on the beam, with a child sitting on it.
	var sw = center+Vector3(-1.6,0,0)
	swing_pivot = Node3D.new()
	swing_pivot.position = sw+Vector3(-.7,2.2,0)
	add_child(swing_pivot)
	var seat = MeshInstance3D.new()
	var seat_box = BoxMesh.new()
	seat_box.size = Vector3(.45,.05,.2)
	seat.mesh = seat_box
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color("303030")
	seat.material_override = dark
	seat.position = Vector3(0,-1.72,0)
	swing_pivot.add_child(seat)
	var grey = StandardMaterial3D.new()
	grey.albedo_color = Color("8a8a8a")
	for k in [-.18,.18]:
		var rope = MeshInstance3D.new()
		var rope_mesh = CylinderMesh.new()
		rope_mesh.top_radius = .008
		rope_mesh.bottom_radius = .008
		rope_mesh.height = 1.7
		rope_mesh.radial_segments = 5
		rope.mesh = rope_mesh
		rope.material_override = grey
		rope.position = Vector3(k,-.85,0)
		swing_pivot.add_child(rope)
	var swinger = spawn(true)
	remove_child(swinger)
	swing_pivot.add_child(swinger)
	swinger.position = Vector3(0,-2.17,.12)
	swinger.rotation.y = PI
	swinger.state = "SENTADO"
	swinger.seat = 1.0
	swinger.animate(0)
	day_only.append(swing_pivot)
	# Slide: a child climbing and sliding in a loop.
	slide_origin = center+Vector3(2.0,0,.6)
	slider = spawn(true)
	slider.set_meta("slider",true)
	slider.state = "CAMINANDO"
	day_only.append(slider)
	# Sandpit: a child sitting on the sand.
	var sand = center+Vector3(-1.2,0,-2.2)
	day_only.append(add_still(sand+Vector3(.2,0,.1),2.4,"suelo","",true))
	# Three children running round the playground, spaced out, all the same way.
	for k in 3:
		var runner = spawn(true)
		runner.state = "CAMINANDO"
		runner.speed = rng.randf_range(1.25,1.6)
		# Inside the gravel ring, clear of the equipment (the slide's exit reaches 4.3 m) and of
		# the benches and the path outside it.
		runner.set_meta("route",{"center":center,"radius":4.55+k*.14,"angle":k*2.2,"dir":1.0})
		place_walker(runner,0.0)
		runner.animate(0)
		day_only.append(runner)

func update_playground(dt: float) -> void:
	if swing_pivot != null and swing_pivot.visible:
		swing_time += dt
		swing_pivot.rotation.x = .5*sin(swing_time*2.3)
	if slider != null and slider.visible: update_slider(dt)

# Height of a foot on the ladder, in rungs, at climb progress c (rungs): the feet go up one rung at
# a time, one after the other (a child's legs are too short to skip rungs). The left foot leads.
static func rung_of(c: float, leading: bool) -> float:
	var n = floorf(c)
	var u = c-n
	var move = smoothstep(0.0,.5,u) if leading else smoothstep(.5,1.0,u)
	return n+move

func update_slider(dt: float) -> void:
	var total = 0.0
	for ph in SLIDE_PHASES: total += ph[1]
	slide_time = fmod(slide_time+dt,total)
	var t = slide_time
	var phase = ""
	var u = 0.0
	for ph in SLIDE_PHASES:
		if t < ph[1]:
			phase = ph[0]
			u = t/ph[1]
			break
		t -= ph[1]
	var ladder_foot = Vector3(0,0,RUNG_Z-TOE_REACH)
	var local = Vector3.ZERO
	var pitch = 0.0
	var before = slider.position
	slider.state = "DETENIDO"
	slider.seat_kind = ""
	match phase:
		"subir":
			# Up the five rungs, then the last short step onto the platform's edge.
			var c = u*(RUNGS+.6)
			var left = minf(rung_of(c,true),RUNGS)
			var right = minf(rung_of(c,false),RUNGS)
			var low = minf(left,right)*RUNG_STEP
			local = ladder_foot+Vector3.UP*low
			slider.position = slide_origin+local
			slider.rotation = Vector3(0,PI,0)
			# Hands: each on a rung three above the feet, going up as the opposite foot does; past
			# the last rung they press on the platform's edge to get up onto it.
			var top_grip = PLATFORM_Y+.02
			var hand_l = minf((rung_of(c,false)+HAND_RUNGS)*RUNG_STEP,top_grip)
			var hand_r = minf((rung_of(c,true)+HAND_RUNGS)*RUNG_STEP,top_grip)
			slider.gait.climb(left*RUNG_STEP-low,right*RUNG_STEP-low,TOE_REACH,hand_l-low,hand_r-low,TOE_REACH+.01)
			return
		"plataforma":
			# From the top rung onto the platform and across it to the chute's mouth, walking.
			var from = ladder_foot+Vector3.UP*RUNGS*RUNG_STEP
			var to = Vector3(0,PLATFORM_Y,CHUTE_TOP.z-.18)
			local = from.lerp(to,smoothstep(0,1,u))
			local.y = lerpf(from.y,PLATFORM_Y,smoothstep(0.0,.35,u))
			slider.position = slide_origin+local
			slider.rotation = Vector3(0,PI,0)
			slider.state = "CAMINANDO"
			slider.animate(dt,Vector3(slider.position.x-before.x,0,slider.position.z-before.z).length())
			return
		"sentarse":
			# Sit down at the top of the chute, the body tipping to its slope.
			var from = Vector3(0,PLATFORM_Y,CHUTE_TOP.z-.18)
			var to = CHUTE_TOP+CHUTE_DIR*.3+CHUTE_UP*.03
			local = from.lerp(to,smoothstep(0,1,u))
			pitch = CHUTE_SLOPE*smoothstep(.2,1.0,u)
			slider.position = slide_origin+local
			slider.transform.basis = Basis(Vector3.RIGHT,pitch)*Basis(Vector3.UP,PI)
			slider.state = "SENTADO"
			slider.seat_kind = "suelo"
			slider.seat = smoothstep(0,1,u)
			slider.gait.slide(.25*u)
			return
		"bajar":
			# Down the chute, faster and faster (uniform acceleration), sitting on it.
			var s = .3+(CHUTE_LEN-.3-.45)*u*u
			local = CHUTE_TOP+CHUTE_DIR*s+CHUTE_UP*.03
			slider.position = slide_origin+local
			slider.transform.basis = Basis(Vector3.RIGHT,CHUTE_SLOPE)*Basis(Vector3.UP,PI)
			slider.state = "SENTADO"
			slider.seat_kind = "suelo"
			slider.seat = 1.0
			slider.gait.slide(.25)
			return
		"levantarse":
			# Off the end of the chute and up on the feet.
			var from = CHUTE_TOP+CHUTE_DIR*(CHUTE_LEN-.45)+CHUTE_UP*.03
			var to = Vector3(0,0,2.25)
			local = from.lerp(to,smoothstep(0,.6,u))
			slider.position = slide_origin+local
			slider.transform.basis = Basis(Vector3.RIGHT,CHUTE_SLOPE*(1.0-smoothstep(0,.5,u)))*Basis(Vector3.UP,PI)
			slider.state = "SENTADO" if u < .98 else "DETENIDO"
			slider.seat_kind = "suelo"
			slider.seat = 1.0-smoothstep(.15,1.0,u)
			slider.gait.pose(dt,0.0)
			return
		"volver":
			# Round the slide and back to the foot of the ladder.
			var path = [Vector3(0,0,2.25),Vector3(1.1,0,2.5),Vector3(1.15,0,-1.5),Vector3(0,0,-1.55),ladder_foot]
			var lengths = []
			var sum = 0.0
			for k in path.size()-1:
				lengths.append(path[k].distance_to(path[k+1]))
				sum += lengths[k]
			var d = u*sum
			var k = 0
			while k < lengths.size()-1 and d > lengths[k]:
				d -= lengths[k]
				k += 1
			local = path[k].lerp(path[k+1],clampf(d/lengths[k],0,1))
			slider.position = slide_origin+local
			var step = slider.position-before
			var facing = atan2(-step.x,-step.z) if step.length() > .0005 else slider.rotation.y
			if u > .93: facing = PI                 # squared up to the ladder for the climb
			slider.rotation = Vector3(0,lerp_angle(slider.rotation.y,facing,minf(1.0,dt*7)),0)
			slider.state = "CAMINANDO"
			slider.seat = 0.0
			slider.animate(dt,Vector3(step.x,0,step.z).length())

func spawn(child = false) -> Pedestrian:
	var p = Person.new()
	p.ambient = true
	add_child(p)
	var t = cast.generate(false)
	var attempts = 0
	while (t.profile == 3) != child and attempts < 40:
		t = cast.generate(false)
		attempts += 1
	p.setup(t,cast.catalog,7000+extras.size()*13)
	extras.append(p)
	return p

func add_walker(center: Vector3, radius: float, angle: float, direction: float) -> void:
	var p = spawn()
	p.state = "CAMINANDO"
	p.speed = rng.randf_range(.55,.8)
	p.set_meta("route",{"center":center,"radius":radius,"angle":angle,"dir":direction})
	place_walker(p,0.0)
	p.animate(0)

func add_still(pos: Vector3, heading: float, seat: String, activity: String, child = false) -> Pedestrian:
	var p = spawn(child)
	p.position = pos
	p.rotation.y = heading
	p.activity = activity
	p.act_time = rng.randf_range(0,20)
	if seat != "":
		p.seat_kind = seat
		p.state = "SENTADO"
	else:
		p.state = "DETENIDO"
	p.animate(0)
	return p

func add_blanket(pos: Vector3, heading: float) -> void:
	var img = Image.create(64,64,false,Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var a = int(x/8)%2 == 0
			var b = int(y/8)%2 == 0
			var c = Color("b8373a") if a and b else Color("efe6d2") if not a and not b else Color("d68a82")
			img.set_pixel(x,y,c)
	var material = StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.roughness = .95
	var blanket = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.7,.012,1.4)
	blanket.mesh = box
	blanket.material_override = material
	blanket.position = pos+Vector3.UP*.006
	blanket.rotation.y = heading
	add_child(blanket)
	day_only.append(blanket)
	var basket_material = StandardMaterial3D.new()
	basket_material.albedo_color = Color("9a6b3c")
	basket_material.roughness = .9
	var basket = MeshInstance3D.new()
	var basket_box = BoxMesh.new()
	basket_box.size = Vector3(.42,.24,.3)
	basket.mesh = basket_box
	basket.material_override = basket_material
	basket.position = pos+blanket.basis*Vector3(.5,.12,-.45)
	basket.rotation.y = heading
	add_child(basket)
	day_only.append(basket)

func add_ball_game(center: Vector3) -> void:
	ball_area = center
	kid = spawn(true)
	kid.state = "CAMINANDO"
	kid.speed = .85
	kid.position = center+Vector3(.8,0,0)
	kid.set_meta("kid",true)
	day_only.append(kid)
	ball = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = .11
	sphere.height = .22
	ball.mesh = sphere
	var img = Image.create(32,16,false,Image.FORMAT_RGB8)
	for y in 16:
		for x in 32: img.set_pixel(x,y,Color("d9342b") if (x/8+y/8)%2 == 0 else Color("f3efe6"))
	var material = StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.roughness = .5
	ball.material_override = material
	ball.position = center+Vector3(0,.11,0)
	add_child(ball)
	day_only.append(ball)

# The child walks to the ball and kicks it somewhere inside the play area (1.8 m around).
func update_ball_game(dt: float) -> void:
	if kid == null or not kid.visible: return
	ball_velocity *= exp(-1.3*dt)
	var next = ball.position+ball_velocity*dt
	var off = Vector3(next.x-ball_area.x,0,next.z-ball_area.z)
	if off.length() > 1.8: ball_velocity = ball_velocity.bounce(off.normalized())*.6
	ball.position += ball_velocity*dt
	ball.position.y = .11
	var speed = ball_velocity.length()
	if speed > .01: ball.rotate(Vector3.UP.cross(ball_velocity.normalized()).normalized(),speed*dt/.11)
	kick_pause -= dt
	var to = Vector3(ball.position.x-kid.position.x,0,ball.position.z-kid.position.z)
	var moved = 0.0
	if kick_pause <= 0 and to.length() > .32:
		moved = minf(kid.speed*dt,to.length()-.3)
		kid.position += to.normalized()*moved
		kid.rotation.y = lerp_angle(kid.rotation.y,atan2(-to.x,-to.z),minf(1.0,dt*5))
		kid.state = "CAMINANDO"
	elif kick_pause <= 0:
		var aim = (ball_area-ball.position).normalized().rotated(Vector3.UP,rng.randf_range(-1.2,1.2))
		ball_velocity = aim*rng.randf_range(1.6,2.6)+to.normalized()*.6
		kick_pause = rng.randf_range(.6,1.4)
	if kick_pause > 0: kid.state = "DETENIDO"
	kid.animate(dt,moved)

func set_time_of_day(tod: String) -> void:
	for node in day_only: node.visible = tod != "night"

func place_walker(p: Pedestrian, dt: float) -> void:
	var route: Dictionary = p.get_meta("route")
	route.angle += route.dir*p.speed*dt/route.radius
	p.position = route.center+Vector3(cos(route.angle),0,sin(route.angle))*route.radius
	# Tangent of the loop in the walking direction.
	var tangent = Vector3(-sin(route.angle),0,cos(route.angle))*route.dir
	p.rotation.y = atan2(-tangent.x,-tangent.z)

func update(dt: float) -> void:
	update_playground(dt)
	for p in extras:
		if p == kid or p == slider: continue
		if swing_pivot != null and p.get_parent() == swing_pivot: continue
		if not p.visible: continue
		if p.state == "CAMINANDO":
			place_walker(p,dt)
			p.animate(dt,p.speed*dt)
		else:
			p.animate(dt,0.0)
	update_ball_game(dt)
	for d in dogs: d.update(dt)
