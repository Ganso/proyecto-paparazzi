extends RefCounted
# Mastery badges (docs/futuro/05 §3): permanent awards for photos that prove a skill. Each photo
# of a real assignment (arcade, tutorial, Academy; never the sandbox) is registered here; the
# counters and the badges earned live in user://insignias.cfg. The same sequence of photos always
# gives the same badges: everything is read from the photo's result and its evidence.
# One badge for each thing the game teaches, earned by taking the photo, and two for going all
# the way (user, 06-10-2026: ten badges, rethought from scratch):
#   halcon     5 photos with the subject's eyes razor sharp (CoC ≤ 0.020 mm), score ≥ 75
#   tercios    5 photos with the subject on a line of thirds and big enough (40 % of the height)
#   fotometro  5 photos in manual exposure within 0.3 EV, score ≥ 75
#   cremoso    5 photos with the subject sharp and the background clearly out of focus
#   detenido   3 runners frozen (no motion blur to speak of), without panning
#   velocidad  a pan: a runner sharp with the background streaked at least 40 px (of 1280)
#   noche      5 night photos exposed within 0.3 EV, score ≥ 75
#   decisiva   5 assignments solved with their first shot, score ≥ 85
#   graduado   the ten exams of the Academy (given by academy.gd)
#   calle      the 30 levels of the arcade passed (given by main.gd)
# Whoever had «halcon» from before (it then asked for the thirds too) keeps it.
const Photo = preload("res://scripts/photography.gd")
static var SAVE = OS.get_environment("PAPARAZZI_BADGES_CFG") if OS.has_environment("PAPARAZZI_BADGES_CFG") else "user://insignias.cfg"
const BADGES = ["halcon","tercios","fotometro","cremoso","detenido","velocidad","noche","decisiva","graduado","calle"]
const GOALS = {"halcon":5,"tercios":5,"fotometro":5,"cremoso":5,"detenido":3,"velocidad":1,"noche":5,"decisiva":5,"graduado":1,"calle":1}
const STREAK_PIXELS = 40.0

static func load_state() -> Dictionary:
	var state = {}
	for id in BADGES: state[id] = 0
	var config = ConfigFile.new()
	if config.load(SAVE) == OK:
		for id in BADGES: state[id] = int(config.get_value("insignias",id,0))
	return state

static func save_state(state: Dictionary) -> void:
	var config = ConfigFile.new()
	for id in BADGES: config.set_value("insignias",id,state[id])
	config.save(SAVE)

static func earned(id: String, state: Dictionary) -> bool:
	return state.get(id,0) >= GOALS[id]

# Which counters a photo advances. context: {"night": bool, "first_shot": bool, "manual": bool}.
static func credits(result: Dictionary, context: Dictionary) -> Array:
	var out = []
	if result.get("rejected",false): return out
	var e: Dictionary = result.evidence
	var good = result.score >= 75
	var eyes = Photo.coc(e.f,e.n,e.get("d_eyes",e.d),e.s)
	if eyes <= .020 and good: out.append("halcon")
	var on_thirds = e.has("chest") and minf(absf(e.chest.x-1.0/3.0),absf(e.chest.x-2.0/3.0)) < .05
	if on_thirds and absf(e.feet.y-e.head.y) >= .4 and good: out.append("tercios")
	if context.get("manual",false) and absf(result.delta) <= .3 and good: out.append("fotometro")
	if result.coc <= Photo.C and Photo.coc(e.f,e.n,e.d+10.0,e.s) >= BACKGROUND_BLUR and good: out.append("cremoso")
	var panning = result.get("panning",false)
	if e.v >= 1.5 and not panning and result.movement >= .95 and good: out.append("detenido")
	if panning and e.v >= 1.5 and result.get("background",0.0)/36.0*1280.0 >= STREAK_PIXELS: out.append("velocidad")
	if context.get("night",false) and absf(result.delta) <= .3 and good: out.append("noche")
	if context.get("first_shot",false) and result.score >= 85: out.append("decisiva")
	return out
const BACKGROUND_BLUR = .07      # mm on the sensor, ten metres behind the subject (as conditions.gd «fondo»)

# Registers a photo and returns the badges it has just earned.
static func register(result: Dictionary, context: Dictionary) -> Array:
	var state = load_state()
	var new_badges = []
	for id in credits(result,context):
		if earned(id,state): continue
		state[id] += 1
		if earned(id,state): new_badges.append(id)
	save_state(state)
	return new_badges

# A badge given from outside (the Academy diploma). Returns true if it is new.
static func grant(id: String) -> bool:
	var state = load_state()
	if earned(id,state): return false
	state[id] = GOALS[id]
	save_state(state)
	return true
