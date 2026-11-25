extends Node
# A Paparazzi run in progress (docs/futuro/29): the level, the person to find, the photo asked
# for, the clock, the photo itself and the end. The rules are in scripts/paparazzi.gd (pure, tested
# headless); this node applies them to the park in front of the player. It lives in main and is
# idle (active = false) outside the mode.
#
# The run's state is in Paparazzi.run (a static): it survives the reload of the scene when the run
# moves from one park to the other (§14).
#
# E4 made it playable; E5 added the aim (§7: lock-on, auto-framing, the zoom's detent) and the aids
# (§8: the traffic light, the live shot, the traits check, the arrow, the ring, the jokers and the
# rescue). The learning steps and the cheat sheet come with E6.
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
# The lock-on (§7).
const LOCK_REACH = Vector2(70,90)      # a click this close to someone's chest locks on to them
const RELEASE_FOCAL = 26.0             # the zoom opened all the way lets go
const FOLLOW_GAIN = 15.0               # the follow's smoothing, and its lead (1/gain s), measured
const PUSH_WINDOW = .6                 # a look away this long…
const PUSH_RELEASE = .4                # …of this much of the frame lets go (.6 framing by hand)
const PUSH_RELEASE_MANUAL = .6
const BEHIND_RELEASE = 1.5
const DETENT_HOLD = .35                # the shot asked for reached: the wheel waits this long…
const DETENT_SLOW = .4                 # …and the held zoom goes this much slower
const FREEZE_TIME = 5.0

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
# The aim (§7) and the aids (§8).
var locked = null                # the person the camera follows
var lock_time = 0.0
var pushes = []                  # [time, look pushed in frames] over the last PUSH_WINDOW
var last_set = Vector2.ZERO      # angle and pitch as the follow left them
var behind_time = 0.0
var zoom_touched = false         # the player zoomed this frame (the size kept starts again from there)
var f_ref = 0.0
var d_ref = 1.0
var offset = Vector2(.5,.5)      # framing by hand (tramo 10+): where the chest goes
var live = {}                    # the verdict on the locked person's frame now, identity aside
var on_plane = false             # the live shot is the one asked for
var detent_left = 0.0
var frozen = 0.0                 # seconds of the park standing still
var search_time = 0.0            # in this level (the arrow and the ring)
var now = 0.0
var locked_desc = PackedStringArray()   # the locked person's traits, in Spanish (§6.5)

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
	locked = null
	frozen = 0.0
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
	release()
	search_time = 0.0
	if main.crowd: main.set_raised(false)      # (the big park: every level starts walking)
	frozen = 0.0
	gift_jokers()
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

# From level 1 the jokers come at their debut levels (§3.5), once a run.
func gift_jokers() -> void:
	var jokers: Dictionary = Paparazzi.run.jokers
	for pair in [["congelar",Paparazzi.FREEZE_FROM],["otro",Paparazzi.SKIP_FROM]]:
		var key = "regalo_"+pair[0]
		if spec.n == pair[1] and not Paparazzi.run.has(key):
			Paparazzi.run[key] = true
			jokers[pair[0]] = mini(Paparazzi.JOKER_MAX,int(jokers[pair[0]])+1)

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
	card_panel(cards.pop_front(),close_card)

# A card over the still park; `closed` gets its id.
func card_panel(id: String, closed: Callable) -> void:
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
	main.button(box,Texts.get_text("pz_entendido"),Rect2(358,262,210,52),func(): closed.call(id),true)

func close_card(id: String) -> void:
	mark_seen(id)
	main.play_sfx("ui_aceptar",-6.0)
	show_next_card()

# A card about something that has just happened (the arrow, someone covering the face): read, and
# back to the search.
func show_event(id: String) -> void:
	card_panel(id,func(card):
		mark_seen(card)
		main.play_sfx("ui_aceptar",-6.0)
		begin_search())

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
	if not main.mode in ["PZ_CARD","PZ_RESCUE"]: return
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
	now += dt
	search_time += dt
	frozen = maxf(0.0,frozen-dt)
	detent_left = maxf(0.0,detent_left-dt)
	if spec.clock and not main.shooting:
		var before = ceili(bank)
		bank = maxf(0.0,bank-dt)
		if ceili(bank) != before and bank > 0.0 and bank <= 10.0: main.play_sfx("tictac",-2.0)
		if bank <= 0.0:
			time_out()
			return
	follow(dt)
	update_live()
	zoom_touched = false
	events()

# At zero: the rescue if there is one left (§3.5), else the end.
func time_out() -> void:
	main.play_sfx("tiempo_agotado",-4.0)
	if int(Paparazzi.run.jokers.get("rescate",0)) > 0: show_rescue()
	else: end_run()

