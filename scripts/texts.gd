extends RefCounted
# All interface copy lives outside gameplay code: textos/<idioma>/*.md → data/textos.<idioma>.json
# (tools/textos.py, docs/futuro/25). Spanish is the original and the fallback: whatever a language
# lacks shows in Spanish, so a half-done translation breaks nothing.
# A {control} placeholder (scripts/input_glyphs.gd) becomes the key or the gamepad button of the
# device in use, so no help text names a key the player does not have in hand.
#
# The language is the player's choice, kept in user://interfaz.cfg ("idioma"). The first launch
# asks for it (main_menu.gd::show_language_choice()); until then the system's language is used if
# the game has it, and English otherwise. -- --idioma=es|en overrides it without saving (tests,
# capture tools).
const LANGUAGES = ["es","en"]
const BASE = "es"
const SETTINGS = "user://interfaz.cfg"
static var entries: Dictionary = {}
static var language = ""
static var chosen_by_player = false

static func current() -> String:
	if language == "": load_language()
	return language

static func load_language() -> void:
	var config = ConfigFile.new()
	var saved = str(config.get_value("interfaz","idioma","")) if config.load(SETTINGS) == OK else ""
	chosen_by_player = saved in LANGUAGES
	language = saved if chosen_by_player else system_language()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--idioma=") and arg.trim_prefix("--idioma=") in LANGUAGES:
			language = arg.trim_prefix("--idioma=")
			chosen_by_player = true

# What the first launch proposes: the system's language if the game has it, else English.
static func system_language() -> String:
	var system = OS.get_locale_language()
	return system if system in LANGUAGES else "en"

# Whether the player has picked a language yet (the first launch asks).
static func chosen() -> bool:
	current()
	return chosen_by_player

# Switch and remember. The interface is built once, so the caller reloads the scene
# (main.gd::set_language()).
static func set_language(code: String, save = true) -> void:
	if not code in LANGUAGES: return
	language = code
	chosen_by_player = true
	entries = {}
	if not save: return
	var config = ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("interfaz","idioma",code)
	config.save(SETTINGS)

static func get_text(key: String) -> String:
	if entries.is_empty():
		entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/textos.%s.json" % BASE))
		var path = "res://data/textos.%s.json" % current()
		if current() != BASE and FileAccess.file_exists(path):
			entries.merge(JSON.parse_string(FileAccess.get_file_as_string(path)),true)
	return preload("res://scripts/input_glyphs.gd").plain(get_rich(key))

# The same with the keys and pad buttons marked, for scripts/glyph_label.gd.
static func get_rich(key: String) -> String:
	if entries.is_empty(): get_text("")
	var value = str(entries.get(key,key))
	return preload("res://scripts/input_glyphs.gd").fill(value) if "{" in value else value
