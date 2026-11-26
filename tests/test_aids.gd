extends SceneTree
# Paparazzi's aids in the other modes (docs/futuro/29 §24): the shots' cheat sheet from the help,
# the pictogram of the shot asked for on the assignment's line and in the result, the brackets of
# the follow, the zone in the big park's briefing and the extra aids of Options (the arrow in the big
# park's arcade, the live shot in the sandbox). Never writes the player's files.
#   ~/bin/godot-4-fp --path . --disable-vsync --script tests/test_aids.gd
const Arcade = preload("res://scripts/arcade.gd")
const Conditions = preload("res://scripts/conditions.gd")
const Texts = preload("res://scripts/texts.gd")
const MainScript = preload("res://scripts/main.gd")
const PlaneIcon = preload("res://scripts/plane_icon.gd")
const Framing = preload("res://scripts/framing.gd")
var checks = 0
var failures = 0
var game

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func level_with(test: Callable) -> int:
	for n in Arcade.LEVELS.size():
		if test.call(Arcade.LEVELS[n]): return n
	return -1

func open(scenario: String) -> void:
	if game: game.queue_free()
	await frames(3)
	MainScript.scenario = scenario
	preload("res://scripts/album.gd").DIR = "user://album_pruebas"
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	Arcade.SAVE = "user://arcade_pruebas.cfg"
	game.pad_polling = false
	game.exposure_thirds = false
	await frames(20)

func icons(node: Node) -> Array:
	return node.find_children("*","",true,false).filter(func(c): return c.get_script() == PlaneIcon)

