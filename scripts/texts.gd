extends RefCounted
# All interface copy lives outside gameplay code. Spanish is the fallback locale.
# A {control} placeholder (scripts/input_glyphs.gd) becomes the key or the gamepad button of the
# device in use, so no help text names a key the player does not have in hand.
static var entries: Dictionary = {}
static func get_text(key: String) -> String:
	if entries.is_empty():
		entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/textos.es.json"))
		var locale_path = "res://data/textos.%s.json" % OS.get_locale_language()
		if locale_path != "res://data/textos.es.json" and FileAccess.file_exists(locale_path):
			entries.merge(JSON.parse_string(FileAccess.get_file_as_string(locale_path)),true)
	return preload("res://scripts/input_glyphs.gd").plain(get_rich(key))

# The same with the keys and pad buttons marked, for scripts/glyph_label.gd.
static func get_rich(key: String) -> String:
	if entries.is_empty(): get_text("")
	var value = str(entries.get(key,key))
	return preload("res://scripts/input_glyphs.gd").fill(value) if "{" in value else value
