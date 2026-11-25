extends RefCounted
# Paparazzi (docs/futuro/29): survival of framings with an ideal camera. This file is the pure part,
# testable without a screen (tests/test_paparazzi.gd): the difficulty curve (level_spec), the clock's
# sums, the requests, the judge of a photo and the saved progress. The run itself (the park, the
# lock-on, the photo) lives in scripts/paparazzi_run.gd.
const Framing = preload("res://scripts/framing.gd")
const Texts = preload("res://scripts/texts.gd")

# Tests and tools point it elsewhere, so the player's progress is never touched.
static var SAVE = OS.get_environment("PAPARAZZI_PZ_CFG") if OS.has_environment("PAPARAZZI_PZ_CFG") else "user://paparazzi.cfg"
const FORMAT = 1
# The run in progress: a static survives get_tree().reload_current_scene() (§14, probe «recarga»).
static var run = {}

const LENS_MIN = 24.0
const LENS_MAX = 600.0

# The clock (§3.1). Seconds.
const START_BANK = 60.0
const MAX_BANK = 120.0
const BONUS_FLOOR = 12.0
const BONUS_SPAN = 18.0
const BONUS_DECAY = 60.0          # levels (A calibrar, §19.4)
const HITO_BONUS = 15.0
const FIRST_TRY_BONUS = 2.0       # from stretch 2
const CLEAN_CUT_BONUS = 3.0       # from stretch 4, when it is taught
const RESCUE_TIME = 30.0
const POLAROID_TIME = 1.5         # the clock waits while the polaroid flies

# Jokers (§3.5).
const FREEZE_TIME = 5.0
const JOKER_MAX = 3
const FREEZE_FROM = 5
const SKIP_FROM = 8
const RESCUE_FROM = 4

# Modifiers (§5), in the order the judge checks them.
const MODS = ["sola","acompanada","frente","perfil","perro","actividad","lugar"]
const PLACES = ["quiosco","estanque"]
const FACE_PLANES = ["medio","primer_plano","cara"]   # where covering the face spoils the photo
const VISIBLE_MIN = .6
const FRONT_MAX = 45.0
const PROFILE_MIN = 60.0
const PROFILE_MAX = 120.0

# What each stretch brings (§9.1). Planes and modifiers come from DEBUTS: a stretch can offer only
# what has already been introduced, so the curve never asks for something before its card.
const TRAMOS = [
	{"scenario":"clasico","time":"day",   "max_mods":0,"mod_chance":0.0,"pace":.70,"dobles":0,"rasgos":"todos",  "check_delay":0.0, "lock_delay":0.0,"auto_frame":true, "penalty":0.0,"arrow":4.0, "ring":12.0},
	{"scenario":"clasico","time":"day",   "max_mods":1,"mod_chance":.5, "pace":.85,"dobles":0,"rasgos":"todos",  "check_delay":0.0, "lock_delay":0.0,"auto_frame":true, "penalty":3.0,"arrow":6.0, "ring":18.0},
	{"scenario":"grande", "time":"day",   "max_mods":1,"mod_chance":.4, "pace":1.0,"dobles":0,"rasgos":"todos",  "check_delay":0.0, "lock_delay":0.0,"auto_frame":true, "penalty":5.0,"arrow":8.0, "ring":22.0},
	{"scenario":"clasico","time":"golden","max_mods":1,"mod_chance":.7, "pace":1.0,"dobles":1,"rasgos":"todos",  "check_delay":0.0, "lock_delay":0.0,"auto_frame":true, "penalty":5.0,"arrow":10.0,"ring":26.0},
	{"scenario":"grande", "time":"day",   "max_mods":1,"mod_chance":.7, "pace":1.0,"dobles":1,"rasgos":"todos",  "check_delay":0.0, "lock_delay":0.0,"auto_frame":true, "penalty":5.0,"arrow":12.0,"ring":30.0},
	{"scenario":"clasico","time":"blue",  "max_mods":1,"mod_chance":.7, "pace":1.0,"dobles":1,"rasgos":"minimos","check_delay":1.5, "lock_delay":0.0,"auto_frame":true, "penalty":5.0,"arrow":14.0,"ring":32.0},
	{"scenario":"grande", "time":"golden","max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":2,"rasgos":"minimos","check_delay":1.5, "lock_delay":0.3,"auto_frame":true, "penalty":5.0,"arrow":16.0,"ring":34.0},
	{"scenario":"clasico","time":"night", "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":2,"rasgos":"minimos","check_delay":1.5, "lock_delay":0.3,"auto_frame":true, "penalty":5.0,"arrow":18.0,"ring":36.0},
	{"scenario":"grande", "time":"blue",  "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":2,"rasgos":"minimos","check_delay":-1.0,"lock_delay":0.3,"auto_frame":true, "penalty":5.0,"arrow":20.0,"ring":38.0},
	{"scenario":"clasico","time":"day",   "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":3,"rasgos":"minimos","check_delay":-1.0,"lock_delay":0.3,"auto_frame":true, "penalty":5.0,"arrow":22.0,"ring":40.0},
]
# Stretch 10 is where the player frames by hand (§7.5).
const NO_AUTO_FROM = 91
# Search in the classic park: the least turn from where the player looks (§9.1).
const MIN_TURN = [60.0, 90.0, 120.0]          # stretch 1 (levels 4–10), stretch 2, from stretch 4
# Search in the big park: straight distance to the person, by stretch.
const DIST = {3:Vector2(8,25), 5:Vector2(15,40), 7:Vector2(20,55)}
const DIST_FAR = Vector2(25,70)                # from stretch 9

