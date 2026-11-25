extends Node
# A Paparazzi run in progress (docs/futuro/29): the level, the person to find, the photo asked
# for, the clock, the photo itself and the end. The rules are in scripts/paparazzi.gd (pure, tested
# headless); this node applies them to the park in front of the player. It lives in main and is
# idle (active = false) outside the mode.
#
# The run's state is in Paparazzi.run (a static): it survives the reload of the scene when the run
# moves from one park to the other (§14).
#
# E4: the playable mode without aiming aids. The lock-on, the auto-framing, the traffic light,
# the jokers and the rescue come with E5; the learning steps and the cheat sheet with E6.
const Paparazzi = preload("res://scripts/paparazzi.gd")
const Framing = preload("res://scripts/framing.gd")
const Texts = preload("res://scripts/texts.gd")
const Glyphs = preload("res://scripts/input_glyphs.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Ideal = preload("res://scripts/ideal_equipment.gd")
const Hud = preload("res://scripts/paparazzi_hud.gd")
const PLAYER_SAVE = "user://paparazzi.cfg"
const NOTICEABLE = .10           # someone counts as «in the photo» from 10 % of the frame's height
const WHEEL_STEP = 1.15          # one notch of the wheel or the D-pad (never skips a shot, §7.6)
const KEY_ZOOM = 1.2             # W/S: ×e^(±1.2·dt)
const PAD_ZOOM = 1.6             # right stick: ×e^(±1.6·dt)
const IN_VIEW = 30.0             # levels 1–3: the view starts within this turn of the person
const CONTACTS = 12              # photos kept for the contact sheet
# Camera keys that do nothing here (§13): exposure, focus, guides, metering, AF points, the strip.
const IDLE_KEYS = [KEY_Q,KEY_E,KEY_Z,KEY_X,KEY_C,KEY_V,KEY_R,KEY_T,KEY_F,KEY_M,KEY_B,KEY_K,KEY_L,KEY_G,
	KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_TAB,KEY_COMMA,KEY_PERIOD,KEY_PAGEUP,
	KEY_PAGEDOWN,KEY_I,KEY_F1,KEY_H,KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_MINUS,KEY_EQUAL,
	KEY_KP_SUBTRACT,KEY_KP_ADD]
const LANE_LINES = [Vector2(1.33,2.12), Vector2(3.07,4.57), Vector2(6.38,7.62), Vector2(10.80,12.04)]   # main.gd

var main
var active = false
var spec = {}
var request = {}
var step = 0                     # the photo of a reportage (0–2)
var fails_here = 0
var shown = []                   # the traits shown on the card (indices 0–3)
var rng = RandomNumberGenerator.new()
var hud
var saved_equipment = null       # the player's camera, kept aside during the run
var cards = []                   # novelty cards still to show before the level's card
var brief_open = false           # the level's card is on screen (a look or a zoom closes it)
var recent = []                  # the last people asked for (not again soon)
var still_wanted = false         # the person is asked for still or seated (kept so: activity_on_duty)
var pending_toast = ""           # said once the level's card is closed
var last_evidence = {}           # (tests)
var last_verdict = {}

var bank: float:
	get: return float(Paparazzi.run.get("bank",0.0))
	set(value): Paparazzi.run["bank"] = value

func _ready() -> void:
	hud = Hud.new(self)
	main.ui.add_child(hud)
	if is_instance_valid(main.touch_controls): main.ui.move_child(hud,main.touch_controls.get_index())

# Only the game itself writes the player's progress; tests point Paparazzi.SAVE to their own file.
func may_save() -> bool:
	return main.badges_count() or Paparazzi.SAVE != PLAYER_SAVE

# ---------------------------------------------------------------------------------------------
# Start, resume, stop

# A new run from level n (1 or a consolidated milestone's next).
func start(n: int) -> void:
	var progress = Paparazzi.load_progress() if may_save() else {"record":0,"hito":0}
	Paparazzi.run = {"n":n, "start":n, "bank":Paparazzi.START_BANK, "jokers":Paparazzi.start_jokers(n),
		"contacts":[], "seed":randi(), "record_before":int(progress.record), "seen":{}}
	recent.clear()
	enter()

# After the scene reloads with the run going on (main._ready()).
func resume() -> void:
	if Paparazzi.run.is_empty(): return
	enter()

# Into the park of the current level: the same one, or a reload into the other.
func enter() -> void:
	var s = Paparazzi.level_spec(int(Paparazzi.run.n))
	if s.scenario != main.scenario:
		restore_equipment()          # (reload_with() keeps the player's camera, not the ideal one)
		active = false
		main.reload_with(s.scenario,{"paparazzi":true})
		return
	active = true
	use_ideal()
	main.arcade_level = -1
	main.start_session(s.time,false)       # → on_session_started()

func use_ideal() -> void:
	if saved_equipment == null:
		saved_equipment = main.equipment
		main.equipment = Ideal.new()
	main.apply_equipment()
	main.update_dof_pass()

func restore_equipment() -> void:
	if saved_equipment == null: return
	main.equipment = saved_equipment
	saved_equipment = null
	main.apply_equipment()

# Out of the mode (the menu): the player's camera back, nobody protected.
func stop() -> void:
	active = false
	brief_open = false
	if is_instance_valid(main.target): main.target.protected_target = false
	restore_equipment()
	Paparazzi.run = {}
	if hud: hud.visible = false
	main.update_dof_pass()

# main.start_session() has set the park, the light and the camera.
func on_session_started() -> void:
	main.focal = 24.0
	main.update_camera()
	begin_level()

# ---------------------------------------------------------------------------------------------
# A level

func begin_level() -> void:
	spec = Paparazzi.level_spec(int(Paparazzi.run.n))
	if spec.time != main.time_of_day: main.preview_time(spec.time)
	main.walk_pace = spec.pace
	rng.seed = hash([Paparazzi.run.seed,spec.n,Paparazzi.run.get("skips",0)])
	request = Paparazzi.level_request(spec,rng)
	step = 0
	fails_here = 0
	choose_target()
	var count = 4
	if spec.rasgos == "minimos":
		count = main.casting.predicates_for(main.target.traits,main.people.map(func(p): return p.traits)).size()
		if count == 0: count = 4
	shown = range(count)
	main.focal = 24.0
	main.update_camera()
	hud.set_request()
	cards.clear()
	for card in spec.cards:
		if not card_seen(card): cards.append(card)
	show_next_card()

func card_seen(card: String) -> bool:
	return Paparazzi.seen(card) if may_save() else Paparazzi.run.seen.has(card)

func mark_seen(card: String) -> void:
	if may_save(): Paparazzi.mark_seen(card)
	else: Paparazzi.run.seen[card] = true

# The request of the photo now (a reportage asks for its planes one after another).
func current_request() -> Dictionary:
	if request.has("sequence"): return {"plane":request.sequence[step],"mods":request.mods}
	return request

# ---------------------------------------------------------------------------------------------
# Novelty cards and the level's card (PZ_CARD): the park waits, and so does the clock.

func show_next_card() -> void:
	if cards.is_empty():
		show_brief()
		return
	var id: String = cards.pop_front()
	brief_open = false
	main.mode = "PZ_CARD"
	var root = main.create_modal()
	var box = Panel.new()
	box.position = Vector2(340,170)
	box.size = Vector2(600,340)
	box.add_theme_stylebox_override("panel",UiStyle.box(UiStyle.surf(.92),18,UiStyle.LINE,1,16))
	root.add_child(box)
	var title = main.label(box,Texts.get_text("pz_nov_%s_titulo" % id),Rect2(32,26,536,44),30,UiStyle.BRAND)
	title.add_theme_font_override("font",UiStyle.font("RussoOne-Regular"))
	var args = Paparazzi.card_args(id,spec)
	var body: String = Texts.get_rich("pz_nov_%s_texto" % id)
	if not args.is_empty(): body = body % args
	main.glyph_label(box,body,Rect2(32,88,536,160),18,UiStyle.INK)
	main.button(box,Texts.get_text("pz_entendido"),Rect2(358,262,210,52),func(): close_card(id),true)

func close_card(id: String) -> void:
	mark_seen(id)
	main.play_sfx("ui_aceptar",-6.0)
	show_next_card()

# The level's card, big: who, what photo, and «Go!». A look or a zoom also closes it.
func show_brief() -> void:
	main.mode = "PZ_CARD"
	brief_open = true
	var root = main.create_modal()
	var box = Panel.new()
	box.position = Vector2(190,110)
	box.size = Vector2(900,500)
	box.add_theme_stylebox_override("panel",UiStyle.box(UiStyle.surf(.92),18,UiStyle.LINE,1,16))
	root.add_child(box)
	var tramo_name = Texts.get_text("pz_tramo_%d" % spec.tramo) if spec.tramo <= 10 else Texts.get_text("pz_tramo_infinito")
	main.label(box,(Texts.get_text("pz_nivel") % spec.n)+" · "+(Texts.get_text("pz_tramo") % spec.tramo)+" · "+tramo_name,Rect2(330,26,540,24),15,UiStyle.SKY_DEEP)
	miniature(box,Rect2(30,30,270,440))
	main.label(box,Texts.get_text("pz_ficha_busca"),Rect2(330,64,540,20),13,UiStyle.SOFT)
	var desc: PackedStringArray = main.casting.descriptors(main.target.traits)
	for k in shown.size():
		var i: int = shown[k]
		var sample = hud.swatch(main.target.traits,i)
		if sample != null:
			var dot = Panel.new()
			dot.position = Vector2(330,96+k*36)
			dot.size = Vector2(22,22)
			dot.add_theme_stylebox_override("panel",UiStyle.box(sample,11,UiStyle.LINE,1))
			box.add_child(dot)
		main.label(box,desc[i],Rect2(364,90+k*36,506,32),21,UiStyle.INK)
	var y = 96+shown.size()*36+18
	main.label(box,Texts.get_text("pz_ficha_foto"),Rect2(330,y,540,20),13,UiStyle.SOFT)
	var cur = current_request()
	var plane_label = main.label(box,Paparazzi.plane_name(cur.plane),Rect2(330,y+22,540,40),28,UiStyle.BRAND)
	plane_label.add_theme_font_override("font",UiStyle.font("RussoOne-Regular"))
	var lines = []
	if request.has("sequence"):
		var names = []
		for plane in request.sequence: names.append(Paparazzi.plane_name(plane))
		lines.append(Texts.get_text("pz_reportaje_ficha") % " → ".join(names))
	for mod in cur.mods: lines.append(Paparazzi.mod_text(mod,cur.mods[mod],spec.scenario))
	if not lines.is_empty():
		main.label(box,"\n".join(lines),Rect2(330,y+68,540,60),18,UiStyle.SOFT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.button(box,Texts.get_text("pz_empezar"),Rect2(610,418,260,56),begin_search,true)
	main.button(box,Texts.get_text("pz_fin_menu"),Rect2(330,418,200,56),main.show_pause)

# The person turning, as in the arcade's briefing (main.show_assignment()).
func miniature(parent: Control, rect: Rect2) -> void:
	var container = SubViewportContainer.new()
	container.position = rect.position
	container.size = rect.size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)
	var view = SubViewport.new()
	view.size = Vector2i(rect.size)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .7
	view.add_child(env)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0)
	light.light_energy = .9
	view.add_child(light)
	var figure = preload("res://scripts/person.gd").new()
	view.add_child(figure)
	figure.setup(main.target.traits.duplicate(true),main.casting.catalog,703)
	figure.state = "DETENIDO"
	figure.animate(0)
	var cam = Camera3D.new()
	view.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = figure.height*1.2
	cam.position = Vector3(0,figure.height*.52,-4)
	cam.look_at(Vector3(0,figure.height*.52,0))
	cam.current = true
	var tween = figure.create_tween().set_loops()
	tween.tween_property(figure,"rotation:y",TAU,8.0).from(0.0)

