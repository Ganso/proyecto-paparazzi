extends RefCounted
# Character forward is -Z. Knees flex toward -Z; elbows flex toward -Z too.
# Both legs use the same solver; contact trajectories distinguish walk and run.
var person
var weight = 1.0
var plants = {}
var was_contact = {}
var swing_start = {}
var last_position = Vector3.ZERO
var has_last_position = false
var sole_outline: Array[Vector2] = []

func _init(p) -> void:
	person = p
	# Use the actual rounded shoe mesh, not a bounding box with imaginary corners.
	var arrays = p.mesh.surface_get_arrays(0)
	var foot: int = p.bones["pie.I"]
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		if arrays[Mesh.ARRAY_BONES][i*4] == foot:
			var vertex = p.rests[foot].inverse()*arrays[Mesh.ARRAY_VERTEX][i]
			var point = Vector2(vertex.y,vertex.z)
			if not sole_outline.has(point): sole_outline.append(point)

# How far sideways a planted foot may be left from under its hip (m, scaled by the body) and how
# much its toes may point away from the body before it pivots with it.
const SPLAY_LIMIT = .10
const TWIST_LIMIT = .7

func reset_contacts() -> void:
	plants.clear()
	was_contact.clear()
	swing_start.clear()

func sample(cycle: float) -> Dictionary:
	var p = person
	var duty = .36 if p.runner else .60
	var span = p.stride*duty
	var front = -span*(.45 if p.runner else .5)
	var back = span*(.55 if p.runner else .5)
	var strike = .04 if p.runner else .20
	var push = -.65 if p.runner else -.45
	var contact = cycle < duty
	var u = cycle/duty if contact else (cycle-duty)/(1-duty)
	var z: float
	var pitch: float
	var clearance = 0.0
	if contact:
		z = lerpf(front,back,u)
		if u < .2:
			pitch = lerpf(strike,0,smoothstep(0,.2,u))
		elif u > .68:
			pitch = lerpf(0,push,smoothstep(.68,1,u))
		else: pitch = 0
	else:
		z = swing_curve(back,front,p.stride*(1-duty),u)
		pitch = lerpf(push,strike,smoothstep(0,.8,u))
		clearance = sin(PI*u)*sin(PI*u)*p.nz*(.20 if p.runner else .035)
	var support = sole_support(pitch)
	var y = support.x+clearance
	var roll_z = support.y
	return {"contact":contact,"u":u,"z":z,"pitch":pitch,"y":y,"roll_z":roll_z,"front":front,"tangent":p.stride*(1-duty)}

func sole_support(pitch: float) -> Vector2:
	var minimum = INF
	var support = Vector2.ZERO
	for v in sole_outline:
		var y = v.x*cos(pitch)-v.y*sin(pitch)
		if y < minimum:
			minimum = y
			support = v
	# Keep the active heel/forefoot vertex fixed while the shoe rolls over it.
	return Vector2(-minimum,support.y-(support.x*sin(pitch)+support.y*cos(pitch)))

func swing_curve(start: float, finish: float, tangent: float, u: float) -> float:
	# Hermite endpoints preserve foot velocity at lift-off and touchdown.
	return (2*u*u*u-3*u*u+1)*start+(u*u*u-2*u*u+u)*tangent+(-2*u*u*u+3*u*u)*finish+(u*u*u-u*u)*tangent

func neutral() -> void:
	var p = person
	p.rig.set_bone_pose_position(p.bones.caderas,p.rests[p.bones.caderas].origin)
	for id in ["lumbar","cuello"]: p.pose_bone(id,0)
	for side in ["I","D"]:
		for part in ["muslo","pierna","pie"]: p.pose_bone(part+"."+side,0)
		var sign_side = -1 if side == "I" else 1
		p.rig.set_bone_pose_rotation(p.bones["brazo."+side],Quaternion(Vector3.BACK,sign_side*p.arm_out[side]))
		p.pose_bone("antebrazo."+side,.12)

