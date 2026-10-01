extends SceneTree
# Arcade levels and their conditions (docs/futuro/21): headless, deterministic.
#   ~/bin/godot-4-fp --path . --headless --script tests/test_arcade.gd
const Arcade = preload("res://scripts/arcade.gd")
const Conditions = preload("res://scripts/conditions.gd")
const Texts = preload("res://scripts/texts.gd")
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
	check(Arcade.LEVELS.size() == 20 and Arcade.BLOCKS.size() == 4,"20 levels in 4 blocks")
	check(Arcade.LEVELS[0].shots == 5 and Arcade.LEVELS[19].shots == 1,"Shots go from 5 to 1")
	check(Arcade.LEVELS[0].min == 50 and Arcade.LEVELS[19].min == 80,"The pass mark goes from 50 to 80")
	check(Arcade.LEVELS[0].limit == 0 and Arcade.LEVELS[19].limit > 0,"The clock appears along the way")
	var ok_order = true
	for n in range(1,20):
		if Arcade.LEVELS[n].min < Arcade.LEVELS[n-1].min or Arcade.LEVELS[n].shots > Arcade.LEVELS[n-1].shots+1: ok_order = false
	check(ok_order,"Pass marks never drop and shots never jump up")
	check(Arcade.LEVELS.slice(0,5).all(func(l): return l.body == 0 and l.auto),"Block 1: automatic compact")
	check(Arcade.LEVELS.slice(15,20).all(func(l): return l.body == 3),"Block 4: the TLR")
	check(Arcade.LEVELS.any(func(l): return l.scenario == "grande"),"Some levels in the big park")
	for n in 20:
		check(Texts.get_text("arcade_nivel_%d_titulo" % (n+1)) != "arcade_nivel_%d_titulo" % (n+1),"Level %d has a title" % (n+1))
		for key in Arcade.LEVELS[n].cond:
			check(not Conditions.describe(key,Arcade.LEVELS[n].cond[key]).begins_with("cond_corta"),"Level %d: condition %s has a label" % [n+1,key])
	# Progress: unlocking and stars.
	check(Arcade.unlocked(0,{}) and not Arcade.unlocked(1,{}) and Arcade.unlocked(1,{0:{"score":70,"stars":2}}),"A passed level opens the next")
	check(Arcade.stars_for(49,50) == 0 and Arcade.stars_for(50,50) == 1 and Arcade.stars_for(100,50) == 5,"Stars from the pass mark to 100")
	Arcade.SAVE = "user://arcade_test_headless.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	Arcade.save_result(2,70,2)
	Arcade.save_result(2,60,1)
	var progress = Arcade.load_progress()
	check(progress.has(2) and int(progress[2].score) == 70,"Progress keeps the best result")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Arcade.SAVE))
	# Conditions.
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
