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
	var picnic = polar(111.0,18.2)
	add_blanket(picnic,facing(picnic,bandstand))
	var side = (bandstand-picnic).normalized().cross(Vector3.UP)
	add_still(picnic+side*.45,facing(picnic+side*.45,picnic-side*.6),"suelo","cafe")
	add_still(picnic-side*.5,facing(picnic-side*.5,picnic+side*.6),"suelo","leer")
	# Two friends chatting and a tourist photographing the bandstand.
	var chat = polar(129.0,19.0)
	var chat_side = chat.normalized().cross(Vector3.UP)*.55
	add_still(chat+chat_side,facing(chat+chat_side,chat-chat_side),"","charla")
	add_still(chat-chat_side,facing(chat-chat_side,chat+chat_side),"","charla")
	var tourist = polar(122.0,17.4)
	add_still(tourist,facing(tourist,bandstand),"","foto")
	# By the pond: a child watching the water, someone on the phone on the grass, a reader.
	var watcher = pond+(Vector3.ZERO-pond).normalized()*3.9+(Vector3.ZERO-pond).normalized().cross(Vector3.UP)*1.2
	add_still(watcher,facing(watcher,pond),"","mirar",true)
	var lounger = polar(237.0,16.6)
	add_still(lounger,facing(lounger,pond)+.8,"suelo","movil")
	var reader = polar(254.5,16.9)
	add_still(reader,facing(reader,pond)-.6,"suelo","leer")

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

func add_still(pos: Vector3, heading: float, seat: String, activity: String, child = false) -> void:
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

func place_walker(p: Pedestrian, dt: float) -> void:
	var route: Dictionary = p.get_meta("route")
	route.angle += route.dir*p.speed*dt/route.radius
	p.position = route.center+Vector3(cos(route.angle),0,sin(route.angle))*route.radius
	# Tangent of the loop in the walking direction.
	var tangent = Vector3(-sin(route.angle),0,cos(route.angle))*route.dir
	p.rotation.y = atan2(-tangent.x,-tangent.z)

func update(dt: float) -> void:
	for p in extras:
		if p.state == "CAMINANDO":
			place_walker(p,dt)
			p.animate(dt,p.speed*dt)
		else:
			p.animate(dt,0.0)
	for d in dogs: d.update(dt)