func begin_search() -> void:
	if main.mode != "PZ_CARD": return
	brief_open = false
	main.close_modal()
	main.mode = "SEARCH"
	main.place_view()
	main.refresh()
	if pending_toast != "":
		main.notify_player(pending_toast)
		pending_toast = ""

# ---------------------------------------------------------------------------------------------
# Who (§10.2)

func choose_target() -> void:
	if is_instance_valid(main.target): main.target.protected_target = false
	still_wanted = false
	var pool = main.people.filter(func(p): return is_instance_valid(p) and p.visible and p.state != "RETIRADO" and not p.has_meta("away"))
	var fresh = pool.filter(func(p): return not p in recent)
	if not fresh.is_empty(): pool = fresh
	var chosen = null
	var seat = false
	for attempt in 8:
		var candidates = pool.filter(func(p): return suits(p))
		# Levels 1 and 3 want someone still: failing that, a walker of the bench path sits down.
		if candidates.is_empty() and learning_still() and not main.crowd:
			candidates = pool.filter(func(p): return can_sit(p) and in_reach(p))
			seat = not candidates.is_empty()
		if not candidates.is_empty():
			chosen = prefer(candidates)
			break
		seat = false
		if not request.mods.is_empty():
			var last = request.mods.keys()[-1]
			request.mods.erase(last)
			print("PAPARAZZI_FALLBACK n=%d motivo=sin_%s" % [spec.n,last])
		elif not request.has("sequence") and request.plane != "entero":
			print("PAPARAZZI_FALLBACK n=%d motivo=plano_%s" % [spec.n,request.plane])
			request.plane = "entero"
		elif request.has("sequence"):
			print("PAPARAZZI_FALLBACK n=%d motivo=reportaje" % spec.n)
			request.erase("sequence")
			request.plane = "entero"
		else:
			break
	if chosen == null:
		print("PAPARAZZI_FALLBACK n=%d motivo=cualquiera" % spec.n)
		chosen = pool[rng.randi()%pool.size()]
	main.target = chosen
	chosen.protected_target = true
	if chosen.state in ["DETENIDO","SENTADO"] and learning_still(): chosen.state_time = maxf(chosen.state_time,90.0)
	recent.append(chosen)
	if recent.size() > 5: recent.pop_front()
	if seat or (request.mods.has("actividad") and not main.crowd):
		still_wanted = true
		main.seat_target()
	elif learning_still():
		still_wanted = true
	# Levels 1–3: the person is in view, a little off the middle, so the first search is short.
	# (After seat_target(), which takes the person to a bench.)
	if spec.in_view and not main.crowd:
		main.angle = fposmod(bearing_of(chosen)+(IN_VIEW*.5 if rng.randf() < .5 else -IN_VIEW*.5),360.0)
		main.pitch = 0.0
	# The runner of a «quien corre» level keeps running.
	if chosen.runner and main.runner_on_duty(chosen): chosen.pending_stop = {}

