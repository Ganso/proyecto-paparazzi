extends SceneTree
# Technical probes of the Paparazzi mode (docs/futuro/29 §23): they answer on the real game the
# questions the plan leaves open before implementing it — where the body landmarks really are,
# which way people and their heads face, whether aim_point() puts a point where it says, which
# shot sizes fit on each path with a 24–600 mm zoom and how wide each one is in zoom terms, how
# well a lock-on keeps a walker framed, what a live evaluation and the capture cost, how the cast
# and the extras behave, whether the freeze stops everything, how long people sit, whether people
# cover their faces, whether a static survives a scene reload, and how the park looks at 600 mm.
# Nothing here changes the game: the ideal camera is an equipment subclass
# (tools/paparazzi_sondas/equipo_ideal.gd) plugged into the running game.
#   ~/bin/godot-4-fp --path . --disable-vsync --resolution 1600x900 --script tools/paparazzi_sondas.gd [-- --only=esqueleto,apuntar --out=<dir>]
# Probes: esqueleto orientacion clasico_orientacion apuntar planos seguimiento coste reparto congelar
# perro sentar visual gpu grande_orientacion taparse recarga. Prints «SONDA <id> · …» lines and
# writes <out>/informe_<renderer>.json and, for «visual», the captures.
const Main = preload("res://main.tscn")
const MainScript = preload("res://scripts/main.gd")
const Ideal = preload("res://tools/paparazzi_sondas/equipo_ideal.gd")
const Holder = preload("res://tools/paparazzi_sondas/estado_estatico.gd")
const Person = preload("res://scripts/person.gd")
const FRAME_MM = 20.25
const AIR = .08
const TOL = .01
const ORDER = ["general","entero","americano","medio","primer_plano","cara"]
const LANDMARKS = ["crown","eyes","chin","neck","shoulders","chest","waist","hips","knees","ankles","feet"]
const BONES = ["cabeza","cuello","clavicula.I","clavicula.D","torax","lumbar","caderas","pierna.I","pierna.D","pie.I","pie.D"]
const STANDING = ["CAMINANDO","DETENIDO"]
const BIG_PARK_PROBES = ["coste","reparto","congelar","perro","grande_orientacion","taparse","visual","gpu"]

class Driver extends Node:
	var on_frame = Callable()
	func _process(dt: float) -> void:
		if on_frame.is_valid(): on_frame.call(dt)

var game
var only: PackedStringArray = []
var out_dir = ""
var report = {}
var driver: Driver
var renderer = ""
var head_axis = Vector3.ZERO          # the head bone's local axis that looks forward (probe «orientacion»)
var head_sign = 0.0                   # how look_yaw turns it: +1 or −1

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func seconds(s: float) -> void:
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec()-t0 < s*1000.0: await process_frame

func wanted(id: String) -> bool:
	return only.is_empty() or id in only

func say(id: String, text: String) -> void:
	print("SONDA %s · %s" % [id,text])

func note(id: String, key: String, value) -> void:
	if not report.has(id): report[id] = {}
	report[id][key] = value

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.trim_prefix("--only=").split(",")
		if a.begins_with("--out="): out_dir = a.trim_prefix("--out=")
	if out_dir == "": out_dir = ProjectSettings.globalize_path("user://paparazzi_sondas")
	DirAccess.make_dir_recursive_absolute(out_dir)
	renderer = RenderingServer.get_current_rendering_method()
	driver = Driver.new()
	driver.process_priority = 1000      # after main.gd: it aims once the frame's poses are done
	root.add_child(driver)
	await make_game("clasico")
	say("arranque","perfil %s · %s · imagen %s · detalle %s" % [game.graphics_preset,renderer,str(game.viewport.size),Person.detail])
	note("arranque","perfil",game.graphics_preset)
	note("arranque","renderizador",renderer)
	note("arranque","imagen",str(game.viewport.size))
	if wanted("esqueleto"): await probe_skeleton()
	if wanted("orientacion"): await probe_facing()
	if wanted("clasico_orientacion"): await probe_classic_facing()
	if wanted("apuntar"): await probe_aim()
	if wanted("planos"): await probe_planes()
	if wanted("seguimiento"): await probe_tracking()
	if wanted("coste"): await probe_cost("clasico")
	if wanted("reparto"): await probe_cast("clasico")
	if wanted("dobles"): await probe_doubles()
	if wanted("congelar"): await probe_freeze("clasico")
	if wanted("perro"): await probe_dog("clasico")
	if wanted("sentar"): await probe_seat()
	if wanted("visual"): await probe_visual_classic()
	if wanted("gpu"): await probe_gpu("clasico")
	if BIG_PARK_PROBES.any(func(id): return wanted(id)):
		await make_game("grande")
		if wanted("coste"): await probe_cost("grande")
		if wanted("reparto"): await probe_cast("grande")
		if wanted("congelar"): await probe_freeze("grande")
		if wanted("perro"): await probe_dog("grande")
		if wanted("grande_orientacion"): await probe_big_facing()
		if wanted("taparse"): await probe_cover()
		if wanted("visual"): await probe_visual_big()
		if wanted("gpu"): await probe_gpu("grande")
	if wanted("recarga"): await probe_reload()
	var path = out_dir.path_join("informe_%s.json" % renderer)
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("SONDAS: informe en %s" % path)
	quit(0)

# ---- The game, with the ideal camera ----
func make_game(which: String) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await frames(3)
	MainScript.scenario = which
	game = Main.instantiate()
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"
	preload("res://scripts/arcade.gd").SAVE = "user://arcade_pruebas.cfg"
	root.add_child(game)
	game.exposure_thirds = false
	game.pad_polling = false
	var t0 = Time.get_ticks_msec()
	while not game.boot_done and Time.get_ticks_msec()-t0 < 90000: await process_frame
	await frames(10)
	var ideal = Ideal.new()
	ideal.preset(0)
	game.equipment = ideal
	game.apply_equipment()

func start_sandbox(tod = "day") -> void:
	driver.on_frame = Callable()
	game.start_session(tod,true)
	await frames(5)
	if game.crowd:
		game.set_raised(true)
		game.raise_anim = 1.0
	game.set_dof_blur(false)
	await frames(2)

func freeze() -> void:
	game.mode = "PROBE"          # nothing in main.gd moves people outside «SEARCH»

func unfreeze() -> void:
	game.mode = "SEARCH"

# The crowd lives on by hand, frozen to the eye: what --advance does (main.gd).
func step_world(sim_seconds: float, dt = 1.0/30) -> void:
	for s in int(sim_seconds/dt):
		for p in game.people: game.update_person(p,dt)

