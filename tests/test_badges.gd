extends SceneTree
# Mastery badges (docs/futuro/05 §3): deterministic awards from fixed photo results. Headless.
const Badges = preload("res://scripts/badges.gd")
const Photo = preload("res://scripts/photography.gd")
const Texts = preload("res://scripts/texts.gd")
var checks = 0
var failures = 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func photo(changes: Dictionary = {}) -> Dictionary:
	var e = {"f":50.0,"n":8.0,"t":1.0/250,"iso":100,"s":4.0,"d":4.0,"v":0.0,"scene_ev":14.0,"head":Vector2(.34,.2),"feet":Vector2(.34,.8),"chest":Vector2(.34,.4),"in_front":true,"blockers":[]}
	e.scene_ev = 14+Photo.ev(e.n,e.t,e.iso,14)
	for key in changes: e[key] = changes[key]
	var result = Photo.evaluate(e)
	result["evidence"] = e
	return result

func _initialize() -> void:
	Badges.SAVE = "user://insignias_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Badges.SAVE))
	for id in Badges.BADGES:
		check(Texts.get_text("insignia_%s_nombre" % id) != "insignia_%s_nombre" % id and Texts.get_text("insignia_%s_texto" % id) != "insignia_%s_texto" % id,"Badge %s has its texts" % id)
		check(Badges.GOALS.has(id),"Badge %s has a goal" % id)
	check(Badges.BADGES.size() == 10,"Ten badges")
	var sharp = photo()
	var got = Badges.credits(sharp,{})
	check(sharp.score >= 90 and "halcon" in got and "tercios" in got and not "decisiva" in got and not "fotometro" in got and not "noche" in got,"A sharp photo on a line of thirds: hawk's eye and rule of thirds (%s)" % str(got))
	check("decisiva" in Badges.credits(sharp,{"first_shot":true}),"…and the decisive moment if it is the first shot")
	var centred = Badges.credits(photo({"chest":Vector2(.5,.4),"head":Vector2(.5,.2),"feet":Vector2(.5,.8)}),{})
	check("halcon" in centred and not "tercios" in centred,"Centred: hawk's eye, but no rule of thirds")
	check(not "tercios" in Badges.credits(photo({"head":Vector2(.34,.4),"feet":Vector2(.34,.7)}),{}),"On the thirds but small: no rule of thirds")
	check(not "halcon" in Badges.credits(photo({"s":6.0}),{}),"Slightly out of focus: no hawk's eye")
	check(not "halcon" in Badges.credits(photo({"d_eyes":4.6,"n":2.0}),{}),"The eyes out of focus: no hawk's eye, however sharp the chest")
	check(Badges.credits(photo({"in_front":false}),{"first_shot":true,"night":true,"manual":true}).is_empty(),"A rejected photo counts for nothing")
	check("noche" in Badges.credits(sharp,{"night":true}) and not "noche" in Badges.credits(sharp,{"night":false}),"Night photos count only at night")
	check("fotometro" in Badges.credits(sharp,{"manual":true}) and not "fotometro" in Badges.credits(sharp,{"manual":false}),"The human light meter counts only in manual exposure")
	var dark = photo()
	dark.delta = .6
	check(not "noche" in Badges.credits(dark,{"night":true}) and not "fotometro" in Badges.credits(dark,{"manual":true}),"0.6 EV off does not count, by night or in manual")
	check("cremoso" in Badges.credits(photo({"f":85.0,"n":1.8}),{}) and not "cremoso" in got,"An 85 mm at f/1.8 gives a creamy background; a 50 mm at f/8 does not")
	var runner = {"v":2.8,"d":7.0,"s":7.0,"t":1.0/1000,"motion_sign":1.0}
	check("detenido" in Badges.credits(photo(runner),{}),"A runner at 1/1000 s is frozen")
	runner.t = 1.0/30
	check(not "detenido" in Badges.credits(photo(runner),{}),"…and at 1/30 s is not")
	check(not "detenido" in got,"A person standing still freezes nothing")
	var pan = {"f":85.0,"d":7.0,"s":7.0,"v":2.8,"t":1.0/30,"motion_sign":1.0,"camera_omega":2.8/7.0}
	var swept = photo(pan)
	check(swept.panning and "velocidad" in Badges.credits(swept,{}) and not "detenido" in Badges.credits(swept,{}),"A pan with an 85 mm at 1/30 s streaks more than 40 px (%.0f px), and is not a frozen runner" % (swept.background/36.0*1280.0))
	pan.f = 50.0
	check(photo(pan).panning and not "velocidad" in Badges.credits(photo(pan),{}),"A pan with too short a streak does not count yet")
	# Five in a row earn the badge once, and it is kept.
	var earned = []
	for k in 5: earned.append(Badges.register(sharp,{}))
	check(earned.slice(0,4).all(func(a): return a.is_empty()) and "halcon" in earned[4] and "tercios" in earned[4],"The fifth photo earns hawk's eye and rule of thirds")
	check(Badges.register(sharp,{}).is_empty() and Badges.load_state().halcon == 5,"A sixth one does not earn them again")
	check(Badges.register(swept,{}) == ["velocidad"],"One good pan earns its badge")
	check(Badges.grant("graduado") and not Badges.grant("graduado"),"The diploma is granted once")
	check(Badges.grant("calle") and not Badges.grant("calle"),"…and so is the badge of the whole arcade")
	var state = Badges.load_state()
	check(Badges.earned("halcon",state) and Badges.earned("velocidad",state) and Badges.earned("graduado",state) and Badges.earned("calle",state) and not Badges.earned("noche",state) and not Badges.earned("decisiva",state) and not Badges.earned("cremoso",state),"The badges earned are kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Badges.SAVE))
	print("BADGE TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