func learning_still() -> bool:
	return spec.n in [1,3]

# Prefers someone with look-alikes when the stretch has them (the look-alikes themselves are E7).
func prefer(candidates: Array):
	return candidates[rng.randi()%candidates.size()]

# Whether this person can be asked for in this request.
func suits(p) -> bool:
	var planes: Array = request.get("sequence",[request.plane])
	var classic = main.crowd == null
	if classic:
		for plane in planes:
			if not Framing.fits(plane,Framing.rest_heights(p),LANE_LINES[p.lane].x,LANE_LINES[p.lane].y,Ideal.IDEAL.min,Ideal.IDEAL.max): return false
	var wide_only = planes.all(func(plane): return plane in ["entero","general"])
	if p.is_child() and not wide_only: return false
	if p.runner and not (spec.runners and wide_only): return false
	if spec.debut == "corredor" and not p.runner: return false
	if not in_reach(p): return false
	if learning_still() and not p.state in ["DETENIDO","SENTADO"]: return false
	if spec.n == 2 and classic and not (p.lane == 1 and p.state == "CAMINANDO"): return false
	for mod in request.mods:
		match mod:
			"perro":
				if main.dog == null or p != main.dog.walker: return false
			"actividad":
				if not classic or not can_sit(p): return false
			"frente":
				if classic and (not p.state in ["DETENIDO","SENTADO"] or main.facing_of(p) > Paparazzi.FRONT_MAX): return false
			"perfil":
				if classic and p.state != "CAMINANDO": return false
			"lugar":
				if classic and p.lane != 2: return false
				if not classic:
					var place: Vector3 = main.park.places.get(request.mods.lugar,Vector3.ZERO)
					if p.global_position.distance_to(place) > 15.0: return false
			"acompanada":
				if company(p) < int(request.mods.acompanada): return false
	return true

