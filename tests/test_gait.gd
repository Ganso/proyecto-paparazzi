extends SceneTree
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 15: push_error(message)
func _initialize() -> void:
	call_deferred("run")
func shoe_vertices(p, side: String) -> Array:
	var out = []
	var arrays = p.mesh.surface_get_arrays(0)
	var index: int = p.bones["pie."+side]
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		if arrays[Mesh.ARRAY_BONES][i*4] == index:
			out.append(p.rests[index].inverse()*arrays[Mesh.ARRAY_VERTEX][i])
	return out
func min_shoe(p, side: String, vertices: Array) -> float:
	var transform = p.rig.get_bone_global_pose(p.bones["pie."+side])
	var minimum = INF
	for v in vertices: minimum = minf(minimum,(transform*v).y)
	return minimum
func run() -> void:
	var cast = Cast.new()
	var worst_clearance = 0.0
	var maximum_slide = 0.0
	for profile in 4:
		for running in [false,true]:
			var t = cast.generate(running)
			t.profile = profile
			var p = Person.new()
			root.add_child(p)
			p.setup(t,cast.catalog,10)
			var soles = {"I":shoe_vertices(p,"I"),"D":shoe_vertices(p,"D")}
			for frame in 120:
				p.phase = TAU*frame/120.0
				p.animate(0)
				for side in ["I","D"]:
					var cycle = fposmod(p.phase/TAU+(0 if side == "I" else .5),1)
					var hip = p.rig.get_bone_global_pose(p.bones["muslo."+side]).origin
					var knee = p.rig.get_bone_global_pose(p.bones["pierna."+side]).origin
					var ankle = p.rig.get_bone_global_pose(p.bones["pie."+side]).origin
					var axis = (ankle-hip).normalized()
					var bend = knee-hip-axis*(knee-hip).dot(axis)
					check(bend.dot(Vector3.FORWARD) >= -.0001,"Knee bends forward: %s/%s/%d" % [profile,running,frame])
					check(p.rig.get_bone_pose_rotation(p.bones["antebrazo."+side]).get_euler().x > 0,"Elbow flexes forward")
					var minimum = min_shoe(p,side,soles[side])
					worst_clearance = minf(worst_clearance,minimum)
					check(minimum >= -.002,"Actual shoe geometry stays above ground: %.5f" % minimum)
					if p.gait.sample(cycle).contact: check(absf(minimum) < .003,"Stance shoe touches ground: %.5f" % minimum)
				if frame == 0 or frame == 60:
					var angle = p.rig.get_bone_pose_rotation(p.bones["brazo.I"]).get_euler().x
					check(angle < 0 if frame == 0 else angle > 0,"Arm opposes same-side advancing leg")
			# No pose discontinuity at either toe-off or heel-strike.
			for boundary in [0.0,.5,.36 if running else .6,.86 if running else .1]:
				p.phase = fposmod(boundary-.00001,1)*TAU
				p.animate(0)
				var before = []
				for id in ["pie.I","pie.D","mano.I","mano.D"]: before.append(p.rig.get_bone_global_pose(p.bones[id]).origin)
				p.phase = fposmod(boundary+.00001,1)*TAU
				p.animate(0)
				for i in 4:
					var id = ["pie.I","pie.D","mano.I","mano.D"][i]
					check(before[i].distance_to(p.rig.get_bone_global_pose(p.bones[id]).origin) < .002,"Continuous limbs at contact boundary")
			# A real translated AND turning character: the stance contact must remain in world space.
			p.phase = 0
			p.gait.reset_contacts()
			var previous_contact = {}
			for frame in 100:
				var distance = p.stride/120.0
				p.rotation.y += distance/1.8
				p.position += -p.basis.z*distance
				p.animate(1.0/120,distance)
				for side in ["I","D"]:
					var cycle = fposmod(p.phase/TAU+(0 if side == "I" else .5),1)
					var sample = p.gait.sample(cycle)
					check(min_shoe(p,side,soles[side]) >= -.002,"Turning keeps actual shoes above ground")
					if not sample.contact or sample.u < .22 or sample.u > .65:
						previous_contact.erase(side)
						continue
					var contact = p.global_transform*(p.rig.get_bone_global_pose(p.bones["pie."+side])*Vector3(0,-p.nz*.03,0))
					if previous_contact.has(side):
						var slide = contact.distance_to(previous_contact[side])
						maximum_slide = maxf(maximum_slide,slide)
						check(slide < .002,"Planted shoe does not slide during translation/turn: %.4f" % slide)
					previous_contact[side] = contact
			var phase_before = p.phase
			p.animate(.005,p.stride*.02)
			check(absf(angle_difference(phase_before,p.phase)-TAU*.02)<.00001,"Cadence follows actual distance, independent of delta")
			for i in 40: p.animate(1.0/120,0.0)
			check(p.gait.weight == 0,"Blocked pedestrian settles to standing")
			for side in ["I","D"]: check(absf(min_shoe(p,side,soles[side]))<.002,"Stopped shoes are on the ground")
			p.state = "SENTADO"
			p.animate(0)
			check(p.rig.get_bone_pose_rotation(p.bones["muslo.I"]).get_euler().x>1,"Seated thighs extend forward")
			check(p.rig.get_bone_pose_rotation(p.bones["pierna.I"]).get_euler().x< -1,"Seated knees flex anatomically")
			p.free()
	print("GAIT TESTS: %d checks, %d failures, min sole y %.5f m, max contact drift %.6f m/frame" % [checks,failures,worst_clearance,maximum_slide])
	quit(0 if failures == 0 else 1)
