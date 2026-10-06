extends SceneTree
# Plays every arcade level automatically to prove it can be passed (docs/futuro/21 §4). It aims at
# the subject, frames it for the level's conditions, focuses on the eyes and, every half second,
# tries every aperture, shutter and ISO on the live evidence: it only shoots when a combination
# passes the conditions and the pass mark, then applies it and takes the real photo through the
# game. In the big park it starts a few metres from the subject (walking there is not the test).
#   ~/bin/godot-4-fp --path . --disable-vsync --script tools/arcade_solver.gd [-- --only=1,16]
# Prints «LEVEL n: PASS score/min» or «LEVEL n: FAIL …» and ARCADE SOLVER: passed/total.
const Main = preload("res://main.tscn")
const MainScript = preload("res://scripts/main.gd")
const Arcade = preload("res://scripts/arcade.gd")
const Conditions = preload("res://scripts/conditions.gd")
const Photo = preload("res://scripts/photography.gd")
var game

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func make_game(which: String) -> void:
	if is_instance_valid(game): game.queue_free()
	await frames(2)
	MainScript.scenario = which
	game = Main.instantiate()
	root.add_child(game)
	game.exposure_thirds = false   # (not the player's option)
	await frames(20)

# Brute force of the exposure settings on a copy of the evidence: the best passing combination.
func best_settings(e: Dictionary, level: Dictionary) -> Dictionary:
	var best = {}
	var stops = game.apertures()
	var isos = [game.equipment.film_iso_index] if game.equipment.film else range(Photo.ISOS.size())
	for n in stops.size():
		for t in Photo.DENOMINATORS.size():
			for iso in isos:
				var trial = e.duplicate()
				trial.n = stops[n]
				trial.t = 1.0/Photo.DENOMINATORS[t]
				trial.iso = Photo.ISOS[iso]
				var r = Photo.evaluate(trial)
				Conditions.apply(r,trial,level.cond)
				if not r.rejected and r.score >= level.min and (best.is_empty() or r.score > best.score):
					best = {"score":r.score,"n":n,"t":t,"iso":iso}
	return best

