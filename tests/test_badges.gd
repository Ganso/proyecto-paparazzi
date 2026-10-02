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
	var sharp = photo()
	check(sharp.score >= 90 and Badges.credits(sharp,{}) == ["halcon"],"A sharp photo on a line of thirds counts for the hawk's eye only")
	check(Badges.credits(sharp,{"first_shot":true}) == ["halcon","decisiva"],"…and for the decisive moment if it is the first shot")
	check(Badges.credits(photo({"chest":Vector2(.5,.4),"head":Vector2(.5,.2),"feet":Vector2(.5,.8)}),{}).is_empty(),"Centred: no hawk's eye")
	check(not "halcon" in Badges.credits(photo({"s":6.0}),{}),"Slightly out of focus: no hawk's eye")
	check(Badges.credits(photo({"in_front":false}),{"first_shot":true,"night":true}).is_empty(),"A rejected photo counts for nothing")
	check("noche" in Badges.credits(sharp,{"night":true}) and not "noche" in Badges.credits(sharp,{"night":false}),"Night photos count only at night")
	var dark = photo()
	dark.delta = .6
	check(not "noche" in Badges.credits(dark,{"night":true}),"Night: 0.6 EV off does not count")
	var pan = {"f":85.0,"d":7.0,"s":7.0,"v":2.8,"t":1.0/30,"motion_sign":1.0,"camera_omega":2.8/7.0}
	var swept = photo(pan)
	check(swept.panning and "velocidad" in Badges.credits(swept,{}),"A pan with an 85 mm at 1/30 s streaks more than 40 px (%.0f px)" % (swept.background/36.0*1280.0))
	pan.f = 50.0
	check(photo(pan).panning and not "velocidad" in Badges.credits(photo(pan),{}),"A pan with too short a streak is not pure speed yet")
	# Five in a row earn the badge once, and it is kept.
	var earned = []
	for k in 5: earned.append(Badges.register(sharp,{}))
	check(earned.slice(0,4).all(func(a): return a.is_empty()) and earned[4] == ["halcon"],"The fifth hawk's-eye photo earns the badge")
	check(Badges.register(sharp,{}).is_empty() and Badges.load_state().halcon == 5,"A sixth one does not earn it again")
	check(Badges.register(swept,{}) == ["velocidad"],"One good pan earns pure speed")
	check(Badges.grant("graduado") and not Badges.grant("graduado"),"The diploma is granted once")
	var state = Badges.load_state()
	check(Badges.earned("halcon",state) and Badges.earned("velocidad",state) and Badges.earned("graduado",state) and not Badges.earned("noche",state) and not Badges.earned("decisiva",state),"The badges earned are saved to disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Badges.SAVE))
	print("BADGE TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