# Within the level's search: in view (levels 1–3), a turn away (classic) or at a distance (big park).
func in_reach(p) -> bool:
	if main.crowd:
		var d = main.camera.global_position.distance_to(p.global_position)
		return spec.dist == Vector2.ZERO or (d >= spec.dist.x and d <= spec.dist.y)
	# (Levels 1–3: anyone; the view is then turned towards the person, see choose_target().)
	if spec.in_view: return true
	var turn = absf(rad_to_deg(angle_difference(deg_to_rad(bearing_of(p)),deg_to_rad(main.angle))))
	return turn >= spec.min_turn

# Where someone is seen from the middle of the classic park (the convention of main.aim_at()).
func bearing_of(p) -> float:
	return rad_to_deg(atan2(p.global_position.x,-p.global_position.z))

# An adult walker of the bench path with free hands, who can be sat down with something to do.
func can_sit(p) -> bool:
	return p.lane == 1 and not p.is_child() and not p.hand_busy and not p.never_sits and not p.has_dog and p.state == "CAMINANDO" and not p.runner

# How many people walk with this one: on its path within 15° (classic), within 3 m (big park).
func company(p) -> int:
	var n = 0
	for q in main.people:
		if q == p or not q.visible or q.state == "RETIRADO": continue
		if main.crowd:
			if q.global_position.distance_to(p.global_position) <= 3.0: n += 1
		elif q.lane == p.lane and absf(angle_difference(deg_to_rad(q.theta),deg_to_rad(p.theta))) <= deg_to_rad(15.0):
			n += 1
	return n

