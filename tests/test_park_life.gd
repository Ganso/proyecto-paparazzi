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
	game.exposure_thirds = false   # (not the player's option)
	for i in 10: await process_frame
	game.start_session(false,true)
	game.mode = "TEST"
	var hd = Person.detail == "hd"

	# --- Extras: out of the playable area, not pedestrians, no colliders ---
	check(game.people.size() == 21,"Still exactly 21 pedestrians")
	if hd: check(game.extras.extras.size() >= 10,"Meadow extras populated in hd")
	if hd:
		check(game.extras.dogs.size() == 2,"Two dogs in the meadow: by the pond and round the bandstand")
		check(game.extras.dogs[1].size < .7 and game.extras.dogs[0].size > .75,"The bandstand dog is a small one")
		check(game.extras.dogs.all(func(d): return d.find_children("*","CollisionObject3D",true,false).is_empty()),"Meadow dogs have no colliders")
	if hd:
		# Ducks on the pond: always on the water, no colliders, still at night.
		check(game.ducks != null and game.ducks.ducks.size() == 3,"Three ducks on the pond")
		check(game.ducks.find_children("*","CollisionObject3D",true,false).is_empty(),"Ducks have no colliders")
		var afloat = true
		for step in 900:
			game.ducks.update(1.0/30)
			for d in game.ducks.ducks:
				var q: Vector3 = d.body.position
				if pow(q.x/3.0,2)+pow(q.z/1.8,2) > 1.0 or Vector2(q.x,q.z).length() < 1.48 or absf(q.y-.2) > .02: afloat = false
		check(afloat,"Ducks stay on the water, between the rim and the fountain")
		check(game.ducks.global_position.length() > 13.5,"The duck pond is beyond the fence")
		var before = game.ducks.ducks.map(func(d): return d.angle)
		game.ducks.night = true
		for step in 240: game.ducks.update(1.0/30)
		var asleep = game.ducks.ducks.map(func(d): return d.angle)
		for step in 60: game.ducks.update(1.0/30)
		check(game.ducks.ducks.map(func(d): return d.angle) == asleep and asleep != before,"At night the ducks drift to a stop")
		game.ducks.night = false
	# Way of walking (docs/futuro/15 P4): each pedestrian has its own, within sane limits.
	var arms = {}
	for p in game.people: arms[snappedf(p.style.arm,.01)] = true
	check(arms.size() >= 12,"Pedestrians swing their arms differently (%d styles)" % arms.size())
	check(game.people.all(func(p): return p.style.arm >= .65 and p.style.arm <= 1.4 and p.style.elbow >= 0.0 and p.style.elbow <= .28 and absf(p.style.lean) <= .035),"Walking styles stay within their limits")
	check(game.people.filter(func(p): return p.runner).all(func(p): return p.style.lean == 0.0 and p.style.elbow == 0.0),"Runners keep their own running form")
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
		# Meadow furniture: beyond the fence and clear of the strollers' circle round the bandstand.
		var bandstand_pos = game.park.polar(game.park.BANDSTAND.x,game.park.BANDSTAND.y)
		for t in game.park.MEADOW_TABLES:
			var table_pos = game.park.polar(t.x,t.y)
			check(table_pos.length() > 13.5 and absf(table_pos.distance_to(bandstand_pos)-6.2) > 1.0,"Picnic table beyond the fence, off the strollers' path")
		check(game.extras.PICNIC_TABLE == game.park.MEADOW_TABLES[0],"The friends at the picnic table sit at a table that is there")
		var at_table = game.extras.extras.filter(func(p): return p.state == "SENTADO" and p.seat_kind == "banco" and p.position.distance_to(game.park.polar(game.park.MEADOW_TABLES[0].x,game.park.MEADOW_TABLES[0].y)) < 1.0)
		check(at_table.size() == 2,"Two people sit at the picnic table")
		check(game.extras.PICNIC_TABLE_FAR == game.park.MEADOW_TABLES[1] and game.extras.extras.any(func(p): return p.activity == "leer" and p.seat_kind == "banco" and p.position.distance_to(game.park.polar(game.park.MEADOW_TABLES[1].x,game.park.MEADOW_TABLES[1].y)) < 1.0),"A reader sits at the far picnic table")
		check(game.park.polar(game.park.MEADOW_TAP.x,game.park.MEADOW_TAP.y).length() > 13.5,"Drinking fountain beyond the fence")
		check(game.park.ParkAssets.available("mesa_picnic") and game.park.ParkAssets.available("fuente_beber"),"Meadow furniture assets are there")
		# By day a scared flock may perch on the fence: one bird per post or pillar.
		check(game.pigeons.fence.size() > 50 and game.pigeons.fence.all(func(v): return absf(Vector2(v.x,v.z).length()-12.8) < .01 and v.y > 1.1),"The fence offers its posts and pillars as perches")
		var fence_flock = game.pigeons.flocks[0]
		game.pigeons.perch_on_fence(fence_flock)
		for i in 150: game.pigeons.update(1.0/30,[],[])
		var perched = game.pigeons.birds.filter(func(b): return game.pigeons.flocks[b.flock] == fence_flock)
		check(fence_flock.state == "posada","The flock settles on the fence")
		check(perched.all(func(b): return game.pigeons.fence.any(func(v): return v.distance_to(b.pos) < .02)),"Every pigeon of the flock stands on a post or a pillar")
		var spots = {}
		for b in perched: spots[b.pos.snapped(Vector3(.05,.05,.05))] = true
		check(spots.size() == perched.size(),"No two pigeons share a post")
		game.pigeons.take_off(fence_flock,fence_flock.home,"suelo")
		for i in 400: game.pigeons.update(1.0/30,[],[])
		check(perched.all(func(b): return b.pos.y < .1),"From the fence the flock comes back to the lawn")

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
		for bench_i in game.park.benches:
			game.set_seat(bench_i,0,null)
			game.set_seat(bench_i,1,null)
		var bench_index = 0
		var bench = game.park.benches[bench_index]
		sitter.theta = fposmod(bench.theta-sitter.direction*9.0,360)
		sitter.radius = 4.3
		sitter.v_fwd = sitter.speed
		sitter.pending_stop = {}
		sitter.stuck_time = 0.0
		sitter.activity = ""
		game.set_seat(bench,0,sitter)
		sitter.bench_slot = 0
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
		check(stood and bench.seats[0] == null,"Stands up and frees the bench")
		check(max_jump < .06,"No teleport while standing up")
		# Someone else sits on the free place beside a seated person: they chat, heads turned.
		var first = null
		var second = null
		for q in game.people:
			if q != sitter and q.lane == 1 and not q.runner and not q.protected_target and q.state == "CAMINANDO":
				if first == null: first = q
				elif second == null: second = q
		if first and second:
			for q in [first,second]:
				q.visible = true
				q.pending_stop = {}
				q.stuck_time = 0.0
				q.activity = ""
				q.partner = null
			sitter.visible = false
			for slot in 2:
				var q = [first,second][slot]
				q.direction = 1.0
				q.theta = fposmod(game.seat_theta(bench,slot)-(9.0 if slot == 0 else 30.0),360)
				q.radius = 4.3
				q.v_fwd = q.speed
				game.set_seat(bench,slot,q)
				q.bench_slot = slot
				q.bench_goal = bench_index
				q.place()
			for q in [first,second]:
				for i in 30*14:
					game.update_person(q,1.0/30)
					if OS.has_environment("LIFE_DEBUG") and i % 15 == 0: print("pair t=%.1f %s θ%.2f r%.2f v%.2f goal%d slot%d stuck%.1f ahead %.2f" % [i/30.0,q.state,q.theta,q.radius,q.v_fwd,q.bench_goal,q.bench_slot,q.stuck_time,game.ahead_of(q,game.seat_theta(bench,q.bench_slot))])
					if q.state == "SENTADO" and q.seat >= 1.0: break
			for i in 30*3:
				for q in [first,second]: game.update_person(q,1.0/30)
			check(first.state == "SENTADO" and second.state == "SENTADO","Two people share a bench")
			check(first.position.distance_to(second.position) > .7,"Each on their own place")
			var chatting = first.activity == "charla" or second.activity == "charla"
			if chatting:
				var talker = first if first.activity == "charla" else second
				check(absf(talker.look_yaw) > .3,"Seated chat turns the head to the other")
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

	# --- Night: pigeons roost in the trees, the picnic and the ball game go home ---
	game.start_session("night",true)
	game.mode = "TEST"
	step(3.0)
	if hd:
		check(game.pigeons.flocks.all(func(f): return f.state == "posada"),"Pigeons roost at night")
		check(game.pigeons.birds.all(func(b): return b.pos.y > 2.0),"No pigeon on the ground at night")
		check(not game.extras.day_only.is_empty() and game.extras.day_only.all(func(n): return not n.visible),"Picnic, tourist and ball game hidden at night")
	check(Person.screen_glow == 1.0,"Phone screens glow fully at night")

	# Sound effects (docs/futuro/24): the bank finds every sound the game asks for, the ones with
	# variations have more than one take, and what is placed in the park has a listener to hear it.
	var asked = ["obturador_compacta","obturador_telemetrica","obturador_reflex","obturador_reflex_lento","obturador_reflex_rapido","obturador_tlr","af_confirmado","af_fallo","motor_af","anillo_enfoque","bloqueo","dial","dial_tope","control_elegir","medicion","camara_subir","camara_bajar","zoom_compacta","zoom_compacta_fin","lupa_tlr","manivela_tlr","carrete_nuevo","ui_mover","ui_aceptar","ui_atras","ui_bloqueado","pausa","revelado","foto_rechazada","condicion_ok","estrella","tictac","tiempo_agotado","nivel_superado","nivel_no_superado","insignia","graduado","album","leccion_superada","tutorial_ok","paso_losa","paso_grava","paso_cesped","paso_corredor","charla","risa","periodico","taza","movil","migas","perro_jadeo","perro_ladrido","pato","pato_agua","columpio","ninos_jugando","tobogan","balon_patada","balon_bote"]
	var absent = asked.filter(func(n): return not game.sfx.has(n))
	check(absent.is_empty(),"Every sound the game plays is in the bank (missing: %s)" % str(absent))
	check(game.sfx.takes("paso_grava").size() >= 2 and game.sfx.takes("dial").size() >= 2,"Sounds with variations have several takes")
	var first_take = game.sfx.take("dial")
	check(game.sfx.take("dial") != first_take,"…and never the same one twice running")
	check(game.sfx.step_on(Vector3(4,0,0)) == "paso_losa","The classic park's paths sound of flagstones")
	check(not game.sfx.play("no_existe"),"A missing sound says so (the caller keeps its tone)")
	check(game.viewport.audio_listener_enable_3d,"The park's world has its own listener: what is placed in it is heard")
	for name in ["pajaros_dia","pajaros_atardecer","hora_azul","grillos_noche","fuente"]:
		check(game.ambience.stream(name,true) != null,"Ambient loop %s is there" % name)
	print("PARK LIFE TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
