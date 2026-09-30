extends SceneTree
# Crowd quality over 60 simulated seconds (docs/NAVEGACION_Y_COLISIONES.md §2): nobody trembles
# (heading and sideways motion change smoothly), nobody overlaps and nobody stays jammed.
# Needs a display (physics and scene): ~/bin/godot-4-fp --path . --script tests/test_crowd.gd
const Main = preload("res://main.tscn")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	for i in 10: await process_frame
	game.start_session(false, true)
	game.mode = "TEST"
	var dt = 1.0 / 30.0
	var steps = 1800
	var headings = {}
	var lateral_sign = {}
	var flips = {}
	var last_flip = {}
	var max_turn_rate = 0.0
	var min_gap = INF
	var worst = ""
	var moving_samples = 0
	var speed_sum = 0.0
	for p in game.people:
		headings[p] = p.rotation.y
		lateral_sign[p] = 0
		flips[p] = 0
	for step in steps:
		for p in game.people: game.update_person(p, dt)
		for p in game.people:
			if not p.visible: continue
			if p.state == "CAMINANDO":
				var rate = absf(angle_difference(headings[p], p.rotation.y)) / dt
				max_turn_rate = maxf(max_turn_rate, rate)
				var s = signi(int(signf(p.v_rad) * (1 if absf(p.v_rad) > .1 else 0)))
				# Trembling = sideways direction reversing again within 1.5 s (passing someone is one
				# smooth swerve out and back, several seconds long).
				if s != 0 and lateral_sign[p] != 0 and s != lateral_sign[p]:
					if step*dt-last_flip.get(p,-9.0) < 1.5:
						flips[p] += 1
						if OS.has_environment("CROWD_DEBUG"): print("  flip t=%.1f " % (step*dt), describe(p), " side ", p.pass_side, " timer ", p.pass_timer)
					last_flip[p] = step*dt
				if s != 0: lateral_sign[p] = s
				moving_samples += 1
				speed_sum += p.actual_velocity.length()
			headings[p] = p.rotation.y
		for i in game.people.size():
			var a = game.people[i]
			if not a.visible or a.state != "CAMINANDO": continue
			for j in range(i + 1, game.people.size()):
				var b = game.people[j]
				if not b.visible or b.state != "CAMINANDO": continue
				var gap = Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()
				if gap < min_gap:
					min_gap = gap
					worst = "step %d: %s vs %s" % [step, describe(a), describe(b)]
	var worst_flips = 0
	for p in flips: worst_flips = maxi(worst_flips, flips[p])
	var jammed = game.people.filter(func(p): return p.visible and p.state == "CAMINANDO" and p.stuck_time > 2.0)
	print("CROWD: max turn %.0f°/s, worst quick lateral reversals %d in 60 s, min gap %.2f m, mean walking speed %.2f m/s, jammed %d" % [rad_to_deg(max_turn_rate), worst_flips, min_gap, speed_sum / maxf(1, moving_samples), jammed.size()])
	if min_gap < .42: print("  closest pair ", worst)
	for p in jammed: print("  jammed ", describe(p))
	for p in flips: if flips[p] > 2: print("  trembling ", describe(p), " reversals ", flips[p])
	check(rad_to_deg(max_turn_rate) <= 125.0, "Heading turns at a bounded rate (no snapping)")
	check(worst_flips <= 2, "No sideways trembling (lateral direction reversals)")
	check(min_gap >= .42, "Walkers never overlap")
	check(jammed.is_empty(), "Nobody stays jammed")
	print("CROWD TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func describe(p) -> String:
	return "[%s lane %d dest %d θ %.1f r %.2f dir %d v %.2f vr %.2f stuck %.1f act '%s' bench %d]" % [p.state, p.lane, p.destination_lane, p.theta, p.radius, p.direction, p.v_fwd, p.v_rad, p.stuck_time, p.activity, p.bench_goal]
