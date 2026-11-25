extends SceneTree
# Shot sizes (scripts/framing.gd, docs/futuro/29 §4): classification, defects, clean cuts, focal
# lengths and which shots fit on each path of the classic park. Headless, deterministic.
#   ~/bin/godot-4-fp --path . --headless --script tests/test_framing.gd
const Framing = preload("res://scripts/framing.gd")
const LANE_LINES = [Vector2(1.33,2.12), Vector2(3.07,4.57), Vector2(6.38,7.62), Vector2(10.80,12.04)]   # main.gd
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

# An adult (estandar: 1.75 m, head ratio 7) standing, seen by a frame whose top edge is at `top`
# metres above the ground and `tall` metres high, the body centred at x.
func adult() -> Dictionary:
	return Framing.rest_for(1.75,1.75-1.75/7.0)

func body(r: Dictionary, top: float, tall: float, x = .5) -> Dictionary:
	var out = {"behind":false}
	for k in Framing.LANDMARKS: out[k] = Vector2(x,(top-r[k])/tall)
	return out

# The frame a shot gets with the auto-framing (crown at AIR, bottom edge mid-band).
func framed(r: Dictionary, plane: String) -> Dictionary:
	match plane:
		"entero":
			var tall = r.crown/.80
			return body(r,r.crown+(tall-r.crown)*.5,tall)
		"general":
			var tall = r.crown/.30
			return body(r,r.crown+(tall-r.crown)*.5,tall)
	var tall = (r.crown-Framing.cut_middle(plane,r))/(1.0-Framing.AIR)
	return body(r,r.crown+Framing.AIR*tall,tall)

