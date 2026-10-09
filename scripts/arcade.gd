extends RefCounted
# Arcade mode (docs/futuro/21_ARCADE_CONDICIONES_TLR.md §1): thirty levels in six blocks, one
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
static var SAVE = OS.get_environment("PAPARAZZI_ARCADE_CFG") if OS.has_environment("PAPARAZZI_ARCADE_CFG") else "user://arcade.cfg"   # tests and capture tools point it elsewhere
const BLOCKS = ["arcade_bloque_1","arcade_bloque_2","arcade_bloque_3","arcade_bloque_4","arcade_bloque_5","arcade_bloque_6"]
#   target: "runner" picks someone running, "activity" someone who sits down to do something,
#           "dog" the dog's owner · toward: "quiosco" or "sol", whoever gets there first
#   focus, metering: the focus mode and the metering, if not the body's own
const LEVELS = [
	# Block 1 · first steps: automatic compact, classic park.
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":5,"limit":0,"min":50,"cond":{}},
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":5,"limit":0,"min":50,"cond":{"grande":.6}},
	{"scenario":"clasico","time":"golden","body":0,"lens":0,"auto":true,"shots":4,"limit":0,"min":55,"cond":{"aislado":true}},
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":4,"limit":90,"min":55,"cond":{"acompanado":1}},
	{"scenario":"clasico","time":"golden","body":0,"lens":0,"auto":true,"shots":3,"limit":90,"min":60,"cond":{"aurea":true}},
	# Block 2 · the SLR: autofocus, the two ends of the zoom; one exposure control at a time (A, S).
	{"scenario":"clasico","time":"day","body":2,"lens":1,"auto":true,"shots":4,"limit":120,"min":55,"cond":{"focal_min":135}},
	{"scenario":"clasico","time":"day","body":2,"lens":0,"auto":true,"shots":4,"limit":120,"min":55,"cond":{"focal_max":35,"aire":true}},
	{"scenario":"clasico","time":"golden","body":2,"lens":4,"auto":"A","shots":4,"limit":120,"min":55,"cond":{"fondo":true}},
	{"scenario":"clasico","time":"day","body":2,"lens":2,"auto":true,"focus":"AF puntual","shots":3,"limit":90,"min":65,"cond":{"ojos":true,"grande":.5}},
	{"scenario":"clasico","time":"day","body":2,"lens":1,"auto":"S","target":"runner","shots":3,"limit":120,"min":65,"cond":{"congelado":true}},
	# Block 3 · street: the rangefinder's manual focus first with automatic exposure, then A (what
	# people do, everything sharp), then everything manual; walkers slower.
	{"scenario":"clasico","time":"day","body":1,"lens":0,"auto":true,"pace":.6,"shots":3,"limit":0,"min":65,"cond":{}},
	{"scenario":"grande","time":"golden","body":1,"lens":1,"auto":true,"pace":.7,"shots":3,"limit":150,"min":65,"cond":{"aislado":true}},
	{"scenario":"clasico","time":"day","body":1,"lens":1,"auto":"A","pace":.6,"target":"activity","shots":3,"limit":150,"min":65,"cond":{"actividad":true,"ojos":true}},
	{"scenario":"clasico","time":"day","body":1,"lens":0,"auto":"A","pace":.6,"toward":"quiosco","shots":3,"limit":180,"min":65,"cond":{"lugar":"quiosco","nitido":true}},
	{"scenario":"grande","time":"day","body":1,"lens":0,"auto":false,"pace":.6,"shots":3,"limit":150,"min":65,"cond":{"grande":.5}},
	# Block 4 · light: the blue hour, an exposure to the third of a stop, the sun behind the
	# subject both ways (the face, the silhouette) and the lamps at night.
	{"scenario":"clasico","time":"blue","body":1,"lens":1,"auto":"A","pace":.6,"shots":3,"limit":120,"min":65,"cond":{"ojos":true}},
	{"scenario":"clasico","time":"day","body":2,"lens":0,"auto":false,"pace":.7,"shots":3,"limit":120,"min":65,"cond":{"exposicion":true}},
	{"scenario":"clasico","time":"golden","body":2,"lens":0,"auto":"A","metering":"puntual","pace":.7,"toward":"sol","shots":3,"limit":180,"min":65,"cond":{"contraluz":true}},
	{"scenario":"clasico","time":"golden","body":2,"lens":0,"auto":false,"pace":.7,"toward":"sol","shots":3,"limit":180,"min":65,"cond":{"silueta":true}},
	{"scenario":"clasico","time":"night","body":1,"lens":1,"auto":false,"pace":.6,"shots":2,"limit":120,"min":70,"cond":{"aislado":true,"ojos":true}},
	# Block 5 · the TLR: waist level, mirrored ground glass, square frame, film, all manual.
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":1,"pace":.5,"shots":3,"limit":0,"min":70,"cond":{}},
	{"scenario":"clasico","time":"golden","body":3,"lens":0,"auto":false,"iso":2,"pace":.6,"shots":3,"limit":120,"min":70,"cond":{"aurea":true}},
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":1,"pace":.6,"shots":2,"limit":120,"min":70,"cond":{"ojos":true,"fondo":true,"grande":.5}},
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":3,"target":"runner","shots":2,"limit":90,"min":70,"cond":{"congelado":true}},
	{"scenario":"clasico","time":"blue","body":3,"lens":0,"auto":false,"iso":4,"pace":.6,"shots":1,"limit":60,"min":75,"cond":{"ojos":true,"aislado":true}},
	# Block 6 · mastery: back to the SLR with everything learned: the pan ("barrido"), the trail
	# ("estela"), the portrait, two subjects at once and the night.
	# (Slow shutters need little light: in full sun, at f/22 and ISO 100, anything slower than
	# 1/60 s burns the photo and there is nothing left to close. Hence the golden and the blue hour.)
	{"scenario":"clasico","time":"golden","body":2,"lens":0,"auto":"S","target":"runner","shots":4,"limit":150,"min":65,"cond":{"barrido":true}},
	{"scenario":"clasico","time":"blue","body":2,"lens":0,"auto":"S","target":"runner","shots":4,"limit":150,"min":65,"cond":{"estela":true}},
	{"scenario":"clasico","time":"golden","body":2,"lens":4,"auto":"A","shots":3,"limit":120,"min":70,"cond":{"fondo":true,"aurea":true}},
	{"scenario":"grande","time":"day","body":2,"lens":0,"auto":false,"pace":.7,"target":"dog","shots":3,"limit":180,"min":70,"cond":{"perro":true,"grande":.4}},
	{"scenario":"clasico","time":"night","body":2,"lens":2,"auto":false,"focus":"AF puntual","pace":.6,"shots":2,"limit":90,"min":80,"cond":{"ojos":true,"aislado":true,"grande":.5}},
]
# Until 0.3.4 there were 25 levels; where each one of those is now (the ones missing were dropped).
const FORMAT = 2
const FROM_25 = {0:0,1:1,2:2,3:3,4:4,5:5,6:7,7:8,9:9,10:10,11:11,12:15,13:14,14:19,15:20,16:21,17:22,18:23,19:24,20:25,21:27,24:29}

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
	if int(config.get_value("arcade","formato",1)) < FORMAT: migrate(config)
	for n in LEVELS.size():
		if config.has_section_key("niveles",str(n)): out[n] = config.get_value("niveles",str(n))
	return out

