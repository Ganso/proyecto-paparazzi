extends SceneTree
# Escena de análisis de la imagen partida (docs/futuro/28 §8): TLR, todos quietos, foco en alguien
# del fondo y una persona que cruza por delante, de derecha a izquierda de la pantalla. Se graba con
#   ~/bin/godot-4-fp --path . --rendering-method forward_plus --resolution 1920x1080 --write-movie <salida.avi> --fixed-fps 60 --script tools/capture_split_image.gd
# e imprime, fotograma a fotograma, dónde está quien cruza, el desplazamiento de la zona y qué
# tocan sus cinco rayos. El vídeo sale a 1440×810; la zona queda en (747, 369), radio ~51 px.
var game
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func screen_x(world: Vector3) -> float:
	var u = game.camera.unproject_position(world).x/float(game.viewport.size.x)
	return 1.0-u if game.equipment.tlr() else u      # (the waist-level finder is mirrored)
func describe(hit: Dictionary, crosser, subject) -> String:
	if hit.is_empty(): return "cielo"
	var d = game.camera.global_position.distance_to(hit.position)
	var c = hit.collider
	if c.has_meta("person"):
		var who = c.get_meta("person")
		return ("CRUZA" if who == crosser else ("SUJETO" if who == subject else "otra")) + " %.1f" % d
	return "fondo %.1f" % d
func run() -> void:
	game = load("res://main.tscn").instantiate()
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"
	root.add_child(game)
	await frames(60)
	game.intro()
	game.start_session("day",true)
	# PARTIDA_CUERPO=1: the rangefinder's double image instead of the TLR's split image.
	# PARTIDA_PLANA=1: the old single offset for the whole zone, to compare.
	game.equipment.preset(int(OS.get_environment("PARTIDA_CUERPO")) if OS.has_environment("PARTIDA_CUERPO") else 3)
	if OS.has_environment("PARTIDA_PLANA"): load("res://scripts/main.gd").aid_flat = true
	game.apply_equipment()
	game.resume_search()
	game.control_help.enabled = false
	await frames(120)
	game.sandbox_paused = true
	var far = game.people.filter(func(p): return p.lane == 3 and p.visible and not p.runner and p.height > 1.6)
	var near = game.people.filter(func(p): return p.lane == 2 and p.visible and not p.runner and p.height > 1.6)
	var subject = far[0]
	var crosser = near[0]
	# Everybody else out of the way of this view.
	for p in game.people:
		if p != subject and p != crosser and absf(angle_difference(deg_to_rad(p.theta),deg_to_rad(subject.theta))) < deg_to_rad(40.0): p.set_hidden(true)
	game.focal = 50.0
	crosser.theta = subject.theta+60.0
	crosser.position = game.park.polar(crosser.theta,7.0)
	await physics_frame
	game.aim_at(subject,1.0)
	game.update_camera()
	game.set_manual_focus(game.camera.global_position.distance_to(subject.control_points()[1]))
	await frames(30)
	# Which way round the park brings the crosser in from the right of the screen.
	var probe = game.park.polar(subject.theta+3.0,7.0)+Vector3.UP*1.2
	var side = 1.0 if screen_x(probe) > .5 else -1.0
	var start = subject.theta+side*7.0
	var step = -side*.045            # degrees per frame at 60 fps: 0.33 m/s at 7 m
	crosser.theta = start
	crosser.position = game.park.polar(crosser.theta,7.0)
	crosser.rotation.y = crosser.heading
	await frames(40)
	print("ESCENA sujeto a %.1f m (foco %.2f m), cruza a 7.0 m · fotograma inicial %d" % [game.camera.global_position.distance_to(subject.control_points()[1]),game.focus_distance,Engine.get_process_frames()])
	var total = int(14.0/absf(step))
	# PARTIDA_ANILLO=1: nobody crosses; the focusing ring goes from 3 m to 30 m and back instead.
	if OS.has_environment("PARTIDA_ANILLO"):
		crosser.set_hidden(true)
		for i in total:
			var along = .5-.5*cos(TAU*i/float(total))
			game.set_manual_focus(1.0/lerpf(1.0/3.0,1.0/30.0,along))
			await physics_frame
			await process_frame
		print("ESCENA fotograma final %d" % Engine.get_process_frames())
		quit()
		return
	var last_offset = -9.0
	for i in total:
		crosser.theta += step
		var before: Vector3 = crosser.position
		crosser.position = game.park.polar(crosser.theta,7.0)
		crosser.look_at(crosser.position+(crosser.position-before).normalized(),Vector3.UP,true)
		crosser.animate(1.0/60.0,before.distance_to(crosser.position))
		await physics_frame
		await process_frame
		if i % 6 == 0 or absf(game.smoothed_focus_aid_offset-last_offset) > .004:
			var c = game.view_rect.get_center()
			var seen = []
			for off in [Vector2.ZERO,Vector2(-24,0),Vector2(24,0),Vector2(0,-16),Vector2(0,16)]: seen.append(describe(game.point_hit(c+off),crosser,subject))
			var half = .078*game.view_rect.size.y
			var cx = (screen_x(crosser.control_points()[1])-.5)*game.view_rect.size.x
			print("F %d · cruza a %+.0f px del centro (zona ±%.0f) · desplazamiento %.4f · «%s» · rayos: %s" % [i,cx,half,game.smoothed_focus_aid_offset,"alineado" if game.finder.mf_coincidence else "ALINEAR",", ".join(seen)])
			last_offset = game.smoothed_focus_aid_offset
	print("ESCENA fotograma final %d · zona en %s de %s" % [Engine.get_process_frames(),str(game.view_rect.get_center()+game.view_shift),str(root.size)])
	quit()