# ---------------------------------------------------------------------------------------------
# Every frame of the search

func update(dt: float) -> void:
	if not active or main.mode != "SEARCH": return
	if spec.clock and not main.shooting:
		var before = ceili(bank)
		bank = maxf(0.0,bank-dt)
		if ceili(bank) != before and bank > 0.0 and bank <= 10.0: main.play_sfx("tictac",-2.0)
		if bank <= 0.0: time_out()

func time_out() -> void:
	main.play_sfx("tiempo_agotado",-4.0)
	end_run()

# The zoom: one notch (wheel, D-pad) or held (keys, stick).
func zoom_step(direction: int) -> void:
	main.focal = clampf(main.focal*pow(WHEEL_STEP,direction),Ideal.IDEAL.min,Ideal.IDEAL.max)
	main.update_camera()

func zoom_continuous(rate: float, dt: float) -> void:
	main.focal = clampf(main.focal*exp(rate*dt),Ideal.IDEAL.min,Ideal.IDEAL.max)

# ---------------------------------------------------------------------------------------------
# Input (main._unhandled_input() asks first; true = taken)

func handle_input(event: InputEvent) -> bool:
	if not active: return false
	var mode: String = main.mode
	if mode == "PZ_CARD":
		if brief_open and closes_brief(event):
			begin_search()
			return false        # (the look or the zoom goes on as usual)
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if brief_open: main.show_pause()
			return true
		return false
	if mode == "PZ_END":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			main.intro()
			return true
		return false
	if mode != "SEARCH": return false
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_Y and not main.crowd: return true
		if event.physical_keycode in IDLE_KEYS: return true
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if main.crowd and not main.camera_raised: return false     # (the big park: the wheel brings the camera up)
		zoom_step(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE: return true
	return false

# Whatever looks around or zooms (the level's card gives way to it).
func closes_brief(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode in [KEY_W,KEY_S,KEY_A,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]
	if event is InputEventMouseButton and event.pressed: return event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]
	if event is InputEventJoypadMotion: return absf(event.axis_value) > .6 and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_Y]
	return false