func extras_list() -> Array:
	return game.extras.extras if is_instance_valid(game.extras) else []

func project(w: Vector3) -> Vector2:
	return game.camera.unproject_position(w)/Vector2(game.viewport.size)

func inside(v: Vector2) -> bool:
	return v.x >= 0 and v.x <= 1 and v.y >= 0 and v.y <= 1

# docs/futuro/29 §7.4: puts a world point at a place of the picture. The closed formula (yaw and
# pitch offsets from the centre) is only exact on the horizon: with the camera tilted, a sideways
# offset on screen is not a pure turn. So it is the first guess, and the measured error on screen
# corrects it (Newton steps on the real projection); then the view moves `rate` of the way there.
var aim_iterations = 3                # 0: the closed formula alone (probe «apuntar» compares)
func aim_point(world: Vector3, screen: Vector2, rate = 1.0) -> void:
	var from = Vector2(game.angle,game.pitch)
	var to = world-game.camera.global_position
	var tan_h = tan(deg_to_rad(game.camera.fov)*.5)
	var tan_v = tan_h*float(game.viewport.size.y)/float(game.viewport.size.x)
	var want = Vector2(rad_to_deg(atan2(to.x,-to.z))-rad_to_deg(atan((screen.x-.5)*2.0*tan_h)),
		rad_to_deg(atan2(to.y,Vector2(to.x,to.z).length()))+rad_to_deg(atan((screen.y-.5)*2.0*tan_v)))
	for i in aim_iterations:
		game.angle = want.x
		game.pitch = want.y
		game.update_camera()
		if game.camera.is_position_behind(world): break
		var miss = project(world)-screen
		if miss.length() < .0002: break
		want.x += rad_to_deg(atan(miss.x*2.0*tan_h))
		want.y -= rad_to_deg(atan(miss.y*2.0*tan_v))
	game.angle = fposmod(from.x+rad_to_deg(angle_difference(deg_to_rad(from.x),deg_to_rad(want.x)))*minf(1.0,rate),360)
	game.pitch = lerpf(from.y,want.y,minf(1.0,rate))
	game.update_camera()

func set_focal(f: float) -> void:
	game.focal = f
	game.update_camera()

# ---- Landmarks and the framing prototype (docs/futuro/29 §4) ----
func world_landmarks(p) -> Dictionary:
	var g: Transform3D = p.global_transform
	var rig: Skeleton3D = p.rig
	var head_h: float = p.height/float(p.profile.relacion_cabeza)
	var hp: Transform3D = rig.get_bone_global_pose(p.bones["cabeza"])
	var o = func(id: String) -> Vector3: return g*rig.get_bone_global_pose(p.bones[id]).origin
	var foot = func(side: String) -> Vector3: return g*(rig.get_bone_global_pose(p.bones["pie."+side])*Vector3(0,-p.nz*.03,0))
	return {"crown":g*(hp*Vector3(0,head_h,0)),"eyes":g*(hp*Vector3(0,.5*head_h,0)),"chin":g*hp.origin,
		"neck":o.call("cuello"),"shoulders":(o.call("clavicula.I")+o.call("clavicula.D"))*.5,"chest":o.call("torax"),
		"waist":o.call("lumbar"),"hips":o.call("caderas"),"knees":(o.call("pierna.I")+o.call("pierna.D"))*.5,
		"ankles":(o.call("pie.I")+o.call("pie.D"))*.5,"feet":(foot.call("I")+foot.call("D"))*.5,"feet_i":foot.call("I"),"feet_d":foot.call("D")}

func screen_body(w: Dictionary) -> Dictionary:
	var out = {"behind":false}
	for k in LANDMARKS:
		if game.camera.is_position_behind(w[k]): out.behind = true
		out[k] = project(w[k])
	var a = project(w.feet_i)
	var b = project(w.feet_d)
	out.feet = a if a.y > b.y else b
	return out

func rest_of(p) -> Dictionary:
	var h: float = p.height
	var nz: float = p.nz
	return {"crown":h,"eyes":nz+.5*(h-nz),"chin":nz,"neck":.965*nz,"shoulders":.929*nz,"chest":.808*nz,"waist":.692*nz,"hips":.542*nz,"knees":.323*nz,"ankles":.03*nz,"feet":0.0}

func classify(b: Dictionary) -> Dictionary:
	if b.behind or b.eyes.x < .04 or b.eyes.x > .96 or b.eyes.y < 0 or b.eyes.y > 1: return {"plane":"","defects":["cara_fuera"]}
	if b.chin.y > 1: return {"plane":"","defects":["corte_cara"]}
	var defects = []
	var plane = ""
	var mid_shin = (b.knees.y+b.ankles.y)*.5
	var tall = b.feet.y-b.crown.y
	if b.feet.y <= 1+TOL: plane = "entero" if tall >= .45 else "general"
	elif mid_shin <= 1:
		plane = "entero"
		defects.append("pies")
	elif b.hips.y <= 1: plane = "americano"
	elif b.chest.y <= 1: plane = "medio"
	elif b.shoulders.y <= 1: plane = "primer_plano"
	else: plane = "cara"
	if plane != "cara" and b.crown.y < -TOL: defects.append("cabeza")
	if plane == "cara" and b.eyes.y < .10: defects.append("cabeza")
	if b.crown.y >= 0:
		if plane in ["medio","primer_plano","cara"] and b.crown.y > .25: defects.append("aire")
		if plane == "americano" and b.crown.y > .30: defects.append("aire")
	return {"plane":plane,"defects":defects}

func cut_middle(plane: String, r: Dictionary) -> float:
	match plane:
		"cara": return (r.chin+r.shoulders)*.5
		"primer_plano": return (r.shoulders+r.chest)*.5
		"medio": return (r.chest+r.hips)*.5
		"americano": return (r.hips+(r.knees+r.ankles)*.5)*.5
	return 0.0

func plane_focal(plane: String, r: Dictionary, d: float) -> float:
	match plane:
		"entero": return .80*FRAME_MM*d/r.crown
		"general": return 24.0
	return FRAME_MM*d/((r.crown-cut_middle(plane,r))/(1.0-AIR))

# Frames someone for a shot size, as the auto-framing would (§7.4): two passes of aim_point().
func compose(p, plane: String, f: float) -> Dictionary:
	set_focal(f)
	for i in 2:
		var w = world_landmarks(p)
		if plane in ["entero","general"]: aim_point((w.crown+w.feet)*.5,Vector2(.5,.5))
		else: aim_point(w.crown,Vector2(.5,AIR))
	return screen_body(world_landmarks(p))

