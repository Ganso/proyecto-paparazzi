extends RefCounted
# Arcade mode (docs/futuro/21_ARCADE_CONDICIONES_TLR.md §1): twenty-five levels in five blocks, one
# assignment each. The level fixes scenario, light and equipment (the sandbox lets you choose), the
# shots, an optional time limit, the minimum score to pass and its conditions (scripts/conditions.gd).
# The curve goes from the automatic compact to the SLR, the manual rangefinder and the TLR, adding
# one manual control at a time (aperture priority A, shutter priority S, manual focus, all manual);
# shots drop from 5 to 1, the clock appears, the pass mark rises from 50 to 75 and, where focus and
# exposure are both manual, walkers go slower ("pace").
# Progress (best score and stars per level) lives in user://arcade.cfg.
#   body: 0 compacta, 1 telemétrica, 2 réflex, 3 TLR · lens: index in equipment.gd LENSES
#   auto: true (program), false (manual), "A" or "S" (priority) · pace: walkers' speed factor
#   limit: seconds (0 = none) · target: "runner" picks someone running
static var SAVE = "user://arcade.cfg"   # tests point it elsewhere
const BLOCKS = ["arcade_bloque_1","arcade_bloque_2","arcade_bloque_3","arcade_bloque_4","arcade_bloque_5"]
const LEVELS = [
	# Block 1 · first steps: automatic compact, classic park.
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":5,"limit":0,"min":50,"cond":{}},
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":5,"limit":0,"min":50,"cond":{"grande":.6}},
	{"scenario":"clasico","time":"golden","body":0,"lens":0,"auto":true,"shots":4,"limit":0,"min":55,"cond":{"aislado":true}},
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":4,"limit":90,"min":55,"cond":{}},
	{"scenario":"clasico","time":"golden","body":0,"lens":0,"auto":true,"shots":3,"limit":90,"min":60,"cond":{"aurea":true}},
	# Block 2 · the SLR: autofocus; one exposure control at a time (A, then S).
	{"scenario":"clasico","time":"day","body":2,"lens":1,"auto":true,"shots":4,"limit":120,"min":55,"cond":{"focal_min":135}},
	{"scenario":"clasico","time":"golden","body":2,"lens":4,"auto":"A","shots":4,"limit":120,"min":55,"cond":{"fondo":true}},
	{"scenario":"clasico","time":"day","body":2,"lens":2,"auto":true,"focus":"AF puntual","shots":3,"limit":90,"min":65,"cond":{"ojos":true,"grande":.5}},
	{"scenario":"clasico","time":"day","body":2,"lens":0,"auto":true,"shots":3,"limit":90,"min":65,"cond":{"acompanado":1}},
	{"scenario":"clasico","time":"day","body":2,"lens":1,"auto":"S","target":"runner","shots":3,"limit":120,"min":65,"cond":{"congelado":true}},
	# Block 3 · street: the rangefinder's manual focus first with automatic exposure, then A, then
	# everything manual; walkers slower so focus and exposure can be handled at once.
	{"scenario":"clasico","time":"day","body":1,"lens":0,"auto":true,"pace":.6,"shots":3,"limit":0,"min":65,"cond":{}},
	{"scenario":"grande","time":"golden","body":1,"lens":1,"auto":true,"pace":.7,"shots":3,"limit":150,"min":65,"cond":{"aislado":true}},
	{"scenario":"clasico","time":"blue","body":1,"lens":1,"auto":"A","pace":.6,"shots":3,"limit":120,"min":65,"cond":{"ojos":true}},
	{"scenario":"grande","time":"day","body":1,"lens":0,"auto":false,"pace":.6,"shots":3,"limit":150,"min":65,"cond":{"grande":.5}},
	{"scenario":"clasico","time":"night","body":1,"lens":1,"auto":false,"pace":.6,"shots":2,"limit":120,"min":70,"cond":{"aislado":true,"ojos":true}},
	# Block 4 · the TLR: waist level, mirrored ground glass, square frame, film, all manual.
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":1,"pace":.5,"shots":3,"limit":0,"min":70,"cond":{}},
	{"scenario":"clasico","time":"golden","body":3,"lens":0,"auto":false,"iso":2,"pace":.6,"shots":3,"limit":120,"min":70,"cond":{"aurea":true}},
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":1,"pace":.6,"shots":2,"limit":120,"min":70,"cond":{"ojos":true,"fondo":true,"grande":.5}},
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":3,"target":"runner","shots":2,"limit":90,"min":70,"cond":{"congelado":true}},
	{"scenario":"clasico","time":"blue","body":3,"lens":0,"auto":false,"iso":4,"pace":.6,"shots":1,"limit":60,"min":75,"cond":{"ojos":true,"aislado":true}},
	# Block 5 · mastery: back to the SLR with everything learned, and the pan ("barrido": follow a
	# runner with the camera at a slow shutter so the background streaks).
	{"scenario":"clasico","time":"day","body":2,"lens":0,"auto":"S","target":"runner","shots":4,"limit":150,"min":65,"cond":{"barrido":true}},
	{"scenario":"clasico","time":"golden","body":2,"lens":4,"auto":"A","shots":3,"limit":120,"min":70,"cond":{"fondo":true,"aurea":true}},
	{"scenario":"grande","time":"day","body":2,"lens":1,"auto":false,"pace":.7,"shots":3,"limit":150,"min":70,"cond":{"aislado":true,"grande":.6}},
	{"scenario":"clasico","time":"golden","body":2,"lens":0,"auto":false,"target":"runner","shots":3,"limit":150,"min":70,"cond":{"barrido":true,"grande":.45}},
	{"scenario":"clasico","time":"night","body":2,"lens":2,"auto":false,"focus":"AF puntual","pace":.6,"shots":2,"limit":90,"min":80,"cond":{"ojos":true,"aislado":true,"grande":.5}},
]

