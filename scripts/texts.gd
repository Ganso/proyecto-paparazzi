extends RefCounted
# All interface copy lives outside gameplay code. Spanish is the fallback locale.
static var entries: Dictionary = {}
static func get_text(key: String) -> String:
	if entries.is_empty():
		entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/textos.es.json"))
		var locale_path = "res://data/textos.%s.json" % OS.get_locale_language()
		if locale_path != "res://data/textos.es.json" and FileAccess.file_exists(locale_path):
			entries.merge(JSON.parse_string(FileAccess.get_file_as_string(locale_path)),true)
	return str(entries.get(key,key))
