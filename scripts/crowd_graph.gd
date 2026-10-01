extends RefCounted
# Pedestrians of the big park (docs/futuro/01 Alternativa C): they walk the path graph of
# park_grande.gd with the same smooth walking as the classic lanes (main.gd::walk_step(): limited
# accelerations, a latched passing side, bounded turning), but in the frame of the edge they are on:
# s along the edge, lat across it (right of the walking direction is positive), keeping right.
# At each node they pick the next edge at random (never straight back unless it is a dead end).
# They stop now and then (with an activity), chat with someone coming the other way, sit on the
# benches beside the paths and react to the photographer coming close with a raised camera.
const WALK_ACCEL = .55
const WALK_BRAKE = 1.6
const LATERAL_MAX = .32
const PERSONAL_SPACE = .72
const FOLLOW_GAP = 1.3
const STAND_ACTIVITIES = ["mirar","mirar","movil","foto","cafe"]
const SEAT_ACTIVITIES = ["leer","movil","cafe","palomas",""]

var main
var park

func _init(owner_main) -> void:
	main = owner_main
	park = owner_main.park

# ---- Spawning ----
func spawn(p, rng: RandomNumberGenerator) -> void:
	p.set_meta("graph",true)
	var total = 0.0
	for e in park.edges: total += park.nodes[e[0]].distance_to(park.nodes[e[1]])
	var pick = rng.randf()*total
	for e in park.edges:
		var length = park.nodes[e[0]].distance_to(park.nodes[e[1]])
		if pick <= length:
			var forward = rng.randf() < .5
			var a = e[0] if forward else e[1]
			var b = e[1] if forward else e[0]
			set_route(p,a,b,rng)
			var dir = (park.nodes[b]-park.nodes[a]).normalized()
			p.position = park.nodes[a]+dir*pick+right_of(dir)*keep_offset(p)
			break
		pick -= length
	p.v_fwd = p.speed
	p.rotation.y = atan2(-(park.nodes[p.get_meta("route")[1]]-park.nodes[p.get_meta("route")[0]]).x,-(park.nodes[p.get_meta("route")[1]]-park.nodes[p.get_meta("route")[0]]).z)
	p.heading = p.rotation.y
	p.heading_ready = true

func right_of(dir: Vector3) -> Vector3:
	return Vector3(-dir.z,0,dir.x)

func edge_width(a: String, b: String) -> float:
	for e in park.edges:
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a): return e[2]
	return 2.5

func keep_offset(p) -> float:
	return edge_width(p.get_meta("route")[0],p.get_meta("route")[1])*.2 if p.has_meta("route") else .4

# route = [from, to, next]: the next node is chosen in advance so corners can be cut smoothly.
func set_route(p, a: String, b: String, rng: RandomNumberGenerator) -> void:
	p.set_meta("route",[a,b,choose_next(a,b,rng)])

func choose_next(a: String, b: String, rng: RandomNumberGenerator) -> String:
	var options: Array = park.neighbours[b].filter(func(n): return n != a)
	if options.is_empty(): return a
	return options[rng.randi()%options.size()]

func advance(p) -> void:
	var r: Array = p.get_meta("route")
	set_route(p,r[1],r[2],p.rng)
	p.set_meta("edge_new",true)

func turn_back(p) -> void:
	var r: Array = p.get_meta("route")
	set_route(p,r[1],r[0],p.rng)

# ---- Per frame ----
func update(p, dt: float) -> void:
	var previous_position = p.position
	var previous_heading = p.rotation.y
	match p.state:
		"CAMINANDO":
			if p.bench_goal >= 0: walk_to_bench(p,dt)
			else: walk(p,dt)
		_: still(p,dt)
	if p.state == "SENTADO" or p.state == "LEVANTANDO":
		var bench = park.benches[p.bench_index]
		var e = smoothstep(0,1,p.seat)
		p.position = p.get_meta("sit_from").lerp(park.seat_position(bench,p.bench_slot),e)
	p.actual_velocity = (p.position-previous_position)/maxf(dt,.0001)
	if p.state == "CAMINANDO":
		main.turn_heading(p,dt,previous_heading)
	else:
		if not p.heading_ready:
			p.heading = previous_heading
			p.heading_ready = true
		if not is_nan(p.face_target):
			p.heading += clampf(angle_difference(p.heading,p.face_target),-deg_to_rad(70.0)*dt,deg_to_rad(70.0)*dt)
		p.rotation.y = p.heading
	react_to_photographer(p,dt)
	p.animate(dt,p.position.distance_to(previous_position))

