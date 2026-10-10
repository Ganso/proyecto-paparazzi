extends SceneTree
# Plays every arcade level automatically to prove it can be passed (docs/futuro/21 §4). It aims at
# the subject, frames it for the level's conditions, focuses on the eyes and, every half second,
# tries every aperture, shutter and ISO on the live evidence: it only shoots when a combination
# passes the conditions and the pass mark, then applies it and takes the real photo through the
# game. In the big park it starts a few metres from the subject (walking there is not the test).
#   ~/bin/godot-4-fp --path . --disable-vsync --script tools/arcade_solver.gd [-- --only=1,16 --repeat=3]
# SOLVER_DEBUG=1 prints every try; SOLVER_SHOTS=<folder> saves each level's briefing and result screens.
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
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"   # (never the player's album)
	root.add_child(game)
	game.exposure_thirds = false   # (not the player's option)
	await frames(20)

# Brute force of the exposure settings on a copy of the evidence: the best passing combination.
func best_settings(e: Dictionary, level: Dictionary) -> Dictionary:
	var best = {}
	var stops = game.apertures()
	var isos = [game.equipment.film_iso_index] if game.equipment.film else range(Photo.ISOS.size())
	# An exposure to the quarter of a stop is found with thirds on the shutter, as a player would.
	var shutters = []
	for t in range(game.fastest_index(),Photo.DENOMINATORS.size()):
		for third in (game.third_gap("t",t) if level.cond.has("exposicion") else 1): shutters.append([t,third])
	for n in stops.size():
		for at in shutters:
			for iso in isos:
				var trial = e.duplicate()
				trial.n = stops[n]
				trial.t = 1.0/game.fine_value("t",at)
				trial.iso = Photo.ISOS[iso]
				var r = Conditions.judge(trial,level.cond)
				if not r.rejected and r.score >= level.min and (best.is_empty() or r.score > best.score):
					best = {"score":r.score,"n":n,"t":at[0],"t_fine":at[1],"iso":iso}
	return best

