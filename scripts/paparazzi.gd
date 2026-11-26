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
# Calibrated with tools/paparazzi_solver.gd (26-11-2026, §19.4): an average player reaches about
# level 70, a good one goes past 120.
const BONUS_FLOOR = 12.0
const BONUS_SPAN = 20.0
const BONUS_DECAY = 100.0         # levels
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

# Modifiers (§5), in the order the judge checks them. («actividad», someone seated doing something,
# only happens in the classic park: it is kept for when the classic park comes back to the mode.)
const MODS = ["sola","acompanada","frente","perfil","perro","lugar"]
const PLACES = ["quiosco","estanque"]
const FACE_PLANES = ["medio","primer_plano","cara"]   # where covering the face spoils the photo
const VISIBLE_MIN = .6
const FRONT_MAX = 45.0
const PROFILE_MIN = 60.0
const PROFILE_MAX = 120.0
# The first stretch asks for the person with any shot (user, 25-11-2026): from a full shot to the
# face, so long as she is not a speck in the landscape. The planes come with stretch 2.
const ANY = "cualquiera"

# What each stretch brings (§9.1). Planes and modifiers come from DEBUTS: a stretch can offer only
# what has already been introduced, so the curve never asks for something before its card.
# The whole mode is played in the big park, «the real hide and seek» (user, 25-11-2026); the classic
# park is still a scenario a stretch can name. The light changes within a stretch too, three
# times (levels 1–4, 5–7 and 8–10), for variety.
const TRAMOS = [
	{"scenario":"grande","times":["day","golden","day"],   "max_mods":0,"mod_chance":0.0,"pace":.80,"dobles":0,"rasgos":"todos",  "check_delay":0.0, "penalty":0.0,"arrow":4.0, "ring":12.0},
	{"scenario":"grande","times":["day","blue","golden"],  "max_mods":0,"mod_chance":0.0,"pace":.90,"dobles":0,"rasgos":"todos",  "check_delay":0.0, "penalty":3.0,"arrow":6.0, "ring":18.0},
	{"scenario":"grande","times":["golden","day","blue"],  "max_mods":1,"mod_chance":.5, "pace":1.0,"dobles":0,"rasgos":"todos",  "check_delay":0.0, "penalty":5.0,"arrow":8.0, "ring":22.0},
	{"scenario":"grande","times":["day","golden","blue"],  "max_mods":1,"mod_chance":.7, "pace":1.0,"dobles":1,"rasgos":"todos",  "check_delay":0.0, "penalty":5.0,"arrow":10.0,"ring":26.0},
	{"scenario":"grande","times":["blue","day","golden"],  "max_mods":1,"mod_chance":.7, "pace":1.0,"dobles":1,"rasgos":"minimos","check_delay":1.5, "penalty":5.0,"arrow":12.0,"ring":30.0},
	{"scenario":"grande","times":["golden","blue","day"],  "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":2,"rasgos":"minimos","check_delay":1.5, "penalty":5.0,"arrow":14.0,"ring":32.0},
	{"scenario":"grande","times":["day","golden","blue"],  "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":2,"rasgos":"minimos","check_delay":1.5, "penalty":5.0,"arrow":16.0,"ring":34.0},
	{"scenario":"grande","times":["night","night","blue"], "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":2,"rasgos":"minimos","check_delay":-1.0,"penalty":5.0,"arrow":18.0,"ring":36.0},
	{"scenario":"grande","times":["golden","night","day"], "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":3,"rasgos":"minimos","check_delay":-1.0,"penalty":5.0,"arrow":20.0,"ring":38.0},
	{"scenario":"grande","times":["day","blue","night"],   "max_mods":2,"mod_chance":.6, "pace":1.0,"dobles":3,"rasgos":"minimos","check_delay":-1.0,"penalty":5.0,"arrow":22.0,"ring":40.0},
]
const LIGHTS = ["day","golden","blue","night"]
# Stretch 10 is where the player frames by hand (§7.5).
const NO_AUTO_FROM = 91
# Search in the classic park: the least turn from where the player looks (§9.1).
const MIN_TURN = [60.0, 90.0, 120.0]          # stretch 1 (levels 4–10), stretch 2, from stretch 4
# Search in the big park: straight distance to the person, by stretch (levels 1–3, nearer).
# (Calibrated: walking is what the clock pays for, so nobody is further than REACH_MAX.)
const DIST_LEARNING = Vector2(6,14)
const DIST = {1:Vector2(6,15), 2:Vector2(7,21), 3:Vector2(10,28), 4:Vector2(10,28), 5:Vector2(14,30), 6:Vector2(14,30)}
const DIST_FAR = Vector2(17,30)                # from stretch 7
const REACH_MAX = 30.0                         # the search widened never goes further

