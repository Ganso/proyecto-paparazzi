extends RefCounted
# Arcade mode (docs/futuro/21_ARCADE_CONDICIONES_TLR.md §1): twenty levels in four blocks, one
# assignment each. The level fixes scenario, light and equipment (the sandbox lets you choose), the
# shots, an optional time limit, the minimum score to pass and its conditions (scripts/conditions.gd).
# The curve goes from the automatic compact to the SLR, the manual rangefinder and the TLR; shots
# drop from 5 to 1, the clock appears and tightens, and the pass mark rises from 50 to 80.
# Progress (best score and stars per level) lives in user://arcade.cfg.
#   body: 0 compacta, 1 telemétrica, 2 réflex, 3 TLR · lens: index in equipment.gd LENSES
#   limit: seconds (0 = none) · target: "runner" picks someone running
static var SAVE = "user://arcade.cfg"   # tests point it elsewhere
const BLOCKS = ["arcade_bloque_1","arcade_bloque_2","arcade_bloque_3","arcade_bloque_4"]
const LEVELS = [
	# Block 1 · first steps: automatic compact, classic park.
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":5,"limit":0,"min":50,"cond":{}},
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":5,"limit":0,"min":50,"cond":{"grande":.6}},
	{"scenario":"clasico","time":"golden","body":0,"lens":0,"auto":true,"shots":4,"limit":0,"min":55,"cond":{"aislado":true}},
	{"scenario":"clasico","time":"day","body":0,"lens":0,"auto":true,"shots":4,"limit":90,"min":55,"cond":{}},
	{"scenario":"clasico","time":"golden","body":0,"lens":0,"auto":true,"shots":3,"limit":90,"min":60,"cond":{"aurea":true}},
	# Block 2 · the SLR: autofocus, automatic exposure first, manual at the end.
	{"scenario":"clasico","time":"day","body":2,"lens":1,"auto":true,"shots":4,"limit":90,"min":60,"cond":{"focal_min":135}},
	{"scenario":"clasico","time":"golden","body":2,"lens":4,"auto":false,"shots":4,"limit":90,"min":60,"cond":{"fondo":true}},
	{"scenario":"clasico","time":"day","body":2,"lens":2,"auto":true,"focus":"AF puntual","shots":3,"limit":90,"min":65,"cond":{"ojos":true,"grande":.5}},
	{"scenario":"clasico","time":"day","body":2,"lens":0,"auto":true,"shots":3,"limit":75,"min":65,"cond":{"acompanado":1}},
	{"scenario":"clasico","time":"day","body":2,"lens":1,"auto":false,"target":"runner","shots":3,"limit":75,"min":65,"cond":{"congelado":true}},
	# Block 3 · street: manual rangefinder, both parks, light falling.
	{"scenario":"clasico","time":"day","body":1,"lens":0,"auto":false,"shots":3,"limit":90,"min":65,"cond":{}},
	{"scenario":"grande","time":"golden","body":1,"lens":1,"auto":false,"shots":3,"limit":120,"min":65,"cond":{"aislado":true}},
	{"scenario":"clasico","time":"blue","body":1,"lens":1,"auto":false,"shots":3,"limit":75,"min":70,"cond":{"ojos":true}},
	{"scenario":"grande","time":"day","body":1,"lens":0,"auto":false,"shots":2,"limit":90,"min":70,"cond":{"acompanado":2}},
	{"scenario":"clasico","time":"night","body":1,"lens":1,"auto":false,"shots":2,"limit":75,"min":70,"cond":{"aislado":true,"ojos":true}},
	# Block 4 · the TLR: waist level, mirrored ground glass, square frame, film.
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":1,"shots":3,"limit":90,"min":70,"cond":{}},
	{"scenario":"clasico","time":"golden","body":3,"lens":0,"auto":false,"iso":2,"shots":2,"limit":75,"min":75,"cond":{"aurea":true}},
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":1,"shots":2,"limit":60,"min":75,"cond":{"ojos":true,"fondo":true,"grande":.5}},
	{"scenario":"clasico","time":"day","body":3,"lens":0,"auto":false,"iso":3,"target":"runner","shots":2,"limit":60,"min":75,"cond":{"congelado":true}},
	{"scenario":"clasico","time":"blue","body":3,"lens":0,"auto":false,"iso":4,"shots":1,"limit":45,"min":80,"cond":{"ojos":true,"aislado":true}},
]

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

static func unlocked(n: int, progress: Dictionary) -> bool:
	return n == 0 or progress.has(n-1)

# Stars of a passed level: the pass mark gives one, then every quarter of the way to 100 another.
static func stars_for(score: int, minimum: int) -> int:
	if score < minimum: return 0
	return 1+mini(4,int(4.0*(score-minimum)/maxf(1.0,100.0-minimum)+.0001))