func visibility(p, s: Dictionary, w: Dictionary) -> Dictionary:
	var count = 0
	var seen = 0
	var face = true
	for k in LANDMARKS:
		if not inside(s[k]): continue
		count += 1
		var hit = game.ray_to(w[k])
		var ok = hit.is_empty() or (hit.collider.has_meta("person") and hit.collider.get_meta("person") == p)
		if ok: seen += 1
		elif k in ["eyes","chin"]: face = false
	return {"fraction":float(seen)/maxf(1.0,count),"face":face,"inside":count}

# Noticeable others in the frame (conditions.gd::companions(), extras included).
func others_in_frame(subject) -> Dictionary:
	var out = {"people":0,"extras":0}
	for list_i in 2:
		var list = game.people if list_i == 0 else extras_list()
		for q in list:
			if q == subject or not is_instance_valid(q) or not q.visible: continue
			if list_i == 0 and q.state == "RETIRADO": continue
			var chest_w: Vector3 = q.control_points()[1]
			if game.camera.is_position_behind(chest_w): continue
			var chest = project(chest_w)
			if not inside(chest): continue
			var top = project(q.global_position+Vector3.UP*q.height)
			var bottom = project(q.global_position)
			if absf(bottom.y-top.y) < .10: continue
			var hit = game.ray_to(chest_w)
			if hit.is_empty() or (hit.collider.has_meta("person") and hit.collider.get_meta("person") == q):
				out["people" if list_i == 0 else "extras"] += 1
	return out

# Yaw of a horizontal direction in the game's convention (heading = atan2(−v.x, −v.z)).
func yaw_of(v: Vector3) -> float:
	return atan2(-v.x,-v.z)

func body_facing(p, from: Vector3) -> float:
	var to = from-p.global_position
	return rad_to_deg(absf(angle_difference(p.rotation.y,yaw_of(to))))

func head_yaw(p) -> float:
	var basis: Basis = p.global_transform.basis*p.rig.get_bone_global_pose(p.bones["cabeza"]).basis
	return yaw_of(basis*head_axis)

func head_facing(p, from: Vector3) -> float:
	var to = from-p.global_position
	return rad_to_deg(absf(angle_difference(head_yaw(p),yaw_of(to))))

func median(values: Array) -> float:
	if values.is_empty(): return NAN
	var v = values.duplicate()
	v.sort()
	return float(v[v.size()/2])

func percentile(values: Array, q: float) -> float:
	if values.is_empty(): return NAN
	var v = values.duplicate()
	v.sort()
	return float(v[mini(v.size()-1,int(v.size()*q))])

func mean(values: Array) -> float:
	if values.is_empty(): return NAN
	var s = 0.0
	for x in values: s += float(x)
	return s/values.size()

func fmt(x: float, d = 2) -> String:
	return ("%."+str(d)+"f") % x

# ---- 1. Where the landmarks really are ----
func probe_skeleton() -> void:
	await start_sandbox("day")
	await seconds(2.0)
	freeze()
	var missing = []
	for id in BONES:
		if not game.people[0].bones.has(id): missing.append(id)
	say("esqueleto","huesos que faltan: %s" % str(missing))
	note("esqueleto","huesos_que_faltan",missing)
	if not missing.is_empty(): return
	var groups = {}
	for p in game.people+extras_list():
		if not p.visible or not p.state in STANDING: continue
		var key = "%s·%s" % [p.profile.id,"anda" if p.state == "CAMINANDO" else "quieto"]
		if not groups.has(key): groups[key] = {"n":0,"err":{},"feet":[]}
		var w = world_landmarks(p)
		var r = rest_of(p)
		var base: float = p.global_position.y
		groups[key].n += 1
		groups[key].feet.append(w.feet.y-base)
		for k in LANDMARKS:
			if not groups[key].err.has(k): groups[key].err[k] = []
			groups[key].err[k].append((w[k].y-base)-r[k])
	var table = {}
	for key in groups:
		var line = []
		table[key] = {"n":groups[key].n}
		for k in LANDMARKS:
			var e = mean(groups[key].err[k])
			table[key][k] = snappedf(e*100.0,.1)
			line.append("%s %+.1f" % [k,e*100.0])
		say("esqueleto","%s (n=%d) error del modelo de pie, cm: %s" % [key,groups[key].n,", ".join(line)])
	note("esqueleto","error_cm_por_grupo",table)

# ---- 2. Which way people and their heads face ----
func detect_head_axis() -> void:
	if head_axis != Vector3.ZERO: return
	var p = null
	for q in game.people:
		if q.visible and not q.runner and q.state in STANDING: p = q
	if p == null: return
	var saved = [p.state,p.activity,p.look_yaw,p.state_time]
	p.state = "DETENIDO"
	p.activity = ""
	p.state_time = 999.0
	p.look_yaw = 0.0
	for i in 20: p.animate(.05,0.0)
	var basis: Basis = p.global_transform.basis*p.rig.get_bone_global_pose(p.bones["cabeza"]).basis
	var body = -p.global_basis.z
	var best = -2.0
	for axis in [Vector3(0,0,-1),Vector3(0,0,1),Vector3(1,0,0),Vector3(-1,0,0)]:
		var v = basis*axis
		v.y = 0
		var d = v.normalized().dot(Vector3(body.x,0,body.z).normalized())
		if d > best:
			best = d
			head_axis = axis
	var yaw0 = head_yaw(p)
	p.look_yaw = .7
	for i in 30: p.animate(.05,0.0)
	var turn = angle_difference(yaw0,head_yaw(p))
	head_sign = signf(turn)
	say("orientacion","eje del hueso de la cabeza que mira al frente: %s (alineado %.3f) · look_yaw=+0.70 gira la cabeza %+.2f rad" % [str(head_axis),best,turn])
	note("orientacion","eje_cabeza",str(head_axis))
	note("orientacion","giro_cabeza_con_look_yaw_0.7",snappedf(turn,.01))
	p.state = saved[0]
	p.activity = saved[1]
	p.look_yaw = saved[2]
	p.state_time = saved[3]