# Passing clouds darken the park only where reading the light is the job (user, 05-10-2026): the
# levels with manual exposure, by day or at golden hour. Everywhere else the light holds still.
# The level's briefing says so (arcade_aviso_nubes).
static func clouds(n: int) -> bool:
	if n < 0 or n >= LEVELS.size(): return false
	var level: Dictionary = LEVELS[n]
	return level.auto is bool and not level.auto and str(level.time) in ["day","golden"]

# Levels where the player sets the exposure by hand (their briefing advises the thirds of a stop).
static func manual_exposure(n: int) -> bool:
	if n < 0 or n >= LEVELS.size(): return false
	return LEVELS[n].auto is bool and not LEVELS[n].auto

static func block_of(n: int) -> int:
	return n/5

static func load_progress() -> Dictionary:
	var config = ConfigFile.new()
	var out = {}
	if config.load(SAVE) != OK: return out
	for n in LEVELS.size():
		if config.has_section_key("niveles",str(n)): out[n] = config.get_value("niveles",str(n))
	return out

# Keeps the best result of a passed level.
static func save_result(n: int, score: int, stars: int) -> void:
	var config = ConfigFile.new()
	config.load(SAVE)
	var previous = config.get_value("niveles",str(n),{"score":-1,"stars":0})
	if score > int(previous.score): config.set_value("niveles",str(n),{"score":score,"stars":stars})
	config.save(SAVE)

# Cheat for this run only (-- --cheat=niveles): every level open; nothing is written for it.
static var all_open = false
static func unlocked(n: int, progress: Dictionary) -> bool:
	return all_open or n == 0 or progress.has(n-1)

# Stars of a passed level: the pass mark gives one, then every quarter of the way to 100 another.
static func stars_for(score: int, minimum: int) -> int:
	if score < minimum: return 0
	return 1+mini(4,int(4.0*(score-minimum)/maxf(1.0,100.0-minimum)+.0001))
