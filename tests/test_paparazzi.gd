extends SceneTree
# The pure part of Paparazzi (scripts/paparazzi.gd, docs/futuro/29 §19.2): the difficulty curve,
# the requests, the judge, the clock's sums, the texts and the saved progress. Headless,
# deterministic, and it never writes the player's own files.
#   ~/bin/godot-4-fp --path . --headless --script tests/test_paparazzi.gd
const Paparazzi = preload("res://scripts/paparazzi.gd")
const Framing = preload("res://scripts/framing.gd")
const Texts = preload("res://scripts/texts.gd")
const PLAYER_SAVE = "user://paparazzi.cfg"
const TEST_SAVE = "user://paparazzi_pruebas.cfg"
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var player_before = save_stamp()
	Paparazzi.SAVE = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	curve()
	far_levels()
	texts()
	requests()
	judge()
	clock()
	progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	check(save_stamp() == player_before,"7. the player's progress file was touched")
	print("PAPARAZZI TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func save_stamp() -> String:
	if not FileAccess.file_exists(PLAYER_SAVE): return "absent"
	return str(FileAccess.get_modified_time(PLAYER_SAVE))+":"+FileAccess.get_md5(PLAYER_SAVE)

# 1. The curve, level by level.
func curve() -> void:
	var before = {}
	for n in range(1,301):
		var s = Paparazzi.level_spec(n)
		var where = "level %d: " % n
		check(s == Paparazzi.level_spec(n),where+"level_spec is not pure")
		check(s.pace <= 1.0,where+"pace above 1.0")
		var check_delay = 0.0 if n <= 40 else (1.5 if n <= 70 else -1.0)
		check(is_equal_approx(s.check_delay,check_delay),where+"check_delay %.1f" % s.check_delay)
		check(s.auto_frame == (n < 91),where+"auto_frame")
		check(s.scenario == "grande",where+"scenario "+s.scenario)
		check(s.time in ["day","golden","blue","night"],where+"light "+s.time)
		check(n > 3 or s.time == "day",where+"the first levels by day")
		check(s.hito == (n%10 == 0),where+"hito")
		check(s.reportaje == (n%10 == 0 and n >= 20),where+"reportaje")
		check(s.clock == (n > 3),where+"clock")
		check(s.coach.is_empty() == (n > 2),where+"coach")
		check(s.dobles >= 0 and s.dobles <= 3,where+"dobles")
		check(s.rasgos == ("todos" if n <= 40 else "minimos"),where+"rasgos")
		check((s.planes == [Paparazzi.ANY]) == (n <= 10),where+"any shot only in stretch 1: %s" % str(s.planes))
		check(s.max_mods >= s.min_mods,where+"min_mods above max_mods")
		check(not s.planes.is_empty(),where+"no planes")
		check(s.dist.x > 0 and s.dist.y > s.dist.x,where+"dist")
		check(s.in_view == (n <= 3),where+"in_view")
		if n > 1:
			check(s.bonus <= before.bonus,where+"the bonus went up")
			check(s.arrow_after >= before.arrow_after,where+"the arrow came sooner")
			check(s.ring_after >= before.ring_after,where+"the ring came sooner")
			check(s.ring_after >= s.arrow_after,where+"ring before the arrow")
			for p in before.planes: check(p == Paparazzi.ANY or p in s.planes,where+"plane %s went away" % p)
			for m in before.mods: check(m in s.mods,where+"modifier %s went away" % m)
			check(s.penalty >= before.penalty,where+"the penalty went down")
		before = s
	# Some numbers of the plan, exactly.
	check(Paparazzi.bonus(1) == 32.0,"bonus(1) %.1f" % Paparazzi.bonus(1))
	check(Paparazzi.bonus(100) == 19.5,"bonus(100) %.1f" % Paparazzi.bonus(100))
	check(Paparazzi.bonus(200) == 14.5,"bonus(200) %.1f" % Paparazzi.bonus(200))
	check(Paparazzi.level_spec(11).penalty == 3.0 and Paparazzi.level_spec(21).penalty == 5.0 and Paparazzi.level_spec(5).penalty == 0.0,"penalty by stretch")
	check(Paparazzi.level_spec(1).planes == [Paparazzi.ANY],"level 1 asks for any shot")
	check(Paparazzi.level_spec(11).planes == ["entero"],"level 11 brings the full shot")
	check(not "primer_plano" in Paparazzi.level_spec(16).planes and "primer_plano" in Paparazzi.level_spec(17).planes,"close-up before its card")
	check(Paparazzi.level_spec(30).planes.size() == 4 and Paparazzi.level_spec(32).planes.size() == 6,"planes of stretches 3 and 4")
	check(not "sola" in Paparazzi.level_spec(22).mods and "sola" in Paparazzi.level_spec(23).mods,"alone before its card")
	check(Paparazzi.level_spec(2).dist == Vector2(6,14) and Paparazzi.level_spec(25).dist == Vector2(10,28) and Paparazzi.level_spec(85).dist == Vector2(17,30),"dist by stretch")
	check(not Paparazzi.level_spec(43).runners and Paparazzi.level_spec(44).runners,"runners from their debut")
	# The light changes within a stretch, and night comes in stretch 8.
	for t in range(1,11):
		var lights = {}
		for k in range(1,11): lights[Paparazzi.level_spec((t-1)*10+k).time] = true
		check(lights.size() >= 2,"stretch %d: one light only" % t)
	check(Paparazzi.level_spec(71).time == "night" and Paparazzi.level_spec(70).time != "night","night from level 71")
	check(Paparazzi.start_points(3) == [1,11,21,31],"start_points(3)")
	check(Paparazzi.start_points(0) == [1],"start_points(0)")

# 2. Far beyond the designed stretches.
func far_levels() -> void:
	for n in [101,150,999,10000]:
		var s = Paparazzi.level_spec(n)
		check(s.bonus >= Paparazzi.BONUS_FLOOR,"level %d: bonus under the floor" % n)
		check(s.planes.size() == 6 and s.mods.size() == Paparazzi.MODS.size(),"level %d: not everything is mixed" % n)
		check(s.pace == 1.0 and s.dobles == 3 and s.check_delay == -1.0 and not s.auto_frame,"level %d: fixed values" % n)
		check(s.arrow_after <= 30.0 and s.ring_after == s.arrow_after+18.0,"level %d: arrow and ring" % n)
		var rng = RandomNumberGenerator.new()
		rng.seed = n
		var request = Paparazzi.level_request(s,rng)
		check(request.plane in Framing.ORDER,"level %d: no request" % n)
	check(Paparazzi.level_spec(101).cards == ["infinito"],"the card of level 101")
	check(Paparazzi.level_spec(150).third_chance > 0 and Paparazzi.level_spec(140).third_chance == 0,"a third demand from stretch 15")

# 3. Every card, debut and verdict has its text in Spanish and in English.
func texts() -> void:
	var keys = []
	for card in Paparazzi.all_cards():
		keys.append("pz_nov_%s_titulo" % card)
		keys.append("pz_nov_%s_texto" % card)
	for n in range(1,120):
		var s = Paparazzi.level_spec(n)
		for card in s.cards: check(card in Paparazzi.all_cards(),"level %d: unknown card %s" % [n,card])
		if s.debut != "" and s.debut != Paparazzi.ANY: check(Paparazzi.debut_card(s.debut) in Paparazzi.all_cards(),"level %d: debut %s without a card" % [n,s.debut])
		for step in s.coach: keys.append("pz_coach_"+step)
	for plane in Framing.ORDER+[Paparazzi.ANY]:
		keys.append("pz_plano_"+plane)
		keys.append("pz_plano_un_"+plane)
	for mod in Paparazzi.MODS:
		if mod != "acompanada" and mod != "lugar": keys.append("pz_mod_"+mod)
	keys += ["pz_mod_acompanada_1","pz_mod_acompanada_2","pz_mod_lugar","pz_lugar_quiosco","pz_lugar_estanque","pz_lugar_fuente"]
	for tip in ["apunta","se_tapa","tapada","mas_zoom","menos_zoom","cabeza","pies","aire","sobra_gente","falta_gente","frente","perfil","perro","actividad","lugar","listo"]:
		keys.append("pz_consejo_"+tip)
	for t in range(1,11): keys.append("pz_tramo_%d" % t)
	keys.append("pz_tramo_infinito")
	for language in ["es","en"]:
		var table = JSON.parse_string(FileAccess.get_file_as_string("res://data/textos.%s.json" % language))
		for key in keys:
			check(table.has(key) and str(table[key]).strip_edges() != "","3. %s missing in %s" % [key,language])
		# The cards that carry a number have their hole.
		for card in ["fallo","corte_limpio","rescate"]:
			check("%d" in str(table.get("pz_nov_%s_texto" % card,"")),"3. %s without its number in %s" % [card,language])

# 4. Requests, thousands of seeds per stretch.
func requests() -> void:
	var seen_two = false
	var seen_three = false
	for t in range(1,17):
		for i in 2000:
			var n = (t-1)*10+1+i%10
			var s = Paparazzi.level_spec(n)
			var rng = RandomNumberGenerator.new()
			rng.seed = t*100000+i
			var r = Paparazzi.make_request(s,rng)
			var where = "level %d seed %d: " % [n,i]
			check(r.plane in s.planes,where+"plane %s not offered" % r.plane)
			check(r.mods.size() <= s.max_mods and r.mods.size() >= s.min_mods,where+"%d demands" % r.mods.size())
			if r.mods.size() == 2: seen_two = true
			if r.mods.size() == 3: seen_three = true
			for mod in r.mods:
				check(mod in s.mods,where+"%s not offered yet" % mod)
				var rest = r.mods.duplicate()
				rest.erase(mod)
				check(Paparazzi.compatible(mod,r.plane,s.scenario,rest),where+"%s does not fit %s %s" % [mod,r.plane,str(rest)])
			check(not (r.mods.has("sola") and r.mods.has("acompanada")),where+"alone and with company")
			check(not (r.mods.has("frente") and r.mods.has("perfil")),where+"facing and in profile")
			if r.mods.has("sola") and s.scenario == "clasico": check(r.plane in ["medio","primer_plano","cara"],where+"alone in a wide shot of the classic park")
			if r.mods.has("actividad"): check(s.scenario == "clasico",where+"seated in the big park")
			if r.mods.has("acompanada"): check(r.mods.acompanada in [1,2],where+"company count")
			if r.mods.has("lugar"): check(r.mods.lugar in Paparazzi.PLACES,where+"place")
			if s.debut in Framing.ORDER: check(r.plane == s.debut,where+"debut plane not forced")
			if s.debut in Paparazzi.MODS: check(r.mods.has(s.debut),where+"debut modifier not forced")
			if s.debut == "corredor": check(r.plane == "entero",where+"a runner not in full shot")
			if s.forced != "": check(r.plane == s.forced and r.mods.is_empty(),where+"forced plane")
	check(seen_two and seen_three,"4. two and three demands never came up")
	# The milestone's reportage: three different planes, wide to tight.
	for n in [20,30,50,100,170]:
		var s = Paparazzi.level_spec(n)
		for i in 200:
			var rng = RandomNumberGenerator.new()
			rng.seed = n*1000+i
			var r = Paparazzi.level_request(s,rng)
			var seq: Array = r.sequence
			check(seq.size() == 3 and r.plane == seq[0],"reportage %d: %s" % [n,str(seq)])
			check(Framing.wider(seq[0],seq[1]) and Framing.wider(seq[1],seq[2]),"reportage %d not wide to tight: %s" % [n,str(seq)])
			for p in seq: check(p in s.planes,"reportage %d: %s not offered" % [n,p])

# A body framed as the auto-framing does (an adult standing; see tests/test_framing.gd).
func body(r: Dictionary, top: float, tall: float) -> Dictionary:
	var out = {"behind":false}
	for k in Framing.LANDMARKS: out[k] = Vector2(.5,(top-r[k])/tall)
	return out

func framed(plane: String, shift = 0.0) -> Dictionary:
	var r = Framing.rest_for(1.75,1.75-1.75/7.0)
	if plane == "entero":
		var tall_e = r.crown/.80
		return body(r,r.crown+(tall_e-r.crown)*.5+shift,tall_e)
	var tall = (r.crown-Framing.cut_middle(plane,r))/(1.0-Framing.AIR)
	return body(r,r.crown+Framing.AIR*tall+shift*tall,tall)

func good(plane = "medio") -> Dictionary:
	return {"has_subject":true, "is_target":true, "body":framed(plane), "visible":1.0,
		"face_blocked":false, "blockers":[], "others":0, "facing":20.0, "covering":false,
		"activity":"leer", "seated":true, "dog_in_frame":true, "places":{"quiosco":true,"estanque":false},
		"subject_desc_es":PackedStringArray(["camiseta roja","vaqueros azules","pelo castaño","sin gafas"]),
		"target_desc_es":PackedStringArray(["camiseta roja","vaqueros azules","pelo castaño","sin gafas"]),
		"shown":PackedInt32Array([0,1,2,3]), "f":200.0, "scenario":"clasico", "time":"day"}

func keys_of(v: Dictionary) -> Array:
	return v.reasons.map(func(r): return r.key)

# 5. The judge.
func judge() -> void:
	var medio = {"plane":"medio","mods":{}}
	for plane in Framing.ORDER:
		if plane == "general": continue
		var v = Paparazzi.judge(good(plane),{"plane":plane,"mods":{}})
		check(v.ok and v.tip == "listo" and v.plane == plane,"5. a good %s is refused: %s" % [plane,str(keys_of(v))])
		# Any shot will do in stretch 1, from the full shot to the face.
		check(Paparazzi.judge(good(plane),{"plane":Paparazzi.ANY,"mods":{}}).ok,"5. any shot refuses a good %s" % plane)
	var r = Framing.rest_for(1.75,1.75-1.75/7.0)
	var far = good().merged({"body":body(r,r.crown+(r.crown/.25-r.crown)*.5,r.crown/.25)},true)
	var tiny = Paparazzi.judge(far,{"plane":Paparazzi.ANY,"mods":{}})
	check(keys_of(tiny) == ["pequena"] and tiny.tip == "mas_zoom","5. any shot: a wide one is too small: %s" % str(keys_of(tiny)))
	var e = good()
	e.has_subject = false
	check(keys_of(Paparazzi.judge(e,medio)) == ["nadie"],"5. nobody")
	e = good()
	e.body.eyes = Vector2(.99,.3)
	check(keys_of(Paparazzi.judge(e,medio)) == ["nadie"],"5. eyes out of the frame")
	e = good()
	e.is_target = false
	e.subject_desc_es = PackedStringArray(["camiseta roja","falda verde","pelo castaño","sin gafas"])
	var v = Paparazzi.judge(e,medio)
	check(keys_of(v) == ["no_es"] and v.reasons[0].args == ["falda verde","vaqueros azules"],"5. not them: %s" % str(v.reasons))
	check(Paparazzi.judge(e,medio,true).ok,"5. ignore_identity")
	e = good()
	e.covering = true
	check(keys_of(Paparazzi.judge(e,medio)) == ["se_tapa"],"5. covering")
	check(Paparazzi.judge(good("entero").merged({"covering":true},true),{"plane":"entero","mods":{}}).ok,"5. covering in a full shot does not matter")
	e = good()
	e.face_blocked = true
	e.blockers = ["un árbol"]
	v = Paparazzi.judge(e,medio)
	check(keys_of(v) == ["cara_tapada"] and v.tip == "tapada","5. face blocked")
	e = good()
	e.visible = .4
	check(keys_of(Paparazzi.judge(e,medio)) == ["tapada"],"5. blocked")
	v = Paparazzi.judge(good("primer_plano"),medio)
	check(keys_of(v) == ["plano"] and v.reasons[0].args == ["primer_plano","medio","menos_zoom"] and v.tip == "menos_zoom","5. tighter plane: %s" % str(v.reasons))
	v = Paparazzi.judge(good("americano"),medio)
	check(keys_of(v) == ["plano"] and v.tip == "mas_zoom","5. wider plane")
	e = good("cara")
	for k in Framing.LANDMARKS: e.body[k] += Vector2(0,.3)
	check(keys_of(Paparazzi.judge(e,{"plane":"cara","mods":{}})).has("corte_cara"),"5. face cut")
	e = good()
	e.body = framed("medio",-.15)
	check(keys_of(Paparazzi.judge(e,medio)) == ["cabeza"],"5. head cut: %s" % str(keys_of(Paparazzi.judge(e,medio))))
	e = good()
	var rest = Framing.rest_for(1.75,1.75-1.75/7.0)
	var tall_air = (rest.crown-Framing.cut_middle("medio",rest))/(1.0-.3)
	e.body = body(rest,rest.crown+.3*tall_air,tall_air)          # the same cut, the crown at 30 %
	check(keys_of(Paparazzi.judge(e,medio)) == ["aire"],"5. air: %s" % str(keys_of(Paparazzi.judge(e,medio))))
	e = good("entero")
	e.body.feet = Vector2(.5,1.05)
	e.body.ankles = Vector2(.5,1.02)
	var entero = {"plane":"entero","mods":{}}
	check(keys_of(Paparazzi.judge(e,entero)) == ["pies"],"5. feet cut: %s" % str(keys_of(Paparazzi.judge(e,entero))))
	# The modifiers, one by one.
	var mods = [["sola",true,{"others":2},"no_sola","sobra_gente"],
		["acompanada",1,{"others":0},"acompanada","falta_gente"],
		["acompanada",1,{"others":3},"acompanada","sobra_gente"],
		["frente",true,{"facing":80.0},"frente","frente"],
		["perfil",true,{"facing":20.0},"perfil","perfil"],
		["perro",true,{"dog_in_frame":false},"perro","perro"],
		["actividad",true,{"activity":""},"actividad","actividad"],
		["actividad",true,{"seated":false},"actividad","actividad"],
		["lugar","estanque",{},"lugar","lugar"]]
	for m in mods:
		var request = {"plane":"medio","mods":{m[0]:m[1]}}
		check(Paparazzi.judge(good(),request).ok or m[0] in ["perfil","lugar","acompanada"],"5. %s refused when met" % m[0])
		v = Paparazzi.judge(good().merged(m[2],true),request)
		check(keys_of(v) == [m[3]] and v.tip == m[4],"5. %s %s: %s" % [m[0],str(m[2]),str(v.reasons)])
	check(Paparazzi.judge(good().merged({"facing":90.0},true),{"plane":"medio","mods":{"perfil":true}}).ok,"5. in profile at 90°")
	check(Paparazzi.judge(good().merged({"others":1},true),{"plane":"medio","mods":{"acompanada":1}}).ok,"5. with one more")
	# The order of the reasons, whatever goes wrong at once.
	e = good("primer_plano")
	e.is_target = false
	e.subject_desc_es = PackedStringArray(["camiseta azul","vaqueros azules","pelo castaño","sin gafas"])
	e.covering = true
	e.face_blocked = true
	e.visible = .3
	e.others = 2
	e.facing = 100.0
	v = Paparazzi.judge(e,{"plane":"medio","mods":{"sola":true,"frente":true}})
	check(keys_of(v) == ["no_es","se_tapa","cara_tapada","tapada","plano","no_sola","frente"],"5. order: %s" % str(keys_of(v)))
	check(v.tip == "se_tapa","5. the tip skips the identity: %s" % v.tip)
	check(keys_of(Paparazzi.judge(e,{"plane":"medio","mods":{"sola":true,"frente":true}},true))[0] == "se_tapa","5. ignore_identity in the order")
	# The clean cut only rewards.
	e = good()
	var tall_waist = (rest.crown-rest.waist)/(1.0-Framing.AIR)*1.005   # the bottom edge just under the waist
	e.body = body(rest,rest.crown+Framing.AIR*tall_waist,tall_waist)
	v = Paparazzi.judge(e,medio)
	check(v.plane == "medio" and not v.clean_cut,"5. a cut at the waist is not clean: %s %s" % [v.plane,str(v.clean_cut)])
	check(v.ok,"5. the clean cut refuses: %s" % str(keys_of(v)))
	check(Paparazzi.judge(good(),medio).clean_cut,"5. the auto-framed medium shot is clean")
	check(Paparazzi.judge(e,medio) == Paparazzi.judge(e,medio),"5. not deterministic")
	# Every reason reads well in both languages.
	var all = [Paparazzi.reason("nadie",[],""),Paparazzi.reason("no_es",["camiseta azul","camiseta roja"],""),
		Paparazzi.reason("no_es",[],""),Paparazzi.reason("se_tapa",[],""),Paparazzi.reason("cara_tapada",["un árbol"],""),
		Paparazzi.reason("cara_tapada",[""],""),Paparazzi.reason("tapada",["una farola"],""),Paparazzi.reason("tapada",[""],""),
		Paparazzi.reason("plano",["medio","cara","mas_zoom"],""),Paparazzi.reason("corte_cara",[],""),
		Paparazzi.reason("cabeza",[],""),Paparazzi.reason("pies",[],""),Paparazzi.reason("aire",[],""),
		Paparazzi.reason("no_sola",[2],""),Paparazzi.reason("acompanada",[1,3],""),Paparazzi.reason("frente",[],""),
		Paparazzi.reason("perfil",[],""),Paparazzi.reason("perro",[],""),Paparazzi.reason("actividad",[],""),
		Paparazzi.reason("lugar",["estanque","grande"],""),Paparazzi.reason("lugar",["quiosco","clasico"],"")]
	for language in ["es","en"]:
		Texts.set_language(language,false)
		for one in all:
			var text = Paparazzi.reason_text(one)
			check(text != "" and not "%" in text and not text.begins_with("pz_"),"5. %s in %s: «%s»" % [one.key,language,text])
		check(Paparazzi.reason_text(all[19]) == Texts.get_text("pz_motivo_lugar") % [Texts.get_text("pz_lugar_fuente")],"5. the big park's water is a fountain")
		for mod in Paparazzi.MODS:
			var value = 2 if mod == "acompanada" else ("quiosco" if mod == "lugar" else true)
			var label = Paparazzi.mod_text(mod,value,"clasico")
			check(label != "" and not "%" in label and not label.begins_with("pz_"),"5. modifier %s in %s" % [mod,language])

# 6. The clock's sums.
func clock() -> void:
	var s1 = Paparazzi.level_spec(5)
	var s2 = Paparazzi.level_spec(15)
	var s4 = Paparazzi.level_spec(35)
	check(Paparazzi.after_success(10.0,s1,{}) == 10.0+s1.bonus,"6. plain success")
	check(Paparazzi.after_success(10.0,s1,{"first_try":true,"clean_cut":true}) == 10.0+s1.bonus,"6. no extras in stretch 1")
	check(Paparazzi.after_success(10.0,s2,{"first_try":true,"clean_cut":true}) == 10.0+s2.bonus+2.0,"6. first try from stretch 2, clean cut not yet")
	check(Paparazzi.after_success(10.0,s4,{"first_try":true,"clean_cut":true}) == 10.0+s4.bonus+5.0,"6. both from stretch 4")
	check(Paparazzi.after_success(10.0,Paparazzi.level_spec(40),{"hito":true}) == 10.0+Paparazzi.level_spec(40).bonus+15.0,"6. milestone")
	check(Paparazzi.after_success(110.0,s4,{"hito":true}) == Paparazzi.MAX_BANK,"6. capped")
	check(Paparazzi.after_fail(10.0,s1) == 10.0,"6. no penalty in stretch 1")
	check(Paparazzi.after_fail(10.0,s2) == 7.0,"6. penalty in stretch 2")
	check(Paparazzi.after_fail(10.0,s4) == 5.0,"6. penalty from stretch 3")
	check(Paparazzi.after_fail(2.0,s4) == 0.0,"6. never below zero")
	check(Paparazzi.start_jokers(1) == {"congelar":0,"otro":0,"rescate":1},"6. jokers from level 1")
	check(Paparazzi.start_jokers(11) == {"congelar":1,"otro":1,"rescate":1},"6. jokers from a milestone")
	check(Paparazzi.milestone_joker(10) == "congelar" and Paparazzi.milestone_joker(20) == "otro" and Paparazzi.milestone_joker(30) == "congelar","6. milestone jokers")

# 7. Progress, in the tests' own file.
func progress() -> void:
	var p = Paparazzi.load_progress()
	check(p.hito == 0 and p.record == 0 and p.visto.is_empty(),"7. a fresh progress")
	Paparazzi.level_passed(9)
	check(Paparazzi.load_progress().hito == 0 and Paparazzi.load_progress().record == 9,"7. level 9 consolidates nothing")
	for n in range(10,31): Paparazzi.level_passed(n)
	p = Paparazzi.load_progress()
	check(p.hito == 3 and p.record == 30 and p.fotos == 22,"7. consolidated: %s" % str(p))
	check(Paparazzi.start_points(p.hito) == [1,11,21,31],"7. starting points")
	Paparazzi.level_passed(12)
	check(Paparazzi.load_progress().hito == 3 and Paparazzi.load_progress().record == 30,"7. a later, shorter run keeps the record")
	check(not Paparazzi.seen("entero"),"7. unseen card")
	Paparazzi.mark_seen("entero")
	check(Paparazzi.seen("entero") and not Paparazzi.seen("medio"),"7. seen card")
	Paparazzi.run_ended()
	check(Paparazzi.load_progress().carreras == 1 and Paparazzi.seen("entero"),"7. a run ended keeps the cards")