# The zoom: one notch (wheel, D-pad) or held (keys, stick). Reaching the shot asked for, the wheel
# waits a moment and the held zoom slows down (§7.6): it tells, it does not zoom for the player.
func zoom_step(direction: int) -> void:
	if detent_left > 0.0: return
	main.focal = clampf(main.focal*pow(WHEEL_STEP,direction),Ideal.IDEAL.min,Ideal.IDEAL.max)
	zoom_touched = true
	main.update_camera()

func zoom_continuous(rate: float, dt: float) -> void:
	if locked != null and on_plane: rate *= DETENT_SLOW
	main.focal = clampf(main.focal*exp(rate*dt),Ideal.IDEAL.min,Ideal.IDEAL.max)
	zoom_touched = true

# ---------------------------------------------------------------------------------------------
# The lock-on (§7). Only when the player asks for it (a click on someone, {pz_enganchar}): it used
# to lock on by itself when zooming in, and kept jumping to whoever crossed the middle (user, E5).

# The middle of the frame, in main.ui's coordinates (as main.finder_position()).
func middle() -> Vector2:
	return main.view_rect.get_center()+main.view_shift

func lock(p) -> void:
	if p == null or p == locked: return
	locked = p
	lock_time = 0.0
	pushes.clear()
	behind_time = 0.0
	last_set = Vector2(main.angle,main.pitch)
	f_ref = main.focal
	d_ref = flat_distance(p)
	var chest: Vector3 = p.control_points()[1]
	offset = (main.camera.unproject_position(chest)/Vector2(main.viewport.size)).clamp(Vector2(.05,.05),Vector2(.95,.95))
	locked_desc = main.casting.descriptors(p.traits,"es")
	live = {}
	on_plane = false
	main.play_sfx("af_confirmado",-6.0)
	main.rumble(.15,0,.05)

func release() -> void:
	if locked == null: return
	locked = null
	live = {}
	on_plane = false
	pushes.clear()

# {pz_enganchar}, A, the trigger half pressed: whoever is nearest the middle; the same one again
# lets go (toggle).
func lock_middle(toggle: bool) -> void:
	if main.mode != "SEARCH": return
	var p = main.person_near(middle(),main.view_rect.size*.5)
	if p == null: return
	if p == locked:
		if toggle: release()
		return
	lock(p)

func flat_distance(p) -> float:
	var chest: Vector3 = p.control_points()[1]
	var to = chest-main.camera.global_position
	return maxf(.5,Vector2(to.x,to.z).length())

# Every frame with someone locked (§7.4): the player's push (to let go, or to move the framing by
# hand), the anchor where the shot wants it, and the size kept while the player leaves the zoom.
func follow(dt: float) -> void:
	if locked == null: return
	var p = locked
	if not is_instance_valid(p) or not p.visible or p.state == "RETIRADO":
		release()
		return
	if main.camera.is_position_behind(p.control_points()[1]): behind_time += dt
	else: behind_time = 0.0
	if behind_time > BEHIND_RELEASE or (zoom_touched and main.focal <= RELEASE_FOCAL):
		release()
		return
	var size = Vector2(main.viewport.size)
	var fov_h: float = main.camera.fov
	var fov_v = rad_to_deg(2.0*atan(tan(deg_to_rad(fov_h)*.5)*size.y/size.x))
	var delta = Vector2(rad_to_deg(angle_difference(deg_to_rad(last_set.x),deg_to_rad(main.angle))),main.pitch-last_set.y)
	var push = Vector2(delta.x/fov_h,delta.y/fov_v)
	pushes.append([now,push])
	while not pushes.is_empty() and now-pushes[0][0] > PUSH_WINDOW: pushes.pop_front()
	var total = Vector2.ZERO
	for item in pushes: total += item[1]
	if total.length() > (PUSH_RELEASE if spec.auto_frame else PUSH_RELEASE_MANUAL):
		release()
		return
	lock_time += dt
	var world = Framing.world_landmarks(p)
	var velocity: Vector3 = p.actual_velocity if frozen <= 0.0 else Vector3.ZERO
	var walking = velocity.length() > .2
	var side = signf(velocity.dot(main.camera.global_basis.x)) if walking else 0.0
	var anchor: Vector3
	var screen: Vector2
	if spec.auto_frame:
		if current_request().plane in ["entero","general"]:
			anchor = (world.crown+world.feet)*.5
			screen = Vector2(.5-.10*side,.5)
		else:
			anchor = world.crown
			screen = Vector2(.5-.08*side,Framing.AIR)
		# The size kept: the shot does not change as the person comes nearer or goes away.
		var d = flat_distance(p)
		if zoom_touched or f_ref <= 0.0:
			f_ref = main.focal
			d_ref = d
		else:
			main.focal = clampf(f_ref*d/d_ref,Ideal.IDEAL.min,Ideal.IDEAL.max)
			main.camera.fov = rad_to_deg(2.0*atan(36.0/(2.0*main.focal)))
	else:
		# Framing by hand: the look moves where the person goes in the frame.
		offset = (offset+Vector2(-push.x,push.y)).clamp(Vector2(.05,.05),Vector2(.95,.95))
		anchor = world.chest
		screen = offset
	main.aim_point(anchor+velocity/FOLLOW_GAIN,screen,1.0-exp(-FOLLOW_GAIN*dt))
	last_set = Vector2(main.angle,main.pitch)

