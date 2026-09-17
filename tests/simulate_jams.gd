extends SceneTree
const Main = preload("res://main.tscn")
var game

func _initialize() -> void:
	call_deferred("run")

func frames(count = 3) -> void:
	for i in count: await process_frame

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	await frames(10)
	game.start_session(false)
	game.begin_assignment() # starts the search phase with all 21 people walking
	
	print("--- SIMULATING 20 SECONDS OF GAMEPLAY (dt = 0.05 s) ---")
	var dt = 0.05
	var total_time = 20.0
	var steps = int(total_time / dt)
	
	var jammed_samples = 0
	for step in steps:
		if step == 40: # At t = 2.0s
			var p17 = game.people[17]
			var p18 = game.people[18]
			print("--- DETAILED CHECK AT STEP 40 (t=2.0s) ---")
			print("p17: pos=", p17.position, " theta=", p17.theta, " r=", p17.radius, " dir=", p17.direction, " stuck=", p17.stuck_time)
			print("p18: pos=", p18.position, " theta=", p18.theta, " r=", p18.radius, " dir=", p18.direction, " stuck=", p18.stuck_time)
			var dist = p17.position.distance_to(p18.position)
			print("Distance p17 to p18 = ", dist)
			var prop_theta = fposmod(p17.theta + rad_to_deg(p17.speed / p17.radius) * dt * p17.direction, 360)
			var next_pos = game.park.polar(prop_theta, p17.radius)
			print("p17 travel_clear(next_pos) = ", game.travel_clear(p17, p17.position, next_pos))
			# Check why travel_clear returned false:
			for other in game.people:
				if other == p17: continue
				var near = Geometry3D.get_closest_point_to_segment(other.position, p17.position, next_pos)
				var d = near.distance_to(other.position)
				if d < 0.65:
					print("   COLLIDING WITH other id=", game.people.find(other), " near_dist=", d, " other_pos=", other.position, " other_r=", other.radius, " other_theta=", other.theta, " other_visible=", other.visible, " other_state=", other.state)
		for p in game.people:
			game.update_person(p, dt)
		
		# Check how many pedestrians in CAMINANDO are stuck (speed ≈ 0 or stuck_time > 1.0)
		var walking = game.people.filter(func(p): return p.state == "CAMINANDO")
		var stuck = walking.filter(func(p): return p.actual_velocity.length() < 0.05)
		var high_stuck_time = walking.filter(func(p): return p.stuck_time > 1.0)
		
		if step % 40 == 0: # Every 2 seconds
			print("Time %4.1fs: %d walking, %d zero-velocity, %d stuck_time > 1.0s" % [step * dt, walking.size(), stuck.size(), high_stuck_time.size()])
			if high_stuck_time.size() > 0:
				for p in high_stuck_time:
					print("   JAMMED: id=%d lane=%d r=%.2f theta=%.1f dir=%.0f stuck_time=%.2f" % [game.people.find(p), p.lane, p.radius, p.theta, p.direction, p.stuck_time])
	
	var final_walking = game.people.filter(func(p): return p.state == "CAMINANDO")
	var final_deadlocked = final_walking.filter(func(p): return p.stuck_time > 0.8)
	var final_yielding = final_walking.filter(func(p): return p.actual_velocity.length() < 0.05)
	print("--- END OF 20s SIMULATION ---")
	print("Total walking: %d" % final_walking.size())
	print("Deadlocked pedestrians (stuck_time > 0.8s): %d" % final_deadlocked.size())
	print("Yielding/momentarily paused (single frame vel < 0.05): %d" % final_yielding.size())
	if final_deadlocked.size() > 0:
		for p in final_deadlocked:
			print("   DEADLOCKED: id=%d lane=%d r=%.2f theta=%.1f stuck_time=%.2f" % [game.people.find(p), p.lane, p.radius, p.theta, p.stuck_time])
	quit(0 if final_deadlocked.size() == 0 else 1)
