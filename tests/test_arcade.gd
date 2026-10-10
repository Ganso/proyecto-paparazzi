extends SceneTree
# Arcade levels and their conditions (docs/futuro/21): headless, deterministic.
#   ~/bin/godot-4-fp --path . --headless --script tests/test_arcade.gd
const Arcade = preload("res://scripts/arcade.gd")
const Conditions = preload("res://scripts/conditions.gd")
const Texts = preload("res://scripts/texts.gd")
const Photography = preload("res://scripts/photography.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func evidence(extra = {}) -> Dictionary:
	var e = {"f":50.0,"n":2.8,"t":1.0/250,"iso":100,"s":5.0,"d":5.0,"d_eyes":5.0,"v":0.0,"scene_ev":14.0,
		"head":Vector2(.4,.2),"feet":Vector2(.4,.85),"chest":Vector2(.382,.45),"in_front":true,"blockers":[],"others":[]}
	e.merge(extra,true)
	return e

func _initialize() -> void:
	# Level data: 20 levels in 4 blocks, the curve tightens.
	check(Arcade.LEVELS.size() == 30 and Arcade.BLOCKS.size() == 6,"30 levels in 6 blocks")
	# Passing clouds only where the exposure is the player's and there is a sun to cover.
	var cloudy = range(30).filter(func(n): return Arcade.clouds(n))
	check(not cloudy.is_empty() and cloudy.all(func(n): return Arcade.LEVELS[n].auto is bool and not Arcade.LEVELS[n].auto and Arcade.LEVELS[n].time in ["day","golden"]) and not Arcade.clouds(0) and not Arcade.clouds(-1),"Clouds darken only the manual-exposure levels by day (%s)" % str(cloudy.map(func(n): return n+1)))
	check(Texts.get_text("arcade_aviso_nubes") != "arcade_aviso_nubes","…and their briefing warns about them")
	check(Arcade.LEVELS[0].shots == 5 and Arcade.LEVELS[24].shots == 1,"Shots go from 5 to 1")
	check(Arcade.LEVELS[0].min == 50 and Arcade.LEVELS[24].min == 75,"The pass mark goes from 50 to 75")
	check(Arcade.LEVELS[0].limit == 0 and Arcade.LEVELS[24].limit > 0,"The clock appears along the way")
	var ok_order = true
	for n in range(1,Arcade.LEVELS.size()):
		var same_block = Arcade.block_of(n) == Arcade.block_of(n-1)
		if (same_block and Arcade.LEVELS[n].min < Arcade.LEVELS[n-1].min) or (same_block and Arcade.LEVELS[n].shots > Arcade.LEVELS[n-1].shots+1) or (n < 25 and Arcade.LEVELS[n].shots > Arcade.LEVELS[n-1].shots+1): ok_order = false
	check(ok_order,"Pass marks never drop within a block (a new camera may start lower) and shots never jump up (the mastery block starts afresh)")
	check(Arcade.LEVELS.slice(25,30).all(func(l): return l.body == 2) and Arcade.LEVELS[25].cond.has("barrido") and Arcade.LEVELS[26].cond.has("estela") and Arcade.LEVELS[29].min == 80,"Block 6: mastery with the SLR, the pan and the trail, the highest pass mark")
	check(Arcade.LEVELS.slice(0,5).all(func(l): return l.body == 0 and l.auto),"Block 1: automatic compact")
	check(Arcade.LEVELS.slice(20,25).all(func(l): return l.body == 3),"Block 5: the TLR")
	check(Arcade.LEVELS.slice(15,20).map(func(l): return l.time) == ["blue","day","golden","golden","night"],"Block 4: the light, from the blue hour to the night")
	check(Arcade.LEVELS.any(func(l): return l.scenario == "grande"),"Some levels in the big park")
	# One manual control at a time: aperture priority and shutter priority come before full manual,
	# and wherever focus and exposure are both manual, walkers go slower.
	var first = func(m): return Arcade.LEVELS.find(Arcade.LEVELS.filter(func(l): return str(l.auto) == m)[0])
	check(first.call("A") < first.call("false") and first.call("S") < first.call("false"),"Priority modes come before full manual")
	check(Arcade.LEVELS.all(func(l): return not (str(l.auto) == "false" and l.body in [1,3]) or l.get("pace",1.0) < 1.0 or l.get("target","") == "runner"),"Manual focus + manual exposure levels slow the walkers")
	for n in Arcade.LEVELS.size():
		check(Texts.get_text("arcade_nivel_%d_texto" % (n+1)) != "arcade_nivel_%d_texto" % (n+1),"Level %d has a text" % (n+1))
		check(Texts.get_text("arcade_nivel_%d_titulo" % (n+1)) != "arcade_nivel_%d_titulo" % (n+1),"Level %d has a title" % (n+1))
		for key in Arcade.LEVELS[n].cond:
			check(not Conditions.describe(key,Arcade.LEVELS[n].cond[key]).begins_with("cond_corta"),"Level %d: condition %s has a label" % [n+1,key])
	# Progress: unlocking and stars.
	check(Arcade.unlocked(0,{}) and not Arcade.unlocked(1,{}) and Arcade.unlocked(1,{0:{"score":70,"stars":2}}),"A passed level opens the next")
	check(Arcade.stars_for(49,50) == 0 and Arcade.stars_for(50,50) == 1 and Arcade.stars_for(100,50) == 5,"Stars from the pass mark to 100")
	# Cheat code (-- --cheat=niveles): every level open for the run, nothing saved for it.
	Arcade.all_open = true
	check(Arcade.unlocked(29,{}) and Arcade.unlocked(7,{}),"The cheat opens every level")
	Arcade.all_open = false
	check(not Arcade.unlocked(29,{}),"…and only while it is on")
	Arcade.SAVE = "user://arcade_test_headless.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	Arcade.save_result(2,70,2)
	Arcade.save_result(2,60,1)
	var progress = Arcade.load_progress()
	check(progress.has(2) and int(progress[2].score) == 70,"Progress keeps the best result")
	# A progress file from the 25 levels: every result goes to where its level is now.
	var before = ConfigFile.new()
	for n in [0,6,8,12,24]: before.set_value("niveles",str(n),{"score":60+n,"stars":2})
	before.save(Arcade.SAVE)
	progress = Arcade.load_progress()
	check(progress.keys() == [0,7,15,29] and int(progress[7].score) == 66 and int(progress[29].score) == 84,"Old progress moves to the new numbers and the dropped level goes (%s)" % str(progress.keys()))
	check(Arcade.load_progress().keys() == [0,7,15,29],"…once only")
	check(Arcade.unlocked(7,progress) and Arcade.unlocked(8,progress) and not Arcade.unlocked(10,progress),"A level passed before stays open, and opens the next")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	# Every condition is asked for by some level.
	var asked = {}
	for l in Arcade.LEVELS:
		for key in l.cond: asked[key] = true
	for key in ["ojos","aislado","acompanado","grande","focal_min","focal_max","aire","aurea","fondo","nitido","congelado","barrido","estela","exposicion","contraluz","silueta","lugar","actividad","perro"]:
		check(asked.has(key),"Some level asks for «%s»" % key)
	# Conditions.
	# The new ones (06-10-2026).
	check(Conditions.check(evidence({"f":28.0}),{"focal_max":35})[0].ok and not Conditions.check(evidence(),{"focal_max":35})[0].ok,"Maximum focal length")
	var walking = {"v":.7,"motion_sign":1.0,"t":1.0/500}
	check(Conditions.check(evidence(walking),{"aire":true})[0].ok,"Room ahead: walking right from the left of the frame")
	check(not Conditions.check(evidence(walking.merged({"motion_sign":-1.0},true)),{"aire":true})[0].ok,"Room ahead: the room behind the back does not count")
	check(Conditions.check(evidence(walking.merged({"motion_sign":-1.0,"chest":Vector2(.62,.45)},true)),{"aire":true})[0].ok,"Room ahead: walking left from the right")
	check(not Conditions.check(evidence({"v":0.0,"motion_sign":0.0}),{"aire":true})[0].ok,"Room ahead needs someone crossing")
	check(Conditions.check(evidence({"scene_ev":14.0,"n":8.0,"t":1.0/250,"iso":100}),{"exposicion":true})[0].ok and Conditions.check(evidence({"scene_ev":14.2,"n":8.0}),{"exposicion":true})[0].ok and not Conditions.check(evidence({"scene_ev":14.4,"n":8.0}),{"exposicion":true})[0].ok,"Exposure within a quarter of a stop")
	check(Conditions.check(evidence({"f":35.0,"n":11.0}),{"nitido":true})[0].ok and not Conditions.check(evidence({"f":35.0,"n":2.8}),{"nitido":true})[0].ok,"Everything sharp depends on the aperture")
	var kiosk = {"quiosco":{"pos":Vector2(.7,.4),"d":14.0,"front":true}}
	check(Conditions.check(evidence({"places":kiosk}),{"lugar":"quiosco"})[0].ok,"The landmark in the frame")
	check(not Conditions.check(evidence({"places":{"quiosco":{"pos":Vector2(1.2,.4),"d":14.0,"front":true}}}),{"lugar":"quiosco"})[0].ok and not Conditions.check(evidence(),{"lugar":"quiosco"})[0].ok and not Conditions.check(evidence({"places":{"quiosco":{"pos":Vector2(.5,.4),"d":14.0,"front":false}}}),{"lugar":"quiosco"})[0].ok,"…not out of it, nor behind the camera")
	check(Conditions.describe("lugar","quiosco").contains("quiosco"),"The landmark is named in the briefing")
	check(Conditions.check(evidence({"activity":"leer"}),{"actividad":true})[0].ok and not Conditions.check(evidence({"activity":""}),{"actividad":true})[0].ok and not Conditions.check(evidence(),{"actividad":true})[0].ok,"Doing something")
	check(Conditions.check(evidence({"dog":{"pos":Vector2(.5,.8),"d":5.2,"front":true}}),{"perro":true})[0].ok,"The dog in the frame and sharp")
	check(not Conditions.check(evidence({"dog":{"pos":Vector2(1.1,.8),"d":5.2,"front":true}}),{"perro":true})[0].ok and not Conditions.check(evidence({"dog":{"pos":Vector2(.5,.8),"d":9.0,"front":true}}),{"perro":true})[0].ok and not Conditions.check(evidence(),{"perro":true})[0].ok,"…not out of the frame, blurred or missing")
	# Against the light: the meter reads the sun; the face wants two stops more, the silhouette less.
	var sun = {"backlight":.9,"sunlit":true,"scene_ev":14.0,"n":8.0,"t":1.0/250,"iso":100}
	var metered = Conditions.judge(evidence(sun),{"contraluz":true})
	check(metered.rejected,"Backlit at what the meter says: the face is dark")
	var compensated = Conditions.judge(evidence(sun.merged({"t":1.0/60},true)),{"contraluz":true})
	check(not compensated.rejected and compensated.exposure > .99,"Backlit and two stops over: the face is right, and the photo is judged on it")
	check(Conditions.judge(evidence(sun.merged({"backlight":.1,"t":1.0/60},true)),{"contraluz":true}).rejected and Conditions.judge(evidence(sun.merged({"sunlit":false,"t":1.0/60},true)),{"contraluz":true}).rejected,"Without the sun behind there is no backlight")
	var shaded = Conditions.judge(evidence(sun.merged({"sunlit":false,"t":1.0/60},true)),{"contraluz":true})
	check(shaded.reason.contains("sombra") and not Conditions.judge(evidence(sun.merged({"backlight":.1,"t":1.0/60},true)),{"contraluz":true}).reason.contains("sombra"),"Facing the sun with the subject in the shade says so, not «the sun is not behind»")
	# «Exposición clavada» is judged against what the meter read (10-10-2026).
	check(Conditions.check(evidence({"scene_ev":14.5,"metered":14.0,"n":8.0,"t":1.0/250,"iso":100}),{"exposicion":true})[0].ok and not Conditions.check(evidence({"scene_ev":14.0,"metered":14.5,"n":8.0,"t":1.0/250,"iso":100}),{"exposicion":true})[0].ok,"The exposure to a quarter of a stop is measured from the meter's zero")
	var dark = Conditions.judge(evidence(sun.merged({"t":1.0/1000},true)),{"silueta":true})
	check(not dark.rejected and dark.exposure > .9,"Silhouette: two stops under the meter")
	check(Conditions.judge(evidence(sun.merged({"t":1.0/60},true)),{"silueta":true}).rejected and Conditions.judge(evidence(sun),{"silueta":true}).rejected,"…not at the meter's reading, nor over it")
	var twice = evidence(sun)
	Conditions.prepare(twice,{"contraluz":true})
	Conditions.prepare(twice,{"contraluz":true})
	check(is_equal_approx(twice.scene_ev,12.0),"The photo's target moves once")
	# The trail: a runner dragged on purpose, the camera still.
	var trail_shot = {"v":2.8,"d":7.0,"s":7.0,"f":50.0,"t":1.0/30,"motion_sign":1.0,"n":22.0,"scene_ev":14.0}
	var trail = Conditions.judge(evidence(trail_shot),{"estela":true})
	check(not trail.rejected and trail.movement > .99,"Trail: a still camera at 1/30 s, and the movement counts in favour")
	check(Photography.evaluate(evidence(trail_shot)).movement < .01,"…which without the level is just a blurred runner")
	check(Conditions.judge(evidence(trail_shot.merged({"t":1.0/500},true)),{"estela":true}).rejected,"Trail: 1/500 s freezes it")
	check(Conditions.judge(evidence(trail_shot.merged({"camera_omega":2.8/7.0},true)),{"estela":true}).rejected,"Trail: following the runner is a pan, not a trail")
	check(Conditions.judge(evidence(trail_shot.merged({"v":.6},true)),{"estela":true}).rejected,"Trail: a walker is not a runner")
	# Pan: a runner followed by the camera at a slow shutter.
	var runner_shot = {"v":2.8,"d":7.0,"s":7.0,"f":50.0,"t":1.0/30,"motion_sign":1.0}
	var pan_check = Conditions.check(evidence(runner_shot.merged({"camera_omega":2.8/7.0})),{"barrido":true})
	check(pan_check[0].ok,"Pan: following the runner at 1/30 s passes")
	check(Conditions.check(evidence(runner_shot.merged({"camera_omega":2.8/7.0*.92})),{"barrido":true})[0].ok,"Pan: 8 % off the runner's speed still passes")
	check(not Conditions.check(evidence(runner_shot.merged({"camera_omega":2.8/7.0*.7})),{"barrido":true})[0].ok,"Pan: 30 % off drags the runner")
	check(not Conditions.check(evidence(runner_shot),{"barrido":true})[0].ok,"Pan: a still camera is not a pan")
	check(not Conditions.check(evidence(runner_shot.merged({"camera_omega":2.8/7.0,"t":1.0/500},true)),{"barrido":true})[0].ok,"Pan: at 1/500 s the background does not streak")
	check(not Conditions.check(evidence(runner_shot.merged({"v":.6,"camera_omega":.6/7.0},true)),{"barrido":true})[0].ok,"Pan: a walker is not a runner")
	check(Conditions.check(evidence(runner_shot.merged({"camera_omega":2.8/7.0})),{"congelado":true})[0].ok,"A good pan also counts as frozen")
	var c = Conditions.check(evidence(),{"ojos":true})
	check(c[0].ok,"Eyes in focus pass")
	c = Conditions.check(evidence({"d_eyes":3.0}),{"ojos":true})
	check(not c[0].ok,"Eyes out of focus fail even if the chest is sharp")
	var crowd = [{"chest":Vector2(.7,.5),"h":.3,"visible":true},{"chest":Vector2(.2,.5),"h":.05,"visible":true},{"chest":Vector2(.6,.5),"h":.3,"visible":false},{"chest":Vector2(1.3,.5),"h":.3,"visible":true}]
	check(Conditions.companions(evidence({"others":crowd})) == 1,"Only visible, noticeable people inside the frame count")
	check(not Conditions.check(evidence({"others":crowd}),{"aislado":true})[0].ok,"Someone else in the frame breaks isolation")
	check(Conditions.check(evidence({"others":crowd}),{"acompanado":1})[0].ok,"Exactly one companion")
	check(Conditions.check(evidence(),{"grande":.6})[0].ok and not Conditions.check(evidence(),{"grande":.7})[0].ok,"Subject size threshold")
	check(Conditions.check(evidence(),{"aurea":true})[0].ok and not Conditions.check(evidence({"chest":Vector2(.5,.45)}),{"aurea":true})[0].ok,"Golden section, not the centre")
	check(Conditions.check(evidence({"f":135.0}),{"focal_min":135})[0].ok and not Conditions.check(evidence(),{"focal_min":135})[0].ok,"Minimum focal length")
	check(Conditions.check(evidence({"f":105.0,"n":1.8}),{"fondo":true})[0].ok and not Conditions.check(evidence({"f":24.0,"n":8.0}),{"fondo":true})[0].ok,"Background blur depends on focal and aperture")
	check(Conditions.check(evidence({"v":2.8,"t":1.0/1000}),{"congelado":true})[0].ok and not Conditions.check(evidence({"v":2.8,"t":1.0/60}),{"congelado":true})[0].ok and not Conditions.check(evidence({"v":0.0}),{"congelado":true})[0].ok,"Frozen motion needs a moving subject and a fast shutter")
	# A failed condition rejects the photo with its reason, deterministically.
	var result = {"score":80,"stars":4,"credits":128,"rejected":false,"reason":""}
	Conditions.apply(result,evidence({"chest":Vector2(.5,.45)}),{"aurea":true})
	check(result.rejected and result.score == 0 and result.reason.contains("áurea"),"A failed condition rejects the photo")
	var again = {"score":80,"stars":4,"credits":128,"rejected":false,"reason":""}
	Conditions.apply(again,evidence({"chest":Vector2(.5,.45)}),{"aurea":true})
	check(again.hash() == result.hash(),"Conditions are deterministic")
	print("ARCADE TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
