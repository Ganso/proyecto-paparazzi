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
const Photo = preload("res://scripts/photography.gd")
const Texts = preload("res://scripts/texts.gd")
const NOTICEABLE = .10
const GOLDEN = [.382,.618]

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
			"congelado":
				var drag: float = e.v*e.t*e.f/e.d
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