# The traffic light and the live shot: the locked person's frame judged as a photo, but never on
# who it is (§3.4), or locking on to everybody until green would find the person.
func update_live() -> void:
	if locked == null:
		live = {}
		on_plane = false
		return
	live = Paparazzi.judge(capture(locked,true),current_request(),true)
	var now_on: bool = live.plane == current_request().plane
	if now_on and not on_plane and detent_left <= 0.0:
		main.play_sfx("dial_tope",-8.0)
		main.rumble(.1,0,.04)
		detent_left = DETENT_HOLD
	on_plane = now_on

# The traits check (§8): per trait shown, 1 if the locked person has it, −1 if not; empty while it
# waits (check_delay) or in the stretches without it.
func trait_marks() -> Array:
	if locked == null or not is_instance_valid(main.target) or spec.check_delay < 0.0 or lock_time < spec.check_delay: return []
	var wanted: PackedStringArray = main.casting.descriptors(main.target.traits,"es")
	var out = []
	for i in shown: out.append(1 if locked_desc[i] == wanted[i] else -1)
	return out

# Where someone is drawn on screen: the box of the body's points (main.ui's coordinates).
func body_box(p) -> Rect2:
	var world = Framing.world_landmarks(p)
	var top: Vector2 = main.finder_position(world.crown)
	var bottom: Vector2 = main.finder_position(world.feet)
	var chest: Vector2 = main.finder_position(world.chest)
	var tall = maxf(24.0,absf(bottom.y-top.y))
	var wide = maxf(24.0,tall*.36)
	return Rect2(chest.x-wide*.5,minf(top.y,bottom.y),wide,tall).grow(6)

func on_screen(p) -> bool:
	var chest: Vector3 = p.control_points()[1]
	return not main.camera.is_position_behind(chest) and inside(main.camera.unproject_position(chest)/Vector2(main.viewport.size))

# The arrow (towards the person off screen) and the ring (around her on screen), when the search
# takes long; never on the person locked on.
func arrow_on() -> bool:
	return is_instance_valid(main.target) and search_time >= spec.arrow_after and locked != main.target and not on_screen(main.target)

func ring_on() -> bool:
	return is_instance_valid(main.target) and search_time >= spec.ring_after and locked != main.target and on_screen(main.target)

# The direction of the person from the middle of the screen (y down); straight to a side if behind.
func arrow_direction() -> Vector2:
	var local: Vector3 = main.camera.global_transform.affine_inverse()*main.target.control_points()[1]
	if local.z > 0.0: return Vector2(1.0 if local.x >= 0.0 else -1.0,0.0)
	var d = Vector2(local.x,-local.y)
	return d.normalized() if d.length() > .001 else Vector2.RIGHT

# The first time the arrow shows, or the person asked for covers the face: their cards.
func events() -> void:
	if main.shooting or main.mode != "SEARCH": return
	if spec.arrow_after > 0.0 and not card_seen("flecha") and arrow_on():
		show_event("flecha")
	elif is_instance_valid(main.target) and str(main.target.activity) == "taparse" and on_screen(main.target) and not card_seen("taparse"):
		show_event("taparse")

# ---------------------------------------------------------------------------------------------
# Jokers (§3.5)

func use_freeze() -> void:
	var jokers: Dictionary = Paparazzi.run.jokers
	if int(jokers.congelar) <= 0 or frozen > 0.0: return
	jokers.congelar = int(jokers.congelar)-1
	frozen = FREEZE_TIME
	main.play_sfx("bloqueo",-4.0)

func use_skip() -> void:
	var jokers: Dictionary = Paparazzi.run.jokers
	if int(jokers.otro) <= 0 or main.shooting: return
	jokers.otro = int(jokers.otro)-1
	Paparazzi.run["skips"] = int(Paparazzi.run.get("skips",0))+1
	main.play_sfx("control_elegir",-4.0)
	if is_instance_valid(main.target): main.target.protected_target = false
	begin_level()

