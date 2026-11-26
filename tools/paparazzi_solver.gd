extends SceneTree
# Paparazzi's automatic player (docs/futuro/29 §19.4): it knows who the person is, walks up to her
# (in the big park it stands about 8 m away, in front, to the side or with the landmark behind her,
# as the request needs), locks on, zooms as the traffic light advises until it turns green and
# shoots. It measures how long each level takes to frame and, with that, simulates the clock of a
# run for an average player (solver × 2.5, walking at 1.4 m/s) and a good one (× 1.6, running at
# 2.2 m/s, first try), adding the walk to the person (the distance at the start) and the search
# (3 s per 10 m).
#   ~/bin/godot-4-fp --path . --disable-vsync --script tools/paparazzi_solver.gd [-- --from=1 --to=120 --repeat=1]
# Prints «LEVEL n: PASS t=… s walk=… m» or «LEVEL n: FAIL reason», the median by stretch, the
# simulated runs and «PAPARAZZI SOLVER: passed/total». Never writes the player's files.
const Paparazzi = preload("res://scripts/paparazzi.gd")
const Framing = preload("res://scripts/framing.gd")
const MainScript = preload("res://scripts/main.gd")
const SEARCH_PER_10M = 3.0
var game
var pz

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func run() -> void:
	var from = 1
	var to = 120
	var repeat = 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="): from = int(arg.trim_prefix("--from="))
		if arg.begins_with("--to="): to = int(arg.trim_prefix("--to="))
		if arg.begins_with("--repeat="): repeat = int(arg.trim_prefix("--repeat="))
	Paparazzi.SAVE = "user://paparazzi_solver.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Paparazzi.SAVE))
	preload("res://scripts/album.gd").DIR = "user://album_solver"
	preload("res://scripts/texts.gd").set_language("es",false)
	MainScript.scenario = "grande"
	Paparazzi.run = {"seed":7}
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	game.pad_polling = false
	await frames(30)
	pz = game.pz
	# Every card counts as seen: the solver does not read.
	for card in Paparazzi.all_cards(): Paparazzi.mark_seen(card)
	var times = {}          # n → [frame seconds]
	var walks = {}          # n → [metres]
	var passed = 0
	var total = 0
	var fails = {}
	for r in repeat:
		for n in range(from,to+1):
			total += 1
			var result = await solve(n,r)
			if result.ok:
				passed += 1
				times[n] = times.get(n,[])+[result.t]
				walks[n] = walks.get(n,[])+[result.walk]
				print("LEVEL %d: PASS t=%.1f s walk=%.0f m" % [n,result.t,result.walk])
			else:
				fails[result.why] = int(fails.get(result.why,0))+1
				print("LEVEL %d: FAIL %s" % [n,result.why])
	# The median by stretch.
	print("--- Mediana por tramo (s de encuadre · m de paseo) ---")
	for t in range((from-1)/10+1,(to-1)/10+2):
		var ts = []
		var ws = []
		for n in range((t-1)*10+1,t*10+1):
			ts += times.get(n,[])
			ws += walks.get(n,[])
		if ts.is_empty(): continue
		ts.sort()
		ws.sort()
		print("TRAMO %d: mediana %.1f s · paseo %.0f m · bonificación %.1f s" % [t,ts[ts.size()/2],ws[ws.size()/2],Paparazzi.bonus((t-1)*10+5)])
	if from == 1:
		for kind in [["medio",2.5,1.4],["bueno",1.6,2.2]]:
			print("JUGADOR %s (×%.1f, %.1f m/s): llega al nivel %d" % [kind[0],kind[1],kind[2],simulate(times,walks,kind[1],kind[2],to)])
	print("FALLOS: %s" % str(fails))
	print("PAPARAZZI SOLVER: %d/%d" % [passed,total])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Paparazzi.SAVE))
	quit()

# A run from level 1 with the clock of §3.1: each level costs factor × the solver's time plus the
# walk and the search; the rescue once. Returns the level where the clock runs out.
func simulate(times: Dictionary, walks: Dictionary, factor: float, speed: float, last: int) -> int:
	var bank = Paparazzi.START_BANK
	var rescue = true
	for n in range(1,last+1):
		var spec = Paparazzi.level_spec(n)
		# (A level the solver could not do counts as its stretch's middle one: a player moves round.)
		var key = n if times.has(n) else stretch_middle(times,n)
		if key < 0: return n
		var t = median(times[key])*factor
		var d = median(walks[key])
		var cost = t+d/speed+d/10.0*SEARCH_PER_10M
		if spec.clock:
			bank -= cost
			if bank <= 0.0:
				if not rescue: return n
				rescue = false
				bank += Paparazzi.RESCUE_TIME
				if bank <= 0.0: return n
			bank = Paparazzi.after_success(bank,spec,{"first_try":factor < 2.0,"hito":spec.hito})
	return last+1

func stretch_middle(times: Dictionary, n: int) -> int:
	var same = times.keys().filter(func(m): return (m-1)/10 == (n-1)/10)
	if same.is_empty(): return -1
	same.sort()
	return same[same.size()/2]