# Level where each plane, modifier or the runner is first asked, forced (§9.3).
const DEBUTS = {1:"entero", 3:"medio", 6:"primer_plano", 11:"cara", 13:"sola", 31:"americano",
	32:"general", 34:"acompanada", 41:"frente", 42:"perfil", 43:"perro", 52:"lugar", 53:"actividad",
	54:"corredor"}
# The milestone of stretch 1 is a plain request, a close-up.
const FORCED = {10:"primer_plano"}
# The level whose card announces two demands asks for two.
const MIN_MODS = {62:2}
# Novelty cards by level (§11.2). Each is seen once per player.
const CARDS_AT = {1:["bienvenida","entero","semaforo"], 2:["enganche","comprobar"], 3:["medio"],
	4:["reloj"], 5:["congelar"], 6:["primer_plano"], 8:["otro"], 10:["hito"], 11:["cara","fallo"],
	13:["sola"], 20:["reportaje"], 21:["grande","zona"], 31:["americano"], 32:["general"],
	33:["corte_limpio"], 34:["acompanada"], 41:["frente"], 43:["perro"], 51:["comprobar_lenta"],
	52:["lugar"], 53:["actividad"], 54:["corredor"], 61:["dobles","enganche_lento"], 62:["dos_mods"],
	71:["noche"], 81:["sin_comprobar"], 91:["encuadras_tu"], 101:["infinito"]}
# Cards that come with an event, not with a level.
const EVENT_CARDS = ["flecha","taparse","rescate"]
# A debut without a card of its own shares one.
const DEBUT_CARD = {"perfil":"frente"}
# Learning steps of levels 1–3 (§11.1), completed by paparazzi_run.gd.
const COACH = {1:["mirar","centro","zoom","disparar"], 2:["enganchar","comprobar","disparar"],
	3:["plano","disparar"]}
const LEARNING = 3                 # levels without clock nor penalty

# ---------------------------------------------------------------------------------------------
# The curve

static func tramo_of(n: int) -> int:
	return (n-1)/10+1

static func bonus(n: int) -> float:
	return snappedf(BONUS_FLOOR+BONUS_SPAN*exp(-float(n-1)/BONUS_DECAY),.5)