# Edge frame of the walker: start node, direction, length, right vector.
func frame(p) -> Dictionary:
	var r: Array = p.get_meta("route")
	var a: Vector3 = park.nodes[r[0]]
	var b: Vector3 = park.nodes[r[1]]
	var dir = (b-a).normalized()
	return {"a":a,"b":b,"dir":dir,"right":right_of(dir),"length":a.distance_to(b),"width":edge_width(r[0],r[1])}

func walk(p, dt: float) -> void:
	var f = frame(p)
	var s = (p.position-f.a).dot(f.dir)
	var lat = (p.position-f.a).dot(f.right)
	# Turn into the next edge a little before the node (cutting the corner like people do).
	if s > f.length-f.width*.5-.2:
		advance(p)
		on_new_edge(p)
		f = frame(p)
		s = (p.position-f.a).dot(f.dir)
		lat = (p.position-f.a).dot(f.right)
	var half = f.width*.5
	var lo = -half+.25
	var hi = half-.25
	var v_des: float = p.speed
	if not p.pending_stop.is_empty(): v_des = 0.0
	if p.activity == "movil": v_des *= .8
	var lat_des = clampf(f.width*.2+p.pref_offset,lo,hi)
	p.pass_timer = maxf(0.0,p.pass_timer-dt)
	p.side_flip_cd = maxf(0.0,p.side_flip_cd-dt)
	if p.pass_timer <= 0: p.pass_side = 0.0
	var nearest_lat = NAN
	var nearest_ahead = INF
	var others = main.people+([main.player_proxy] if main.player_proxy else [])
	for other in others:
		if other == p or not other.visible: continue
		var rel = other.position-p.position
		if rel.length_squared() > 25.0: continue
		var ahead = rel.dot(f.dir)
		if ahead <= -.9 or ahead > 4.0: continue
		var other_lat = (other.position-f.a).dot(f.right)
		var lateral = other_lat-lat
		if absf(lateral) > 1.1: continue
		var still = other.state != "CAMINANDO"
		var other_dir: Vector3 = other.actual_velocity.normalized() if other.actual_velocity.length() > .1 else Vector3.ZERO
		var same = other_dir.dot(f.dir) > -.2
		var other_v = 0.0 if still else other.actual_velocity.dot(f.dir)
		var closing = p.v_fwd-other_v
		if ahead > -.2 and ahead < nearest_ahead:
			nearest_ahead = ahead
			nearest_lat = other_lat
		if ahead <= .05:
			if p.pass_side != 0.0 and absf(lateral) < PERSONAL_SPACE+.05:
				lat_des = clampf(other_lat+p.pass_side*PERSONAL_SPACE,lo,hi)
				p.pass_timer = maxf(p.pass_timer,.8)
			continue
		if closing <= .02 and not still: continue
		if absf(lateral) < PERSONAL_SPACE+.1:
			if not same and not still and p.pass_side != 1.0 and p.stuck_time < 1.0: p.pass_side = 0.0
			if p.pass_side == 0.0:
				var room_out = hi-(other_lat+PERSONAL_SPACE)
				var room_in = (other_lat-PERSONAL_SPACE)-lo
				if not same and not still: p.pass_side = 1.0     # oncoming: keep to the right
				else: p.pass_side = 1.0 if room_out >= room_in else -1.0
				if (p.pass_side > 0 and room_out < -.05) or (p.pass_side < 0 and room_in < -.05): p.pass_side = -p.pass_side
				p.pass_timer = 3.0
			var side_target = clampf(other_lat+p.pass_side*PERSONAL_SPACE,lo,hi)
			var can_pass = absf(side_target-other_lat) > PERSONAL_SPACE-.12
			if not can_pass and p.side_flip_cd <= 0 and still:
				var other_side = clampf(other_lat-p.pass_side*PERSONAL_SPACE,lo,hi)
				if absf(other_side-other_lat) > PERSONAL_SPACE-.12:
					p.pass_side = -p.pass_side
					side_target = other_side
					can_pass = true
					p.side_flip_cd = 2.5
			var weight = clampf((4.0-ahead)/2.5,0.0,1.0)
			lat_des = lerpf(lat_des,side_target,weight)
			p.pass_timer = maxf(p.pass_timer,1.2)
			if not can_pass and (same or still):
				v_des = minf(v_des,maxf(0.0,other_v)+maxf(0.0,ahead-FOLLOW_GAP)*.8)
		if absf(lateral) < PERSONAL_SPACE-.2 and ahead < 2.0 and same and not still:
			v_des = minf(v_des,maxf(0.0,other_v)+maxf(0.0,ahead-FOLLOW_GAP)*1.2)
	var accel = (WALK_ACCEL*(2.5 if p.runner else 1.0)) if v_des > p.v_fwd else WALK_BRAKE
	p.v_fwd = move_toward(p.v_fwd,v_des,accel*dt)
	var lat_max = LATERAL_MAX*(1.9 if p.runner else 1.0)
	p.v_rad = move_toward(p.v_rad,clampf((lat_des-lat)*1.4,-lat_max,lat_max),1.2*dt)
	var next = f.a+f.dir*(s+p.v_fwd*dt)+f.right*clampf(lat+p.v_rad*dt,-half,half)
	if main.travel_clear(p,p.position,next):
		p.position = next
		p.stuck_time = maxf(0.0,p.stuck_time-dt*2.0)
	else:
		var side_only = f.a+f.dir*s+f.right*clampf(lat+p.v_rad*dt,-half,half)
		if main.travel_clear(p,p.position,side_only):
			p.position = side_only
			p.v_fwd = move_toward(p.v_fwd,0.0,WALK_BRAKE*2.0*dt)
			p.stuck_time += dt*.5
		else:
			p.v_fwd = move_toward(p.v_fwd,0.0,WALK_BRAKE*3.0*dt)
			p.v_rad = 0.0
			p.stuck_time += dt
	if p.stuck_time > 2.0 and p.pass_timer < 1.5:
		if not is_nan(nearest_lat):
			var away = 1.0 if lat >= nearest_lat else -1.0
			if (away > 0 and lat > hi-.05) or (away < 0 and lat < lo+.05): away = -away
			p.pass_side = away
		else: p.pass_side = -p.pass_side if p.pass_side != 0.0 else 1.0
		p.pass_timer = 3.0
	if p.stuck_time > 5.0:
		turn_back(p)
		p.v_fwd = 0.0
		p.stuck_time = 0.0
	if not p.pending_stop.is_empty() and p.v_fwd < .04:
		var stop: Dictionary = p.pending_stop
		p.pending_stop = {}
		p.state = "DETENIDO"
		p.state_time = stop.time
		p.activity = stop.activity
		p.act_time = 0.0
		p.face_target = stop.get("face",NAN)
	if p.activity == "movil":
		p.state_time -= dt
		if p.state_time <= 0: p.activity = ""