func solve(n: int) -> String:
	var level: Dictionary = Arcade.LEVELS[n]
	if MainScript.scenario != level.scenario or not is_instance_valid(game): await make_game(level.scenario)
	game.exposure_thirds = level.cond.has("exposicion")
	game.start_level(n)
	await frames(3)
	if OS.has_environment("SOLVER_SHOTS"):
		await frames(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SOLVER_SHOTS").path_join("encargo_%02d.png" % (n+1)))
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
		if level.cond.has("focal_max"): want_f = minf(want_f,float(level.cond.focal_max))
		game.focal = clampf(want_f,game.equipment.lens().min,game.equipment.lens().max)
		game.update_camera()
		# A tight framing (a telephoto on someone near) is a portrait: what has to be in is the face,
		# so the camera tilts up until the head sits near the top of the frame.
		var tight = game.capture_evidence()
		if absf(tight.feet.y-tight.head.y) > .85:
			game.pitch += (tight.head.y-.1)*-rad_to_deg(2*atan(20.25/(2.0*game.focal)))
			game.update_camera()
		# Golden section: turn so the chest sits on the 38 % line (on the square for the TLR).
		if level.cond.has("aurea"):
			var e0 = game.capture_evidence()
			var hfov = 2*atan(36.0/(2.0*game.focal))
			var width_frac = 9.0/16.0 if game.equipment.tlr() else 1.0
			aim_offset = (e0.chest.x-.382)*rad_to_deg(hfov)*width_frac
			game.angle += aim_offset
			game.update_camera()
		# Room ahead: the subject on the line behind its step. A landmark: half way between the two.
		if level.cond.has("aire") or level.cond.has("lugar"):
			var e0 = game.capture_evidence()
			var hfov = rad_to_deg(2*atan(36.0/(2.0*game.focal)))
			if level.cond.has("aire"): game.angle += (e0.chest.x-(.36 if e0.motion_sign > 0 else .64))*hfov
			else:
				var place: Dictionary = e0.places.get(str(level.cond.lugar),{})
				if not place.is_empty() and place.front and absf(place.pos.x-.5) < .9: game.angle += (place.pos.x-.5)*.5*hfov
			game.update_camera()
		await physics_frame
		var e = game.capture_evidence()
		# An exposure nailed to the meter is judged against the meter: read it as the photo will,
		# with the middle point on the subject.
		if level.cond.has("exposicion"):
			game.finder.active = 4
			game.angle += (e.chest.x-.5)*rad_to_deg(2*atan(36.0/(2.0*game.focal)))
			game.update_camera()
			await physics_frame
			e = game.capture_evidence()
			game.update_meter()
			e["metered"] = game.measured_ev
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
				var r = Conditions.judge(e.duplicate(),level.cond)
				print("  try %d: d %.1f f %.0f h %.2f reason %s score %d" % [tries,e.d,e.f,absf(e.feet.y-e.head.y),r.reason,r.score])
			continue
		var m = game.equipment.exposure_mode()
		# Against the light the meter reads the sun behind: two stops of compensation for the face.
		if level.cond.has("contraluz") and m != "M": game.equipment.ev_comp_index = game.equipment.EV_COMPENSATIONS.size()-1
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
			game.set_fine("t",[best.t,best.t_fine])
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
			var on: Vector2 = e.chest if Photo.inside(e.chest) else e.get("eyes",e.chest)
			var face = game.view_rect.position+on*game.view_rect.size
			var points: Array = game.finder.points()
			var nearest = 4
			for i in points.size():
				if points[i].distance_to(face) < points[nearest].distance_to(face): nearest = i
			game.finder.active = nearest
			# …and put it on the subject, as a player does (aim_at() leads a walker by a hand's width,
			# enough for the point to slip past a chest seven metres away). Not where the level
			# places the subject in the frame itself.
			if not (level.cond.has("aurea") or level.cond.has("aire") or level.cond.has("lugar")) and not pans:
				var at: Vector2 = (points[nearest]-game.view_rect.position)/game.view_rect.size
				game.angle += (on.x-at.x)*rad_to_deg(2*atan(36.0/(2.0*game.focal)))*(9.0/16.0 if game.equipment.tlr() else 1.0)
				game.update_camera()
		if OS.has_environment("SOLVER_DEBUG"): print("  before: locks %s %s · point %d · t 1/%d n %s iso %d · meter %s" % [str(game.exposure_locked),str(game.focus_locked),game.finder.active,game.shutter_denominator(),str(game.aperture_value()),game.iso_value(),str(game.measured_ev)])
		await game.take_photo()
		if OS.has_environment("SOLVER_DEBUG"):
			var cr: Dictionary = game.current_result
			var ce: Dictionary = cr.evidence
			print("  subject: %.2f m tall, path %d · d %.2f eyes %.2f focus %.2f · head %.2f feet %.2f chest %s · pitch %.1f" % [target.height,target.lane,ce.d,ce.get("d_eyes",0.0),ce.s,ce.head.y,ce.feet.y,str(ce.chest),game.pitch])
			print("  shot: expected %d, got %d · %s · %s" % [best.score,cr.score,cr.get("reason",""),"foco %s expo %s mov %s ocl %s enc %s delta %s" % [str(cr.focus),str(cr.exposure),str(cr.movement),str(cr.occlusion),str(cr.framing),str(cr.delta)]])
	# SOLVER_SHOTS=<folder>: the result screen of each level, as evidence.
	if game.mode == "RESULT" and OS.has_environment("SOLVER_SHOTS"):
		await frames(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("SOLVER_SHOTS").path_join("nivel_%02d.png" % (n+1)))
	var clock = " · %d s de %d" % [roundi(elapsed*Engine.time_scale),int(level.limit)] if int(level.limit) > 0 else ""
	var spent = " · %d de %d disparos" % [int(level.get("shots",3))-game.shots,int(level.get("shots",3))]
	if game.mode == "RESULT": game.end_level()
	elif game.mode == "SEARCH": game.end_level()
	var passed = not game.best.is_empty() and not game.best.rejected and game.best.score >= level.min
	if passed: return "PASS %d/%d%s%s" % [game.best.score,level.min,clock,spent]
	return "FAIL %s (best %s, %d tries)" % [game.best.get("reason","") if not game.best.is_empty() else "no photo",str(game.best.get("score","-")),tries]

func run() -> void:
	Arcade.SAVE = "user://arcade_solver.cfg"
	var repeat = 1
	var only = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = Array(arg.trim_prefix("--only=").split(",")).map(func(x): return int(x)-1)
		# --repeat=N: each level N times over (another subject, another moment each time).
		if arg.begins_with("--repeat="): repeat = int(arg.trim_prefix("--repeat="))
	Engine.time_scale = 2.0
	var passed = 0
	var total = 0
	for n in Arcade.LEVELS.size():
		if not only.is_empty() and not n in only: continue
		for again in repeat:
			var verdict = await solve(n)
			total += 1
			if verdict.begins_with("PASS"): passed += 1
			print("LEVEL %d: %s" % [n+1,verdict])
	print("ARCADE SOLVER: %d/%d" % [passed,total])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	quit(0 if passed == total else 1)