# Everything a level asks and helps with (§9.3). Pure: the same n gives the same spec.
static func level_spec(n: int) -> Dictionary:
	n = maxi(n,1)
	var t = tramo_of(n)
	var k = (n-1)%10+1
	var s = {}
	if t <= TRAMOS.size():
		s = TRAMOS[t-1].duplicate()
	else:
		# Beyond level 100 (§9.2): odd stretches in the big park, even ones in the classic.
		var big = t%2 == 1
		s = TRAMOS[TRAMOS.size()-1].duplicate()
		s.scenario = "grande" if big else "clasico"
		s.time = ["day","golden","blue"][((t-11)/2)%3] if big else ["day","golden","blue","night"][((t-12)/2)%4]
		s.max_mods = 3 if t >= 15 else 2
		s.mod_chance = .7
		s.arrow = minf(30.0,22.0+(t-10))
		s.ring = s.arrow+18.0
	var spec = {
		"n":n, "tramo":t, "k":k, "hito":k == 10, "reportaje":k == 10 and t >= 2,
		"scenario":s.scenario, "time":s.time,
		"planes":available(n,Framing.ORDER), "new_planes":[], "mods":available(n,MODS),
		"max_mods":s.max_mods, "mod_chance":s.mod_chance, "third_chance":.25 if t >= 15 else 0.0,
		"min_mods":MIN_MODS.get(n,0),
		"pace":s.pace, "runners":n >= DEBUTS.find_key("corredor"), "dobles":s.dobles, "rasgos":s.rasgos,
		"check_delay":s.check_delay, "lock_delay":s.lock_delay, "auto_frame":n < NO_AUTO_FROM,
		"penalty":0.0 if n <= LEARNING else s.penalty,
		"arrow_after":0.0 if n <= LEARNING else s.arrow, "ring_after":0.0 if n <= LEARNING else s.ring,
		"in_view":n <= LEARNING, "min_turn":0.0, "dist":Vector2.ZERO,
		"bonus":bonus(n), "clock":n > LEARNING,
		"debut":DEBUTS.get(n,""), "forced":FORCED.get(n,""), "coach":COACH.get(n,[]),
		"cards":CARDS_AT.get(n,[]),
	}
	for plane in spec.planes:
		if tramo_of(DEBUTS.find_key(plane)) == t: spec.new_planes.append(plane)
	if spec.scenario == "clasico" and n > LEARNING:
		spec.min_turn = MIN_TURN[0] if t == 1 else (MIN_TURN[1] if t <= 3 else MIN_TURN[2])
	elif spec.scenario == "grande":
		spec.dist = DIST.get(t,DIST_FAR)
	return spec

# The planes or modifiers already introduced by level n, in their own order.
static func available(n: int, names: Array) -> Array:
	var out = []
	for name in names:
		if DEBUTS.find_key(name) <= n: out.append(name)
	return out

# The card a debut shows (the debut itself, or the card it shares).
static func debut_card(debut: String) -> String:
	return DEBUT_CARD.get(debut,debut)

# Every card id the game can show.
static func all_cards() -> Array:
	var out = []
	for n in CARDS_AT:
		for card in CARDS_AT[n]:
			if not card in out: out.append(card)
	for card in EVENT_CARDS:
		if not card in out: out.append(card)
	return out

# The numbers some cards carry (seconds).
static func card_args(card: String, spec: Dictionary) -> Array:
	match card:
		"fallo": return [int(spec.penalty)]
		"corte_limpio": return [int(CLEAN_CUT_BONUS)]
		"rescate": return [int(RESCUE_TIME)]
	return []

# ---------------------------------------------------------------------------------------------
# Requests (§10.1)

# Whether a modifier can go with a plane, in a park, beside the ones already chosen (§5).
static func compatible(mod: String, plane: String, scenario: String, mods: Dictionary) -> bool:
	if mods.has(mod): return false
	var classic = scenario == "clasico"
	match mod:
		"sola":
			if mods.has("acompanada"): return false
			# A full shot with nobody else in the crowded square is all but impossible.
			if classic and not plane in ["medio","primer_plano","cara"]: return false
		"acompanada":
			if mods.has("sola") or not plane in ["general","entero","americano"]: return false
		"frente":
			if mods.has("perfil") or plane == "general": return false
			# In the classic park only someone still or seated faces the camera (§5.1): not the
			# dog's walker, nor someone who must pass by a landmark.
			if classic and (mods.has("perro") or mods.has("lugar")): return false
		"perfil":
			if mods.has("frente") or plane == "general": return false
			# In the classic park only walkers are seen side on: not someone seated.
			if classic and mods.has("actividad"): return false
		"perro":
			if not plane in ["general","entero","americano"]: return false
			if mods.has("actividad"): return false          # the walker walks
			if classic and mods.has("frente"): return false
		"actividad":
			# Seated people only sit in the classic park (§10.2), on the inner lane.
			if not classic or not plane in ["entero","americano","medio"]: return false
			if mods.has("perro") or mods.has("lugar") or mods.has("perfil"): return false
		"lugar":
			if not plane in ["general","entero","americano"]: return false
			if mods.has("actividad"): return false          # the seats are not by the landmarks
			if classic and mods.has("frente"): return false
		_:
			return false
	return true