# Level where each plane, modifier or the runner is first asked, forced (§9.3).
const DEBUTS = {1:"cualquiera", 11:"entero", 14:"medio", 17:"primer_plano", 21:"cara", 23:"sola",
	26:"frente", 27:"perfil", 31:"americano", 32:"general", 34:"acompanada", 36:"perro", 41:"lugar",
	44:"corredor"}
# Levels whose plane is fixed without being a debut.
const FORCED = {}
# The level whose card announces two demands asks for two.
const MIN_MODS = {52:2}
# Novelty cards by level (§11.2). Each is seen once per player.
const CARDS_AT = {1:["bienvenida","grande","semaforo"], 2:["enganche","comprobar"], 3:["zona"],
	4:["reloj"], 5:["congelar"], 8:["otro"], 10:["hito"], 11:["planos","entero","fallo"], 14:["medio"],
	17:["primer_plano"], 20:["reportaje"], 21:["cara"], 23:["sola"], 26:["frente"], 31:["americano"],
	32:["general"], 33:["corte_limpio"], 34:["acompanada"], 36:["perro"], 41:["lugar","comprobar_lenta"],
	44:["corredor"], 51:["dobles"], 52:["dos_mods"], 71:["noche","sin_comprobar"], 91:["encuadras_tu"],
	101:["infinito"]}
