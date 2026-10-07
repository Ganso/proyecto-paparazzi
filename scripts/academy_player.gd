extends RefCounted
# Plays the Academy by itself, as a student who does everything right would: every theory page,
# the demonstration, the practice (task by task, with the game's own controls and photos) and the
# exam of each lesson. It is the proof that every practice and exam can be done with what the
# lesson teaches (tests/test_academy_play.gd) and what the video of the whole Academy records
# (-- --academy-play=<seconds per page>[:<first>-<last>], tools/capture_academy.sh).
const Photo = preload("res://scripts/photography.gd")

var academy
var main
var page_seconds = 4.0
var pace = 1.0                 # multiplies every wait (tests go faster)
var with_demo = true
var results: Array = []        # per lesson: {"kind", "practice", "exam", "score"}
var running = false

func _init(owner_academy) -> void:
	academy = owner_academy
	main = academy.main

func wait(seconds: float) -> void:
	await main.get_tree().create_timer(maxf(.02,seconds*pace)).timeout

func run(first = 1, last = -1) -> void:
	running = true
	if last < 0: last = academy.LESSONS
	for n in range(first,last+1):
		academy.begin(n,"teoria")
		for k in academy.THEORY_PAGES[academy.kind]:
			await wait(page_seconds)
			academy.go_next()
		# The last «next» of the theory opens the demonstration.
		if with_demo:
			var guard = 0.0
			while not academy.demo_done and guard < 150.0:
				await wait(.25)
				guard += .25
			await wait(2.0)
		academy.set_phase("practica")
		await wait(2.5)
		await practice()
		await wait(1.0)
		var practice_ok: bool = academy.tasks.all(func(t): return t)
		await wait(2.0)
		academy.set_phase("examen")
		await wait(3.0)
		await exam()
		var report: Dictionary = academy.exam_last
		results.append({"kind":academy.kind,"practice":practice_ok,"exam":report.get("passed",false),"score":report.get("score",0),"lines":report.get("lines",[])})
		print("ACADEMY PLAY %d %s: practice %s (%s) · exam %s %d" % [n,academy.kind,"ok" if practice_ok else "NO",str(academy.tasks),"ok" if report.get("passed",false) else "NO",report.get("score",0)])
		await wait(1.0)
	academy.exit_lesson()
	running = false

# ---- Hands ----
func aim(who, x = .5, y = .3, seconds = 1.8) -> void:
	if not is_instance_valid(who): return
	academy.frame_goal = {"who":who,"x":x,"y":y}
	await wait(seconds)

# Put an AF point on the person (as a click on it would) and focus.
func focus_on(who) -> void:
	if not is_instance_valid(who): return
	var point = academy.point_on(who,6.0)
	if point >= 0: main.finder.active = point
	if main.equipment.focus_mode == "MF": main.set_manual_focus(main.camera.global_position.distance_to(who.control_points()[1]))
	else: main.autofocus()
	await wait(.6)

func shoot(hold = 3.2) -> void:
	await main.take_photo()
	await wait(hold)
	if main.mode == "RESULT": main.resume_search()
	await wait(.7)

func step(parameter: String, direction: int, times = 1) -> void:
	main.selected_control = parameter
	for i in times:
		main.change_parameter(parameter,direction)
		await wait(.4)

func aperture_to(f_number: float) -> void:
	var guard = 0
	while main.aperture_value() < f_number-.01 and main.n_index < main.apertures().size()-1 and guard < 12:
		await step("n",1)
		guard += 1
	while main.aperture_value() > f_number+.01 and main.n_index > 0 and guard < 24:
		await step("n",-1)
		guard += 1

func speed_to(denominator: int) -> void:
	var goal = Photo.DENOMINATORS.find(denominator)
	var guard = 0
	while main.t_index != goal and guard < 14:
		await step("t",signi(goal-main.t_index))
		guard += 1

# Bring the meter to the centre in whole stops: with the shutter while it stays hand-holdable,
# then the aperture, then the ISO.
func centre_meter(slowest = 0) -> void:
	for i in 16:
		var needle: float = academy.exam_needle()
		if absf(needle) <= .5: return
		var more_light = needle < 0
		var slower = main.t_index+1 < Photo.DENOMINATORS.size() and (slowest <= 0 or Photo.DENOMINATORS[main.t_index+1] >= slowest)
		if more_light:
			if slower: await step("t",1)
			elif main.n_index > 0: await step("n",-1)
			else: await step("iso",1)
		else:
			if main.t_index > main.fastest_index(): await step("t",-1)
			elif main.n_index < main.apertures().size()-1: await step("n",1)
			else: await step("iso",-1)

# The runner crossing in front: wait for it and shoot as it passes the middle of the frame.
func shoot_runner() -> void:
	var waited = 0.0
	while waited < 25.0:
		var r = academy.runner
		if is_instance_valid(r):
			var off = rad_to_deg(angle_difference(deg_to_rad(main.angle),deg_to_rad(r.theta)))
			if absf(off) < 5.0 and r.visible: break
		await main.get_tree().process_frame
		waited += main.get_process_delta_time()
	await shoot()