# Something to do on entering an edge: a stop with an activity, a chat, a bench, the phone.
func on_new_edge(p) -> void:
	if p.runner or p.has_meta("staged"): return
	if p.protected_target and p.rng.randf() < .5: return
	var roll = p.rng.randf()
	if roll < .3 and choose_bench(p): return
	if roll < .42:
		plan_stop(p)
	elif roll < .55 and p.activity == "":
		p.activity = "movil"
		p.act_time = 0.0
		p.state_time = p.rng.randf_range(8,18)

func plan_stop(p) -> void:
	var f = frame(p)
	var time = p.rng.randf_range(6,16)
	for q in main.people:
		if q == p or q.runner or q.protected_target or q.state != "CAMINANDO" or q.bench_goal >= 0 or not q.pending_stop.is_empty(): continue
		var rel = q.position-p.position
		var ahead = rel.dot(f.dir)
		if ahead < 1.4 or ahead > 3.6 or absf(rel.dot(f.right)) > 1.2: continue
		if q.actual_velocity.dot(f.dir) > -.1: continue
		if p.rng.randf() < .55:
			time += 6
			p.pending_stop = {"activity":"charla","time":time}
			q.pending_stop = {"activity":"charla","time":time}
			p.partner = q
			q.partner = p
			return
	var face = p.heading+p.rng.randf_range(-1.6,1.6)+(PI*.5 if p.rng.randf() < .5 else -PI*.5)
	p.pending_stop = {"activity":STAND_ACTIVITIES[p.rng.randi()%STAND_ACTIVITIES.size()],"time":time,"face":face}

