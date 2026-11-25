extends RefCounted
# Shot sizes (docs/futuro/29 §4): where the frame cuts a person tells the shot — wide, full, cowboy
# (americano), medium, close-up, extreme close-up (cara). Pure and static: the arcade conditions
# (conditions.gd «plano», «corte_limpio») and the Paparazzi mode use the same rules.
# Landmarks come from the 20-bone rig (validated against the real rig by tools/paparazzi_sondas.gd:
# standing, they match the rest heights below to the millimetre). On screen, y grows downwards and
# the frame is [0,1]×[0,1].
const ORDER = ["general","entero","americano","medio","primer_plano","cara"]   # wide → tight
const LANDMARKS = ["crown","eyes","chin","neck","shoulders","chest","waist","hips","knees","ankles","feet"]
const JOINTS = ["neck","waist","knees","ankles"]      # never cut there (§4.5)
const TOL = .01
const AIR = .08              # the auto-framing leaves the crown 8 % below the top edge
const FRAME_MM = 20.25       # frame height on the 36 mm reference sensor, 16:9
const CLEAN = .03            # how far (frame heights) the bottom edge keeps from a joint

# World positions of the landmarks of a person (a Pedestrian: rig, bones, height, nz, profile).
# «feet_i»/«feet_d» are both soles: on screen the lower one counts.
static func world_landmarks(p) -> Dictionary:
	var g: Transform3D = p.global_transform
	var rig: Skeleton3D = p.rig
	var head_h: float = p.height/float(p.profile.relacion_cabeza)
	var hp: Transform3D = rig.get_bone_global_pose(p.bones["cabeza"])
	var o = func(id: String) -> Vector3: return g*rig.get_bone_global_pose(p.bones[id]).origin
	var foot = func(side: String) -> Vector3: return g*(rig.get_bone_global_pose(p.bones["pie."+side])*Vector3(0,-p.nz*.03,0))
	return {"crown":g*(hp*Vector3(0,head_h,0)),"eyes":g*(hp*Vector3(0,.5*head_h,0)),"chin":g*hp.origin,
		"neck":o.call("cuello"),"shoulders":(o.call("clavicula.I")+o.call("clavicula.D"))*.5,"chest":o.call("torax"),
		"waist":o.call("lumbar"),"hips":o.call("caderas"),"knees":(o.call("pierna.I")+o.call("pierna.D"))*.5,
		"ankles":(o.call("pie.I")+o.call("pie.D"))*.5,"feet":(foot.call("I")+foot.call("D"))*.5,
		"feet_i":foot.call("I"),"feet_d":foot.call("D")}

# The same landmarks on the picture (fractions of the frame), and whether any is behind the camera.
static func project(world: Dictionary, camera: Camera3D, size: Vector2) -> Dictionary:
	var out = {"behind":false}
	for k in LANDMARKS:
		if camera.is_position_behind(world[k]): out.behind = true
		out[k] = camera.unproject_position(world[k])/size
	var a: Vector2 = camera.unproject_position(world.feet_i)/size
	var b: Vector2 = camera.unproject_position(world.feet_d)/size
	out.feet = a if a.y > b.y else b
	return out

# Heights above the ground of the landmarks of someone standing (metres).
static func rest_heights(p) -> Dictionary:
	return rest_for(float(p.height),float(p.nz))

static func rest_for(h: float, nz: float) -> Dictionary:
	return {"crown":h,"eyes":nz+.5*(h-nz),"chin":nz,"neck":.965*nz,"shoulders":.929*nz,"chest":.808*nz,"waist":.692*nz,"hips":.542*nz,"knees":.323*nz,"ankles":.03*nz,"feet":0.0}

# The shot a framing makes, and what is wrong with it (§4.3, §4.4).
static func classify(b: Dictionary) -> Dictionary:
	if b.get("behind",false) or b.eyes.x < .04 or b.eyes.x > .96 or b.eyes.y < 0 or b.eyes.y > 1: return {"plane":"","defects":["cara_fuera"]}
	if b.chin.y > 1: return {"plane":"","defects":["corte_cara"]}
	var defects = []
	var plane = ""
	var mid_shin = (b.knees.y+b.ankles.y)*.5
	var tall = b.feet.y-b.crown.y
	if b.feet.y <= 1+TOL: plane = "entero" if tall >= .45 else "general"
	elif mid_shin <= 1:
		plane = "entero"
		defects.append("pies")
	elif b.hips.y <= 1: plane = "americano"
	elif b.chest.y <= 1: plane = "medio"
	elif b.shoulders.y <= 1: plane = "primer_plano"
	else: plane = "cara"
	if plane != "cara" and b.crown.y < -TOL: defects.append("cabeza")
	if plane == "cara" and b.eyes.y < .10: defects.append("cabeza")
	if b.crown.y >= 0:
		if plane in ["medio","primer_plano","cara"] and b.crown.y > .25: defects.append("aire")
		if plane == "americano" and b.crown.y > .30: defects.append("aire")
	return {"plane":plane,"defects":defects}

# The bottom edge keeps away from the joints (neck, waist, knees, ankles). An extreme close-up
# always ends somewhere on the neck: there only the waist, knees and ankles count.
static func clean_cut(b: Dictionary, plane = "") -> bool:
	for j in JOINTS:
		if j == "neck" and plane == "cara": continue
		if absf(float(b[j].y)-1.0) < CLEAN: return false
	return true

static func wider(a: String, b: String) -> bool:
	return ORDER.find(a) < ORDER.find(b)

# Height (metres above the ground) where the auto-framing cuts each shot: inside its band and away
# from the joints (the middle of the medium shot's band is the waist itself, that of the extreme
# close-up the neck). Under the chin; across the chest; at the navel; mid-thigh.
static func cut_middle(plane: String, r: Dictionary) -> float:
	match plane:
		"cara": return (r.chin+r.neck)*.5
		"primer_plano": return (r.shoulders+r.chest)*.5
		"medio": return (r.chest+r.waist)*.5
		"americano": return (r.hips+r.knees)*.5
	return 0.0

# Focal length (35 mm equivalent) that makes a shot of someone at d metres, framed as the
# auto-framing does: full and wide shots with the body at 80 % / small, the rest with the crown at
# AIR and the bottom edge in the middle of its band.
static func focal_for(plane: String, r: Dictionary, d: float) -> float:
	match plane:
		"entero": return .80*FRAME_MM*d/r.crown
		"general": return .30*FRAME_MM*d/r.crown
	return FRAME_MM*d/((r.crown-cut_middle(plane,r))/(1.0-AIR))

# Whether a shot can be made of someone between d_near and d_far metres with a zoom f_min–f_max.
static func fits(plane: String, r: Dictionary, d_near: float, d_far: float, f_min: float, f_max: float) -> bool:
	match plane:
		"entero": return r.crown*f_min/(d_near*FRAME_MM) <= .92 and r.crown*f_max/(d_far*FRAME_MM) >= .50
		"general": return r.crown*f_min/(d_far*FRAME_MM) <= .40
	return focal_for(plane,r,d_far) <= f_max*.95 and focal_for(plane,r,d_near) >= f_min