func probe_facing() -> void:
	await start_sandbox("day")
	await seconds(3.0)
	freeze()
	var minus_z = []
	var plus_z = []
	for p in game.people:
		var v: Vector3 = p.actual_velocity
		v.y = 0
		if p.state != "CAMINANDO" or v.length() < .3: continue
		var f = -p.global_basis.z
		f.y = 0
		minus_z.append(rad_to_deg(f.angle_to(v)))
		plus_z.append(rad_to_deg((-f).angle_to(v)))
	say("orientacion","caminantes: ángulo entre −Z del cuerpo y la velocidad: media %s°, máx %s° (con +Z: media %s°) · n=%d" % [fmt(mean(minus_z),1),fmt(percentile(minus_z,1.0),1),fmt(mean(plus_z),1),minus_z.size()])
	note("orientacion","menos_z_vs_velocidad_media_grados",snappedf(mean(minus_z),.1))
	note("orientacion","menos_z_vs_velocidad_max_grados",snappedf(percentile(minus_z,1.0),.1))
	detect_head_axis()

# ---- 3. In the classic park, are walkers always seen in profile? ----
func bucket(angle: float) -> String:
	if angle <= 45: return "frente"
	if angle >= 60 and angle <= 120: return "perfil"
	if angle >= 135: return "espaldas"
	return "tres_cuartos"

func probe_classic_facing() -> void:
	await start_sandbox("day")
	freeze()
	detect_head_axis()
	var cam: Vector3 = game.camera.global_position
	var hist = {}
	for s in 120:     # 60 s, every half second
		step_world(.5)
		for p in game.people:
			if not p.visible or p.state == "RETIRADO": continue
			var key = p.state+("·corre" if p.runner else "")
			if not hist.has(key): hist[key] = {"frente":0,"perfil":0,"espaldas":0,"tres_cuartos":0,"n":0}
			hist[key][bucket(head_facing(p,cam))] += 1
			hist[key].n += 1
	for key in hist:
		var h = hist[key]
		say("clasico_orientacion","%s (n=%d): frente %d%% · perfil %d%% · tres cuartos %d%% · espaldas %d%%" % [key,h.n,100*h.frente/h.n,100*h.perfil/h.n,100*h.tres_cuartos/h.n,100*h.espaldas/h.n])
	note("clasico_orientacion","histograma_cabeza",hist)

# ---- 4. Does aim_point() put the point where it says? ----
func probe_aim() -> void:
	await start_sandbox("day")
	freeze()
	var rng = RandomNumberGenerator.new()
	rng.seed = 29
	var people = game.people.filter(func(p): return p.visible and p.state != "RETIRADO")
	for f in [24.0,50.0,200.0,600.0]:
		set_focal(f)
		var one = []
		var two = []
		var pitches = []
		for i in 40:
			var p = people[rng.randi_range(0,people.size()-1)]
			var point: Vector3 = p.control_points()[1]+Vector3(rng.randf_range(-.3,.3),rng.randf_range(-.5,.4),rng.randf_range(-.3,.3))
			aim_point(point,Vector2(.5,.5))
			var target = Vector2(rng.randf_range(.1,.9),rng.randf_range(.1,.9))
			aim_iterations = 0
			aim_point(point,target)
			one.append(project(point).distance_to(target))
			aim_iterations = 3
			aim_point(point,target)
			two.append(project(point).distance_to(target))
			pitches.append(absf(game.pitch))
		say("apuntar","%3.0f mm (inclinación hasta %s°): fórmula cerrada, error medio %s · máx %s; con 3 correcciones, máx %s (fracción del encuadre)" % [f,fmt(percentile(pitches,1.0),0),fmt(mean(one),4),fmt(percentile(one,1.0),4),fmt(percentile(two,1.0),5)])
		note("apuntar","%d_mm" % f,{"formula_media":snappedf(mean(one),.0001),"formula_max":snappedf(percentile(one,1.0),.0001),"corregida_max":snappedf(percentile(two,1.0),.00001)})

# ---- 5. Which shot sizes fit on each path, how wide each is in zoom, and is the subject alone ----
func probe_planes() -> void:
	await start_sandbox("day")
	await seconds(1.0)
	freeze()
	var cells = {}
	var bands = {}
	for snapshot in 3:
		if snapshot > 0: step_world(15.0)
		for p in game.people:
			if not p.visible or not p.state in STANDING: continue
			var w0 = world_landmarks(p)
			var d = Vector2(w0.chest.x-game.camera.global_position.x,w0.chest.z-game.camera.global_position.z).length()
			var r = rest_of(p)
			for plane in ORDER:
				var key = "camino %d · %s%s" % [p.lane,plane," · corre" if p.runner else ""]
				if not cells.has(key): cells[key] = {"n":0,"fuera":0,"ok":0,"f":[],"defectos":{},"visible":0,"cara_libre":0,"sola":0,"solo_figurantes":0,"hecho":{}}
				var c = cells[key]
				c.n += 1
				var f = plane_focal(plane,r,d)
				if f > 600.0 or f < 24.0:
					c.fuera += 1
					continue
				c.f.append(f)
				var s = compose(p,plane,f)
				var verdict = classify(s)
				c.hecho[verdict.plane] = int(c.hecho.get(verdict.plane,0))+1
				if verdict.plane == plane and verdict.defects.is_empty(): c.ok += 1
				for dfx in verdict.defects: c.defectos[dfx] = int(c.defectos.get(dfx,0))+1
				var w = world_landmarks(p)
				var vis = visibility(p,s,w)
				if vis.fraction >= .6: c.visible += 1
				if vis.face: c.cara_libre += 1
				var others = others_in_frame(p)
				if others.people+others.extras == 0: c.sola += 1
				elif others.people == 0: c.solo_figurantes += 1
				# How much zoom keeps this shot size (first snapshot only): the band, as a ratio.
				if snapshot == 0 and not plane in ["general","entero"] and not p.runner:
					var lo = INF
					var hi = 0.0
					var g = f/1.8
					while g <= minf(600.0,f*1.8):
						if classify(compose(p,plane,g)).plane == plane:
							lo = minf(lo,g)
							hi = maxf(hi,g)
						g *= 1.004
					if hi > 0.0:
						if not bands.has(plane): bands[plane] = []
						bands[plane].append(hi/lo)
	var keys = cells.keys()
	keys.sort()
	var table = {}
	for key in keys:
		var c = cells[key]
		var done = c.n-c.fuera
		table[key] = {"n":c.n,"fuera_de_rango":c.fuera,"acierta":c.ok,"f_mediana":snappedf(median(c.f),1),"f_max":snappedf(percentile(c.f,1.0),1),"defectos":c.defectos,"se_ve_60":c.visible,"cara_libre":c.cara_libre,"sola":c.sola,"solo_figurantes":c.solo_figurantes,"plano_hecho":c.hecho}
		say("planos","%s: n=%d · fuera de 24–600 %d · clasifica bien %d/%d · f mediana %s máx %s · se ve ≥60%% %d · cara libre %d · sola %d (+%d con figurantes) · defectos %s" % [key,c.n,c.fuera,c.ok,done,fmt(median(c.f),0),fmt(percentile(c.f,1.0),0),c.visible,c.cara_libre,c.sola,c.solo_figurantes,str(c.defectos)])
	note("planos","por_camino_y_plano",table)
	var band_table = {}
	for plane in bands:
		band_table[plane] = {"mediana":snappedf(median(bands[plane]),.001),"minimo":snappedf(percentile(bands[plane],0.0),.001),"n":bands[plane].size()}
		say("planos","franja de zoom de %s: mediana ×%s · mínima ×%s (n=%d) — un paso de rueda de ×1,15 %s" % [plane,fmt(median(bands[plane]),3),fmt(percentile(bands[plane],0.0),3),bands[plane].size(),"puede saltársela" if percentile(bands[plane],0.0) < 1.15 else "no se la salta"])
	note("planos","franja_de_zoom",band_table)

