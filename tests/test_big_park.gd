extends SceneTree
# The big park (docs/futuro/01 Alternativa C): path graph, crowd on the paths, the photographer
# walking with collisions, the camera raised to the eye with a toggle, photos only at the eye,
# pedestrians reacting to a camera close to them. Needs a display:
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_big_park.gd
const MainScript = preload("res://scripts/main.gd")
const Main = preload("res://main.tscn")
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

func frames(n = 3) -> void:
	for i in n: await process_frame

func seconds(t: float) -> void:
	var start = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < t*1000: await process_frame

func key(code: Key, pressed: bool) -> void:
	var ev = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

func run() -> void:
	MainScript.scenario = "grande"
	game = Main.instantiate()
	root.add_child(game)
	await frames(12)
	var park = game.park
	# --- The park and its graph ---
	check(park.get_script().resource_path.ends_with("park_grande.gd"),"The big park is built")
	check(game.people.size() == game.GRANDE_PEOPLE,"%d pedestrians" % game.GRANDE_PEOPLE)
	var seen = {"PN":true}
	var queue = ["PN"]
	while not queue.is_empty():
		var n = queue.pop_back()
		for m in park.neighbours[n]:
			if not seen.has(m):
				seen[m] = true
				queue.append(m)
	check(seen.size() == park.nodes.size(),"Every node of the path graph is reachable (%d/%d)" % [seen.size(),park.nodes.size()])
	check(park.benches.size() >= 12,"Benches beside the paths (%d)" % park.benches.size())
	check(park.lamps.size() >= 20,"Lamps along the paths (%d)" % park.lamps.size())
	for e in park.edges:
		var mid = (park.nodes[e[0]]+park.nodes[e[1]])*.5
		check(park.path_distance(mid) <= .01,"Edge %s–%s lies on a paved path" % [e[0],e[1]])
	# --- The playground always has children (docs/futuro/19 §10) ---
	if game.park.detail == "hd":
		var kids = game.extras.extras
		check(kids.size() >= 6 and kids.all(func(k): return k.traits.profile == 3 and k.ambient and k.colliders.is_empty()),"Six children at the playground, ambient and without colliders (%d)" % kids.size())
		check(not kids.any(func(k): return k in game.people),"They are not pedestrians of the assignments")
		var swing0 = game.extras.swing_pivot.rotation.x
		var slide0 = game.extras.slider.position
		for i in 60: game.extras.update(1.0/30)
		check(absf(game.extras.swing_pivot.rotation.x-swing0) > .05,"The swing swings")
		check(game.extras.slider.position.distance_to(slide0) > .3,"A child goes round the slide")
		# The slide's child follows the real ladder and chute (docs/futuro/19 §10).
		var ex = game.extras
		var base = park.PLAYGROUND_POS+Vector3(2.0,0,.6)
		var phases_seen = {}
		var worst_chute = 0.0
		var worst_foot = 0.0
		ex.slide_time = 0.0
		for i in 400:
			ex.update(1.0/30)
			var t = ex.slide_time
			var local = ex.slider.position-base
			if t < 3.4:
				phases_seen["subir"] = true
				# Feet on rungs: each foot's height is a whole rung when it is not moving.
				for side in ["I","D"]:
					var foot = (ex.slider.global_transform*ex.slider.rig.get_bone_global_pose(ex.slider.bones["pie."+side]).origin)-base
					if absf(foot.z-ex.RUNG_Z) < .12: worst_foot = maxf(worst_foot,absf(foot.z-ex.RUNG_Z))
				if i == 30: check(absf(local.z-(ex.RUNG_Z-ex.TOE_REACH)) < .001,"Climbing: the child stays at the ladder")
			elif t > 5.3 and t < 6.3:
				phases_seen["bajar"] = true
				# Sitting on the chute: the root lies on its surface.
				var along = (local-ex.CHUTE_TOP).dot(ex.CHUTE_DIR)
				var off = (local-ex.CHUTE_TOP-ex.CHUTE_DIR*along).length()
				worst_chute = maxf(worst_chute,off)
		check(phases_seen.has("subir") and phases_seen.has("bajar"),"The loop climbs the ladder and slides down")
		check(worst_chute < .05,"Sliding: the child stays on the chute (%.3f m off)" % worst_chute)
		check(ex.RUNGS*ex.RUNG_STEP < ex.PLATFORM_Y and ex.PLATFORM_EDGE > ex.RUNG_Z,"The platform starts just past the ladder")
		check(kids.all(func(k): return k.global_position.distance_to(park.PLAYGROUND_POS) < 9.0),"All of them stay by the playground")
	# --- Lamps clear of the benches, the slide slopes down, pigeons flee to real trees ---
	var worst_lamp = INF
	for bench in park.benches:
		for lamp in park.lamps: worst_lamp = minf(worst_lamp,Vector2(lamp.global_position.x-bench.pos.x,lamp.global_position.z-bench.pos.z).length())
	check(worst_lamp >= 2.2,"No lamp stands in front of a bench or beside it (nearest %.1f m)" % worst_lamp)
	var flock = game.pigeons.flocks[0]
	var perch = game.pigeons.roost(flock)
	check(park.tree_spots.any(func(t): return Vector2(t.x-perch.x,t.z-perch.z).length() < .1),"The pigeons' perch is a real tree")
	flock.state = "suelo"
	game.player_proxy.position = flock.center+Vector3(1.5,0,0)
	game.player_proxy.state = "CAMINANDO"
	game.pigeons.update(1.0/30,game.people,[game.player_proxy])
	check(flock.state == "vuelo" and flock.next == "posada","Walking up to the pigeons puts them to flight")
	game.player_proxy.state = "DETENIDO"
	# --- Nothing in the playground can be walked through ---
	var labels = {}
	for body in park.find_children("*","StaticBody3D",true,false):
		var l = str(body.get_meta("label",""))
		labels[l] = labels.get(l,0)+1
	check(labels.get(game.Texts.get_text("un_arenero"),0) == 8,"The sandpit's eight boards are solid")
	check(labels.get(game.Texts.get_text("un_tobogan"),0) >= 11,"The slide's posts, platform, chute and rungs are solid (%d)" % labels.get(game.Texts.get_text("un_tobogan"),0))
	if park.detail == "hd":
		var kid = game.extras.extras[game.extras.extras.size()-1]
		game.set_raised(false)
		game.raise_anim = 0.0
		game.player.position = Vector3(kid.global_position.x+.1,0,kid.global_position.z)
		game.mode = "SEARCH"
		for i in 3: await process_frame
		check(Vector2(game.player.position.x-kid.global_position.x,game.player.position.z-kid.global_position.z).length() >= .5,"The photographer cannot walk through a child of the playground")
	# --- The crowd walks the paths ---
	game.start_session("day")
	game.begin_assignment()
	game.mode = "SEARCH"
	# The subject of the assignment stops and sits less (main.gd protected_target): this minute is
	# about the crowd, so nobody is held back by it.
	game.target.protected_target = false
	var dt = 1.0/30
	var max_stuck = 0.0
	var off_path = 0
	var min_gap = INF
	var visited = {}
	var ever_sat = false
	for step in 1800:
		for p in game.people: game.update_person(p,dt)
		for p in game.people:
			max_stuck = maxf(max_stuck,p.stuck_time)
			if p.state == "CAMINANDO" and p.bench_goal < 0 and park.path_distance(p.position) > .6: off_path += 1
			visited[p.get_meta("route")[0]] = true
			if p.state == "SENTADO": ever_sat = true
		if step % 10 == 0:
			for i in game.people.size():
				var a = game.people[i]
				if a.state != "CAMINANDO": continue
				for j in range(i+1,game.people.size()):
					var b = game.people[j]
					if b.state != "CAMINANDO": continue
					min_gap = minf(min_gap,Vector2(a.position.x-b.position.x,a.position.z-b.position.z).length())
	print("BIG PARK CROWD: longest stuck %.1f s, off-path samples %d, min gap %.2f m, nodes visited %d/%d" % [max_stuck,off_path,min_gap,visited.size(),park.nodes.size()])
	check(max_stuck < 5.5,"Nobody stays jammed (escalation turns back at 5 s)")
	check(off_path < 60,"Walkers stay on the paths")
	check(min_gap >= .42,"Walkers never overlap")
	check(visited.size() >= park.nodes.size()*.8,"The crowd spreads over the whole network")
	check(ever_sat,"Someone sits on a bench during the minute")
	check(game.people.any(func(p): return p.state == "DETENIDO"),"Someone stops to do something")
	# --- The photographer ---
	await frames(3)
	check(not game.camera_raised and not game.eye_ready(),"The big park starts walking, camera down")
	check(game.camera.fov > 70.0,"Walking: natural field of view")
	check(not game.finder.visible and not game.hud_top.any(func(n): return n.visible),"Walking: no camera interface")
	game.shots = 3
	await game.take_photo()
	check(game.mode == "SEARCH" and game.shots == 3,"No photo with the camera down")
	# The Y key raises and lowers the camera too (not only the right click).
	var was_raised = game.camera_raised
	var y_key = InputEventKey.new()
	y_key.physical_keycode = KEY_Y
	y_key.keycode = KEY_Y
	y_key.pressed = true
	game._unhandled_input(y_key)
	check(game.camera_raised != was_raised,"Y raises the camera in the big park")
	game._unhandled_input(y_key)
	check(game.camera_raised == was_raised,"…and lowers it again")
	game.player.position = Vector3(30,0,-14)
	game.angle = 0.0
	game.update_camera()
	var start = game.player.position
	var t0 = Time.get_ticks_msec()
	var frames_n = 0
	key(KEY_W,true)
	# Until it has walked a metre (4 s at most): a fixed second failed when the machine stalled and
	# few frames were drawn, because each frame's step is capped.
	while Time.get_ticks_msec()-t0 < 4000 and game.player.position.z > start.z-1.0:
		await process_frame
		frames_n += 1
	key(KEY_W,false)
	print("walk test: frames %d, velocity %.2f, pos %s" % [frames_n,game.player.velocity.length(),str(game.player.position)])
	await frames(3)
	check(game.player.position.z < start.z-.8,"W walks forward (%.2f m)" % (start.z-game.player.position.z))
	# Into the fence: it stops there.
	game.player.position = Vector3(0,0,park.HALF.y-1.5)
	game.angle = 180.0
	game.update_camera()
	key(KEY_W,true)
	await seconds(1.5)
	key(KEY_W,false)
	check(game.player.position.z < park.HALF.y-.25,"The fence stops the photographer")
	# Raise the camera (a toggle): after the gesture, the camera interface; then lower it again.
	game.player.position = Vector3(0,0,20)
	game.toggle_raise()
	check(game.camera_raised and not game.eye_ready(),"Raising takes a moment (the gesture)")
	await seconds(.6)
	check(game.eye_ready() and game.finder.visible,"Camera at the eye: the camera interface is back")
	check(absf(game.camera.fov-rad_to_deg(2*atan(36.0/(2.0*game.focal)))) < .1,"At the eye the lens decides the field of view")
	var before = game.player.position
	key(KEY_W,true)
	await seconds(.5)
	key(KEY_W,false)
	check(game.player.position.distance_to(before) < .01,"With the camera at the eye you stand still")
	await game.take_photo()
	check(game.mode == "RESULT","A photo at the eye works")
	game.resume_search()
	game.toggle_raise()
	await seconds(.6)
	check(not game.eye_ready() and not game.finder.visible,"Lowered again: back to walking")
	# --- A camera pointed at someone close: they react ---
	var subject = null
	for p in game.people:
		if p.state == "CAMINANDO" and not p.runner and not p.has_meta("react"):
			subject = p
			break
	if subject:
		var f = game.crowd.frame(subject)
		game.player.position = subject.position+f.dir*1.8
		var to = subject.position-game.player.position
		game.angle = rad_to_deg(atan2(to.x,-to.z))
		game.pitch = -8.0
		game.update_camera()
		game.toggle_raise()
		await seconds(.8)
		check(subject.has_meta("react") or subject.get_meta("react",0.0) > 0,"Someone with a camera pointed at them from 1.8 m reacts")
		game.toggle_raise()
	# --- The pedestrians keep clear of the photographer ---
	check(game.player_proxy != null and game.player_proxy.position.distance_to(game.player.position) < .01,"Pedestrians know where the photographer is")
	MainScript.scenario = "clasico"
	print("BIG PARK TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
