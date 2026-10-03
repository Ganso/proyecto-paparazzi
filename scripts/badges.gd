extends RefCounted
# Mastery badges (docs/futuro/05 §3): permanent awards for photos that prove a skill. Each photo
# of a real assignment (arcade, tutorial, Academy; never the sandbox) is registered here; the
# counters and the badges earned live in user://insignias.cfg. The same sequence of photos always
# gives the same badges: everything is read from the photo's result and its evidence.
#   halcon     5 photos with the subject razor sharp (CoC ≤ 0.020 mm) on a line of thirds, score ≥ 75
#   decisiva   5 assignments solved with their first shot, score ≥ 85
#   noche      5 night photos exposed within 0.3 EV, score ≥ 75
#   velocidad  a pan: a runner sharp with the background streaked at least 40 px (of 1280)
#   graduado   the ten exams of the Academy (given by academy.gd)
static var SAVE = OS.get_environment("PAPARAZZI_BADGES_CFG") if OS.has_environment("PAPARAZZI_BADGES_CFG") else "user://insignias.cfg"
const BADGES = ["halcon","decisiva","noche","velocidad","graduado"]
const GOALS = {"halcon":5,"decisiva":5,"noche":5,"velocidad":1,"graduado":1}
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

# Which counters a photo advances. context: {"night": bool, "first_shot": bool}.
static func credits(result: Dictionary, context: Dictionary) -> Array:
	var out = []
	if result.get("rejected",false): return out
	var e: Dictionary = result.evidence
	var on_thirds = e.has("chest") and minf(absf(e.chest.x-1.0/3.0),absf(e.chest.x-2.0/3.0)) < .05
	if result.coc <= .020 and on_thirds and result.score >= 75: out.append("halcon")
	if context.get("first_shot",false) and result.score >= 85: out.append("decisiva")
	if context.get("night",false) and absf(result.delta) <= .3 and result.score >= 75: out.append("noche")
	if result.get("panning",false) and e.v >= 1.5 and result.get("background",0.0)/36.0*1280.0 >= STREAK_PIXELS: out.append("velocidad")
	return out

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