func _initialize() -> void:
	var r = adult()
	# 1. Every shot, framed as the auto-framing does: that shot, no defects.
	for plane in Framing.ORDER:
		var got = Framing.classify(framed(r,plane))
		check(got.plane == plane and got.defects.is_empty(),"%s framed as such reads %s %s" % [plane,got.plane,str(got.defects)])
	# 2. The borders: the bottom edge just above / below each landmark changes the shot.
	var borders = [["shoulders","cara","primer_plano"],["chest","primer_plano","medio"],["hips","medio","americano"]]
	for b in borders:
		var above = Framing.classify(body(r,r.crown+.05,(r.crown+.05)-(r[b[0]]+.01)))
		var below = Framing.classify(body(r,r.crown+.05,(r.crown+.05)-(r[b[0]]-.01)))
		check(above.plane == b[1] and below.plane == b[2],"Cut just above / below %s: %s / %s (want %s / %s)" % [b[0],above.plane,below.plane,b[1],b[2]])
	# 3. Defects.
	var m = Framing.classify(body(r,r.crown-.08,1.0))
	check("cabeza" in m.defects,"Crown out of a medium shot: cabeza (%s)" % str(m.defects))
	var feet_cut = Framing.classify(body(r,r.crown+.05,(r.crown+.05)-.02))
	check(feet_cut.plane == "entero" and "pies" in feet_cut.defects,"Only the feet cut: full shot with pies (%s %s)" % [feet_cut.plane,str(feet_cut.defects)])
	var close_tall = (r.crown-Framing.cut_middle("primer_plano",r))/(1.0-.4)
	var airy = Framing.classify(body(r,r.crown+.4*close_tall,close_tall))
	check(airy.plane == "primer_plano" and "aire" in airy.defects,"Crown at 0.4 in a close-up: aire (%s %s)" % [airy.plane,str(airy.defects)])
	var mouth = Framing.classify(body(r,r.crown+.02,(r.crown+.02)-(r.chin+.03)))
	check(mouth.plane == "" and "corte_cara" in mouth.defects,"Bottom edge through the face: corte_cara (%s)" % str(mouth.defects))
	var aside = Framing.classify(body(r,r.crown+.1,1.0,1.1))
	check(aside.plane == "" and "cara_fuera" in aside.defects,"Eyes outside the frame: cara_fuera")
	var behind = framed(r,"medio")
	behind.behind = true
	check(Framing.classify(behind).plane == "","Behind the camera: no shot")
	var forehead = Framing.classify(body(r,r.eyes+.01,.18))
	check(forehead.plane == "cara" and "cabeza" in forehead.defects,"A face cut through the eyes: cabeza (%s %s)" % [forehead.plane,str(forehead.defects)])
	check(Framing.classify(framed(r,"cara")).defects.is_empty() and Framing.classify(body(r,r.eyes+.06,.25)).defects.is_empty(),"A face may cut the top of the head, not the eyes")
	# 4. Clean cuts.
	var at = func(height: float) -> Dictionary: return body(r,r.crown+.05,(r.crown+.05)-height)
	check(not Framing.clean_cut(at.call(r.knees)),"Cut at the knees: not clean")
	check(Framing.clean_cut(at.call((r.hips+r.knees)*.5)),"Cut mid-thigh: clean")
	check(not Framing.clean_cut(at.call(r.neck)),"Cut at the neck: not clean")
	check(not Framing.clean_cut(at.call(r.waist)),"Cut at the waist: not clean")
	check(Framing.clean_cut(framed(r,"entero")),"Whole body in: clean")
	for plane in Framing.ORDER:
		check(Framing.clean_cut(framed(r,plane),plane),"The auto-framing cuts %s clean" % plane)
	check(not Framing.clean_cut(at.call(r.neck),"primer_plano") and Framing.clean_cut(at.call(r.neck),"cara"),"The neck counts except in an extreme close-up")
	# 5. Focal lengths (measured on the real park by tools/paparazzi_sondas.gd: §4.6 of the plan).
	var face_76 = Framing.focal_for("cara",r,7.62)
	check(face_76 > 490 and face_76 < 530,"Extreme close-up of an adult at 7.62 m: %.0f mm (490–530: cut under the chin)" % face_76)
	check(Framing.focal_for("cara",r,12.04) > 600,"…at 12.04 m, beyond 600 mm")
	check(Framing.focal_for("medio",r,4.0) < Framing.focal_for("primer_plano",r,4.0) and Framing.focal_for("primer_plano",r,4.0) < Framing.focal_for("cara",r,4.0),"Tighter shots need longer lenses")
	# 6. Which shots fit on each path with the ideal 24–600 mm zoom (the table of §4.6).
	var table = {"general":[false,false,true,true],"entero":[false,true,true,true],"americano":[false,true,true,true],
		"medio":[true,true,true,true],"primer_plano":[true,true,true,true],"cara":[true,true,true,false]}
	for plane in table:
		for lane in 4:
			var ok = Framing.fits(plane,r,LANE_LINES[lane].x,LANE_LINES[lane].y,24.0,600.0)
			check(ok == table[plane][lane],"%s on path %d: %s (want %s)" % [plane,lane,str(ok),str(table[plane][lane])])
	var kid = Framing.rest_for(1.15,1.15-1.15/4.5)
	check(not Framing.fits("entero",kid,LANE_LINES[0].x,LANE_LINES[0].y,24.0,600.0) and Framing.fits("entero",kid,LANE_LINES[1].x,LANE_LINES[1].y,24.0,600.0),"A child: full shot from path 1 on")
	check(Framing.fits("cara",kid,LANE_LINES[2].x,LANE_LINES[2].y,24.0,600.0),"A child's face fits on path 2")
	# 7. Deterministic.
	var first = Framing.classify(framed(r,"americano"))
	var same = true
	for i in 100: same = same and Framing.classify(framed(r,"americano")) == first
	check(same,"Same framing, same verdict")
	# 8. Order.
	check(Framing.wider("entero","medio") and not Framing.wider("cara","primer_plano") and Framing.ORDER[0] == "general" and Framing.ORDER[-1] == "cara","Order from wide to tight")
	print("FRAMING TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