static func make_request(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var debut: String = spec.debut
	var plane = ""
	if debut in Framing.ORDER: plane = debut
	elif spec.forced != "": plane = spec.forced
	elif debut == "corredor": plane = "entero"        # a runner, always full length (§9.1)
	else: plane = weighted_plane(spec,rng)
	var mods = {}
	if debut in MODS:
		if not compatible(debut,plane,spec.scenario,mods):
			var fits = []
			for p in spec.planes:
				if compatible(debut,p,spec.scenario,mods): fits.append(p)
			plane = fits[rng.randi()%fits.size()]
		add_mod(mods,debut,rng)
	elif debut == "" and spec.forced == "":
		var wanted = spec.min_mods
		for slot in spec.max_mods:
			if mods.size() > slot: continue
			var chance = spec.third_chance if slot >= 2 else spec.mod_chance
			if slot >= wanted and rng.randf() >= chance: break
			var options = []
			for mod in spec.mods:
				if compatible(mod,plane,spec.scenario,mods): options.append(mod)
			if options.is_empty(): break
			add_mod(mods,options[rng.randi()%options.size()],rng)
	return {"plane":plane, "mods":mods}

# A plane of the level's; the ones new in this stretch weigh ×3.
static func weighted_plane(spec: Dictionary, rng: RandomNumberGenerator) -> String:
	var bag = []
	for plane in spec.planes:
		for i in (3 if plane in spec.new_planes else 1): bag.append(plane)
	return bag[rng.randi()%bag.size()]

static func add_mod(mods: Dictionary, mod: String, rng: RandomNumberGenerator) -> void:
	match mod:
		"acompanada": mods[mod] = 1 if rng.randf() < .7 else 2
		"lugar": mods[mod] = PLACES[rng.randi()%PLACES.size()]
		_: mods[mod] = true

# The milestone's reportage (§9.4): three different planes of the level's, wide to tight.
static func reportage_planes(spec: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pool: Array = spec.planes.duplicate()
	var out = []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi()%pool.size()))
	out.sort_custom(func(a,b): return Framing.wider(a,b))
	return out

