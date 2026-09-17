class_name Photography
extends RefCounted
const Texts = preload("res://scripts/texts.gd")

const APERTURES = [2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
const DENOMINATORS = [1000, 500, 250, 125, 60, 30, 15, 8]
const ISOS = [100, 200, 400, 800, 1600, 3200]
const C = 0.030

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

static func inside(p: Vector2) -> bool:
	return p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1

static func evaluate(e: Dictionary) -> Dictionary:
	var blur = coc(e.f, e.n, e.d, e.s)
	var delta = ev(e.n, e.t, e.iso, e.scene_ev)
	var ratio: float = e.t*e.f
	var drag: float = e.v*e.t*e.f/e.d
	var focus = clampf((5*C-blur)/(4*C), 0, 1)
	var exposure = clampf(1-maxf(0, abs(delta)-0.5)/2.5, 0, 1)
	var shake = clampf(1-(ratio-1)/2, 0, 1)
	var subject = clampf((3*C-drag)/(2*C), 0, 1)
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
	var shutter_needed = 1000
	for denom in DENOMINATORS:
		if 1.0/denom <= 1.0/e.f and e.v/denom*e.f/e.d <= C: shutter_needed = denom
	var lines = [
		Texts.get_text("enfoque_d_coc_3f_mm_nitido_0_030_foco_a_s_sujeto_a_2f_m_s") % [roundi(focus*100), blur, Texts.get_text("infinito") if is_inf(e.s) else Texts.get_text("2f_m") % e.s, e.d, Texts.get_text("vuelve_a_enfocar_sobre_el_sujeto") if focus < 1 else Texts.get_text("el_sujeto_esta_dentro_de_la_nitidez_aceptable")],
		Texts.get_text("exposicion_d_ev_2f_s_s") % [roundi(exposure*100), delta, Texts.get_text("subexpuesta") if delta > .5 else Texts.get_text("sobreexpuesta") if delta < -.5 else Texts.get_text("correcta"), Texts.get_text("abre_diafragma_sube_iso_o_alarga_el_tiempo") if delta > .5 else Texts.get_text("cierra_diafragma_baja_iso_o_acorta_el_tiempo") if delta < -.5 else Texts.get_text("dentro_de_la_tolerancia_de_medio_paso")],
		Texts.get_text("movimiento_d_pulso_tf_2f_arrastre_3f_mm_s") % [roundi(movement*100), ratio, drag, Texts.get_text("usa_1_d_s_o_mas_rapido_para_congelar_este_movimiento") % shutter_needed if movement < 1 else Texts.get_text("velocidad_suficiente_para_pulso_y_sujeto")],
		Texts.get_text("oclusion_d_d_5_puntos_libres_s") % [roundi(occlusion*100), 5-e.blockers.size(), Texts.get_text("obstaculos")+", ".join(e.blockers)+Texts.get_text("espera_a_que_despejen_la_vista") if not e.blockers.is_empty() else Texts.get_text("cabeza_pecho_cadera_y_ambas_rodillas_visibles")],
		Texts.get_text("encuadre_d_altura_0f_ideal_4585_s_s") % [roundi(framing*100), h*100, Texts.get_text("cabeza_o_pies_recortados") if crop < 1 else Texts.get_text("cuerpo_entero"), Texts.get_text("bonificacion_de_tercios") if thirds > 0 else Texts.get_text("situa_el_pecho_cerca_de_una_linea_de_tercios")]
	]
	return {"score":score, "stars":stars, "credits":reward, "rejected":rejected, "reason":reason, "focus":focus, "exposure":exposure, "movement":movement, "occlusion":occlusion, "framing":framing, "coc":blur, "delta":delta, "ratio":ratio, "drag":drag, "lines":lines}