# ---- Benches ----
func choose_bench(p) -> bool:
	var f = frame(p)
	var best = -1
	var best_slot = 0
	for i in park.benches.size():
		var bench = park.benches[i]
		if bench.occupied: continue
		for slot in 2:
			if bench.seats[slot] != null: continue
			var front = park.seat_front(bench,slot)
			var s = (front-f.a).dot(f.dir)
			var off = absf((front-f.a).dot(f.right))
			if s < 2.0 or s > f.length-1.0 or off > f.width*.5+1.6: continue
			if (p.position-f.a).dot(f.dir) > s-1.5: continue
			best = i
			best_slot = slot
			break
		if best >= 0: break
	if best < 0: return false
	var bench = park.benches[best]
	set_seat(bench,best_slot,p)
	p.bench_goal = best
	p.bench_slot = best_slot
	return true

func set_seat(bench: Dictionary, slot: int, who) -> void:
	bench.seats[slot] = who
	bench.occupied = bench.seats[0] != null and bench.seats[1] != null

# Along the path until level with the seat, then straight to the spot in front of it.
func walk_to_bench(p, dt: float) -> void:
	var bench = park.benches[p.bench_goal]
	var front = park.seat_front(bench,p.bench_slot)
	var f = frame(p)
	var level = (front-f.a).dot(f.dir)-(p.position-f.a).dot(f.dir)
	if level > 1.0 and not p.get_meta("off_path",false):
		walk(p,dt)
		if p.state != "CAMINANDO" or p.bench_goal < 0: return
		return
	p.set_meta("off_path",true)
	var to = front-p.position
	to.y = 0
	var d = to.length()
	p.v_fwd = move_toward(p.v_fwd,minf(p.speed,maxf(.12,d*.9)),WALK_BRAKE*dt)
	var step = to.normalized()*minf(d,p.v_fwd*dt)
	if d < .08:
		p.remove_meta("off_path")
		p.bench_index = p.bench_goal
		p.bench_goal = -1
		p.state = "DETENIDO"
		p.set_meta("to_sit",true)
		p.state_time = 999.0
		var face: Vector3 = bench.face
		p.face_target = atan2(-face.x,-face.z)
		return
	if main.travel_clear(p,p.position,p.position+step,false):
		p.position += step
		p.stuck_time = maxf(0.0,p.stuck_time-dt)
	else:
		p.stuck_time += dt
		if p.stuck_time > 3.0:
			set_seat(bench,p.bench_slot,null)
			p.bench_goal = -1
			p.remove_meta("off_path")
			p.stuck_time = 0.0

func bench_neighbour(p):
	if p.bench_index < 0: return null
	var other = park.benches[p.bench_index].seats[1-p.bench_slot]
	return other if other != null and other.state == "SENTADO" else null