# PZ_RESCUE: the clock at zero with the rescue left.
func show_rescue() -> void:
	main.mode = "PZ_RESCUE"
	brief_open = false
	var root = main.create_modal()
	var box = Panel.new()
	box.position = Vector2(370,220)
	box.size = Vector2(540,260)
	box.add_theme_stylebox_override("panel",UiStyle.box(UiStyle.surf(.92),18,UiStyle.LINE,1,16))
	root.add_child(box)
	main.label(box,Texts.get_text("pz_rescate_titulo"),Rect2(32,26,476,44),30,UiStyle.BRAND)
	main.label(box,Texts.get_text("pz_rescate_texto") % int(Paparazzi.RESCUE_TIME),Rect2(32,86,476,90),19,UiStyle.INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.button(box,Texts.get_text("pz_rescate_no"),Rect2(32,176,200,56),end_run)
	main.button(box,Texts.get_text("pz_rescate_si"),Rect2(252,176,256,56),use_rescue,true)

func use_rescue() -> void:
	if main.mode != "PZ_RESCUE": return
	var jokers: Dictionary = Paparazzi.run.jokers
	jokers.rescate = int(jokers.rescate)-1
	bank = Paparazzi.RESCUE_TIME
	mark_seen("rescate")
	hud.show_flash(Texts.get_text("pz_bonus") % int(Paparazzi.RESCUE_TIME),true)
	main.play_sfx("ui_aceptar",-6.0)
	begin_search()

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
	if mode == "PZ_RESCUE":
		return event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	if mode == "PZ_END":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			main.intro()
			return true
		return false
	if mode != "SEARCH": return false
	if event is InputEventKey and event.pressed:
		if not event.echo:
			match event.physical_keycode:
				KEY_E:
					lock_middle(true)
					return true
				KEY_1:
					use_freeze()
					return true
				KEY_2:
					use_skip()
					return true
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

# A click (or a tap) without dragging: on the person locked on, the photo; on someone else, the lock.
# So the mode can be played with the mouse alone (§7.2).
func click(point: Vector2) -> void:
	if main.mode != "SEARCH": return
	if locked != null and body_box(locked).has_point(point):
		main.take_photo()
		return
	var p = main.person_near(point,LOCK_REACH)
	if p != null: lock(p)

# Gamepad buttons while searching (main.pad_button() asks first; true = taken).
func pad_button(event: InputEventJoypadButton) -> bool:
	if not active or not event.pressed or main.mode != "SEARCH": return false
	match event.button_index:
		JOY_BUTTON_START: return false             # (the pause, as always)
		JOY_BUTTON_DPAD_UP: zoom_step(1)
		JOY_BUTTON_DPAD_DOWN: zoom_step(-1)
		JOY_BUTTON_DPAD_LEFT: use_freeze()
		JOY_BUTTON_DPAD_RIGHT: use_skip()
		JOY_BUTTON_A: lock_middle(true)
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
	if locked != null and is_instance_valid(locked) and locked.visible:
		var eyes: Vector2 = main.body_landmarks(locked).eyes
		if not main.camera.is_position_behind(Framing.world_landmarks(locked).eyes) and inside(eyes): return locked
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

# live: the traffic light's, every frame (without the descriptions, which it does not judge).
func capture(p, live_check = false) -> Dictionary:
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
	if live_check:
		return {"has_subject":true, "is_target":p == target, "body":body,
			"visible":float(seen)/maxf(1,inside_count), "face_blocked":eyes_blocker != "", "blockers":([eyes_blocker] if eyes_blocker != "" else [])+blockers,
			"others":others, "facing":main.facing_of(p), "covering":str(p.activity) == "taparse",
			"activity":str(p.activity) if p.state in ["SENTADO","DETENIDO"] else "", "seated":p.state == "SENTADO",
			"dog_in_frame":dog_in, "places":places, "scenario":main.scenario}
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
	if spec.hito:
		lines.append(Texts.get_text("pz_hito_consolidado") % (spec.n+1))
		var kind = Paparazzi.milestone_joker(spec.n)
		var jokers: Dictionary = Paparazzi.run.jokers
		if int(jokers[kind]) < Paparazzi.JOKER_MAX:
			jokers[kind] = int(jokers[kind])+1
			lines.append(Texts.get_text("pz_comodin_ganado") % Texts.get_text("pz_comodin_"+kind+"_nombre"))
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
	release()
	frozen = 0.0
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
