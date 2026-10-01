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
	for p in extras:
		if p == kid: continue
		if not p.visible: continue
		if p.state == "CAMINANDO":
			place_walker(p,dt)
			p.animate(dt,p.speed*dt)
		else:
			p.animate(dt,0.0)
	update_ball_game(dt)
	for d in dogs: d.update(dt)