# A click without dragging (the lock-on, E5).
func click(_point: Vector2) -> void:
	pass

# Gamepad buttons while searching (main.pad_button() asks first; true = taken).
func pad_button(event: InputEventJoypadButton) -> bool:
	if not active or not event.pressed or main.mode != "SEARCH": return false
	match event.button_index:
		JOY_BUTTON_START: return false             # (the pause, as always)
		JOY_BUTTON_DPAD_UP: zoom_step(1)
		JOY_BUTTON_DPAD_DOWN: zoom_step(-1)
		JOY_BUTTON_Y:
			if main.crowd: return false            # (the big park: up and down with the camera)
	return true

# ---------------------------------------------------------------------------------------------
# The photo (§16.3): the ideal camera keeps the frame as it is.

func take_photo() -> void:
	if main.mode != "SEARCH" or main.shooting or not main.eye_ready(): return
	main.shooting = true
	main.rumble(.2,.75,.09)
	main.play_sfx("obturador_reflex_rapido",-4.0)
	await get_tree().physics_frame
	var e = capture(protagonist())
	var v = Paparazzi.judge(e,current_request())
	await RenderingServer.frame_post_draw
	var image: Image = main.viewport.get_texture().get_image()
	main.shooting = false
	last_evidence = e
	last_verdict = v
	if not active: return
	if v.ok: on_success(v,image)
	else: on_fail(v)

func inside(v: Vector2) -> bool:
	return v.x >= 0.0 and v.x <= 1.0 and v.y >= 0.0 and v.y <= 1.0

func candidates() -> Array:
	var out = main.people.filter(func(p): return is_instance_valid(p) and p.visible and p.state != "RETIRADO")
	if main.extras: out += main.extras.extras.filter(func(p): return is_instance_valid(p) and p.visible)
	return out

# Whom the photo is of (§6.4): the one whose eyes are in, most visible and nearest the middle of the
# frame across; how tall counts only up to 60 % of the frame (§6.4 gave height its full weight, and
# someone passing close by, half in the frame, won over the person framed in the middle).
func protagonist():
	var best = null
	var best_score = -1.0
	for p in candidates():
		var body = main.body_landmarks(p)
		if body.behind or not inside(body.eyes) or body.eyes.x < .04 or body.eyes.x > .96: continue
		var tall = clampf(body.feet.y,0,1)-clampf(body.crown.y,0,1)
		var score = minf(tall,.6)/.6*seen_fraction(p,body).x*maxf(0.0,1.0-1.4*absf(body.eyes.x-.5))
		if score > best_score:
			best_score = score
			best = p
	return best