# A pan: the key held the runner's way from before it arrives (main.gd waits for it, then goes with
# it), and the photo once the camera has been following for a moment.
func pan_runner() -> void:
	for attempt in 4:
		var r = academy.runner
		var waited = 0.0
		# Hold the key when the runner is coming and still a little short of the middle.
		while waited < 25.0:
			if is_instance_valid(r) and r.visible:
				var off = rad_to_deg(angle_difference(deg_to_rad(main.angle),deg_to_rad(r.theta)))*r.direction
				if off > -14.0 and off < -4.0: break
			await main.get_tree().process_frame
			waited += main.get_process_delta_time()
		main.demo_keys["turn"] = float(r.direction)
		var following = 0.0
		var held = 0.0
		while held < 5.0 and following < .5:
			await main.get_tree().process_frame
			held += main.get_process_delta_time()
			following = following+main.get_process_delta_time() if main.follow_state == "siguiendo" else 0.0
		if following >= .5: await shoot()
		main.demo_keys.erase("turn")
		await wait(.8)
		if academy.tasks[2]: return
		if main.mode == "RESULT": main.resume_search()

# ---- The practices ----
func practice() -> void:
	var s = academy.subject
	match academy.kind:
		"composicion":
			main.finder.thirds = true
			await wait(1.2)
			academy.frame_goal = {"who":s,"x":academy.lead_x(s),"y":1.0/3.0,"lead":true}
			await wait(3.0)
			await shoot()
		"enfoque":
			await aim(s,.5,.3)
			main.finder.active = 3
			await wait(1.0)
			await focus_on(s)
			main.toggle_lock()
			await wait(1.0)
			await aim(s,.28,.3,2.2)
			await shoot()
		"focal":
			academy.do_action("lens:3:28")
			await aim(s,.5,.08,2.0)
			await focus_on(s)
			await shoot()
			academy.do_action("lens:5:135")
			academy.frame_goal = {"who":academy.second,"x":.5,"y":.08,"snap":true}
			await wait(2.0)
			await focus_on(academy.second)
			await shoot()
		"exposicion":
			await aperture_to(11.0)
			await wait(.8)
			await centre_meter()
			await wait(.8)
			await shoot()
		"dof":
			await aim(s,.5,.3)
			await focus_on(s)
			await aperture_to(1.8)
			await shoot()
			await aperture_to(8.0)
			await shoot()
		"movimiento":
			await speed_to(30)
			await shoot_runner()
			await speed_to(1000)
			await shoot_runner()
			await speed_to(30)
			await pan_runner()
		"medicion":
			academy.do_action("meter:puntual")
			await wait(1.2)
			await aim(s,.5,.3)
			await step("ev_comp",1,3)
			await wait(1.2)
			await step("ev_comp",-1,3)
			await focus_on(s)
			await shoot()
		"modos":
			await aim(s,.5,.3)
			academy.do_action("mode:A")
			await wait(.8)
			await aperture_to(4.0)
			await focus_on(s)
			await shoot()
			academy.do_action("mode:S")
			await wait(.8)
			await speed_to(500)
			await shoot()
			academy.do_action("mode:M")
			await wait(.8)
			await centre_meter(60)
			await shoot()
		"objetivos":
			await aim(s,.5,.3)
			while main.iso_value() > 100: await step("iso",-1)
			await aperture_to(4.0)
			await centre_meter()
			await wait(1.0)
			academy.do_action("lens:2:50")
			await wait(.8)
			await aperture_to(1.8)
			await centre_meter(60)
			await wait(1.0)
			await focus_on(s)
			await shoot()
		"camaras":
			for body in [1,3,2]:
				academy.do_action("body:%d" % body)
				await aim(s,.5,.3)
				await focus_on(s)
				await shoot()
	academy.frame_goal = {}

# ---- The exams ----
func exam() -> void:
	var s = academy.subject
	match academy.kind:
		"composicion":
			# The model walks: follow it with its head on a crossing and air in front.
			academy.frame_goal = {"who":s,"x":academy.lead_x(s),"y":1.0/3.0,"lead":true}
			await wait(3.5)
		"enfoque":
			await aim(s,.5,.3)
			await focus_on(s)
		"focal":
			academy.do_action("lens:5:135")
			academy.frame_goal = {"who":academy.second,"x":.5,"y":.08,"snap":true}
			await wait(2.0)
			await focus_on(academy.second)
		"exposicion":
			await centre_meter()
		"dof":
			await aim(s,.36,.3,2.2)
			await aperture_to(22.0)
			await focus_on(s)
		"movimiento":
			await speed_to(1000)
			await shoot_runner()
			academy.frame_goal = {}
			return
		"medicion":
			academy.do_action("meter:puntual")
			await aim(s,.5,.3)
			await step("ev_comp",1,3)
			await focus_on(s)
		"modos":
			await aim(s,.5,.3)
			academy.do_action("mode:A")
			await wait(.6)
			await aperture_to(2.8)
			await focus_on(s)
		"objetivos":
			academy.do_action("lens:0:24")
			await wait(.8)
			await aim(s,.5,.4)
			await speed_to(30)
			await centre_meter(30)
		"camaras":
			academy.do_action("body:3")
			await aim(s,.5,.3)
			await focus_on(s)
	await shoot(4.5)
	academy.frame_goal = {}
