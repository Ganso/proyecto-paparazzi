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
		check(kids.all(func(k): return k.global_position.distance_to(park.PLAYGROUND_POS) < 9.0),"All of them stay by the playground")
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
	while Time.get_ticks_msec()-t0 < 1000:
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
