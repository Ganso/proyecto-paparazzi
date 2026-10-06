extends RefCounted
# Level conditions of the arcade (docs/futuro/21_ARCADE_CONDICIONES_TLR.md §2). Each one is checked
# on the photo's evidence (main.gd::capture_evidence()), deterministically, and a failed condition
# rejects the photo with its reason. Keys of a level's "cond" dictionary:
#   ojos        the subject's face sharp (CoC at the face, halfway up the head, ≤ 0.030 mm); the
#               mannequins have no eyes, so every text says «cara»
#   aislado     nobody else noticeable in the frame (another person with chest inside, height ≥ 10 %)
#   acompanado  exactly N other noticeable people in the frame
#   grande      the subject fills at least that fraction of the frame height
#   focal_min   focal length at least that (35 mm equivalent)
#   aurea       the subject's chest on a golden-section line (x = 0.382 or 0.618, ± 0.045)
#   fondo       background blurred: a point 10 m behind the subject has a CoC ≥ 0.07 mm (more than
#               twice the sharpness limit)
#   congelado   the subject moves (≥ 1.5 m/s across the view) and its drag stays within the CoC
#   focal_max   focal length at most that (a wide angle, close)
#   aire        room ahead: the subject crosses the frame and has the wider side in front of it
#   exposicion  exposure within a quarter of a stop (thirds of a stop get there every time)
#   nitido      everything sharp: a point 10 m behind the subject within the sharpness limit
#   lugar       a landmark of the park (its key: "quiosco", "estanque") shows in the frame
#   actividad   the subject is doing something (seated or standing: reading, phone, coffee, crumbs)
#   perro       the subject's dog in the frame and sharp too
#   contraluz   the camera faces the sun behind a sunlit subject, and the face is well exposed:
#               two stops over what the meter says (prepare() moves the photo's target there)
#   silueta     the same light, exposed the other way: 0.7 to 2.7 stops under the meter
#   estela      a runner blurred on purpose with the camera still: drag ≥ 0.5 mm, sharp background
const Photo = preload("res://scripts/photography.gd")
const Texts = preload("res://scripts/texts.gd")
const NOTICEABLE = .10
const GOLDEN = [.382,.618]
const BACKLIGHT = .5          # cosine between the view and the sun, seen from above (within 60°)
const BACKLIT_FACE = 2.0      # stops a backlit face is under what the meter reads
const SILHOUETTE = 1.7        # stops under the meter that make a silhouette
const NAMES = {"quiosco":"lugar_quiosco","estanque":"lugar_estanque"}

static func backlit(e: Dictionary) -> bool:
	return float(e.get("backlight",0.0)) >= BACKLIGHT and bool(e.get("sunlit",false))

# What the level changes in how the photo itself is judged, before Photography.evaluate(): the
# exposure a backlit portrait or a silhouette aims at, and the trail of a runner as a virtue.
static func prepare(e: Dictionary, cond: Dictionary) -> void:
	if e.get("prepared",false): return
	e["prepared"] = true
	# (ev_shift: what the developed image adds back, so that it is still drawn as the scene was:
	# burnt behind a well exposed backlit face, dark around a silhouette)
	if cond.has("contraluz") and backlit(e):
		e["scene_ev"] = e.scene_ev-BACKLIT_FACE
		e["ev_shift"] = -BACKLIT_FACE
	if cond.has("silueta") and backlit(e):
		e["scene_ev"] = e.scene_ev+SILHOUETTE
		e["ev_shift"] = SILHOUETTE
	if cond.has("estela"): e["trail"] = true

# The whole verdict of a level's photo.
static func judge(e: Dictionary, cond: Dictionary) -> Dictionary:
	prepare(e,cond)
	var result = Photo.evaluate(e)
	apply(result,e,cond)
	return result

# How many other people count in the frame (see "aislado" and "acompanado").
static func companions(e: Dictionary) -> int:
	var count = 0
	for o in e.get("others",[]):
		if o.visible and o.h >= NOTICEABLE and Photo.inside(o.chest): count += 1
	return count