func solve(n: int) -> String:
	var level: Dictionary = Arcade.LEVELS[n]
	if MainScript.scenario != level.scenario or not is_instance_valid(game): await make_game(level.scenario)
	game.start_level(n)
	await frames(3)
	game.begin_assignment()
	var target = game.target
	if game.crowd:
		var away = Vector3(sin(game.angle),0,cos(game.angle))
		game.player.position = target.global_position+Vector3(4.5,0,3.0)
		game.set_raised(true)
		game.raise_anim = 1.0
	var want_h = .7
	if level.cond.has("grande"): want_h = maxf(want_h,float(level.cond.grande)+.12)
	if level.cond.has("aislado"): want_h = .85
	if level.cond.has("fondo"): want_h = maxf(want_h,.8)
	# Without a passing combination at the first framing, a looser one is tried (a child running
	# fills the frame at a focal length that no shutter speed freezes), never below what «grande» asks.
	var floor_h = float(level.cond.grande)+.06 if level.cond.has("grande") else .3
	var sweep = [.75,.55,.4,.3,.22,.6,.45] if level.cond.has("acompanado") else [want_h,maxf(floor_h,want_h*.8),maxf(floor_h,want_h*.62)]
	var aim_offset = 0.0
	var budget = float(level.limit) if level.limit > 0 else 90.0
	var elapsed = 0.0
	var tries = 0
	while elapsed < budget and game.mode in ["SEARCH","RESULT"]:
		if game.mode == "RESULT":
			if game.current_result.rejected or game.current_result.score < level.min:
				if game.shots > 0: game.resume_search()
				else: break
			else: break
		await frames(15)
		elapsed += .25
		if not is_instance_valid(target) or game.mode != "SEARCH": continue
		if game.crowd and game.player.position.distance_to(target.global_position) > 9.0:
			game.player.position = target.global_position+Vector3(4.5,0,3.0)
		game.aim_at(target,1.0)
		var h_goal: float = sweep[tries % sweep.size()]
		var d = game.camera.global_position.distance_to(target.control_points()[1])
		var want_f = h_goal*20.25*d/target.height
		if level.cond.has("focal_min"): want_f = maxf(want_f,float(level.cond.focal_min))
		game.focal = clampf(want_f,game.equipment.lens().min,game.equipment.lens().max)
		game.update_camera()
		# Golden section: turn so the chest sits on the 38 % line (on the square for the TLR).
		if level.cond.has("aurea"):
			var e0 = game.capture_evidence()
			var hfov = 2*atan(36.0/(2.0*game.focal))
			var width_frac = 9.0/16.0 if game.equipment.tlr() else 1.0
			aim_offset = (e0.chest.x-.382)*rad_to_deg(hfov)*width_frac
			game.angle += aim_offset
			game.update_camera()
		await physics_frame
		var e = game.capture_evidence()
		game.focus_distance = e.get("d_eyes",e.d)
		e.s = game.focus_distance
		tries += 1
		# A pan: the trial assumes the camera turns with the subject, as the follow below will do.
		var pans = level.cond.has("barrido")
		if pans:
			var side: float = e.get("motion_sign",1.0)
			e["camera_omega"] = e.v*side/e.d
		var best = best_settings(e,level)
		if best.is_empty():
			if OS.has_environment("SOLVER_DEBUG") and (tries % 40 == 1 or tries < 12):
				var r = Photo.evaluate(e)
				Conditions.apply(r,e,level.cond)
				print("  try %d: d %.1f f %.0f h %.2f reason %s score %d" % [tries,e.d,e.f,absf(e.feet.y-e.head.y),r.reason,r.score])
			continue
		var m = game.equipment.exposure_mode()
		if m == "A":
			game.n_index = best.n
			game.auto_expose()
		elif m == "S":
			game.t_index = best.t
			game.auto_expose()
		elif m == "P":
			pass   # the camera's own exposure (the photo is re-checked anyway)
		else:
			game.n_index = best.n
			game.t_index = best.t
			if not game.equipment.film: game.iso_index = best.iso
		game.refresh()
		if pans:
			# Follow the runner for half a second, frame by frame, and shoot without stopping.
			for i in 30:
				game.aim_at(target,1.0)
				await process_frame
			# The runner may have stopped to stretch meanwhile: wait for the next pass.
			if target.state != "CAMINANDO" or target.actual_velocity.length() < 1.5: continue
		else:
			# Aiming moved the camera; a real photographer holds still before a frozen shot.
			game.camera_omega = 0.0
		# The shot autofocuses on the active AF point: take the one nearest to the chest, as a
		# player does when the subject is off-centre (golden section, lead room).
		if game.equipment.focus_mode != "MF":
			var face = game.view_rect.position+Vector2(e.chest.x,e.chest.y)*game.view_rect.size
			var points: Array = game.finder.points()
			var nearest = 4
			for i in points.size():
				if points[i].distance_to(face) < points[nearest].distance_to(face): nearest = i
			game.finder.active = nearest
		if OS.has_environment("SOLVER_DEBUG"): print("  before: locks %s %s · point %d · t 1/%d n %s iso %d · meter %s" % [str(game.exposure_locked),str(game.focus_locked),game.finder.active,game.shutter_denominator(),str(game.aperture_value()),game.iso_value(),str(game.measured_ev)])
		await game.take_photo()
		if OS.has_environment("SOLVER_DEBUG"):
			var cr: Dictionary = game.current_result
			print("  shot: expected %d, got %d · %s · %s" % [best.score,cr.score,cr.get("reason",""),"foco %s expo %s mov %s ocl %s enc %s delta %s" % [str(cr.focus),str(cr.exposure),str(cr.movement),str(cr.occlusion),str(cr.framing),str(cr.delta)]])
	if game.mode == "RESULT": game.end_level()
	elif game.mode == "SEARCH": game.end_level()
	var passed = not game.best.is_empty() and not game.best.rejected and game.best.score >= level.min
	if passed: return "PASS %d/%d" % [game.best.score,level.min]
	return "FAIL %s (best %s, %d tries)" % [game.best.get("reason","") if not game.best.is_empty() else "no photo",str(game.best.get("score","-")),tries]

func run() -> void:
	Arcade.SAVE = "user://arcade_solver.cfg"
	var only = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = Array(arg.trim_prefix("--only=").split(",")).map(func(x): return int(x)-1)
	Engine.time_scale = 2.0
	var passed = 0
	var total = 0
	for n in Arcade.LEVELS.size():
		if not only.is_empty() and not n in only: continue
		var verdict = await solve(n)
		total += 1
		if verdict.begins_with("PASS"): passed += 1
		print("LEVEL %d: %s" % [n+1,verdict])
	print("ARCADE SOLVER: %d/%d" % [passed,total])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	quit(0 if passed == total else 1)