func run() -> void:
	Texts.set_language("es",false)
	# --- The condition of a shot keeps what was asked for and what was made ---
	var body = {"behind":false,"eyes":Vector2(.5,.2),"chin":Vector2(.5,.3)}
	var got = Conditions.check({"f":50.0,"n":4.0,"t":.004,"iso":100,"s":5.0,"d":5.0,"v":0.0,"scene_ev":14.0,"head":Vector2(.4,.2),"feet":Vector2(.4,.85),"chest":Vector2(.4,.45),"in_front":true,"blockers":[],"others":[]},{"plano":"americano"})
	check(got.size() == 1 and got[0].get("want","") == "americano" and got[0].has("made"),"The shot's condition carries the shot asked for and the one made (%s)" % str(got))
	# --- A level about a shot (block 7) ---
	var lv = level_with(func(l): return str(l.get("cond",{}).get("plano","")) == "americano")
	await open(Arcade.LEVELS[lv].scenario)
	game.start_level(lv)
	await frames(20)
	check(game.mode == "BRIEFING","The level opens with its briefing")
	check(Texts.get_text("arcade_plano_chuleta") in game.modal.find_children("*","RichTextLabel",true,false).map(func(r): return r.get_parsed_text()).reduce(func(a,b): return a+b,""),"…which says where the cheat sheet is")
	game.begin_assignment()
	await frames(5)
	check(game.arcade_icon.visible and game.arcade_icon.plane == "americano","The assignment's line shows the pictogram of the shot asked for")
	check(game.shot_level(),"…in a level about a shot")
	game.help_key()
	await frames(3)
	check(game.mode == "HELP" and icons(game.modal).size() == 6,"The help key opens the cheat sheet with the six shots (%d)" % icons(game.modal).size())
	check(game.modal.find_children("*","Label",true,false).any(func(l): return l.text == Texts.get_text("chuleta_pedido") % Conditions.plane_name("americano")),"…saying which shot the level asks for")
	game.show_help()
	await frames(3)
	check(game.mode == "HELP" and game.modal.find_children("*","Button",true,false).any(func(b): return b.text == Texts.get_text("ayuda_chuleta")),"The controls have a button for the cheat sheet")
	game.help_back()
	await frames(3)
	check(game.mode == "SEARCH","«Volver» returns to the search")
	# The result: the shot asked for beside the one made.
	var row = game.shots_compared({"ok":false,"want":"americano","made":"medio"})
	check(icons(row).map(func(i): return i.plane) == ["americano","medio"],"The result compares the pictograms of the shot asked for and the one made")
	row = game.shots_compared({"ok":false,"want":"americano","made":""})
	check(icons(row).size() == 2 and icons(row)[1].plane == "cualquiera","…and nobody framed is a grey figure")
	row.free()
	# --- The follow: brackets on whoever the camera follows ---
	if not game.camera_raised: game.set_raised(true)
	game.raise_anim = 1.0
	game.aim_at(game.target,1.0)
	await frames(2)
	game.follow_state = "siguiendo"
	game.follow_subject = game.target
	var box: Rect2 = game.body_box(game.target)
	check(game.aim_overlay.visible and box.has_area() and game.view_rect.intersects(box),"The person followed has a box on the camera's image (%s in %s)" % [str(box),str(game.view_rect)])
	game.follow_state = ""
	game.follow_subject = null
	# --- A level elsewhere does not show the pictogram ---
	var plain = level_with(func(l): return not l.get("cond",{}).has("plano") and l.scenario == Arcade.LEVELS[lv].scenario)
	game.start_level(plain)
	await frames(20)
	game.begin_assignment()
	await frames(3)
	check(not game.arcade_icon.visible and not game.shot_level(),"A level without a shot has no pictogram, and the help key opens the controls")
	# --- The big park's arcade: the zone in the briefing; the arrow only with the extra aids ---
	var far = level_with(func(l): return l.scenario == "grande" and str(l.get("target","")) != "anyone")
	await open("grande")
	game.start_level(far)
	await frames(30)
	var zone: String = game.pz.zone_text()
	check(zone != "" and game.modal.find_children("*","Label",true,false).any(func(l): return l.text.begins_with(zone.get_slice(" · ",0))),"The big park's briefing says where the person is (%s)" % zone)
	game.begin_assignment()
	await frames(3)
	if not game.camera_raised: game.set_raised(true)
	game.raise_anim = 1.0
	# Back to the person: she is not on screen.
	game.aim_at(game.target,1.0)
	game.angle = fposmod(game.angle+180.0,360.0)
	game.update_camera()
	await frames(2)
	game.extra_aids = false
	game.aim_overlay.lost_time = 60.0
	await frames(2)
	check(not game.aim_overlay.arrow_on(),"Without the extra aids, no arrow")
	game.extra_aids = true
	await frames(2)
	check(not game.aim_overlay.arrow_on() and game.aim_overlay.lost_time < 1.0,"With them, not at once")
	game.aim_overlay.lost_time = game.aim_overlay.ARROW_AFTER
	await frames(2)
	check(game.aim_overlay.arrow_on(),"…but after %d s without the person on screen" % game.aim_overlay.ARROW_AFTER)
	var d: Vector2 = game.aim_overlay.arrow_direction()
	check(d.is_normalized(),"…pointing somewhere (%s)" % str(d))
	game.aim_at(game.target,1.0)
	await frames(3)
	check(not game.aim_overlay.arrow_on(),"Once she is on screen, the arrow goes")
	# --- The sandbox: the live shot only with the extra aids ---
	await open("clasico")
	game.start_session("day",true)
	await frames(30)
	game.close_modal()
	game.mode = "SEARCH"
	if not game.camera_raised: game.set_raised(true)
	game.raise_anim = 1.0
	# Someone framed in a medium shot (whoever shows the face from where the camera stands).
	var framed = false
	for p in game.people.filter(func(q): return q.visible):
		var to = p.global_position-game.camera.global_position
		game.focal = clampf(Framing.focal_for("medio",Framing.rest_heights(p),Vector2(to.x,to.z).length()),game.equipment.lens().min,game.equipment.lens().max)
		game.update_camera()
		game.aim_point(Framing.world_landmarks(p).crown,Vector2(.5,Framing.AIR),1.0)
		await frames(1)
		var who = game.framed_person()
		if who != null and Framing.classify(game.body_landmarks(who)).plane != "":
			framed = true
			break
	check(framed,"Someone can be framed in the sandbox")
	game.extra_aids = false
	game.arcade_shot_timer = 0.0
	await frames(3)
	check(not is_instance_valid(game.arcade_shot_label) or not game.arcade_shot_label.visible,"The sandbox shows no live shot by default")
	game.extra_aids = true
	game.arcade_shot_timer = 0.0
	await frames(3)
	check(is_instance_valid(game.arcade_shot_label) and game.arcade_shot_label.visible and game.arcade_shot_label.text.begins_with("Ahora:") and not game.arcade_shot_label.text.ends_with("✓"),"…and with the extra aids, the shot made, never ticked («%s»)" % (game.arcade_shot_label.text if is_instance_valid(game.arcade_shot_label) else ""))
	game.extra_aids = false
	print("AIDS TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