var idle_time = 0.0
func pose(delta: float, traveled_distance = -1.0) -> void:
	var p = person
	var live = traveled_distance >= 0
	var moving = p.state == "CAMINANDO"
	if moving:
		var distance = traveled_distance if live else p.speed*delta
		p.phase = fposmod(p.phase+maxf(0,distance)*TAU/p.stride,TAU)
	# The walk blends out only after a real stop (0.6 s without moving): a walker held up for a
	# frame now and then by someone in the way kept blending its legs in and out, which looked
	# like trembling against them.
	if live and traveled_distance > .00001: idle_time = 0.0
	elif live: idle_time += delta
	var desired_weight = 1.0 if moving and (not live or idle_time < .6) else 0.0
	weight = move_toward(weight,desired_weight,delta*6) if live else desired_weight
	if has_last_position and p.position.distance_to(last_position) > p.stride*.7: reset_contacts()
	last_position = p.position
	has_last_position = true
	# Sitting down / standing up takes ~1.3 s (docs/PERSONAJES_Y_CINEMATICA.md §6).
	var seat_goal = 1.0 if p.state == "SENTADO" else 0.0
	p.seat = move_toward(p.seat,seat_goal,delta/1.3) if live else seat_goal
	var activity_goal = 1.0 if p.activity != "" and (p.state != "CAMINANDO" or p.activity in WALKING_ACTIVITIES) else 0.0
	p.act_w = move_toward(p.act_w,activity_goal,delta*1.2) if live else activity_goal
	if activity_goal > 0: p.act_time += delta
	neutral()
	if p.seat > 0:
		reset_contacts()
		weight = 0
		sit(smoothstep(0,1,p.seat))
		activity()
		return
	if weight == 0:
		reset_contacts()
		activity()
		return
	var neutral_rotations = {}
	for id in ["lumbar","cuello","muslo.I","muslo.D","pierna.I","pierna.D","pie.I","pie.D","brazo.I","brazo.D","antebrazo.I","antebrazo.D"]:
		neutral_rotations[id] = p.rig.get_bone_pose_rotation(p.bones[id])
	var targets = {}
	var foot_rotations = {}
	var a = p.nz*(.542-.323)
	var b = p.nz*(.323-.03)
	var cycle_base = p.phase/TAU
	var hip = p.nz*.03+(a+b)*(.95-.035*cos(TAU*(fposmod(cycle_base*2,1)-.12)) if p.runner else .98)
	for side in ["I","D"]:
		var sign_side = -1 if side == "I" else 1
		var x = p.profile.hombros*.22*sign_side
		var cycle = fposmod(cycle_base+(0 if side == "I" else .5),1)
		var s = sample(cycle)
		var target = Vector3(x,s.y,s.z+s.roll_z)
		var foot_basis = Basis(Vector3.RIGHT,s.pitch)
		if live:
			if s.contact:
				if not was_contact.get(side,false) or not plants.has(side):
					plants[side] = {"position":p.to_global(Vector3(x,0,s.z)),"heading":p.global_basis}
				var plant: Dictionary = plants[side]
				# A planted shoe never slides while walking straight, but when the body turns a lot
				# during one step (setting off facing elsewhere, turning back, a tight curve) it was
				# left far to the side and the legs splayed. Past SPLAY_LIMIT the foot pivots with
				# the body, as a person turning on the spot does, and its toes follow the turn.
				var planted = p.to_local(plant.position)
				var side_gap = planted.x-x
				if absf(side_gap) > SPLAY_LIMIT:
					planted.x = x+signf(side_gap)*SPLAY_LIMIT
					plant.position = p.to_global(planted)
				var twist = plant.heading.get_rotation_quaternion().angle_to(p.global_basis.get_rotation_quaternion())
				if twist > TWIST_LIMIT:
					plant.heading = Basis(plant.heading.get_rotation_quaternion().slerp(p.global_basis.get_rotation_quaternion(),1.0-TWIST_LIMIT/twist))
				target = p.to_local(plant.position+Vector3.UP*s.y+plant.heading*Vector3(0,0,s.roll_z))
				foot_basis = p.global_basis.inverse()*plant.heading*foot_basis
			else:
				if was_contact.get(side,false) and plants.has(side): swing_start[side] = p.to_local(plants[side].position)
				if swing_start.has(side):
					target.x = lerpf(swing_start[side].x,x,smoothstep(0,1,s.u))
					target.z = swing_curve(swing_start[side].z,s.front,s.tangent,s.u)+s.roll_z
			was_contact[side] = s.contact
		else: reset_contacts()
		targets[side] = target
		foot_rotations[side] = foot_basis.get_rotation_quaternion()
		# Lower the pelvis only as needed to keep the requested shoe contact reachable.
		var horizontal_sq = (target.x-x)*(target.x-x)+target.z*target.z
		hip = minf(hip,target.y+sqrt(maxf(.001,pow(a+b-.003,2)-horizontal_sq)))
	p.rig.set_bone_pose_position(p.bones.caderas,Vector3(0,hip,0))
	for side in ["I","D"]:
		var sign_side = -1 if side == "I" else 1
		var hip_joint = Vector3(p.profile.hombros*.22*sign_side,hip,0)
		solve_leg(side,targets[side]-hip_joint,foot_rotations[side],a,b)
		var cycle = fposmod(cycle_base+(0 if side == "I" else .5),1)
		var arm = -cos(cycle*TAU)*(.55 if p.runner else .27)
		var elbow = 1.30+arm*.16 if p.runner else .20+arm*.25
		var shoulder = Quaternion(Vector3.BACK,sign_side*p.arm_out[side])*Quaternion(Vector3.RIGHT,arm)
		p.rig.set_bone_pose_rotation(p.bones["brazo."+side],shoulder)
		p.pose_bone("antebrazo."+side,elbow)
	var lean = -.12 if p.runner else -.025
	p.rig.set_bone_pose_rotation(p.bones.lumbar,Quaternion(Vector3.RIGHT,lean)*Quaternion(Vector3.UP,sin(p.phase)*.035))
	p.pose_bone("cuello",-lean*.6)
	if weight < 1:
		p.rig.set_bone_pose_position(p.bones.caderas,p.rests[p.bones.caderas].origin.lerp(Vector3(0,hip,0),weight))
		for id in neutral_rotations:
			p.rig.set_bone_pose_rotation(p.bones[id],neutral_rotations[id].slerp(p.rig.get_bone_pose_rotation(p.bones[id]),weight))
		# Interpolating joint angles is nonlinear: keep soles above the ground on stops.
		var minimum = 0.0
		for side in ["I","D"]:
			var transform = p.rig.get_bone_global_pose(p.bones["pie."+side])
			for v in sole_outline: minimum = minf(minimum,(transform*Vector3(0,v.x,v.y)).y)
		if minimum < 0:
			p.rig.set_bone_pose_position(p.bones.caderas,p.rig.get_bone_pose_position(p.bones.caderas)-Vector3.UP*minimum)
	activity()

