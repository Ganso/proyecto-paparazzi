extends SceneTree
const Photo = preload("res://scripts/photography.gd")
const Cast = preload("res://scripts/casting.gd")
var checks = 0
var failures = 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func near(a: float,b: float,tolerance = .002) -> bool:
	return abs(a-b) <= tolerance
func fixture() -> Dictionary:
	return {"f":24.0,"n":8.0,"t":1.0/250,"iso":100,"s":4.0,"d":4.0,"v":0.0,"scene_ev":14.0,"head":Vector2(.5,.2),"feet":Vector2(.5,.8),"chest":Vector2(.5,.4),"in_front":true,"blockers":[]}
func _initialize() -> void:
	check(near(Photo.coc(50,4,4,4),0),"CoC exact focus")
	check(near(Photo.coc(50,4,4,5),.031566),"CoC near focus")
	check(near(Photo.coc(105,2.8,4,4.2),.048076),"CoC telephoto")
	check(near(Photo.coc(105,2.8,4,7),.428309),"CoC large blur")
	check(near(Photo.coc(50,4,4,INF),.15625),"Infinite focus analytic limit")
	var dof = Photo.dof(50,4,4)
	check(near(dof.x,3.36375,.01) and near(dof.y,4.933,.01),"DOF reference")
	check(is_inf(Photo.dof(24,8,4).y),"Far DOF infinity")
	var e = fixture()
	var result = Photo.evaluate(e)
	check(result.score == 100 and result.stars == 5 and result.credits == 150,"Perfect photo")
	check(result == Photo.evaluate(e.duplicate(true)),"Determinism")
	for delta in [-3.0,-2.0,-1.0,0.0,1.0,2.0,3.0]:
		e = fixture()
		e.scene_ev = 14+Photo.ev(e.n,e.t,e.iso,14)-delta
		result = Photo.evaluate(e)
		check(near(result.exposure,clampf(1-maxf(0,abs(delta)-.5)/2.5,0,1)),"Exposure curve %s" % delta)
	e = fixture()
	e.f = 105.0
	e.t = 1.0/15
	e.v = 1.2
	e.n = 22.0
	result = Photo.evaluate(e)
	check(result.movement == 0 and result.ratio >= 7 and result.drag > 2,"1/15 at 105 mm visibly moved")
	# Normative weighted sum limits the movement-only penalty to 18 points.
	check(result.score <= 82,"Incorrect shutter penalized")
	for blocked in range(6):
		e = fixture()
		for i in blocked: e.blockers.append("una farola")
		result = Photo.evaluate(e)
		check(result.rejected == (blocked >= 4),"Occlusion rejection boundary")
		check(near(result.occlusion,(5.0-blocked)/5),"Occlusion score")
	e = fixture()
	e.chest = Vector2(1.01,.5)
	check(Photo.evaluate(e).rejected,"Chest out of frame rejects")
	e = fixture()
	e.in_front = false
	check(Photo.evaluate(e).rejected,"Behind camera rejects")
	e = fixture()
	e.head.y = -.1
	e.feet.y = .5
	check(near(Photo.evaluate(e).framing,.6),"Cropped frame penalty")
	e.chest.x = .333
	check(near(Photo.evaluate(e).framing,.75),"Thirds bonus")
	var casting = Cast.new()
	var all_traits: Array = []
	var signatures = {}
	for i in 100:
		var t = casting.generate()
		var desc = casting.descriptors(t)
		check(not signatures.has(desc),"Unique appearance")
		signatures[desc] = true
		check(t.has("upper") and t.has("lower") and t.has("hair"),"All mandatory slots")
		check(not "piel" in ",".join(desc),"Briefing excludes skin tone")
		all_traits.append(t)
	for t in all_traits:
		var predicates = casting.predicates_for(t,all_traits)
		check(predicates.size() >= 1 and predicates.size() <= 4,"Unique briefing available")
		var matches = 0
		for other in all_traits:
			if casting.descriptors(other).slice(0,predicates.size()) == predicates: matches += 1
		check(matches == 1,"Briefing has exactly one match")
	var piece = casting.catalog.piezas.piernas[2]
	check(casting.garment(piece,"gris",casting.catalog.tonos_ropa) == "bermudas grises","Plural adjective agreement")
	print("TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