# x: the share of the body's points inside the frame that the camera sees; y: 1 if the eyes are
# hidden. And the first thing in the way (label), in z of a Dictionary: see capture().
func seen_fraction(p, body: Dictionary) -> Vector2:
	var world = Framing.world_landmarks(p)
	var inside_count = 0
	var seen = 0
	for k in Framing.LANDMARKS:
		if not inside(body[k]): continue
		inside_count += 1
		if blocker(p,world[k]) == "": seen += 1
	return Vector2(float(seen)/maxf(1,inside_count),0)

# What stands between the camera and a point of p ("" if nothing).
func blocker(p, point: Vector3) -> String:
	var hit = main.ray_to(point)
	if hit.is_empty(): return ""
	if hit.collider.has_meta("person") and hit.collider.get_meta("person") == p: return ""
	return str(hit.collider.get_meta("label",Texts.get_text("un_elemento_del_parque")))

func capture(p) -> Dictionary:
	if p == null: return {"has_subject":false}
	var world = Framing.world_landmarks(p)
	var body = Framing.project(world,main.camera,Vector2(main.viewport.size))
	var inside_count = 0
	var seen = 0
	var blockers = []
	for k in Framing.LANDMARKS:
		if not inside(body[k]): continue
		inside_count += 1
		var what = blocker(p,world[k])
		if what == "": seen += 1
		elif not what in blockers: blockers.append(what)
	var eyes_blocker = blocker(p,world.eyes)
	var others = 0
	for q in candidates():
		if q == p: continue
		var chest: Vector3 = q.control_points()[1]
		if main.camera.is_position_behind(chest): continue
		var at = main.camera.unproject_position(chest)/Vector2(main.viewport.size)
		if not inside(at): continue
		var top = main.camera.unproject_position(q.global_position+Vector3.UP*q.height)/Vector2(main.viewport.size)
		var bottom = main.camera.unproject_position(q.global_position)/Vector2(main.viewport.size)
		if absf(bottom.y-top.y) < NOTICEABLE: continue
		if blocker(q,chest) != "": continue
		others += 1
	var dog_in = false
	if main.dog and is_instance_valid(main.dog) and main.dog.walker == p:
		var at: Vector3 = main.dog.global_position+Vector3.UP*.25
		dog_in = not main.camera.is_position_behind(at) and inside(main.camera.unproject_position(at)/Vector2(main.viewport.size))
	var places = {}
	for key in main.park.places:
		var spot: Vector3 = main.park.places[key]+Vector3.UP*1.6
		places[key] = not main.camera.is_position_behind(spot) and inside(main.camera.unproject_position(spot)/Vector2(main.viewport.size))
	var target = main.target
	return {"has_subject":true, "is_target":p == target, "body":body,
		"visible":float(seen)/maxf(1,inside_count), "face_blocked":eyes_blocker != "", "blockers":([eyes_blocker] if eyes_blocker != "" else [])+blockers,
		"others":others, "facing":main.facing_of(p), "covering":str(p.activity) == "taparse",
		"activity":str(p.activity) if p.state in ["SENTADO","DETENIDO"] else "", "seated":p.state == "SENTADO",
		"dog_in_frame":dog_in, "places":places,
		"subject_desc_es":main.casting.descriptors(p.traits,"es"), "target_desc_es":main.casting.descriptors(target.traits,"es"),
		"subject_desc":main.casting.descriptors(p.traits), "target_desc":main.casting.descriptors(target.traits),
		"shown":PackedInt32Array(shown), "f":main.focal, "scenario":main.scenario, "time":main.time_of_day}

