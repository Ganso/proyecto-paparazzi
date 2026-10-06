class_name Photography
extends RefCounted
const Texts = preload("res://scripts/texts.gd")

const APERTURES = [2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
# The same scales in thirds of a stop, with the names cameras engrave (main.gd::fine_step()).
const THIRD_DENOMINATORS = [4000,3200,2500,2000,1600,1250,1000,800,640,500,400,320,250,200,160,125,100,80,60,50,40,30,25,20,15,13,10,8]
const THIRD_ISOS = [100,125,160,200,250,320,400,500,640,800,1000,1250,1600,2000,2500,3200]
# The two fastest are only on the SLR and the rangefinder (main.gd::fastest_index()): with a fast
# lens wide open in the sun, 1/1000 s burnt every photo.
const DENOMINATORS = [4000, 2000, 1000, 500, 250, 125, 60, 30, 15, 8]
const ISOS = [100, 200, 400, 800, 1600, 3200]
const C = 0.030
# Panning: the background has to streak at least this much on the sensor (mm; about 18 px of a
# 1280 px frame) behind a subject that really moves (m/s across the view).
const PAN_STREAK = .5
const TRAIL = .5                # mm of drag from which a moving subject reads as a trail
const PAN_SUBJECT_SPEED = .4
# A pan is never perfect: the subject may keep this much drag (mm) and still read as sharp. With
# 0.030 mm the turn had to match the runner within 1°/s; with 0.075 mm, within some 10 %.
const PAN_TOLERANCE = .075

static func ev(n: float, t: float, iso: float, scene_ev: float) -> float:
	return log(n*n/t)/log(2.0) - log(iso/100.0)/log(2.0) - scene_ev

static func coc(f: float, n: float, d: float, s: float) -> float:
	if is_inf(s): return f*f/(n*d*1000.0)
	return f*f*abs(d-s)/(n*d*(s*1000.0-f))

static func dof(f: float, n: float, s: float) -> Vector2:
	var h = f*f/(n*C)+f
	if is_inf(s): return Vector2(h/1000.0, INF)
	var mm = s*1000.0
	return Vector2(h*mm/(h+mm-f)/1000.0, INF if h <= mm-f else h*mm/(h-mm+f)/1000.0)

# Slowest standard shutter speed (denominator) that keeps a subject moving at v m/s across the
# view, at focal f mm and distance d m, within the circle of confusion; −1 if not even 1/1000 s.
static func needed_shutter(v: float, f: float, d: float) -> int:
	var best = -1
	for denom in DENOMINATORS:
		if v/denom*f/maxf(d, .1) <= C: best = denom
	return best

static func inside(p: Vector2) -> bool:
	return p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1

static func evaluate(e: Dictionary) -> Dictionary:
	# Focus is judged on the eyes when the evidence has them (docs/futuro/21 §2).
	var blur = coc(e.f, e.n, e.get("d_eyes", e.d), e.s)
	var delta = ev(e.n, e.t, e.iso, e.scene_ev)
	var ratio: float = e.t*e.f
	# Panning (docs/futuro/11 §1): the camera turning at camera_omega rad/s (+ to the right) sweeps
	# the scene across the sensor; what blurs the subject is its speed *relative* to that sweep.
	# Without camera_omega (a still camera) this is the subject's own speed, as always.
	var pan: float = e.get("camera_omega", 0.0)
	var direction: float = e.get("motion_sign", 1.0)
	if direction == 0.0: direction = 1.0
	var lateral: float = e.v*direction-pan*e.d
	var drag: float = absf(lateral)*e.t*e.f/e.d
	var background: float = absf(pan)*e.t*e.f
	var panning: bool = background >= PAN_STREAK and drag <= PAN_TOLERANCE and e.v >= PAN_SUBJECT_SPEED
	var focus = clampf((5*C-blur)/(4*C), 0, 1)
	var exposure = clampf(1-maxf(0, abs(delta)-0.5)/2.5, 0, 1)
	# A good pan is a deliberate slow shutter: the hand rule does not count against it.
	var shake = 1.0 if panning else clampf(1-(ratio-1)/2, 0, 1)
	var subject = 1.0 if panning else clampf((3*C-drag)/(2*C), 0, 1)
	# A trail asked for (conditions.gd «estela»): a runner dragged on purpose with the camera still
	# is what the photo is about, and the slow shutter is braced.
	var trail: bool = e.get("trail", false) and e.v >= PAN_SUBJECT_SPEED and drag >= TRAIL and background <= C
	if trail:
		shake = 1.0
		subject = 1.0
	var movement = minf(shake, subject)
	var occlusion = (5.0-e.blockers.size())/5.0
	var h: float = abs(e.feet.y-e.head.y)
	var size_score = 1.0
	if h < .45: size_score = clampf((h-.15)/.30, 0, 1)
	if h > .85: size_score = clampf((1.15-h)/.30, 0, 1)
	var crop = 1.0 if inside(e.head) and inside(e.feet) else .6
	var thirds = .15 if minf(abs(e.chest.x-.333), abs(e.chest.x-.667)) < .05 else 0.0
	var framing = clampf(size_score*crop+thirds, 0, 1)
	var rejected: bool = not e.in_front or not inside(e.chest) or e.blockers.size() >= 4
	var score = 0 if rejected else roundi(100*(.28*focus+.24*exposure+.18*movement+.15*occlusion+.15*framing))
	var stars = 0 if rejected else (5 if score >= 90 else 4 if score >= 75 else 3 if score >= 60 else 2 if score >= 40 else 1)
	var reward = roundi(150*[0, .15, .35, .60, .85, 1.0][stars])
	var reason = ""
	if not e.in_front or not inside(e.chest): reason = Texts.get_text("el_objetivo_esta_fuera_del_encuadre_su_pecho_debe_verse_dentro_d")
	elif e.blockers.size() >= 4: reason = Texts.get_text("el_objetivo_esta_tapado_en_d_de_los_5_puntos_de_control") % e.blockers.size()
	# Movement explained in shutter speeds, not millimetres: the slowest one that freezes the
	# subject at this focal length and distance, and the one the hand needs (1/focal).
	var subject_needed = needed_shutter(absf(lateral), e.f, e.d)
	var hand_needed = 1000
	for denom in DENOMINATORS:
		if 1.0/denom <= 1.0/e.f: hand_needed = denom
	var used = roundi(1.0/e.t)
	var movement_text = Texts.get_text("mov_ok") % [used, roundi(e.f)]
	if subject < 1:
		movement_text = Texts.get_text("mov_imposible") % roundi(e.f) if subject_needed < 0 else Texts.get_text("mov_sujeto") % [used, roundi(e.f), maxi(subject_needed, hand_needed)]
	elif shake < 1:
		movement_text = Texts.get_text("mov_pulso") % [used, roundi(e.f), hand_needed]
	if panning: movement_text = Texts.get_text("mov_barrido") % [used, background]
	elif trail: movement_text = Texts.get_text("mov_estela") % [used, drag]
	elif subject < 1 and background > C and e.v < PAN_SUBJECT_SPEED: movement_text = Texts.get_text("mov_camara") % used
	var lines = [
		Texts.get_text("enfoque_d_coc_3f_mm_nitido_0_030_foco_a_s_sujeto_a_2f_m_s") % [roundi(focus*100), blur, Texts.get_text("infinito") if is_inf(e.s) else Texts.get_text("2f_m") % e.s, e.get("d_eyes", e.d), Texts.get_text("vuelve_a_enfocar_sobre_el_sujeto") if focus < 1 else Texts.get_text("el_sujeto_esta_dentro_de_la_nitidez_aceptable")],
		Texts.get_text("exposicion_d_ev_2f_s_s") % [roundi(exposure*100), delta, Texts.get_text("subexpuesta") if delta > .5 else Texts.get_text("sobreexpuesta") if delta < -.5 else Texts.get_text("correcta"), Texts.get_text("abre_diafragma_sube_iso_o_alarga_el_tiempo") if delta > .5 else Texts.get_text("cierra_diafragma_baja_iso_o_acorta_el_tiempo") if delta < -.5 else Texts.get_text("dentro_de_la_tolerancia_de_medio_paso")],
		Texts.get_text("movimiento_d_pulso_tf_2f_arrastre_3f_mm_s") % [roundi(movement*100), movement_text],
		Texts.get_text("oclusion_d_d_5_puntos_libres_s") % [roundi(occlusion*100), 5-e.blockers.size(), Texts.get_text("obstaculos")+", ".join(e.blockers)+Texts.get_text("espera_a_que_despejen_la_vista") if not e.blockers.is_empty() else Texts.get_text("cabeza_pecho_cadera_y_ambas_rodillas_visibles")],
		Texts.get_text("encuadre_d_altura_0f_ideal_4585_s_s") % [roundi(framing*100), ("%.0f" % (h*100)) if h <= 1.5 else Texts.get_text("mas_de_150"), Texts.get_text("cabeza_o_pies_recortados") if crop < 1 else Texts.get_text("cuerpo_entero"), Texts.get_text("bonificacion_de_tercios") if thirds > 0 else Texts.get_text("situa_el_pecho_cerca_de_una_linea_de_tercios")]
	]
	return {"score":score, "stars":stars, "credits":reward, "rejected":rejected, "reason":reason, "focus":focus, "exposure":exposure, "movement":movement, "occlusion":occlusion, "framing":framing, "coc":blur, "delta":delta, "ratio":ratio, "drag":drag, "lines":lines, "panning":panning, "background":background, "drag_sign":signf(lateral)}