# Seated pose blended by e (0 standing, 1 seated). The feet stay where they are while the hips go
# back and down onto the seat: main.gd moves the root back by the thigh length meanwhile.
func sit(e: float) -> void:
	var p = person
	var a = p.nz*(.542-.323)
	var b = p.nz*(.323-.03)
	var ground = sole_support(0).x
	var standing: float = p.rests[p.bones.caderas].origin.y
	if p.seat_kind == "suelo":
		sit_ground(e,a,b,ground,standing)
		return
	var seat = maxf(.47,b+ground)
	var hip = lerpf(standing,seat,e)
	p.rig.set_bone_pose_position(p.bones.caderas,Vector3(0,hip,0))
	for side in ["I","D"]:
		var sign_side = -1 if side == "I" else 1
		var x = p.profile.hombros*.22*sign_side
		# Short legs (children) dangle: thigh on the seat, shin hanging, feet off the ground.
		var target = Vector3(x*1.1,lerpf(ground,maxf(ground,seat-b),e),-a*e)
		solve_leg(side,target-Vector3(x,hip,0),Quaternion.IDENTITY,a,b)
		p.pose_bone("brazo."+side,.15*e)
		p.pose_bone("antebrazo."+side,.12+.78*e)
	# Lean forward while lowering (and rising), upright once seated.
	p.pose_bone("lumbar",-.38*sin(PI*e)-.04*e)

