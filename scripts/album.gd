extends RefCounted
# The photo album: the player's good photos, developed (exposure, blur, grain, the lens's own
# character) and kept as JPG files in user://album/, with their data in album.cfg. main.gd saves
# every accepted photo of an assignment that reaches MIN_SCORE; Options → Álbum shows them.
# Only the newest MAX are kept. Tests and capture tools point DIR elsewhere.
static var DIR = OS.get_environment("PAPARAZZI_ALBUM_DIR") if OS.has_environment("PAPARAZZI_ALBUM_DIR") else "user://album"
const MAX = 60
const MIN_SCORE = 80

static func index_path() -> String:
	return DIR+"/album.cfg"

# Newest first: [{"file", "score", "stars", "f", "n", "t", "iso", "date", "where", "panning"}].
static func list() -> Array:
	var config = ConfigFile.new()
	var out = []
	if config.load(index_path()) != OK: return out
	for section in config.get_sections():
		if not FileAccess.file_exists(DIR+"/"+section): continue
		var entry = {"file":section}
		for key in config.get_section_keys(section): entry[key] = config.get_value(section,key)
		out.append(entry)
	out.sort_custom(func(a,b): return int(a.get("order",0)) > int(b.get("order",0)))
	return out

# Saves a developed image with its data and returns the file name.
static func add(image: Image, meta: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var config = ConfigFile.new()
	config.load(index_path())
	var order = 1
	for section in config.get_sections(): order = maxi(order,int(config.get_value(section,"order",0))+1)
	var file = "foto_%05d.jpg" % order
	image.save_jpg(DIR+"/"+file,.92)
	for key in meta: config.set_value(file,key,meta[key])
	config.set_value(file,"order",order)
	config.save(index_path())
	prune()
	return file

static func remove(file: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR+"/"+file))
	var config = ConfigFile.new()
	if config.load(index_path()) != OK: return
	if config.has_section(file): config.erase_section(file)
	config.save(index_path())

static func prune() -> void:
	var all = list()
	for k in range(MAX,all.size()): remove(all[k].file)

static func load_image(file: String) -> Image:
	var image = Image.new()
	if image.load_jpg_from_buffer(FileAccess.get_file_as_bytes(DIR+"/"+file)) != OK: return null
	return image