# Cards that come with an event, not with a level.
const EVENT_CARDS = ["flecha","taparse","rescate"]
# A debut without a card of its own shares one.
const DEBUT_CARD = {"perfil":"frente"}
# Learning steps (§11.1), completed by paparazzi_run.gd.
const COACH = {1:["andar","sacar","zoom","disparar"], 2:["enganchar","comprobar","disparar"]}
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
	var light = 0 if k <= 4 else (1 if k <= 7 else 2)
	if t <= TRAMOS.size():
		s = TRAMOS[t-1].duplicate()
		s.time = s.times[light]
	else:
		# Beyond level 100 (§9.2): everything mixed, the light turning round every few levels.
		s = TRAMOS[TRAMOS.size()-1].duplicate()
		s.time = LIGHTS[(t+light)%LIGHTS.size()]
		s.max_mods = 3 if t >= 15 else 2
		s.mod_chance = .7
		s.arrow = minf(30.0,22.0+(t-10))
		s.ring = s.arrow+18.0
	var spec = {
		"n":n, "tramo":t, "k":k, "hito":k == 10, "reportaje":k == 10 and t >= 2,
		"scenario":s.scenario, "time":s.time,
		"planes":[ANY] if n < DEBUTS.find_key("entero") else available(n,Framing.ORDER), "new_planes":[], "mods":available(n,MODS),
		"max_mods":s.max_mods, "mod_chance":s.mod_chance, "third_chance":.25 if t >= 15 else 0.0,
		"min_mods":MIN_MODS.get(n,0),
		"pace":s.pace, "runners":n >= DEBUTS.find_key("corredor"), "dobles":s.dobles, "rasgos":s.rasgos,
		"check_delay":s.check_delay, "auto_frame":n < NO_AUTO_FROM,
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
		spec.dist = DIST_LEARNING if n <= LEARNING else DIST.get(t,DIST_FAR)
	return spec

# The planes or modifiers already introduced by level n, in their own order.
static func available(n: int, names: Array) -> Array:
	var out = []
	for name in names:
		var debut = DEBUTS.find_key(name)
		if debut != null and debut <= n: out.append(name)
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
			if mods.has("acompanada") or mods.has("lugar"): return false
			# A full shot with nobody else in the crowded square is all but impossible.
			if classic and not plane in ["medio","primer_plano","cara"]: return false
		"acompanada":
			if mods.has("sola") or mods.has("lugar") or not plane in ["general","entero","americano"]: return false
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
			# (The dog is knee-high: a cowboy shot cuts it off.)
			if not plane in ["general","entero"]: return false
			if mods.has("actividad"): return false          # the walker walks
			if classic and mods.has("frente"): return false
		"actividad":
			# Seated people only sit in the classic park (§10.2), on the inner lane.
			if not classic or not plane in ["entero","americano","medio"]: return false
			if mods.has("perro") or mods.has("lugar") or mods.has("perfil"): return false
		"lugar":
			if not plane in ["general","entero","americano"]: return false
			# (People gather by the bandstand and the fountain: alone, or with exactly so many, there
			# is all but impossible; seen with the solver, 26-11-2026.)
			if mods.has("sola") or mods.has("acompanada"): return false
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
	elif wanted == ANY:
		# Any shot will do, but not a speck in the landscape (a wide shot).
		if shape.plane == "general": reasons.append(reason("pequena",[],"mas_zoom"))
	elif shape.plane != wanted:
		var advice = "mas_zoom" if Framing.wider(shape.plane,wanted) else "menos_zoom"
		reasons.append(reason("plano",[shape.plane,wanted,advice],advice))
	# 7. Defects of the framing (a cut foot only matters in a full shot).
	for defect in ["cabeza","pies","aire"]:
		if not defect in shape.defects: continue
		if defect == "pies" and wanted != "entero": continue
		if defect == "aire" and wanted == ANY: continue      # (composition comes with the planes)
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
# Look-alikes (§10.3): made on purpose when the park is cast for a run, since the casting hardly
# ever makes them. Only colours change, which never breaks the casting's rules.

const COLOUR_SLOTS = ["upper_color","lower_color","hair_color","accessory_color","glasses"]

# How many of the four descriptions (in Spanish) two people share.
static func shared(c, a: Dictionary, b: Dictionary) -> int:
	var da = c.descriptors(a,"es")
	var db = c.descriptors(b,"es")
	var n = 0
	for k in 4:
		if da[k] == db[k]: n += 1
	return n

# A variant of t sharing exactly `keep` descriptions, whose four are nobody else's.
static func double_of(c, t: Dictionary, keep: int, crowd: Array, rng: RandomNumberGenerator):
	var signatures = crowd.map(func(x): return "|".join(c.descriptors(x,"es")))
	for attempt in 200:
		var d = t.duplicate(true)
		for change in 4-keep+rng.randi()%2:
			var slot: String = COLOUR_SLOTS[rng.randi()%COLOUR_SLOTS.size()]
			match slot:
				"hair_color": d.hair_color = c.catalog.tonos_pelo.keys()[rng.randi()%c.catalog.tonos_pelo.size()]
				"glasses": d.glasses = rng.randi()%c.catalog.piezas.gafas.size()
				_: d[slot] = c.catalog.tonos_ropa.keys()[rng.randi()%c.catalog.tonos_ropa.size()]
		if shared(c,d,t) == keep and not "|".join(c.descriptors(d,"es")) in signatures: return d
	return null

# Groups of look-alikes in a cast (an Array of traits, changed in place): a model and `per` others
# turned into its variants, the first sharing three descriptions and the rest two. Runners
# (`skip`, indices) are left alone. Returns how many look-alikes were made.
static func make_doubles(c, crowd: Array, rng: RandomNumberGenerator, groups: int, per: int, skip: Array) -> int:
	var free = []
	for i in crowd.size():
		if not i in skip: free.append(i)
	var made = 0
	for g in groups:
		if free.size() < per+1: break
		var model: int = free.pop_at(rng.randi()%free.size())
		for k in per:
			var d = double_of(c,crowd[model],3 if k == 0 else 2,crowd,rng)
			if d == null: continue
			crowd[free.pop_at(rng.randi()%free.size())] = d
			made += 1
	return made

# How many people of a cast look like t (two or more descriptions in common).
static func doubles_count(c, t: Dictionary, crowd: Array) -> int:
	var n = 0
	for other in crowd:
		if other != t and shared(c,other,t) >= 2: n += 1
	return n

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
