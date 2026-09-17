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
		p.rig.set_bone_pose_rotation(p.bones["brazo."+side],Quaternion(Vector3.BACK,sign_side*.055))
		p.pose_bone("antebrazo."+side,.12)

func pose(delta: float, traveled_distance = -1.0) -> void:
	var p = person
	var live = traveled_distance >= 0
	var moving = p.state == "CAMINANDO"
	if moving:
		var distance = traveled_distance if live else p.speed*delta
		p.phase = fposmod(p.phase+maxf(0,distance)*TAU/p.stride,TAU)
	var desired_weight = 1.0 if moving and (not live or traveled_distance > .00001) else 0.0
	weight = move_toward(weight,desired_weight,delta*6) if live else desired_weight
	if has_last_position and p.position.distance_to(last_position) > p.stride*.7: reset_contacts()
	last_position = p.position
	has_last_position = true
	neutral()
	if p.state == "SENTADO":
		reset_contacts()
		weight = 0
		var seat = maxf(.47,p.nz*(.323-.03)+p.nz*.03)
		p.rig.set_bone_pose_position(p.bones.caderas,Vector3(0,seat,0))
		for side in ["I","D"]:
			p.pose_bone("muslo."+side,PI*.5)
			p.pose_bone("pierna."+side,-PI*.5)
			p.pose_bone("brazo."+side,.15)
			p.pose_bone("antebrazo."+side,.9)
		return
	if weight == 0:
		reset_contacts()
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
		var shoulder = Quaternion(Vector3.BACK,sign_side*.055)*Quaternion(Vector3.RIGHT,arm)
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