# Sitting on the grass: hips down to the ground, legs stretched forward with the knees a little
# raised, leaning back on straight arms.
func sit_ground(e: float, a: float, b: float, ground: float, standing: float) -> void:
	var p = person
	var hip = lerpf(standing,p.nz*.075,e)
	p.rig.set_bone_pose_position(p.bones.caderas,Vector3(0,hip,0))
	for side in ["I","D"]:
		var sign_side = -1 if side == "I" else 1
		var x = p.profile.hombros*.22*sign_side
		var reach = (a+b)*lerpf(.2,.86,e)
		var target = Vector3(x*1.15,lerpf(ground,ground+.02,e),-reach)
		target.y = maxf(target.y,hip-sqrt(maxf(0.0,pow(a+b-.004,2)-reach*reach)))
		solve_leg(side,target-Vector3(x,hip,0),Quaternion(Vector3.RIGHT,-.5*e),a,b)
		arm(side,lerpf(0,-.55,e),-.1,.05,1.0)
	p.pose_bone("lumbar",lerpf(0,.18,e)-.3*sin(PI*e))

const WALKING_ACTIVITIES = ["movil","taparse"]

func arm(side: String, pitch: float, inward: float, elbow: float, weight_arm: float) -> void:
	var p = person
	var sign_side = -1 if side == "I" else 1
	var bone: int = p.bones["brazo."+side]
	var target = Quaternion(Vector3.UP,sign_side*inward)*Quaternion(Vector3.BACK,sign_side*p.arm_out[side])*Quaternion(Vector3.RIGHT,pitch)
	p.rig.set_bone_pose_rotation(bone,p.rig.get_bone_pose_rotation(bone).slerp(target,weight_arm))
	var fore: int = p.bones["antebrazo."+side]
	p.rig.set_bone_pose_rotation(fore,p.rig.get_bone_pose_rotation(fore).slerp(Quaternion(Vector3.RIGHT,elbow),weight_arm))

func head(pitch: float, yaw: float, weight_head: float) -> void:
	var p = person
	var bone: int = p.bones["cuello"]
	var target = Quaternion(Vector3.UP,yaw)*Quaternion(Vector3.RIGHT,pitch)
	p.rig.set_bone_pose_rotation(bone,p.rig.get_bone_pose_rotation(bone).slerp(target,weight_head))

