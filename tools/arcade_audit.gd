extends SceneTree
# Audits every arcade level from the player's side (docs/futuro/21, «Auditoría de los niveles»):
# not «is there some combination that passes» (tools/arcade_solver.gd answers that) but «what does
# a player get who uses the camera as the level teaches». For each level it draws several
# assignments and, at several moments of each, frames the subject and works out:
#   reach     how tall the subject can come out with the level's lens (against «grande»)
#   meter     what the exposure meter reads against the light the photo is judged by
#   player    the best score within the player's reach: in P, A and S, what the camera's own
#             exposure gives for each value the player may choose; in M, the combinations that
#             leave the meter at zero (as well as whole stops allow)
#   any       the best score with any combination at all, for comparison
#   ready     seconds until the level's situation exists at all (the subject seated, backlit…)
# Conditions that depend on waiting or aiming (alone, in company, golden section, room ahead, the
# landmark, the dog) are left out here: the solver plays those.
#   ~/bin/godot-4-fp --path . --disable-vsync --script tools/arcade_audit.gd [-- --only=1,16 --draws=6 --samples=5]
# Prints «AUDIT n …» per level and «  ! …» for every sample below the pass mark.
const Main = preload("res://main.tscn")
const MainScript = preload("res://scripts/main.gd")
const Arcade = preload("res://scripts/arcade.gd")
const Conditions = preload("res://scripts/conditions.gd")
const Photo = preload("res://scripts/photography.gd")
const SETTINGS = ["ojos","grande","focal_min","focal_max","fondo","congelado","exposicion","nitido","estela","barrido","contraluz","silueta"]
var game
var draws = 6
var samples = 5

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func make_game(which: String) -> void:
	if is_instance_valid(game): game.queue_free()
	await frames(2)
	MainScript.scenario = which
	game = Main.instantiate()
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"
	root.add_child(game)
	game.exposure_thirds = false
	await frames(20)

func judge(e: Dictionary, cond: Dictionary, n: float, denominator: float, iso: float, pans: bool) -> Dictionary:
	var trial = e.duplicate()
	trial.n = n
	trial.t = 1.0/denominator
	trial.iso = iso
	if pans: trial["camera_omega"] = trial.v*trial.get("motion_sign",1.0)/trial.d
	return Conditions.judge(trial,cond)

func better(a: Dictionary, r: Dictionary, label: String) -> Dictionary:
	var score = 0 if r.rejected else int(r.score)
	if a.is_empty() or score > a.score: return {"score":score,"label":label,"r":r}
	return a

# Frames the subject as the level asks and returns the evidence (focused on the face).
func frame_subject(level: Dictionary, target) -> Dictionary:
	if game.crowd:
		# (the photographer walks up to where the lens frames the subject as the level asks)
		var lens: Dictionary = game.equipment.lens()
		var tall = maxf(.75,float(level.cond.get("grande",.5))+.2)
		var reach = clampf(target.height*minf(lens.max,50.0)/(20.25*tall),2.2,9.0)
		game.player.position = target.global_position+Vector3(.82,0,.57)*reach
		game.set_raised(true)
		game.raise_anim = 1.0
	game.aim_at(target,1.0)
	var d = game.camera.global_position.distance_to(target.control_points()[1])
	var want_h = .7
	if level.cond.has("grande"): want_h = maxf(want_h,float(level.cond.grande)+.12)
	var want_f = want_h*20.25*d/target.height
	if level.cond.has("focal_min"): want_f = maxf(want_f,float(level.cond.focal_min))
	if level.cond.has("focal_max"): want_f = minf(want_f,float(level.cond.focal_max))
	game.focal = clampf(want_f,game.equipment.lens().min,game.equipment.lens().max)
	game.update_camera()
	var tight = game.capture_evidence()
	if absf(tight.feet.y-tight.head.y) > .85:
		game.pitch += (tight.head.y-.1)*-rad_to_deg(2*atan(20.25/(2.0*game.focal)))
		game.update_camera()
	await physics_frame
	var e = game.capture_evidence()
	# The point the camera focuses and meters with: the one the matrix AF picks, or the nearest
	# one put on the subject, as a player does (the middle one on the cameras without autofocus).
	if game.equipment.focus_mode == "AF matricial": game.select_matrix_point()
	else:
		var on: Vector2 = e.chest if Photo.inside(e.chest) else e.get("eyes",e.chest)
		var points: Array = game.finder.points()
		var nearest = 4
		if game.equipment.focus_mode != "MF":
			for i in points.size():
				if points[i].distance_to(game.view_rect.position+on*game.view_rect.size) < points[nearest].distance_to(game.view_rect.position+on*game.view_rect.size): nearest = i
		game.finder.active = nearest
		var at: Vector2 = (points[nearest]-game.view_rect.position)/game.view_rect.size
		game.angle += (on.x-at.x)*rad_to_deg(2*atan(36.0/(2.0*game.focal)))*(9.0/16.0 if game.equipment.tlr() else 1.0)
		if Photo.inside(e.chest): game.pitch -= (on.y-at.y)*rad_to_deg(2*atan(20.25/(2.0*game.focal)))
		game.update_camera()
		await physics_frame
		e = game.capture_evidence()
	e.s = e.get("d_eyes",e.d)
	game.focus_distance = e.s
	return e