func median(a: Array) -> float:
	var s = a.duplicate()
	s.sort()
	return s[s.size()/2]

# One level, from its card to the photo that passes it (three in a reportage).
func solve(n: int, r: int) -> Dictionary:
	Paparazzi.run = {}
	pz.start(n)
	Paparazzi.run.seed = 1000*r+n
	await frames(3)
	await dismiss()
	var walk = game.camera.global_position.distance_to(game.target.global_position)
	var spent = 0.0
	var attempt = 0
	var t0 = Time.get_ticks_msec()
	while pz.spec.n == n and pz.active:
		if Time.get_ticks_msec()-t0 > 45000:
			return {"ok":false,"why":"tiempo "+str(pz.live.get("reasons",[]).map(func(x): return x.key))}
		if game.mode == "PZ_CARD":
			await dismiss()
			continue
		if game.mode == "PZ_RESCUE": pz.use_rescue()
		pz.bank = 100.0          # (the solver measures; it never runs out of time)
		place(attempt)
		attempt += 1
		await frames(2)
		var frame_t0 = Time.get_ticks_msec()
		var shot = await frame_and_shoot()
		spent += (Time.get_ticks_msec()-frame_t0)/1000.0
		if not shot: continue
	return {"ok":pz.spec.n != n,"t":spent,"walk":walk,"why":""}

func dismiss() -> void:
	for i in 30:
		if game.mode == "PZ_POLAROID":
			await process_frame
			continue
		if game.mode != "PZ_CARD": return
		if pz.brief_open: pz.begin_search()
		else: game.modal.find_children("*","Button",true,false)[0].pressed.emit()
		await frames(2)

# Where to stand: 8 m from the person; in front of her for «de frente», at her side for «de
# perfil», with the landmark behind her for «con el sitio».
func place(attempt = 0) -> void:
	var p = game.target
	if not game.camera_raised: game.set_raised(true)
	game.raise_anim = 1.0
	var at: Vector3 = p.global_position
	var heading: Vector3 = p.actual_velocity if p.actual_velocity.length() > .2 else -p.global_basis.z
	heading.y = 0
	heading = heading.normalized() if heading.length() > .01 else Vector3.FORWARD
	var mods: Dictionary = pz.current_request().get("mods",{})
	var dir: Vector3
	if mods.has("frente"): dir = heading
	elif mods.has("perfil"): dir = heading.cross(Vector3.UP)
	elif mods.has("lugar"):
		var spot: Vector3 = game.park.places.get(mods.lugar,Vector3.ZERO)
		dir = Vector3(at.x-spot.x,0,at.z-spot.z).normalized()
	else:
		dir = Vector3(game.player.global_position.x-at.x,0,game.player.global_position.z-at.z)
		dir = dir.normalized() if dir.length() > .1 else Vector3(0,0,1)
	# Another try: round the person (70° each time), as a player looks for another angle.
	if attempt > 0 and not mods.has("frente") and not mods.has("perfil"): dir = dir.rotated(Vector3.UP,deg_to_rad(70.0*attempt))
	var d = 8.0
	if pz.current_request().plane in ["general"] or mods.has("lugar"): d = 14.0
	game.player.global_position = Vector3(at.x,0,at.z)+dir*d
	game.camera.position = game.player.position+Vector3.UP*game.eye_height
	game.update_camera()

# Locks on, zooms by the light's advice until green, and shoots: whether a photo was taken.
func frame_and_shoot() -> bool:
	var plane: String = pz.current_request().plane
	if plane == Paparazzi.ANY: plane = "medio"
	var p = game.target
	var to = p.global_position-game.camera.global_position
	game.focal = clampf(Framing.focal_for(plane,Framing.rest_heights(p),Vector2(to.x,to.z).length()),24.0,600.0)
	game.update_camera()
	game.aim_at(p,1.0)
	pz.release()
	# Framing by hand (stretch 10): the crown under the top edge first, then locked there.
	if not pz.spec.auto_frame:
		var w = Framing.world_landmarks(p)
		game.aim_point(w.crown if plane != "entero" and plane != "general" else (w.crown+w.feet)*.5,Vector2(.5,Framing.AIR if plane != "entero" and plane != "general" else .5),1.0)
	pz.lock(p)
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec()-t0 < 12000:
		await frames(2)
		if game.mode != "SEARCH": return false
		if pz.locked != p: return false
		if pz.live.is_empty(): continue
		if pz.live.ok:
			game.take_photo()
			await frames(2)
			while game.shooting or game.mode == "PZ_POLAROID": await process_frame
			return true
		match pz.live.tip:
			"mas_zoom": pz.zoom_step(1)
			"menos_zoom","cabeza": pz.zoom_step(-1)
			"apunta","tapada","se_tapa","sobra_gente","falta_gente":
				# (The follow needs a moment to bring the head in at a long focal; then, elsewhere.)
				if Time.get_ticks_msec()-t0 > 1500: return false
	return false