# ---- 6. Lock-on: how well does following keep the person framed, and is the shot size stable ----
func pick(filter: Callable):
	var list = game.people.filter(filter)
	return null if list.is_empty() else list[0]

func probe_tracking() -> void:
	var cases = [
		["andando, camino 1, primer plano",1,"primer_plano",false],
		["andando, camino 1, cara",1,"cara",false],
		["andando, camino 2, medio",2,"medio",false],
		["andando, camino 2, cara",2,"cara",false],
		["andando, camino 3, primer plano",3,"primer_plano",false],
		["corriendo, entero",-1,"entero",true],
		["corriendo, medio",-1,"medio",true],
	]
	var table = {}
	# [gain, lead]: the lead that cancels a first-order lag is 1/gain (a fixed 0.12 s overshot it).
	# [gain, lead, keep size]: the lead that cancels a first-order lag is 1/gain (a fixed 0.12 s
	# overshot it); «keep size» zooms with the distance so the shot size holds (§7.4).
	for setup in [[10.0,.12,false],[10.0,.10,false],[15.0,1.0/15.0,false],[10.0,0.0,false],[15.0,1.0/15.0,true]]:
		var gain: float = setup[0]
		var lead_s: float = setup[1]
		var keep: bool = setup[2]
		for case in cases:
			await start_sandbox("day")
			await seconds(.5)
			var p = pick(func(q): return q.visible and q.state == "CAMINANDO" and q.runner == case[3] and (case[1] < 0 or q.lane == case[1]) and q.actual_velocity.length() > .3)
			if p == null:
				say("seguimiento","%s: no hay nadie así ahora" % case[0])
				continue
			var w0 = world_landmarks(p)
			var d = Vector2(w0.chest.x,w0.chest.z).distance_to(Vector2(game.camera.global_position.x,game.camera.global_position.z))
			var f = clampf(plane_focal(case[2],rest_of(p),d),24.0,600.0)
			set_focal(f)
			for i in 3:
				var w = world_landmarks(p)
				aim_point(w.crown if case[2] != "entero" else (w.crown+w.feet)*.5,Vector2(.5,AIR) if case[2] != "entero" else Vector2(.5,.5))
			var st = {"t":0.0,"err":[],"same":0,"n":0,"done":false,"d0":d,"dmin":d,"dmax":d}
			var plane: String = case[2]
			driver.on_frame = func(dt: float) -> void:
				if st.done or not is_instance_valid(p): return
				st.t += dt
				var w = world_landmarks(p)
				var lead = signf(p.actual_velocity.dot(game.camera.global_basis.x))
				var anchor: Vector3 = (w.crown+w.feet)*.5 if plane == "entero" else w.crown
				var screen = Vector2(.5-.10*lead,.5) if plane == "entero" else Vector2(.5-.08*lead,AIR)
				var dist = Vector2(w.chest.x,w.chest.z).distance_to(Vector2(game.camera.global_position.x,game.camera.global_position.z))
				st.dmin = minf(st.dmin,dist)
				st.dmax = maxf(st.dmax,dist)
				if keep: set_focal(clampf(f*dist/st.d0,24.0,600.0))
				aim_point(anchor+p.actual_velocity*lead_s,screen,1.0-exp(-gain*dt))
				if st.t > .6:
					st.err.append(project(anchor).distance_to(screen))
					st.n += 1
					if classify(screen_body(w)).plane == plane: st.same += 1
				if st.t > 4.6: st.done = true
			while not st.done: await process_frame
			driver.on_frame = Callable()
			var key = "%s · ganancia %d, adelanto %.3f s%s" % [case[0],int(gain),lead_s," · mantiene el tamaño" if keep else ""]
			table[key] = {"f":snappedf(f,1),"d":snappedf(d,.01),"error_medio":snappedf(mean(st.err),.001),"error_p95":snappedf(percentile(st.err,.95),.001),"error_max":snappedf(percentile(st.err,1.0),.001),"plano_estable":snappedf(float(st.same)/maxf(1,st.n),.01),"fotogramas":st.n}
			table[key]["distancia_min_max"] = [snappedf(st.dmin,.01),snappedf(st.dmax,.01)]
			say("seguimiento","%s: %s mm a %s m (la distancia va de %s a %s m) · error medio %s p95 %s máx %s · mismo plano %d%% de %d fotogramas" % [key,fmt(f,0),fmt(d,1),fmt(st.dmin,2),fmt(st.dmax,2),fmt(mean(st.err),3),fmt(percentile(st.err,.95),3),fmt(percentile(st.err,1.0),3),roundi(100.0*st.same/maxf(1,st.n)),st.n])
	note("seguimiento","casos",table)

# ---- 7. What a live evaluation and a capture cost ----
func live_capture(p) -> Dictionary:
	var w = world_landmarks(p)
	var s = screen_body(w)
	return {"plane":classify(s),"vis":visibility(p,s,w),"others":others_in_frame(p)}

