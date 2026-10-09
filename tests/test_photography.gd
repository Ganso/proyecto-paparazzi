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
	# The face is what the photo asks for (the chest does not fit beside it with a telephoto).
	e = fixture()
	e.head.y = .05
	e.eyes = Vector2(.5,.2)
	e.chest.y = 1.3
	e.feet.y = 2.6
	var close = Photo.evaluate(e)
	check(not close.rejected and near(close.framing,1.0),"A portrait with the chest out of the frame is a good framing")
	e.head.y = -.1
	check(near(Photo.evaluate(e).framing,.6),"A portrait with the head cut is penalised")
	e.eyes.y = -.05
	check(Photo.evaluate(e).rejected,"Face out of frame rejects")
	e = fixture()
	e.eyes = Vector2(.333,.25)
	check(near(Photo.evaluate(e).framing,1.0),"Thirds are measured on the face")
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
	# --- Panning (docs/futuro/11 §1): the camera's turn is part of the evidence ---
	var pan = fixture()
	pan.f = 50.0
	pan.d = 7.0
	pan.s = 7.0
	pan.v = 2.8
	pan.t = 1.0/30
	pan.motion_sign = 1.0
	pan.scene_ev = 14+Photo.ev(pan.n,pan.t,pan.iso,14)
	var still = Photo.evaluate(pan)
	check(not still.panning and still.movement < .05 and near(still.drag,2.8/30*50/7.0,.001),"A runner at 1/30 s with a still camera is dragged")
	pan.camera_omega = 0.0
	check(Photo.evaluate(pan) == still,"A camera that does not turn changes nothing")
	pan.camera_omega = 2.8/7.0
	var swept = Photo.evaluate(pan)
	check(swept.panning and near(swept.drag,0.0) and swept.movement == 1.0,"Following the runner at its angular speed keeps it sharp")
	check(near(swept.background,2.8/7.0/30*50,.001) and swept.background >= Photo.PAN_STREAK,"…and streaks the background (%.2f mm)" % swept.background)
	check(swept.score > still.score+15 and swept == Photo.evaluate(pan.duplicate(true)),"The pan scores, deterministically (%d against %d)" % [swept.score,still.score])
	check(swept.lines[2].contains("Barrido"),"The movement line names the pan")
	pan.camera_omega = -2.8/7.0
	check(not Photo.evaluate(pan).panning and Photo.evaluate(pan).drag > still.drag,"Turning the other way doubles the drag")
	pan.camera_omega = 2.8/7.0*.92
	check(Photo.evaluate(pan).panning and Photo.evaluate(pan).movement == 1.0,"8 % off the runner's speed is still a pan (nobody pans perfectly)")
	pan.camera_omega = 2.8/7.0*.5
	check(not Photo.evaluate(pan).panning,"Half the speed is not enough: the runner is still dragged")
	pan.v = 0.0
	pan.camera_omega = .4
	var jerked = Photo.evaluate(pan)
	check(not jerked.panning and jerked.movement < .05 and jerked.lines[2].contains("Moviste la cámara"),"Turning the camera on someone standing blurs the photo")
	pan.t = 1.0/1000
	check(Photo.evaluate(pan).movement == 1.0,"…unless the shutter is fast enough")
	print("TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
