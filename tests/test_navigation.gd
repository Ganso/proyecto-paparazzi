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
	check(absf(p1.radius - game.LANES[1]) <= game.LANE_OFFSETS[1] + 0.1, "P1 stays within wide lane band")
	check(absf(p2.radius - game.LANES[1]) <= game.LANE_OFFSETS[1] + 0.1, "P2 stays within wide lane band")
	
	# -------------------------------------------------------------
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
	p1.place()
	p2.place()
	
	var runner_overtook = false
	for step in 16:
		game.update_person(p1, 0.1)
		game.update_person(p2, 0.1)
		if p2.theta > p1.theta and p2.theta < 340.0:
			runner_overtook = true
	
	check(runner_overtook, "Faster runner smoothly overtakes slower pedestrian")
	check(p2.stuck_time < 0.2, "Runner does not deadlock or freeze while overtaking")
	
	# -------------------------------------------------------------
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
	
	for step in 30:
		game.update_person(walker, 0.1)
	
	check(walker.theta > 282.0, "Walker bypasses frontal obstacle")
	check(walker.stuck_time < 0.2, "Walker bypasses obstacle without getting stuck")
	check(absf(walker.radius - game.LANES[2]) > 0.15, "Walker shifted radius laterally to avoid obstacle")
	
	print("NAVIGATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
