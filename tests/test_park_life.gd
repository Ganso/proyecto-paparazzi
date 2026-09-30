extends SceneTree
# Park life (docs/futuro/19_VIDA_EN_EL_PARQUE.md): extras, pigeons, the dog, benches, chats,
# activities and hand-held props. Needs a display (physics and rendering):
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_park_life.gd
const Main = preload("res://main.tscn")
const Texts = preload("res://scripts/texts.gd")
const Person = preload("res://scripts/person.gd")
var checks = 0
var failures = 0
var game

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func step(seconds: float) -> void:
	for i in int(seconds*30):
		for p in game.people: game.update_person(p,1.0/30)
		game.pigeons.update(1.0/30,game.people,[game.dog] if game.dog else [])
		game.extras.update(1.0/30)
		if game.dog: game.dog.update(1.0/30)

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	for i in 10: await process_frame
	game.start_session(false,true)
	game.mode = "TEST"
	var hd = Person.detail == "hd"

	# --- Extras: out of the playable area, not pedestrians, no colliders ---
	check(game.people.size() == 21,"Still exactly 21 pedestrians")
	if hd: check(game.extras.extras.size() >= 10,"Meadow extras populated in hd")
	for p in game.extras.extras:
		check(not game.people.has(p),"Extras are not in the pedestrian list")
		check(p.ambient and p.colliders.is_empty(),"Extras have no colliders")
		check(Vector2(p.position.x,p.position.z).length() > 12.8,"Extras stay beyond r = 12.8 m")
	step(20.0)
	for p in game.extras.extras:
		check(Vector2(p.position.x,p.position.z).length() > 12.8,"Walking extras stay beyond r = 12.8 m")

	# --- Pigeons: small, drawn only ---
	if hd:
		check(game.pigeons.birds.size() > 0,"Pigeons populated in hd")
		check(game.pigeons.find_children("*","CollisionObject3D",true,false).is_empty(),"Pigeons have no colliders")
		check(game.pigeons.triangle_count() < 40000,"Pigeons are cheap (%d triangles)" % game.pigeons.triangle_count())
		for b in game.pigeons.birds:
			if game.pigeons.flocks[b.flock].state == "suelo": check(b.pos.y < .1,"Pigeons on the ground stay on the ground")

	# --- The dog: collider for photos only ---
	if game.dog:
		check(game.dog.walker.has_dog and game.people.has(game.dog.walker),"The dog has an owner among the pedestrians")
		var bodies = game.dog.find_children("*","StaticBody3D",true,false)
		check(bodies.size() == 1 and bodies[0].collision_layer & 2 == 0,"Dog collider is invisible to navigation (not on layer 2)")
		check(str(bodies[0].get_meta("label","")) == Texts.get_text("un_perro"),"Dog collider is labelled for the photo report")
		var gap = Vector2(game.dog.position.x-game.dog.walker.position.x,game.dog.position.z-game.dog.walker.position.z).length()
		check(gap < 1.6,"The dog stays within the leash (%.2f m)" % gap)

	# --- Bench: walk up, turn, sit down smoothly, stand up clear ---
	var sitter = null
	for p in game.people:
		if p.lane == 1 and not p.runner and not p.protected_target and p.state == "CAMINANDO" and p.destination_lane < 0 and p.bench_goal < 0:
			sitter = p
			break
	check(sitter != null,"A walker on the bench path")
	if sitter:
		# Everyone else on the bench path steps out of the way (hidden) and frees the benches.
		for q in game.people:
			if q != sitter and q.lane == 1: q.visible = false
		for bench_i in game.park.benches: bench_i.occupied = false
		var bench_index = 0
		var bench = game.park.benches[bench_index]
		sitter.theta = fposmod(bench.theta-sitter.direction*9.0,360)
		sitter.radius = 4.3
		sitter.v_fwd = sitter.speed
		sitter.pending_stop = {}
		sitter.stuck_time = 0.0
		sitter.activity = ""
		bench.occupied = true
		sitter.bench_goal = bench_index
		sitter.place()
		var max_jump = 0.0
		var previous = sitter.position
		var sat = false
		for i in 30*25:
			game.update_person(sitter,1.0/30)
			if OS.has_environment("LIFE_DEBUG") and i % 15 == 0: print("t=%.1f %s θ%.2f r%.2f v%.2f bench%d stuck%.1f seat%.2f ahead %.2f" % [i/30.0,sitter.state,sitter.theta,sitter.radius,sitter.v_fwd,sitter.bench_goal,sitter.stuck_time,sitter.seat,game.ahead_of(sitter,bench.theta)])
			max_jump = maxf(max_jump,sitter.position.distance_to(previous))
			previous = sitter.position
			if sitter.state == "SENTADO" and sitter.seat >= 1.0:
				sat = true
				break
		check(sat,"The walker reaches the bench and sits down")
		check(max_jump < .06,"No teleport while approaching and sitting (max %.3f m/frame)" % max_jump)
		check(absf(angle_difference(sitter.rotation.y,PI-deg_to_rad(bench.theta))) < .1,"Seated facing the path")
		check(absf(sitter.radius-game.bench_seat(bench,sitter)) < .02,"Hips on the seat")
		sitter.state_time = 0.0
		sitter.activity = ""
		var stood = false
		for i in 30*10:
			game.update_person(sitter,1.0/30)
			max_jump = maxf(max_jump,sitter.position.distance_to(previous))
			previous = sitter.position
			if sitter.state == "CAMINANDO":
				stood = true
				break
		check(stood and not bench.occupied,"Stands up and frees the bench")
		check(max_jump < .06,"No teleport while standing up")
		for q in game.people: q.visible = true

	# --- Chat: two oncoming walkers stop and face each other ---
	var a = null
	var b = null
	for p in game.people:
		if p.lane == 2 and not p.runner and not p.protected_target:
			if a == null: a = p
			elif p.direction != a.direction: b = p; break
	if a and b:
		for q in game.people:
			if q != a and q != b and q.lane == 2: q.visible = false
		for p in [a,b]:
			p.state = "CAMINANDO"
			p.bench_goal = -1
			p.pending_stop = {}
			p.destination_lane = -1
			p.radius = 7.0
			p.v_fwd = p.speed
		a.theta = 60.0
		b.theta = fposmod(60.0+a.direction*rad_to_deg(2.4/7.0),360)
		var rng_state = a.rng.state
		var paired = false
		for attempt in 20:
			a.rng.state = rng_state+attempt
			a.pending_stop = {}
			b.pending_stop = {}
			game.plan_stop(a)
			if a.pending_stop.get("activity","") == "charla":
				paired = true
				break
		check(paired,"Oncoming walkers can pair up to chat")
		if paired:
			for i in 30*8: for p in [a,b]: game.update_person(p,1.0/30)
			check(a.state == "DETENIDO" and b.state == "DETENIDO","Both stop to chat")
			var to_b = b.position-a.position
			check(absf(angle_difference(a.rotation.y,atan2(-to_b.x,-to_b.z))) < .35,"They face each other")
			check(a.position.distance_to(b.position) > .6,"At a conversational distance")
		for q in game.people: q.visible = true

	# --- Activities: props appear with the pose and go away after it ---
	var actor = game.people[3]
	actor.state = "DETENIDO"
	actor.state_time = 99.0
	for activity in ["movil","leer","foto","cafe","palomas"]:
		actor.activity = activity
		for i in 60: game.update_person(actor,1.0/30)
		var shown = actor.props.keys().filter(func(k): return actor.props[k].visible)
		check(shown == Person.PROP_FOR[activity],"Prop for %s shown (%s)" % [activity,str(shown)])
		for key in actor.props:
			check(actor.props[key].find_children("*","CollisionObject3D",true,false).is_empty(),"Props have no colliders")
	actor.activity = ""
	for i in 60: game.update_person(actor,1.0/30)
	check(actor.props.values().all(func(n): return not n.visible),"Props hidden when the activity ends")
	check(actor.props.has("telefono") and actor.props.telefono.get_meta("light").shadow_enabled == false,"Phone light casts no shadows")

	print("PARK LIFE TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