static func check(e: Dictionary, cond: Dictionary) -> Array:
	var out = []
	var h: float = absf(e.feet.y-e.head.y)
	for key in cond:
		var ok = false
		var text_value = ""
		match key:
			"ojos":
				var blur = Photo.coc(e.f,e.n,e.get("d_eyes",e.d),e.s)
				ok = blur <= Photo.C
				text_value = Texts.get_text("cond_ojos") % blur
			"aislado":
				var n = companions(e)
				ok = n == 0
				text_value = Texts.get_text("cond_aislado") % n
			"acompanado":
				var n = companions(e)
				ok = n == int(cond[key])
				text_value = Texts.get_text("cond_acompanado") % [int(cond[key]),n]
			"grande":
				ok = h >= float(cond[key])
				text_value = Texts.get_text("cond_grande") % [roundi(float(cond[key])*100),roundi(h*100)]
			"focal_min":
				ok = e.f >= float(cond[key])-.5
				text_value = Texts.get_text("cond_focal_min") % [float(cond[key]),e.f]
			"aurea":
				var gap = minf(absf(e.chest.x-GOLDEN[0]),absf(e.chest.x-GOLDEN[1]))
				ok = gap <= .045
				text_value = Texts.get_text("cond_aurea") % roundi(e.chest.x*100)
			"fondo":
				var blur = Photo.coc(e.f,e.n,e.d+10.0,e.s)
				ok = blur >= .07
				text_value = Texts.get_text("cond_fondo") % blur
			"focal_max":
				ok = e.f <= float(cond[key])+.5
				text_value = Texts.get_text("cond_focal_max") % [float(cond[key]),e.f]
			"aire":
				var side: float = e.get("motion_sign",0.0)
				var crossing: bool = e.v >= .25 and side != 0.0
				ok = crossing and ((side > 0 and e.chest.x <= .45) or (side < 0 and e.chest.x >= .55))
				text_value = Texts.get_text("cond_aire") % Texts.get_text("cond_aire_ok" if ok else ("cond_aire_falta" if crossing else "cond_aire_quieto"))
			"exposicion":
				var delta: float = Photo.ev(e.n,e.t,e.iso,e.scene_ev)
				ok = absf(delta) <= .25
				text_value = Texts.get_text("cond_exposicion") % delta
			"nitido":
				var blur = Photo.coc(e.f,e.n,e.d+10.0,e.s)
				ok = blur <= Photo.C
				text_value = Texts.get_text("cond_nitido") % blur
			"lugar":
				var place: Dictionary = e.get("places",{}).get(str(cond[key]),{})
				ok = not place.is_empty() and place.front and place.pos.x >= .04 and place.pos.x <= .96 and place.pos.y >= 0.0 and place.pos.y <= 1.0
				text_value = Texts.get_text("cond_lugar") % [Texts.get_text(NAMES.get(str(cond[key]),str(cond[key]))),Texts.get_text("cond_lugar_ok" if ok else "cond_lugar_fuera")]
			"actividad":
				ok = str(e.get("activity","")) != ""
				text_value = Texts.get_text("cond_actividad") % Texts.get_text("cond_actividad_ok" if ok else "cond_actividad_no")
			"perro":
				var dog: Dictionary = e.get("dog",{})
				var seen: bool = not dog.is_empty() and dog.front and Photo.inside(dog.pos)
				var dog_blur: float = Photo.coc(e.f,e.n,dog.d,e.s) if seen else 0.0
				ok = seen and dog_blur <= Photo.C*1.5
				text_value = Texts.get_text("cond_perro") % (Texts.get_text("cond_perro_fuera") if not seen else Texts.get_text("cond_perro_ok" if ok else "cond_perro_borroso") % dog_blur)
			"contraluz", "silueta":
				# (prepare() has already moved scene_ev to what this light asks for)
				var delta: float = Photo.ev(e.n,e.t,e.iso,e.scene_ev)
				var margin = .75 if key == "contraluz" else 1.0
				ok = backlit(e) and absf(delta) <= margin
				var why = "cond_luz_ok"
				if not backlit(e): why = "cond_luz_no"
				elif delta > margin: why = "cond_luz_oscura" if key == "contraluz" else "cond_silueta_negra"
				elif delta < -margin: why = "cond_luz_clara" if key == "contraluz" else "cond_silueta_clara"
				text_value = Texts.get_text("cond_"+key) % Texts.get_text(why)
			"estela":
				var side: float = e.get("motion_sign",1.0)
				if side == 0.0: side = 1.0
				var pan: float = e.get("camera_omega",0.0)
				var trail: float = absf(e.v*side-pan*e.d)*e.t*e.f/e.d
				var ground: float = absf(pan)*e.t*e.f
				ok = e.v >= 1.5 and trail >= Photo.TRAIL and ground <= Photo.C
				var why = Texts.get_text("cond_estela_ok") % [roundi(1.0/e.t),trail]
				if e.v < 1.5: why = Texts.get_text("cond_congelado_quieto")
				elif ground > Photo.C: why = Texts.get_text("cond_estela_camara")
				elif trail < Photo.TRAIL: why = Texts.get_text("cond_estela_corta") % [trail,roundi(1.0/e.t)]
				text_value = Texts.get_text("cond_estela") % why
			"barrido":
				# A pan (docs/futuro/11 §1): the camera follows a runner, who stays sharp while the
				# background streaks. Same thresholds as Photography.evaluate().
				var pan: float = e.get("camera_omega",0.0)
				var side: float = e.get("motion_sign",1.0)
				if side == 0.0: side = 1.0
				var pan_drag: float = absf(e.v*side-pan*e.d)*e.t*e.f/e.d
				var streak: float = absf(pan)*e.t*e.f
				ok = e.v >= 1.5 and streak >= Photo.PAN_STREAK and pan_drag <= Photo.PAN_TOLERANCE
				var pan_why = ""
				if e.v < 1.5: pan_why = Texts.get_text("cond_congelado_quieto")
				elif ok: pan_why = Texts.get_text("cond_barrido_ok") % [roundi(1.0/e.t),streak]
				elif pan_drag > Photo.PAN_TOLERANCE: pan_why = Texts.get_text("cond_barrido_movido")
				elif e.t >= 1.0/30-.0001: pan_why = Texts.get_text("cond_barrido_corto_focal") % [streak,roundi(1.0/e.t)]
				else: pan_why = Texts.get_text("cond_barrido_corto") % [streak,roundi(1.0/e.t)]
				text_value = Texts.get_text("cond_barrido") % pan_why
			"congelado":
				# Relative to the camera's own turn: a good pan freezes the runner too.
				var drag: float = absf(e.v*(1.0 if e.get("motion_sign",1.0) == 0.0 else e.get("motion_sign",1.0))-e.get("camera_omega",0.0)*e.d)*e.t*e.f/e.d
				ok = e.v >= 1.5 and drag <= Photo.C
				# Said as shutter speeds at the focal length used, not as millimetres of drag.
				var needed = Photo.needed_shutter(e.v,e.f,e.d)
				var why = ""
				if e.v < 1.5: why = Texts.get_text("cond_congelado_quieto")
				elif ok: why = Texts.get_text("cond_congelado_ok") % [roundi(e.f),roundi(1.0/e.t)]
				elif needed < 0: why = Texts.get_text("cond_congelado_imposible") % roundi(e.f)
				else: why = Texts.get_text("cond_congelado_lento") % [roundi(e.f),needed,roundi(1.0/e.t)]
				text_value = Texts.get_text("cond_congelado") % why
		out.append({"key":key,"ok":ok,"text":text_value})
	return out

# Short label of a condition for the briefing and the HUD list.
static func describe(key: String, value) -> String:
	match key:
		"acompanado": return Texts.get_text("cond_corta_acompanado") % int(value)
		"grande": return Texts.get_text("cond_corta_grande") % roundi(float(value)*100)
		"focal_min": return Texts.get_text("cond_corta_focal_min") % float(value)
		"focal_max": return Texts.get_text("cond_corta_focal_max") % float(value)
		"lugar": return Texts.get_text("cond_corta_lugar") % Texts.get_text(NAMES.get(str(value),str(value)))
	return Texts.get_text("cond_corta_"+key)

# Adds the condition results to an evaluated photo; any failure rejects it with its reason.
static func apply(result: Dictionary, e: Dictionary, cond: Dictionary) -> void:
	var checks = check(e,cond)
	result["conditions"] = checks
	for c in checks:
		if not c.ok and not result.rejected:
			result.rejected = true
			result.score = 0
			result.stars = 0
			result.credits = 0
			result.reason = Texts.get_text("cond_no_cumple") % c.text