func still(p, dt: float) -> void:
	match p.state:
		"DETENIDO":
			if p.get_meta("to_sit",false):
				if absf(angle_difference(p.heading,p.face_target)) < .08:
					p.remove_meta("to_sit")
					p.state = "SENTADO"
					p.set_meta("sit_from",p.position)
					p.state_time = p.rng.randf_range(25,70)
					p.activity = SEAT_ACTIVITIES[p.rng.randi()%SEAT_ACTIVITIES.size()]
					p.act_time = 0.0
					var neighbour = bench_neighbour(p)
					if neighbour != null and p.rng.randf() < .7:
						p.activity = "charla"
						p.partner = neighbour
						neighbour.activity = "charla"
						neighbour.partner = p
						neighbour.act_time = 0.0
						neighbour.state_time = maxf(neighbour.state_time,p.state_time*.8)
				return
			if p.activity == "charla" and is_instance_valid(p.partner):
				var to = p.partner.position-p.position
				p.face_target = atan2(-to.x,-to.z)
			p.state_time -= dt
			if p.state_time <= 0: resume(p)
		"SENTADO":
			var target_yaw = 0.0
			if p.activity == "charla" and is_instance_valid(p.partner):
				var to = p.partner.position-p.position
				target_yaw = clampf(angle_difference(p.rotation.y,atan2(-to.x,-to.z)),-1.1,1.1)
			elif p.activity == "charla": p.activity = ""
			p.look_yaw = move_toward(p.look_yaw,target_yaw,dt*1.5)
			p.state_time -= dt
			if p.state_time <= 0:
				if p.activity != "":
					if p.activity == "charla" and is_instance_valid(p.partner) and p.partner.partner == p:
						p.partner.activity = SEAT_ACTIVITIES[p.rng.randi()%SEAT_ACTIVITIES.size()]
						p.partner.partner = null
					p.activity = ""
					p.partner = null
				elif p.act_w <= 0: p.state = "LEVANTANDO"
		"LEVANTANDO":
			p.look_yaw = move_toward(p.look_yaw,0.0,dt*1.5)
			if p.seat <= 0:
				set_seat(park.benches[p.bench_index],p.bench_slot,null)
				p.bench_index = -1
				resume(p)
		_:
			p.state_time -= dt
			if p.state_time <= 0: resume(p)

func resume(p) -> void:
	p.state = "CAMINANDO"
	p.activity = ""
	p.partner = null
	p.face_target = NAN
	p.v_fwd = 0.0
	p.v_rad = 0.0
	p.stuck_time = 0.0

# ---- The photographer comes close with a raised camera ----
# Within 2.5 m and near the middle of the frame: they glance at the camera; some cover their face
# for a moment, some hurry on. Never applied to anyone sitting down with a partner.
func react_to_photographer(p, dt: float) -> void:
	var react = float(p.get_meta("react",0.0))
	if react > 0:
		react -= dt
		p.set_meta("react",react)
		var to = main.camera.global_position-p.position
		var yaw = clampf(angle_difference(p.rotation.y,atan2(-to.x,-to.z)),-1.2,1.2)
		if p.activity != "charla": p.look_yaw = move_toward(p.look_yaw,yaw,dt*3.0)
		if react <= 0:
			if p.activity == "taparse": p.activity = ""
			if p.activity != "charla": p.look_yaw = 0.0
		return
	if p.activity != "charla" and absf(p.look_yaw) > .01 and p.state != "SENTADO": p.look_yaw = move_toward(p.look_yaw,0.0,dt*2.0)
	if not main.camera_raised or p.has_meta("staged"): return
	var cam: Vector3 = main.camera.global_position
	var flat = Vector3(cam.x-p.position.x,0,cam.z-p.position.z)
	if flat.length() > 2.5: return
	var axis = -main.camera.global_basis.z
	var to_person = (p.position+Vector3.UP*1.3-cam).normalized()
	if axis.dot(to_person) < .93: return
	p.set_meta("react",2.6)
	var roll = p.rng.randf()
	if roll < .35 and p.state == "CAMINANDO": p.activity = "taparse"
	elif roll < .6 and p.state == "CAMINANDO": p.v_fwd = minf(p.speed*1.25,p.v_fwd+.3)