func probe_cost(scenario: String) -> void:
	await start_sandbox("day")
	await seconds(1.0)
	var p = null
	var best = INF
	for q in game.people:
		if not q.visible or q.state == "RETIRADO": continue
		var d = q.global_position.distance_to(game.camera.global_position)
		if d > 4.0 and d < best:
			best = d
			p = q
	if p == null: return
	set_focal(35.0)
	aim_point(p.control_points()[1],Vector2(.5,.5))
	var t0 = Time.get_ticks_usec()
	for i in 200: live_capture(p)
	var per = (Time.get_ticks_usec()-t0)/200.0
	var grabs = []
	for i in 10:
		await RenderingServer.frame_post_draw
		var t1 = Time.get_ticks_usec()
		var image = game.viewport.get_texture().get_image()
		grabs.append((Time.get_ticks_usec()-t1)/1000.0)
		if i == 0: note("coste","imagen_%s" % scenario,"%dx%d" % [image.get_width(),image.get_height()])
	say("coste","%s: evaluación en vivo %s µs (personas %d, figurantes %d) · get_image() mediana %s ms máx %s ms" % [scenario,fmt(per,0),game.people.size(),extras_list().size(),fmt(median(grabs),1),fmt(percentile(grabs,1.0),1)])
	note("coste","evaluacion_us_%s" % scenario,snappedf(per,1))
	note("coste","get_image_ms_%s" % scenario,snappedf(median(grabs),.1))

# ---- 8. The cast: look-alikes, minimal descriptions and extras that dress like someone ----
func probe_cast(scenario: String) -> void:
	var cast = game.casting
	var people = game.people.filter(func(p): return p.visible)
	var descs = people.map(func(p): return cast.descriptors(p.traits,"es"))
	var all_traits = people.map(func(p): return p.traits)
	var doubles = {}
	var minimal = {}
	var kids = 0
	for i in people.size():
		var n = 0
		for j in people.size():
			if i == j: continue
			var shared = 0
			for k in 4:
				if descs[i][k] == descs[j][k]: shared += 1
			if shared >= 2: n += 1
		doubles[n] = int(doubles.get(n,0))+1
		var m = cast.predicates_for(people[i].traits,all_traits).size()
		minimal[m] = int(minimal.get(m,0))+1
		if people[i].profile.id == "nino": kids += 1
	var extra_full = 0
	var extra_minimal = 0
	for e in extras_list():
		var ed = cast.descriptors(e.traits,"es")
		for i in people.size():
			if ed == descs[i]: extra_full += 1
			var m = cast.predicates_for(people[i].traits,all_traits).size()
			var same = true
			for k in m:
				if ed[k] != descs[i][k]: same = false
			if same: extra_minimal += 1
	say("reparto","%s: %d personas (%d niños, %d figurantes) · personas con N dobles (≥2 rasgos en común): %s · descripción mínima de 3/4 rasgos: %s · figurantes idénticos a alguien: %d en todo, %d en lo mínimo" % [scenario,people.size(),kids,extras_list().size(),str(doubles),str(minimal),extra_full,extra_minimal])
	note("reparto",scenario,{"personas":people.size(),"ninos":kids,"figurantes":extras_list().size(),"dobles":doubles,"descripcion_minima":minimal,"figurantes_identicos":extra_full,"figurantes_identicos_en_lo_minimo":extra_minimal})

# ---- 8b. Look-alikes on purpose: can the cast make them and keep everyone unique, and what does
# building a person cost (to re-dress at run time instead of when the scene loads)? ----
const Cast = preload("res://scripts/casting.gd")
const COLOUR_SLOTS = ["upper_color","lower_color","hair_color","accessory_color","glasses"]

func shared(c, a: Dictionary, b: Dictionary) -> int:
	var da = c.descriptors(a,"es")
	var db = c.descriptors(b,"es")
	var n = 0
	for k in 4:
		if da[k] == db[k]: n += 1
	return n

# A double of t sharing exactly `keep` descriptors, changing colours only (colours never break the
# casting's rules: children's clothes, skirts and coats, bald heads).
func double_of(c, t: Dictionary, keep: int, crowd: Array):
	var signatures = crowd.map(func(x): return "|".join(c.descriptors(x,"es")))
	for attempt in 200:
		var d = t.duplicate(true)
		for change in 4-keep+c.rng.randi()%2:
			var slot: String = COLOUR_SLOTS[c.rng.randi()%COLOUR_SLOTS.size()]
			match slot:
				"hair_color": d.hair_color = c.catalog.tonos_pelo.keys()[c.rng.randi()%c.catalog.tonos_pelo.size()]
				"glasses": d.glasses = c.rng.randi()%c.catalog.piezas.gafas.size()
				_: d[slot] = c.catalog.tonos_ropa.keys()[c.rng.randi()%c.catalog.tonos_ropa.size()]
		if shared(c,d,t) == keep and not "|".join(c.descriptors(d,"es")) in signatures: return d
	return null

func probe_doubles() -> void:
	var lengths = {}
	var failures = 0
	var made = {1:0,2:0,3:0}
	var asked = {1:0,2:0,3:0}
	for trial in 300:
		var c = Cast.new(5000+trial)
		var crowd = []
		for i in 21: crowd.append(c.generate(i in [12,17,20]))
		var target: Dictionary = crowd[trial%12]
		var wanted_doubles = 1+trial%3
		asked[wanted_doubles] += 1
		var got = 0
		for k in wanted_doubles:
			var d = double_of(c,target,3 if k == 0 else 2,crowd)
			if d == null: continue
			crowd[(trial%12+1+k*3)%21] = d     # (replaces somebody else, never the target)
			got += 1
		if got == wanted_doubles: made[wanted_doubles] += 1
		var m = c.predicates_for(target,crowd).size()
		if m == 0: failures += 1
		lengths[m] = int(lengths.get(m,0))+1
	say("dobles","reparto con dobles hechos a propósito (300 pruebas): dobles conseguidos %s de %s · la buscada sigue siendo única: %d/300 (rasgos mínimos: %s)" % [str(made),str(asked),300-failures,str(lengths)])
	note("dobles","reparto",{"conseguidos":made,"pedidos":asked,"unica":300-failures,"rasgos_minimos":lengths})
	# What it costs to build one person, as populate() does.
	var times = []
	var model = game.people[0].traits
	for i in 6:
		var t0 = Time.get_ticks_usec()
		var q = Person.new()
		game.viewport.add_child(q)
		q.setup(model.duplicate(true),game.casting.catalog,9100+i)
		q.position = Vector3(0,-50,0)
		q.animate(0)
		times.append((Time.get_ticks_usec()-t0)/1000.0)
		q.queue_free()
		await frames(1)
	say("dobles","construir una persona (%s): mediana %s ms, máx %s ms" % [Person.detail,fmt(median(times),1),fmt(percentile(times,1.0),1)])
	note("dobles","construir_persona_ms",{"mediana":snappedf(median(times),.1),"max":snappedf(percentile(times,1.0),.1),"detalle":Person.detail})