func on_success(v: Dictionary, image: Image) -> void:
	main.play_sfx("condicion_ok",-2.0)
	var contacts: Array = Paparazzi.run.contacts
	contacts.append({"image":image,"plane":v.plane})
	while contacts.size() > CONTACTS: contacts.pop_front()
	# A reportage: the next photo of the same person, no bonus until the third.
	if request.has("sequence") and step < request.sequence.size()-1:
		step += 1
		hud.set_request()
		main.notify_player(Texts.get_text("pz_reportaje_siguiente") % [step+1,Paparazzi.plane_name(request.sequence[step])])
		return
	var lines = []
	if spec.clock:
		var before = bank
		var first = fails_here == 0 and spec.tramo >= 2
		var clean = v.clean_cut and spec.tramo >= 4
		bank = Paparazzi.after_success(bank,spec,{"first_try":first,"clean_cut":clean,"hito":spec.hito})
		hud.show_flash(Texts.get_text("pz_bonus") % roundi(bank-before),true)
		lines.append(Texts.get_text("pz_bonus") % roundi(bank-before))
		if clean: lines.append(Texts.get_text("pz_corte_limpio") % int(Paparazzi.CLEAN_CUT_BONUS))
		if first: lines.append(Texts.get_text("pz_primera") % int(Paparazzi.FIRST_TRY_BONUS))
	else:
		lines.append(Texts.get_text("pz_bien"))
	if may_save(): Paparazzi.level_passed(spec.n)
	Paparazzi.run["passed"] = spec.n
	if spec.hito: lines.append(Texts.get_text("pz_hito_consolidado") % (spec.n+1))
	pending_toast = " · ".join(lines)
	Paparazzi.run.n = spec.n+1
	main.target.protected_target = false
	if Paparazzi.level_spec(spec.n+1).scenario != main.scenario:
		main.notify_player(pending_toast)
		enter()
		return
	begin_level()

func on_fail(v: Dictionary) -> void:
	main.play_sfx("foto_rechazada",-4.0)
	main.notify_player(Paparazzi.reason_text(v.reasons[0]))
	fails_here += 1
	if spec.clock and spec.penalty > 0.0:
		bank = Paparazzi.after_fail(bank,spec)
		hud.show_flash(Texts.get_text("pz_penal") % int(spec.penalty),false)

# ---------------------------------------------------------------------------------------------
# The end (PZ_END, §3.6)

func end_run() -> void:
	if Paparazzi.run.is_empty(): return
	var reached = int(Paparazzi.run.n)
	if may_save(): Paparazzi.run_ended()
	var passed = int(Paparazzi.run.get("passed",0))      # the last level passed in this run
	var progress = Paparazzi.load_progress() if may_save() else {"record":maxi(passed,int(Paparazzi.run.record_before)),"hito":passed/10}
	var new_record = passed > int(Paparazzi.run.record_before)
	var from = 10*int(progress.hito)+1
	main.mode = "PZ_END"
	brief_open = false
	var root = main.create_modal()
	main.label(root,Texts.get_text("pz_fin_record") if new_record else Texts.get_text("pz_fin_titulo"),Rect2(50,40,1180,60),43,UiStyle.BRAND if new_record else UiStyle.INK)
	var info = [Texts.get_text("pz_fin_nivel") % reached, Texts.get_text("pz_fin_mejor") % int(progress.record), Texts.get_text("pz_fin_desde") % from]
	main.label(root,"\n".join(info),Rect2(805,150,420,200),24,UiStyle.INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var contacts: Array = Paparazzi.run.contacts
	for k in contacts.size():
		var at = Vector2(50+(k%4)*180,150+(k/4)*130)
		var shot = TextureRect.new()
		shot.texture = ImageTexture.create_from_image(contacts[k].image)
		shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shot.position = at
		shot.size = Vector2(170,96)
		root.add_child(shot)
		main.label(root,Paparazzi.plane_name(contacts[k].plane),Rect2(at.x,at.y+98,170,18),12,UiStyle.SOFT)
	main.button(root,Texts.get_text("pz_fin_otra") % from,Rect2(805,420,410,56),func(): start(from),true)
	if from > 1: main.button(root,Texts.get_text("pz_fin_inicio"),Rect2(805,490,410,52),func(): start(1))
	main.button(root,Texts.get_text("pz_fin_menu"),Rect2(805,556 if from > 1 else 490,410,52),main.intro)
