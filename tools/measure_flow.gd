extends SceneTree
# How freely the crowd of the classic park moves (docs/NAVEGACION_Y_COLISIONES.md §6): simulates
# several minutes and reports, for the runners and for the walkers, how much of their own speed
# they really reach, how long they spend held up behind someone and how often a jam is solved by
# turning back. It is the measure behind the right-of-way rules: run it before and after touching
# walk_step().
#   ~/bin/godot-4-fp --path . --disable-vsync --script tools/measure_flow.gd [-- --seconds=300 --level=10]
# Prints FLOW lines (one per runner, one for the walkers) and FLOW SUMMARY.
const Main = preload("res://main.tscn")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var seconds = 300.0
	var level = -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = float(arg.get_slice("=",1))
		if arg.begins_with("--level="): level = int(arg.get_slice("=",1))-1
	var game = Main.instantiate()
	root.add_child(game)
	game.exposure_thirds = false   # (not the player's option)
	for i in 10: await process_frame
	if level >= 0:
		load("res://scripts/arcade.gd").SAVE = "user://arcade_flow.cfg"
		game.start_level(level)
		for i in 3: await process_frame
		game.begin_assignment()
	else:
		game.start_session(false,true)
	game.mode = "TEST"
	var dt = 1.0/30.0
	var steps = int(seconds/dt)
	var stats = {}
	for p in game.people: stats[p] = {"walk":0,"speed":0.0,"free":0,"held":0,"turns":0,"dir":p.direction,"stops":0,"was_slow":false}
	var debug = "--debug" in OS.get_cmdline_user_args()
	var jams_seen = 0
	var last_dir = {}
	for p in game.people: last_dir[p] = p.direction
	for step in steps:
		for p in game.people: game.update_person(p,dt)
		if debug and game.jam_turns != jams_seen and jams_seen < 12:
			# Who gave up and turned back, and who was around.
			jams_seen = game.jam_turns
			for p in game.people:
				if p.direction == last_dir[p] or p.state != "CAMINANDO": continue
				print("FLOW JAM t=%.0f %s" % [step*dt,describe(p)])
				for q in game.people:
					if q == p or not q.visible: continue
					var a = deg_to_rad(fposmod((q.theta-p.theta)*last_dir[p]+180.0,360.0)-180.0)*p.radius
					if absf(a) < 4.0 and absf(q.radius-p.radius) < 1.7: print("      %+.1f m ahead %s" % [a,describe(q)])
		for p in game.people: last_dir[p] = p.direction
		for p in game.people:
			if not p.visible or p.state != "CAMINANDO" or not p.pending_stop.is_empty() or p.bench_goal >= 0: continue
			var s = stats[p]
			var own: float = p.speed*(1.0 if p.runner else game.walk_pace)*(.8 if p.activity == "movil" else 1.0)
			s.walk += 1
			s.speed += p.v_fwd/own
			if p.v_fwd >= own*.8: s.free += 1
			var slow = p.v_fwd < own*.4
			if slow: s.held += 1
			if slow and not s.was_slow: s.stops += 1
			s.was_slow = slow
			if p.direction != s.dir:
				s.turns += 1
				s.dir = p.direction
	if "--edges" in OS.get_cmdline_user_args():
		# Is every line of every path clear of fixed things all the way round?
		await physics_frame
		var space = game.viewport.world_3d.direct_space_state
		for lane in 4:
			var e = game.lane_edges(lane)
			for r in [e.x,(e.x+e.y)*.5,e.y]:
				var blocked = []
				for deg in 360:
					var shape = CapsuleShape3D.new()
					shape.radius = .30
					shape.height = 1.7
					var q = PhysicsShapeQueryParameters3D.new()
					q.shape = shape
					q.transform = Transform3D(Basis.IDENTITY,game.park.polar(deg,r)+Vector3.UP*.85)
					q.collision_mask = 2
					var hits = space.intersect_shape(q,1)
					if not hits.is_empty(): blocked.append("%d° %s" % [deg,str(hits[0].collider.get_meta("label","?"))])
				print("FLOW EDGE path %d line r=%.2f: %s" % [lane,r,"clear" if blocked.is_empty() else "%d° blocked (%s…)" % [blocked.size(),blocked[0]]])
	var by_lane = {}
	for p in game.people:
		if p.runner or stats[p].walk == 0: continue
		if not by_lane.has(p.lane): by_lane[p.lane] = {"walk":0,"free":0,"turns":0}
		by_lane[p.lane].walk += stats[p].walk
		by_lane[p.lane].free += stats[p].free
		by_lane[p.lane].turns += stats[p].turns
	for lane in by_lane: print("FLOW walkers ending on path %d: at full speed %.0f %% · %d turn-backs" % [lane,100.0*by_lane[lane].free/by_lane[lane].walk,by_lane[lane].turns])
	var runner_free = []
	var walker = {"walk":0,"speed":0.0,"free":0,"held":0,"turns":0,"stops":0}
	for p in game.people:
		var s = stats[p]
		if s.walk == 0: continue
		if p.runner:
			var share = 100.0*s.free/s.walk
			runner_free.append(share)
			print("FLOW runner lane %d%s: %.0f %% of its speed on average · at full speed %.0f %% of the time · held up %.0f %% · %d slow-downs · %d turn-backs" % [p.lane," (target)" if p.protected_target else "",100.0*s.speed/s.walk,share,100.0*s.held/s.walk,s.stops,s.turns])
		else:
			for k in walker: walker[k] += s[k]
	print("FLOW walkers: %.0f %% of their speed on average · at full speed %.0f %% of the time · held up %.0f %% · %d slow-downs · %d turn-backs in %d s" % [100.0*walker.speed/maxf(1,walker.walk),100.0*walker.free/maxf(1,walker.walk),100.0*walker.held/maxf(1,walker.walk),walker.stops,walker.turns,int(seconds)])
	print("FLOW SUMMARY: runners at full speed %.0f %% of the time (worst %.0f %%) · walkers at full speed %.0f %% · jams solved by turning back: %d" % [runner_free.reduce(func(a,b): return a+b,0.0)/maxf(1,runner_free.size()),runner_free.min() if not runner_free.is_empty() else 0.0,100.0*walker.free/maxf(1,walker.walk),game.jam_turns])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://arcade_flow.cfg"))
	quit()

func describe(p) -> String:
	return "[%s%s path %d θ %.0f r %.2f dir %d v %.2f goal %.2f pass %s stuck %.1f act '%s' stop %s bench %d/%d to %d]" % [p.state," runner" if p.runner else "",p.lane,p.theta,p.radius,p.direction,p.v_fwd,p.r_goal,"-" if is_nan(p.pass_r) else "%.2f" % p.pass_r,p.stuck_time,p.activity,"yes" if not p.pending_stop.is_empty() else "no",p.bench_goal,p.bench_index,p.destination_lane]