# ---- 9. Does the freeze stop everything? ----
func snapshot() -> Dictionary:
	var out = {"people":game.people.map(func(p): return p.global_position),"extras":extras_list().map(func(p): return p.global_position)}
	out["dog"] = game.dog.global_position if is_instance_valid(game.dog) else Vector3.ZERO
	out["birds"] = game.pigeons.birds.map(func(b): return b.pos) if is_instance_valid(game.pigeons) else []
	out["ducks"] = game.ducks.ducks.map(func(d): return d.angle) if is_instance_valid(game.ducks) else []
	return out

func moved(a: Dictionary, b: Dictionary) -> Dictionary:
	var out = {}
	for key in ["people","extras","birds"]:
		var most = 0.0
		for i in mini(a[key].size(),b[key].size()): most = maxf(most,a[key][i].distance_to(b[key][i]))
		out[key] = snappedf(most,.001)
	out["dog"] = snappedf(a.dog.distance_to(b.dog),.001)
	var duck = 0.0
	for i in mini(a.ducks.size(),b.ducks.size()): duck = maxf(duck,absf(a.ducks[i]-b.ducks[i]))
	out["ducks"] = snappedf(duck,.0001)
	return out

func probe_freeze(scenario: String) -> void:
	await start_sandbox("day")
	await seconds(1.0)
	game.set_sandbox_pause(true)
	await frames(2)
	var a = snapshot()
	await seconds(5.0)
	var still = moved(a,snapshot())
	game.set_sandbox_pause(false)
	var b = snapshot()
	await seconds(2.0)
	var after = moved(b,snapshot())
	say("congelar","%s: en 5 s congelado se mueven como mucho (m) %s · al soltar, en 2 s: %s" % [scenario,str(still),str(after)])
	note("congelar",scenario,{"congelado":still,"suelto":after})

# ---- 10. The dog and its walker ----
func probe_dog(scenario: String) -> void:
	var ok = is_instance_valid(game.dog) and is_instance_valid(game.dog.walker)
	var walker_in = ok and game.dog.walker in game.people
	say("perro","%s: perro %s · su paseante está en main.people: %s · distancia %s m" % [scenario,"sí" if ok else "no",str(walker_in),fmt(game.dog.global_position.distance_to(game.dog.walker.global_position),2) if ok else "—"])
	note("perro",scenario,{"perro":ok,"paseante_en_people":walker_in})

# ---- 11. seat_target(): how long until the subject sits, and how long it stays ----
func probe_seat() -> void:
	var trials = []
	for trial in 3:
		await start_sandbox("day")
		await seconds(.5)
		var p = pick(func(q): return q.visible and q.lane == 1 and q.state == "CAMINANDO" and not q.runner and not q.never_sits and not q.has_dog and not q in trials.map(func(t): return t.p))
		if p == null: continue
		freeze()
		game.target = p
		p.protected_target = true
		game.seat_target()
		var t = 0.0
		var sat_at = -1.0
		var stood_at = -1.0
		var busy = {}
		while t < 180.0:
			step_world(.5)
			t += .5
			if sat_at < 0 and p.state == "SENTADO": sat_at = t
			if sat_at >= 0 and stood_at < 0 and p.state == "SENTADO": busy[str(p.activity)] = float(busy.get(str(p.activity),0.0))+.5
			if sat_at >= 0 and stood_at < 0 and p.state != "SENTADO": stood_at = t
			if stood_at >= 0: break
		p.protected_target = false
		trials.append({"p":p,"se_sienta_s":sat_at,"se_levanta_s":stood_at,"actividad":busy})
		say("sentar","prueba %d: se sienta a los %s s y %s · segundos sentada por actividad: %s" % [trial+1,fmt(sat_at,1),("se levanta a los %s s" % fmt(stood_at,1)) if stood_at >= 0 else "sigue sentada a los 180 s",str(busy)])
	note("sentar","pruebas",trials.map(func(t): return {"se_sienta_s":t.se_sienta_s,"se_levanta_s":t.se_levanta_s,"actividad":t.actividad}))

# ---- 12. How the park looks at 600 mm, and what it costs ----
func capture(name: String) -> void:
	# The ideal camera has no depth of field. (In the big park raising the camera turns the
	# finder's blur back on through update_dof_pass(): the mode will switch it off for good.)
	game.set_dof_blur(false)
	await frames(4)
	game.set_dof_blur(false)
	await frames(1)
	await RenderingServer.frame_post_draw
	var image = game.viewport.get_texture().get_image()
	var path = out_dir.path_join("%s_%s_%s.png" % [name,renderer,game.graphics_preset])
	image.save_png(path)
	say("visual","captura %s" % path)

func frame_someone(filter: Callable, plane: String, cap = 600.0) -> Dictionary:
	for p in game.people.filter(filter):
		var w0 = world_landmarks(p)
		var d = Vector2(w0.chest.x,w0.chest.z).distance_to(Vector2(game.camera.global_position.x,game.camera.global_position.z))
		var f = minf(cap,plane_focal(plane,rest_of(p),d))
		var s = compose(p,plane,f)
		var vis = visibility(p,s,world_landmarks(p))
		if vis.face and vis.fraction >= .8: return {"p":p,"f":f,"d":d,"plano":classify(s).plane}
	return {}

func probe_visual_classic() -> void:
	var shots = [["day",1,"cara"],["day",2,"cara"],["day",3,"primer_plano"],["day",2,"medio"],["golden",2,"cara"],["night",2,"cara"],["night",1,"primer_plano"]]
	var last_tod = ""
	for shot in shots:
		if shot[0] != last_tod:
			await start_sandbox(shot[0])
			await seconds(1.0)
			last_tod = shot[0]
		freeze()
		var lane: int = shot[1]
		var got = frame_someone(func(q): return q.visible and q.lane == lane and q.state in STANDING and not q.runner,shot[2])
		if got.is_empty():
			say("visual","clásico %s camino %d %s: nadie a la vista" % [shot[0],lane,shot[2]])
			unfreeze()
			continue
		await capture("clasico_%s_camino%d_%s_%dmm" % [shot[0],lane,shot[2],roundi(got.f)])
		note("visual","clasico_%s_camino%d_%s" % [shot[0],lane,shot[2]],{"f":snappedf(got.f,1),"d":snappedf(got.d,.1),"plano":got.plano})
		unfreeze()
	# The far end at full zoom: 600 mm on the outer path, whatever the shot size.
	freeze()
	var far = game.people.filter(func(q): return q.visible and q.lane == 3 and q.state in STANDING)
	if not far.is_empty():
		set_focal(600.0)
		aim_point(world_landmarks(far[0]).eyes,Vector2(.5,.35))
		await capture("clasico_night_camino3_600mm")
	unfreeze()