# A progress file of the 25 levels: each result moves to where its level is now.
static func migrate(config: ConfigFile) -> void:
	var moved = {}
	if config.has_section("niveles"):
		for key in config.get_section_keys("niveles"):
			if FROM_25.has(int(key)): moved[FROM_25[int(key)]] = config.get_value("niveles",key)
		config.erase_section("niveles")
	for n in moved: config.set_value("niveles",str(n),moved[n])
	config.set_value("arcade","formato",FORMAT)
	config.save(SAVE)

# Keeps the best result of a passed level.
static func save_result(n: int, score: int, stars: int) -> void:
	var config = ConfigFile.new()
	if config.load(SAVE) == OK and int(config.get_value("arcade","formato",1)) < FORMAT: migrate(config)
	config.set_value("arcade","formato",FORMAT)
	var previous = config.get_value("niveles",str(n),{"score":-1,"stars":0})
	if score > int(previous.score): config.set_value("niveles",str(n),{"score":score,"stars":stars})
	config.save(SAVE)

# Cheat for this run only (-- --cheat=niveles): every level open; nothing is written for it.
static var all_open = false
static func unlocked(n: int, progress: Dictionary) -> bool:
	return all_open or n == 0 or progress.has(n-1) or progress.has(n)   # (or passed before the levels were reordered)

# Stars of a passed level: the pass mark gives one, then every quarter of the way to 100 another.
static func stars_for(score: int, minimum: int) -> int:
	if score < minimum: return 0
	return 1+mini(4,int(4.0*(score-minimum)/maxf(1.0,100.0-minimum)+.0001))