func audit(n: int) -> void:
	var level: Dictionary = Arcade.LEVELS[n]
	if MainScript.scenario != level.scenario or not is_instance_valid(game): await make_game(level.scenario)
	var thirds: bool = level.cond.has("exposicion")
	game.exposure_thirds = thirds
	var cond = {}
	for key in level.cond:
		if key in SETTINGS: cond[key] = level.cond[key]
	var pans: bool = level.cond.has("barrido")
	var rows = []
	var notes = []
	var waits = []
	var skipped = {}
	for k in draws:
		game.start_level(n)
		await frames(3)
		game.begin_assignment()
		game.ui.visible = false
		var target = game.target
		var waited = 0.0
		for s in samples:
			# Let the park move on, and wait for the level's situation where it has one.
			var t0 = waited
			while true:
				# (the game's own clock: with the window hidden the compositor may stop the frames)
				var tick: float = game.total_time
				await frames(30)
				waited += game.total_time-tick
				if not is_instance_valid(target) or game.mode != "SEARCH": break
				if waited-t0 > 240.0: break
				var kind = str(level.get("target",""))
				if kind == "runner" and (target.state != "CAMINANDO" or target.actual_velocity.length() < 2.4): continue
				if kind == "activity" or level.cond.has("contraluz") or level.cond.has("silueta"):
					var peek = await frame_subject(level,target)
					if kind == "activity" and str(peek.get("activity","")) == "": continue
					if (level.cond.has("contraluz") or level.cond.has("silueta")) and not Conditions.backlit(peek): continue
				elif waited-t0 < 6.0: continue
				break
			if not is_instance_valid(target) or game.mode != "SEARCH": break
			if s == 0: waits.append(waited)
			var e = await frame_subject(level,target)
			# (someone or something in front: that moment is not the level's fault)
			for retry in 12:
				if e.blockers.is_empty(): break
				await frames(20)
				e = await frame_subject(level,target)
			if not e.blockers.is_empty():
				skipped["tapado"] = skipped.get("tapado",0)+1
				continue
			# (nor a framing of this tool's that leaves the face out)
			if not Photo.inside(e.get("eyes",e.chest)) or not e.in_front:
				skipped["sin encuadrar"] = skipped.get("sin encuadrar",0)+1
				continue
			if str(level.get("target","")) == "runner" and e.v < 1.5:
				skipped["no corre de lado"] = skipped.get("no corre de lado",0)+1
				continue
			var h = absf(e.feet.y-e.head.y)
			game.update_meter()
			var meter: float = game.measured_ev
			e["metered"] = meter
			var mode: String = game.equipment.exposure_mode()
			var stops: Array = game.apertures()
			var isos = [game.equipment.film_iso_index] if game.equipment.film else range(Photo.ISOS.size())
			var shutters = []
			for t in range(game.fastest_index(),Photo.DENOMINATORS.size()):
				for third in (game.third_gap("t",t) if thirds else 1): shutters.append(game.fine_value("t",[t,third]))
			var any = {}
			for a in stops:
				for sh in shutters:
					for iso in isos: any = better(any,judge(e,cond,a,sh,Photo.ISOS[iso],pans),"f/%s 1/%d ISO %d" % [str(a),sh,Photo.ISOS[iso]])
			var player = {}
			var follow_bad = 0
			var follow_all = 0
			if mode == "M":
				var slack = .17 if thirds else .5
				for a in stops:
					for sh in shutters:
						for iso in isos:
							var off = Photo.ev(a,1.0/sh,Photo.ISOS[iso],meter)
							# (a silhouette is exposed one to two stops under the meter, as its briefing says)
							var wanted = (off >= .75 and off <= 2.25) if level.cond.has("silueta") else absf(off) <= slack
							if not wanted: continue
							var r = judge(e,cond,a,sh,Photo.ISOS[iso],pans)
							player = better(player,r,"f/%s 1/%d ISO %d" % [str(a),sh,Photo.ISOS[iso]])
							if level.cond.has("silueta"):
								follow_all += 1
								if r.get("conditions",[]).any(func(c): return c.key == "silueta" and not c.ok): follow_bad += 1
			else:
				var comps = range(game.equipment.EV_COMPENSATIONS.size()) if level.cond.has("contraluz") else [game.equipment.EV_COMPENSATIONS.find(0.0)]
				var choices = [0]
				if mode == "A": choices = range(stops.size())
				if mode == "S": choices = range(game.fastest_index(),Photo.DENOMINATORS.size())
				for comp in comps:
					game.equipment.ev_comp_index = comp
					for c in choices:
						if mode == "A": game.n_index = c
						if mode == "S": game.t_index = c
						game.fine = {"n":0,"t":0,"iso":0}
						game.auto_expose()
						var r = judge(e,cond,game.aperture_value(),game.shutter_denominator(),game.iso_value(),pans)
						var label = "f/%s 1/%d ISO %d%s" % [str(game.aperture_value()),game.shutter_denominator(),game.iso_value()," comp %+.1f" % game.equipment.exposure_compensation() if comps.size() > 1 else ""]
						player = better(player,r,label)
						if level.cond.has("contraluz") and absf(game.equipment.exposure_compensation()-2.0) < .01:
							follow_all += 1
							if r.get("conditions",[]).any(func(c2): return c2.key == "contraluz" and not c2.ok): follow_bad += 1
				game.equipment.ev_comp_index = game.equipment.EV_COMPENSATIONS.find(0.0)
			if player.is_empty(): player = {"score":0,"label":"nada al alcance","r":{"focus":0.0,"exposure":0.0,"movement":0.0,"occlusion":0.0,"framing":0.0,"delta":0.0,"reason":"ninguna combinación deja el exposímetro en cero"}}
			var row = {"h":h,"reach":game.subject_reach(target,target.lane) if not game.crowd else 9.0,"ev":float(e.scene_ev)+float(e.get("ev_shift",0.0))*0.0,"meter":meter-float(e.scene_ev),"player":player.score,"any":any.get("score",0),"d":float(e.d),"tall":float(target.height),"lane":int(target.lane),"follow_bad":follow_bad,"follow_all":follow_all}
			rows.append(row)
			if absf(row.meter) > .7:
				var under = game.point_hit(game.finder.points()[game.finder.active])
				var what = "nada" if under.is_empty() else ("el sujeto" if under.collider.has_meta("person") and under.collider.get_meta("person") == target else ("otra persona" if under.collider.has_meta("person") else "decorado"))
				notes.append("  ~ fotómetro %+.1f: sujeto EV %.1f, punto %d sobre %s, enfoque %s, pecho en %s" % [row.meter,row.ev,game.finder.active,what,game.equipment.focus_mode,str(e.chest)])
			var pr: Dictionary = player.r
			if player.score < level.min:
				notes.append("  ! %.2f m, camino %d, a %.1f m, EV %.1f (fotómetro %+.1f), h %d %% · jugador %d con %s [foco %d expo %d mov %d ocl %d enc %d, ΔEV %+.1f] %s · cualquiera %d con %s" % [row.tall,row.lane,row.d,row.ev,row.meter,roundi(h*100),player.score,player.label,roundi(pr.focus*100),roundi(pr.exposure*100),roundi(pr.movement*100),roundi(pr.occlusion*100),roundi(pr.framing*100),pr.delta,str(pr.get("reason","")),any.get("score",0),any.get("label","-")])
		if game.mode in ["SEARCH","RESULT"]: game.end_level()
	if rows.is_empty():
		print("AUDIT %d: sin muestras %s" % [n+1,str(skipped)])
		return
	var col = func(key: String) -> Array:
		var values = rows.map(func(r): return float(r[key]))
		values.sort()
		return values
	var players: Array = col.call("player")
	var anys: Array = col.call("any")
	var evs: Array = col.call("ev")
	var meters: Array = col.call("meter")
	var hs: Array = col.call("h")
	var passing = rows.filter(func(r): return r.player >= level.min).size()
	var follow = ""
	var bad = 0
	var all = 0
	for r in rows:
		bad += int(r.follow_bad)
		all += int(r.follow_all)
	if all > 0: follow = " · siguiendo el texto fallan la condición %d de %d" % [bad,all]
	waits.sort()
	print("AUDIT %d (mín %d, %s): al alcance del jugador %d/%d muestras · nota jugador %d–%d (mediana %d) · cualquiera %d–%d · EV %.1f–%.1f · fotómetro %+.1f…%+.1f · altura %d–%d %%%s%s" % [n+1,level.min,game.equipment.exposure_mode(),passing,rows.size(),players[0],players[-1],players[players.size()/2],anys[0],anys[-1],evs[0],evs[-1],meters[0],meters[-1],roundi(hs[0]*100),roundi(hs[-1]*100)," · listo a los %d–%d s (límite %d)" % [waits[0],waits[-1],int(level.limit)] if not waits.is_empty() else "",follow])
	for line in notes.slice(0,10): print(line)
	if notes.size() > 10: print("  ! … y %d notas más" % (notes.size()-10))

func run() -> void:
	Arcade.SAVE = "user://arcade_solver.cfg"
	var only = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = Array(arg.trim_prefix("--only=").split(",")).map(func(x): return int(x)-1)
		if arg.begins_with("--draws="): draws = int(arg.trim_prefix("--draws="))
		if arg.begins_with("--samples="): samples = int(arg.trim_prefix("--samples="))
	Engine.time_scale = 3.0
	for n in Arcade.LEVELS.size():
		if not only.is_empty() and not n in only: continue
		await audit(n)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	print("AUDIT FIN")
	quit()