# Upper-body layer for what the person is doing (docs/futuro/19). Blended by p.act_w over the
# walking, standing or seated pose; the legs are never touched.
func activity() -> void:
	var p = person
	# A glance (the photographer, a partner on the bench) turns the head whatever the activity.
	if absf(p.look_yaw) > .01 and p.activity != "charla": head(0,p.look_yaw,1.0)
	if p.has_dog: arm("I",.32,-.05,.5,1.0-p.seat)
	var w: float = smoothstep(0,1,p.act_w)
	if w <= 0: return
	var t: float = p.act_time+p.act_seed
	match p.activity:
		"movil":
			arm("D",.78,.38,1.62+.05*sin(t*1.7),w)
			if p.state != "CAMINANDO": arm("I",.45,.55,1.7,w*.8)
			head(-.42,0,w)
		"leer":
			arm("D",.55,.1,1.5,w)
			arm("I",.55,.1,1.5,w)
			head(-.3+.04*sin(t*.4),.1*sin(t*.23),w)
		"foto":
			# Raise the camera to the eye every few seconds, look around between shots.
			var up = smoothstep(.0,.25,fposmod(t,7.0)/7.0)*(1.0-smoothstep(.55,.7,fposmod(t,7.0)/7.0))
			arm("D",lerpf(.3,1.05,up),lerpf(.25,.55,up),lerpf(1.3,2.35,up),w)
			arm("I",lerpf(.1,.95,up),lerpf(0,.65,up),lerpf(.3,2.3,up),w*up)
			head(lerpf(-.1,.05,up),lerpf(.35*sin(t*.5),0,up),w)
		"charla":
			var g = sin(t*1.3)*.5+.5
			arm("D",.25+.35*g,.2,.9+.6*g,w*(.4+.6*smoothstep(-.2,.6,sin(t*.31))))
			arm("I",.15+.15*sin(t*.9+1),.1,.5+.3*g,w*.5)
			head(.06*sin(t*2.1),p.look_yaw+.12*sin(t*.37),w)
			# A wave of the hand when they meet (the first two seconds).
			var hello = 1.0-smoothstep(1.4,2.0,p.act_time)
			if hello > 0: arm("D",1.75,.1,1.45+.35*sin(p.act_time*11.0),hello)
		"estirar":
			# A runner's break: arms overhead, bending from side to side.
			var bend = sin(t*.9)
			arm("D",2.9,0,.15,w)
			arm("I",2.9,0,.15,w)
			var lumbar: int = p.bones["lumbar"]
			p.rig.set_bone_pose_rotation(lumbar,p.rig.get_bone_pose_rotation(lumbar).slerp(Quaternion(Vector3.BACK,.28*bend),w))
			head(.1,0,w)
		"mirar":
			# Arms crossed, head sweeping the view slowly.
			arm("D",.28,.62,1.95,w)
			arm("I",.22,.55,2.05,w)
			head(.02,.55*sin(t*.21),w)
		"palomas":
			# Tosses crumbs forward every few seconds.
			var cycle = fposmod(t,3.6)/3.6
			var toss = sin(PI*smoothstep(.0,.35,cycle))*(1.0-smoothstep(.35,.5,cycle))
			arm("D",.2+.75*toss,.15,1.2-.8*toss,w)
			arm("I",.35,.35,1.5,w*.8)
			head(-.38,0,w)
		"taparse":
			# Shielding the face from a camera pointed at them (big park, crowd_graph.gd).
			arm("D",1.25,.75,2.2,w)
			head(-.15,-.35,w)
		"cafe":
			var sip = smoothstep(.7,.8,fposmod(t,9.0)/9.0)*(1.0-smoothstep(.9,1.0,fposmod(t,9.0)/9.0))
			arm("D",lerpf(.25,.7,sip),lerpf(.2,.45,sip),lerpf(1.65,2.5,sip),w)
			head(lerpf(-.05,.15,sip),.2*sin(t*.3),w)

func solve_leg(side: String, target: Vector3, foot_rotation: Quaternion, a: float, b: float) -> void:
	var p = person
	var distance = clampf(target.length(),absf(a-b)+.001,a+b-.001)
	var along = target.normalized()
	var forward = (Vector3.FORWARD-along*Vector3.FORWARD.dot(along)).normalized()
	var alpha = acos(clampf((a*a+distance*distance-b*b)/(2*a*distance),-1,1))
	var thigh_direction = along*cos(alpha)+forward*sin(alpha)
	var shin_direction = (along*distance-thigh_direction*a).normalized()
	var thigh = Quaternion(Vector3.DOWN,thigh_direction)
	var shin = Quaternion(Vector3.DOWN,shin_direction)
	p.rig.set_bone_pose_rotation(p.bones["muslo."+side],thigh)
	p.rig.set_bone_pose_rotation(p.bones["pierna."+side],thigh.inverse()*shin)
	p.rig.set_bone_pose_rotation(p.bones["pie."+side],shin.inverse()*foot_rotation)