# The whole request of a level: one photo, or the reportage of a milestone (its first photo first).
static func level_request(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if spec.reportaje:
		var sequence = reportage_planes(spec,rng)
		return {"plane":sequence[0], "mods":{}, "sequence":sequence}
	return make_request(spec,rng)

# ---------------------------------------------------------------------------------------------
# The judge (§3.4)

# → {"ok", "plane", "reasons": [{"key","args"}], "tip", "clean_cut", "subject_is_target"}.
# Deterministic: the same evidence always gives the same verdict. The first reason is the one shown.
# The live traffic light passes ignore_identity: it judges the framing of whoever is locked on.
static func judge(e: Dictionary, request: Dictionary, ignore_identity = false) -> Dictionary:
	var out = {"ok":false, "plane":"", "reasons":[], "tip":"", "clean_cut":false,
		"subject_is_target":bool(e.get("is_target",false))}
	var wanted: String = request.plane
	var reasons: Array = out.reasons
	var body: Dictionary = e.get("body",{})
	var shape = Framing.classify(body) if e.get("has_subject",false) and not body.is_empty() else {"plane":"","defects":["cara_fuera"]}
	# 1. Somebody, with the eyes in the frame.
	if "cara_fuera" in shape.defects:
		reasons.append(reason("nadie",[],"apunta"))
		return finish(out)
	out.plane = shape.plane
	# 2. The person asked for.
	if not ignore_identity and not out.subject_is_target:
		reasons.append(reason("no_es",differing_trait(e),""))
	# 3. Covering the face, where the face matters.
	if e.get("covering",false) and wanted in FACE_PLANES:
		reasons.append(reason("se_tapa",[],"se_tapa"))
	# 4–5. Something in front.
	var blockers: Array = e.get("blockers",[])
	var blocker = str(blockers[0]) if not blockers.is_empty() else ""
	if e.get("face_blocked",false):
		reasons.append(reason("cara_tapada",[blocker],"tapada"))
	if float(e.get("visible",1.0)) < VISIBLE_MIN:
		reasons.append(reason("tapada",[blocker],"tapada"))
	# 6. The plane.
	if "corte_cara" in shape.defects:
		reasons.append(reason("corte_cara",[],"menos_zoom"))
	elif shape.plane != wanted:
		var advice = "mas_zoom" if Framing.wider(shape.plane,wanted) else "menos_zoom"
		reasons.append(reason("plano",[shape.plane,wanted,advice],advice))
	# 7. Defects of the framing (a cut foot only matters in a full shot).
	for defect in ["cabeza","pies","aire"]:
		if not defect in shape.defects: continue
		if defect == "pies" and wanted != "entero": continue
		reasons.append(reason(defect,[],defect))
	# 8. The modifiers, in the request's order.
	var others = int(e.get("others",0))
	for mod in request.get("mods",{}):
		var value = request.mods[mod]
		match mod:
			"sola":
				if others > 0: reasons.append(reason("no_sola",[others],"sobra_gente"))
			"acompanada":
				if others != int(value): reasons.append(reason("acompanada",[int(value),others],"sobra_gente" if others > int(value) else "falta_gente"))
			"frente":
				if float(e.get("facing",180.0)) > FRONT_MAX: reasons.append(reason("frente",[],"frente"))
			"perfil":
				var facing = float(e.get("facing",0.0))
				if facing < PROFILE_MIN or facing > PROFILE_MAX: reasons.append(reason("perfil",[],"perfil"))
			"perro":
				if not e.get("dog_in_frame",false): reasons.append(reason("perro",[],"perro"))
			"actividad":
				if str(e.get("activity","")) == "" or not e.get("seated",false): reasons.append(reason("actividad",[],"actividad"))
			"lugar":
				if not e.get("places",{}).get(value,false): reasons.append(reason("lugar",[value,str(e.get("scenario","clasico"))],"lugar"))
	out.clean_cut = shape.plane != "" and Framing.clean_cut(body,shape.plane)
	return finish(out)

static func reason(key: String, args: Array, tip: String) -> Dictionary:
	return {"key":key, "args":args, "tip":tip}

static func finish(out: Dictionary) -> Dictionary:
	out.ok = out.reasons.is_empty()
	out.tip = "listo" if out.ok else ""
	for r in out.reasons:
		if r.tip != "":
			out.tip = r.tip
			break
	return out

# «Wears X and you were after Y» (§6.5): the first trait shown on the card where the two differ, in
# the language in use. Compared in Spanish, as the casting decides who is who.
static func differing_trait(e: Dictionary) -> Array:
	var subject_es: PackedStringArray = e.get("subject_desc_es",PackedStringArray())
	var target_es: PackedStringArray = e.get("target_desc_es",PackedStringArray())
	var subject: PackedStringArray = e.get("subject_desc",subject_es)
	var target: PackedStringArray = e.get("target_desc",target_es)
	var shown: Array = Array(e.get("shown",PackedInt32Array([0,1,2,3])))
	for i in shown:
		if i < subject_es.size() and i < target_es.size() and subject_es[i] != target_es[i]:
			return [subject[i], target[i]]
	return []

# ---------------------------------------------------------------------------------------------
# Texts of the verdict

static func plane_name(plane: String) -> String:
	return Texts.get_text("pz_plano_"+plane)

static func place_name(place: String, scenario: String) -> String:
	# The big park's water is a fountain.
	return Texts.get_text("pz_lugar_fuente" if place == "estanque" and scenario == "grande" else "pz_lugar_"+place)

# The one-line message of a reason, in the language in use.
static func reason_text(r: Dictionary) -> String:
	var text = Texts.get_text("pz_motivo_"+r.key)
	var a: Array = r.args
	match r.key:
		"no_es":
			if a.size() < 2: return Texts.get_text("pz_motivo_no_es_corto")
			return text % [a[0],a[1]]
		"cara_tapada", "tapada":
			if str(a[0]) == "": return Texts.get_text("pz_motivo_"+r.key+"_algo")
			return text % [a[0]]
		"plano":
			return text % [Texts.get_text("pz_plano_un_"+a[0]),Texts.get_text("pz_plano_un_"+a[1]),Texts.get_text("pz_consejo_"+a[2])]
		"no_sola":
			return text % [a[0]]
		"acompanada":
			return text % [a[0],a[1]]
		"lugar":
			return text % [place_name(a[0],a[1])]
	return text

# The short label of a request's modifier, for the card.
static func mod_text(mod: String, value, scenario: String) -> String:
	match mod:
		"acompanada": return Texts.get_text("pz_mod_acompanada_%d" % int(value))
		"lugar": return Texts.get_text("pz_mod_lugar") % [place_name(value,scenario)]
	return Texts.get_text("pz_mod_"+mod)

# ---------------------------------------------------------------------------------------------
# The clock (§3.1)

# flags: first_try, clean_cut, hito.
static func after_success(bank: float, spec: Dictionary, flags: Dictionary) -> float:
	var gain: float = spec.bonus
	if flags.get("first_try",false) and spec.tramo >= 2: gain += FIRST_TRY_BONUS
	if flags.get("clean_cut",false) and spec.tramo >= 4: gain += CLEAN_CUT_BONUS
	if flags.get("hito",false): gain += HITO_BONUS
	return minf(MAX_BANK,bank+gain)

static func after_fail(bank: float, spec: Dictionary) -> float:
	return maxf(0.0,bank-spec.penalty)

# Jokers a run starts with (§3.2): from level 1 they are given at their debut levels.
static func start_jokers(n: int) -> Dictionary:
	return {"congelar":1 if n >= FREEZE_FROM else 0, "otro":1 if n >= SKIP_FROM else 0, "rescate":1}

# The joker a milestone gives (§3.5): odd milestones freeze, even ones skip. Kept under JOKER_MAX.
static func milestone_joker(n: int) -> String:
	return "congelar" if (n/10)%2 == 1 else "otro"

# ---------------------------------------------------------------------------------------------
# Progress (§15)

static func start_points(hito: int) -> Array:
	var out = []
	for i in hito+1: out.append(10*i+1)
	return out

static func load_progress() -> Dictionary:
	var out = {"hito":0, "record":0, "carreras":0, "fotos":0, "visto":{}}
	var config = ConfigFile.new()
	if config.load(SAVE) != OK: return out
	for key in ["hito","record","carreras","fotos"]:
		out[key] = int(config.get_value("progreso",key,0))
	if config.has_section("visto"):
		for card in config.get_section_keys("visto"):
			if config.get_value("visto",card,false): out.visto[card] = true
	return out

static func save_progress(progress: Dictionary) -> void:
	var config = ConfigFile.new()
	config.set_value("formato","version",FORMAT)
	for key in ["hito","record","carreras","fotos"]:
		config.set_value("progreso",key,int(progress.get(key,0)))
	for card in progress.get("visto",{}):
		config.set_value("visto",card,true)
	config.save(SAVE)

# A level passed: the record and, on a milestone, the consolidated starting point. Saved at once.
static func level_passed(n: int) -> Dictionary:
	var progress = load_progress()
	progress.record = maxi(progress.record,n)
	progress.fotos += 1
	if n%10 == 0: progress.hito = maxi(progress.hito,n/10)
	save_progress(progress)
	return progress

static func run_ended() -> void:
	var progress = load_progress()
	progress.carreras += 1
	save_progress(progress)

static func mark_seen(card: String) -> void:
	var progress = load_progress()
	progress.visto[card] = true
	save_progress(progress)

static func seen(card: String) -> bool:
	return load_progress().visto.has(card)
