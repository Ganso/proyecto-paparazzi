extends SceneTree
const Main = preload("res://main.tscn")
var game
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func frames(count = 3) -> void:
	for i in count: await process_frame

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	game.exposure_thirds = false   # (not the player's option)
	await frames(10)
	game.start_session(false)
	game.mode = "TEST"
	
	# Desactivar a todos los viandantes del parque para aislar las pruebas de navegación
	for p in game.people:
		p.visible = false
		p.state = "DETENIDO"
	
	# -------------------------------------------------------------
	# Test 1: Cruce en sentidos opuestos en el mismo carril (Carril 1, r ~ 4.0 m)
	# -------------------------------------------------------------
	var p1 = game.people[0]
	var p2 = game.people[1]
	p1.visible = true
	p2.visible = true
	p1.lane = 1
	p2.lane = 1
	p1.direction = 1.0
	p2.direction = -1.0
	p1.speed = 1.2
	p2.speed = 1.2
	p1.radius = game.LANES[1] + game.LANE_OFFSETS[1] # ~4.35 m
	p2.radius = game.LANES[1] - game.LANE_OFFSETS[1] # ~3.65 m
	p1.theta = 260.0
	p2.theta = 280.0
	p1.lane_timer = 999.0
	p2.lane_timer = 999.0
	p1.state = "CAMINANDO"
	p2.state = "CAMINANDO"
	p1.stuck_time = 0.0
	p2.stuck_time = 0.0
	p1.place()
	p2.place()
	
	for step in 14:
		game.update_person(p1, 0.1)
		game.update_person(p2, 0.1)
	
	check(p1.theta > 275.0, "Pedestrian 1 advances past crossing angle")
	check(p2.theta < 265.0, "Pedestrian 2 advances past crossing angle in opposite direction")
	check(p1.stuck_time < 0.1 and p2.stuck_time < 0.1, "Zero deadlock during opposite-direction lane crossing")
	# Three lines per path (docs/NAVEGACION_Y_COLISIONES.md §3): each walker keeps to the edge on
	# its right, so the middle stays free.
	var edges1: Vector2 = game.lane_edges(1)
	check(p1.radius >= edges1.x - .02 and p1.radius <= edges1.y + .02 and p1.radius > game.LANES[1] + .15, "P1 keeps to the outer line of the path (r %.2f)" % p1.radius)
	check(p2.radius >= edges1.x - .02 and p2.radius <= edges1.y + .02 and p2.radius < game.LANES[1] - .5, "P2 keeps to the inner line of the path (r %.2f)" % p2.radius)
	
	# -------------------------------------------------------------
	print("· test 2")
	# Test 2: Adelantamiento en el mismo carril y mismo sentido (corredor adelanta a caminante)
	# -------------------------------------------------------------
	p1.direction = 1.0
	p2.direction = 1.0
	p1.speed = 0.9 # Caminante lento
	p2.speed = 2.6 # Corredor rápido
	p1.theta = 276.0
	p2.theta = 264.0 # 12 grados por detrás
	p1.radius = game.LANES[1] + game.LANE_OFFSETS[1]
	p2.radius = game.LANES[1] + game.LANE_OFFSETS[1] # Misma sub-pista inicial
	p1.stuck_time = 0.0
	p2.stuck_time = 0.0
	p1.lane_timer = 999.0
	p2.lane_timer = 999.0
	p1.runner = false
	p2.runner = true
	p1.place()
	p2.place()
	
	# Smooth walking (docs/NAVEGACION §2): speeds and side steps change gradually, so passing takes
	# a little longer than with the old instant dodges.
	var runner_overtook = false
	for step in 40:
		game.update_person(p1, 0.1)
		game.update_person(p2, 0.1)
		if p2.theta > p1.theta and p2.theta < 340.0:
			runner_overtook = true
	
	check(runner_overtook, "Faster runner smoothly overtakes slower pedestrian")
	check(p2.stuck_time < 0.2, "Runner does not deadlock or freeze while overtaking")
	
	# -------------------------------------------------------------
	print("· test 3")
	# Test 3: Evasión dinámica de obstáculo frontal en el mismo radio (Carril 2, r ~ 7.0 m)
	# -------------------------------------------------------------
	var blocker = game.people[2]
	blocker.visible = true
	blocker.state = "DETENIDO"
	blocker.theta = 280.0
	blocker.radius = game.LANES[2]
	blocker.place()
	
	var walker = game.people[3]
	walker.visible = true
	walker.state = "CAMINANDO"
	walker.direction = 1.0
	walker.speed = 1.2
	walker.lane = 2
	walker.theta = 265.0
	walker.radius = game.LANES[2] # Inicialmente en el mismo radio exacto que el obstáculo
	walker.lane_timer = 999.0
	walker.stuck_time = 0.0
	walker.place()
	
	var max_shift = 0.0
	for step in 60:
		game.update_person(walker, 0.1)
		max_shift = maxf(max_shift, absf(walker.radius - game.LANES[2]))
	
	check(walker.theta > 282.0, "Walker bypasses frontal obstacle")
	check(walker.stuck_time < 0.2, "Walker bypasses obstacle without getting stuck")
	check(max_shift > 0.15, "Walker shifted radius laterally to avoid obstacle")
	
	# -------------------------------------------------------------
	print("· test 4")
	# Test 4: tres líneas — el corredor pasa por el centro entre las dos filas sin frenar
	# -------------------------------------------------------------
	for q in game.people:
		q.visible = false
		q.state = "DETENIDO"
		q.runner = false
	var edges2: Vector2 = game.lane_edges(2)
	var middle = (edges2.x + edges2.y) * .5
	check(edges2.y - edges2.x >= 2.0 * game.PASS_SPACE - .001 and game.PASS_SPACE - .03 > game.HARD_SPACE, "A path holds three lines %.2f m apart, more than the %.2f m two people may ever come to" % [game.PASS_SPACE, game.HARD_SPACE])
	var same_way = game.people[4]
	var other_way = game.people[5]
	var runner = game.people[6]
	var setup_walker = func(q, theta: float, direction: float, speed: float, is_runner: bool):
		q.visible = true
		q.state = "CAMINANDO"
		q.lane = 2
		q.destination_lane = -1
		q.bench_goal = -1
		q.pending_stop = {}
		q.activity = ""
		q.runner = is_runner
		q.direction = direction
		q.speed = speed
		q.v_fwd = speed
		q.v_rad = 0.0
		q.theta = theta
		q.radius = game.home_radius(2, direction, is_runner)
		q.pass_r = NAN
		q.r_goal = NAN
		q.stuck_time = 0.0
		q.lane_timer = 999.0
		q.poi = int(theta / 30)
		q.place()
	setup_walker.call(same_way, 60.0, 1.0, .7, false)
	setup_walker.call(other_way, 95.0, -1.0, .7, false)
	setup_walker.call(runner, 20.0, 1.0, 2.8, true)
	check(is_equal_approx(runner.radius, middle) and is_equal_approx(same_way.radius, edges2.y) and is_equal_approx(other_way.radius, edges2.x), "Runner on the middle line, walkers on the edge to their right")
	var slowest = runner.v_fwd
	var widest = 0.0
	var closest = INF
	for step in 80:
		for q in [same_way, other_way, runner]: game.update_person(q, .05)
		slowest = minf(slowest, runner.v_fwd)
		widest = maxf(widest, absf(runner.radius - middle))
		for q in [same_way, other_way]: closest = minf(closest, runner.position.distance_to(q.position))
	check(game.ahead_of(same_way, runner.theta) > 2.0, "The runner gets past the walker going its way")
	check(slowest > 2.8 * .97, "…without slowing down (slowest %.2f m/s of 2.80)" % slowest)
	check(widest < .05, "…and without leaving the middle line (%.2f m off at most)" % widest)
	check(closest >= game.HARD_SPACE, "…never closer than %.2f m to anyone (%.2f m)" % [game.HARD_SPACE, closest])
	check(same_way.stuck_time < .1 and other_way.stuck_time < .1 and absf(same_way.radius - edges2.y) < .05 and absf(other_way.radius - edges2.x) < .05, "The walkers hold their lines while it goes by")

	# -------------------------------------------------------------
	print("· test 5")
	# Test 5: un paseante no sale al centro delante de un corredor: espera a que pase y entonces adelanta
	# -------------------------------------------------------------
	var standing = game.people[7]
	standing.visible = true
	standing.state = "DETENIDO"
	standing.state_time = 999.0
	standing.lane = 2
	standing.theta = 200.0
	standing.radius = edges2.y
	standing.place()
	other_way.visible = false
	other_way.state = "DETENIDO"
	setup_walker.call(same_way, 185.0, 1.0, .7, false)      # 1.8 m behind whoever stands on its line
	setup_walker.call(runner, 150.0, 1.0, 2.8, true)        # 4.3 m behind the walker, coming fast
	var pulled_out_early = false
	var runner_slowest = runner.v_fwd
	var passed_at = -1.0
	for step in 300:
		for q in [same_way, runner]: game.update_person(q, .05)
		var runner_past = game.ahead_of(same_way, runner.theta) > 1.0
		if not runner_past and same_way.radius < edges2.y - .15: pulled_out_early = true
		if step < 60: runner_slowest = minf(runner_slowest, runner.v_fwd)
		if passed_at < 0 and deg_to_rad(same_way.theta - standing.theta) * same_way.radius > .9: passed_at = step * .05
	check(not pulled_out_early, "A walker held up behind someone standing does not pull out in front of the runner")
	check(runner_slowest > 2.8 * .97, "…so the runner goes by at full speed (slowest %.2f m/s)" % runner_slowest)
	check(passed_at > 0 and passed_at < 14.0, "…and then the walker goes round through the middle (past after %.1f s)" % passed_at)
	check(same_way.stuck_time < .1, "…without ever being stuck")

	# -------------------------------------------------------------
	print("· test 6")
	# Test 6: quien queda fuera del camino vuelve a él andando (antes se quedaba clavado en el césped)
	# -------------------------------------------------------------
	for q in [standing, runner]:
		q.visible = false
		q.state = "DETENIDO"
	setup_walker.call(same_way, 231.0, 1.0, .7, false)
	same_way.radius = 5.56
	same_way.place()
	for step in 160: game.update_person(same_way, .05)
	check(same_way.radius >= game.LANE_BOUNDS[2].x and same_way.radius <= game.LANE_BOUNDS[2].y, "Someone left on the grass between two paths walks back onto the path (r %.2f)" % same_way.radius)
	check(same_way.stuck_time < .5, "…instead of standing there stuck")

	# -------------------------------------------------------------
	print("· test 7")
	# Test 7: las líneas de cada camino están libres de obstáculos fijos, y los corredores van por fuera
	# -------------------------------------------------------------
	await physics_frame
	var space = game.viewport.world_3d.direct_space_state
	for lane in 4:
		var e: Vector2 = game.lane_edges(lane)
		var lines = [e.x, (e.x + e.y) * .5] if lane == 1 else [e.x, (e.x + e.y) * .5, e.y]   # path 1 narrows by its benches
		var blocked = 0
		for r in lines:
			for deg in 360:
				var shape = CapsuleShape3D.new()
				shape.radius = .30
				shape.height = 1.7
				var query = PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.transform = Transform3D(Basis.IDENTITY, game.park.polar(deg, r) + Vector3.UP * .85)
				query.collision_mask = 2
				if not space.intersect_shape(query, 1).is_empty(): blocked += 1
		check(blocked == 0, "Path %d: its lines are clear of lamps, benches and shrubs all the way round" % lane)
	print("· fresh game")
	var fresh = Main.instantiate()
	root.add_child(fresh)
	var fresh_runners = fresh.people.filter(func(q): return q.runner)
	check(fresh_runners.size() == 3 and fresh_runners.all(func(q): return q.lane >= 2 and q.direction > 0), "Three runners, on the two outer paths, all running the same way round")
	check(fresh_runners.all(func(q): var e = fresh.lane_edges(q.lane); return is_equal_approx(q.radius, (e.x + e.y) * .5)), "…on the middle line of their path")
	check(fresh.people.filter(func(q): return not q.runner).all(func(q): var e = fresh.lane_edges(q.lane); return is_equal_approx(q.radius, e.y if q.direction > 0 else e.x)), "Every walker starts on the edge to its right")
	check(fresh.people.size() == 21 and [0, 1, 2, 3].map(func(l): return fresh.people.filter(func(q): return q.lane == l).size()) == [3, 7, 6, 5], "Still 21 people: 3, 7, 6 and 5 per path")
	await frames(10)
	# Two people never walk to the same bench from opposite ends (they met face to face in front of it).
	print("· bench")
	var bench = fresh.park.benches[0]
	var first = fresh.people[3]
	var second = fresh.people[4]
	for q in fresh.people:
		q.visible = false
		q.state = "DETENIDO"
	for pair in [[first, -1.0, 3.0], [second, 1.0, -3.0]]:
		var q = pair[0]
		q.visible = true
		q.state = "CAMINANDO"
		q.lane = 1
		q.direction = pair[1]
		q.destination_lane = -1
		q.bench_goal = -1
		q.pending_stop = {}
		q.runner = false
		q.radius = fresh.home_radius(1, q.direction, false)
		q.theta = fposmod(bench.theta + rad_to_deg(pair[2] / q.radius), 360.0)
		q.place()
	fresh.set_seat(bench, 0, null)
	fresh.set_seat(bench, 1, null)
	var took = 0
	for attempt in 60:
		for q in [first, second]:
			if q.bench_goal < 0:
				if q.has_meta("bench_seen"): q.remove_meta("bench_seen")
				fresh.choose_bench(q)
		if first.bench_goal >= 0 and second.bench_goal >= 0: took += 1
	check(first.bench_goal >= 0 or second.bench_goal >= 0, "Someone takes the bench")
	check(took == 0 or first.bench_slot != second.bench_slot and fresh.ahead_of(first, fresh.seat_theta(bench, first.bench_slot)) < fresh.ahead_of(first, fresh.seat_theta(bench, second.bench_slot)), "Two people walking to one bench from opposite ends each take the place they reach first (no crossing in front of it)")

	print("NAVIGATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
