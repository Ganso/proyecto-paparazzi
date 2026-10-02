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
			for i in 120: p.animate(1.0/120,0.0)   # 0.6 s of real stop, then the blend (gait.gd idle_time)
			check(p.gait.weight == 0,"Blocked pedestrian settles to standing")
			for side in ["I","D"]: check(absf(min_shoe(p,side,soles[side]))<.002,"Stopped shoes are on the ground")
			p.state = "SENTADO"
			p.animate(0)
			check(p.rig.get_bone_pose_rotation(p.bones["muslo.I"]).get_euler().x>1,"Seated thighs extend forward")
			check(p.rig.get_bone_pose_rotation(p.bones["pierna.I"]).get_euler().x< -1,"Seated knees flex anatomically")
			p.free()
	# The hips of a walker ride a smooth wave (no rebound at each double support): the height
	# changes little from frame to frame, its slope never jumps, and the cadence is the person's own.
	var cadences = {}
	for seed_value in [10,11,12,13,14,15]:
		var t = cast.generate(false)
		t.profile = seed_value%3
		var p = Person.new()
		root.add_child(p)
		p.setup(t,cast.catalog,seed_value)
		p.state = "CAMINANDO"
		var heights = []
		for frame in 241:
			p.phase = TAU*frame/240.0
			p.animate(0)
			heights.append(p.rig.get_bone_pose_position(p.bones.caderas).y)
		var bounce = heights.max()-heights.min()
		var worst_kink = 0.0
		for k in range(1,240): worst_kink = maxf(worst_kink,absf(heights[k+1]-2.0*heights[k]+heights[k-1]))
		check(bounce > .008 and bounce < .042,"The hips rise and fall gently (%.1f mm, seed %d)" % [bounce*1000.0,seed_value])
		check(worst_kink < bounce*.012,"…without a sharp corner anywhere in the stride (kink %.3f mm of %.1f mm, seed %d)" % [worst_kink*1000.0,bounce*1000.0,seed_value])
		check(absf(heights[0]-heights[240]) < .0001 and absf(heights[0]-heights[120]) < .0005,"…the same for both steps of the stride (seed %d)" % seed_value)
		check(p.style.bounce >= .85 and p.style.bounce <= 1.15 and p.style.cadence >= .9 and p.style.cadence <= 1.12,"Bounce and cadence within their limits (seed %d)" % seed_value)
		cadences[snappedf(p.style.cadence,.01)] = true
		p.free()
	check(cadences.size() >= 4,"People walk at different cadences (%d of 6)" % cadences.size())
	print("GAIT TESTS: %d checks, %d failures, min sole y %.5f m, max contact drift %.6f m/frame" % [checks,failures,worst_clearance,maximum_slide])
	quit(0 if failures == 0 else 1)