func probe_visual_big() -> void:
	await start_sandbox("day")
	await seconds(1.0)
	freeze()
	var cam: Vector3 = game.camera.global_position
	for band in [[12.0,20.0,"cara"],[20.0,35.0,"cara"],[35.0,60.0,"primer_plano"]]:
		var got = frame_someone(func(q): return q.visible and q.state in STANDING and q.global_position.distance_to(cam) > band[0] and q.global_position.distance_to(cam) < band[1],band[2])
		if got.is_empty():
			say("visual","grande %s–%s m: nadie a la vista" % [band[0],band[1]])
			continue
		await capture("grande_day_%d-%dm_%s_%dmm" % [band[0],band[1],got.plano,roundi(got.f)])
		note("visual","grande_%d-%dm" % [band[0],band[1]],{"f":snappedf(got.f,1),"d":snappedf(got.d,.1),"plano":got.plano})
	unfreeze()

func probe_gpu(scenario: String) -> void:
	await start_sandbox("day")
	await seconds(1.0)
	var rid = game.viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	var result = {}
	for setup in ["24 mm","600 mm"]:
		if setup == "24 mm": set_focal(24.0)
		else:
			var got = frame_someone(func(q): return q.visible and q.state in STANDING and q.global_position.distance_to(game.camera.global_position) > 6.0,"cara")
			set_focal(600.0)
			if not got.is_empty(): aim_point(world_landmarks(got.p).eyes,Vector2(.5,.4))
		var gpu = []
		var cpu = []
		for i in 150:
			await RenderingServer.frame_post_draw
			if i < 30: continue
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		result[setup] = {"gpu_ms":snappedf(median(gpu),.01),"cpu_ms":snappedf(median(cpu),.01)}
	say("gpu","%s: %s" % [scenario,str(result)])
	note("gpu",scenario,result)

# ---- 13. In the big park, how do people face a photographer who stands on a path? ----
func probe_big_facing() -> void:
	await start_sandbox("day")
	freeze()
	detect_head_axis()
	var cam: Vector3 = game.camera.global_position
	var hist = {}
	var since = {}
	var spans = {"SENTADO":[],"DETENIDO":[]}
	for s in 180:     # 90 s, every half second
		step_world(.5)
		for p in game.people:
			var state: String = p.state
			if since.has(p) and since[p][0] != state:
				if spans.has(since[p][0]): spans[since[p][0]].append(s*.5-since[p][1])
				since[p] = [state,s*.5]
			elif not since.has(p): since[p] = [state,s*.5]
			if not p.visible or p.global_position.distance_to(cam) > 30.0: continue
			if not hist.has(state): hist[state] = {"frente":0,"perfil":0,"espaldas":0,"tres_cuartos":0,"n":0}
			hist[state][bucket(head_facing(p,cam))] += 1
			hist[state].n += 1
	for key in hist:
		var h = hist[key]
		say("grande_orientacion","%s a menos de 30 m (n=%d): frente %d%% · perfil %d%% · tres cuartos %d%% · espaldas %d%%" % [key,h.n,100*h.frente/h.n,100*h.perfil/h.n,100*h.tres_cuartos/h.n,100*h.espaldas/h.n])
	for key in spans:
		say("grande_orientacion","%s: %d episodios completos, mediana %s s, mínimo %s s" % [key,spans[key].size(),fmt(median(spans[key]),1),fmt(percentile(spans[key],0.0),1)])
	note("grande_orientacion","histograma_cabeza",hist)
	note("grande_orientacion","duraciones",{"SENTADO_mediana":snappedf(median(spans.SENTADO),.1),"DETENIDO_mediana":snappedf(median(spans.DETENIDO),.1),"episodios":spans.SENTADO.size()+spans.DETENIDO.size()})

# ---- 14. Do people cover their faces when the camera comes close? ----
func probe_cover() -> void:
	await start_sandbox("day")
	await seconds(1.0)
	var tries = 0
	var reacted = 0
	var covered = 0
	var cover_time = []
	var done = []
	for attempt in 14:
		var p = pick(func(q): return q.visible and q.state == "CAMINANDO" and not q.runner and q.actual_velocity.length() > .3 and not q in done)
		if p == null: break
		done.append(p)
		var v: Vector3 = p.actual_velocity
		v.y = 0
		game.player.position = p.global_position+v.normalized()*1.9
		game.player.position.y = 0
		set_focal(50.0)
		var st = {"t":0.0,"react":false,"cover":0.0}
		driver.on_frame = func(dt: float) -> void:
			if not is_instance_valid(p): return
			st.t += dt
			aim_point(world_landmarks(p).eyes,Vector2(.5,.45))
			if float(p.get_meta("react",0.0)) > 0: st.react = true
			if str(p.activity) == "taparse": st.cover += dt
		while st.t < 3.5: await process_frame
		driver.on_frame = Callable()
		tries += 1
		if st.react: reacted += 1
		if st.cover > 0:
			covered += 1
			cover_time.append(st.cover)
	say("taparse","de %d acercamientos a 1,9 m con la cámara al ojo: reaccionan %d, se tapan %d (tapados una media de %s s)" % [tries,reacted,covered,fmt(mean(cover_time),1)])
	note("taparse","resultado",{"intentos":tries,"reaccionan":reacted,"se_tapan":covered,"segundos_tapados":snappedf(mean(cover_time),.1)})

# ---- 15. Does a static survive a scene reload, and how long does a reload take? ----
func probe_reload() -> void:
	Holder.data["marca"] = 4242
	current_scene = game
	var times = {}
	for which in ["grande","clasico"]:
		var old = current_scene
		var t0 = Time.get_ticks_msec()
		old.reload_with(which,{})
		while current_scene == old or current_scene == null or not current_scene.get("boot_done"): await process_frame
		times[which] = Time.get_ticks_msec()-t0
		game = current_scene
		await frames(10)
	var kept = Holder.data.get("marca",0) == 4242
	say("recarga","el estático sobrevive a dos recargas: %s · recargar al grande %d ms, al clásico %d ms" % [str(kept),times.grande,times.clasico])
	note("recarga","resultado",{"estatico_sobrevive":kept,"ms_al_grande":times.grande,"ms_al_clasico":times.clasico})
