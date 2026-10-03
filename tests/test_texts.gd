extends SceneTree
# The texts are edited in textos/es/*.md and data/textos.es.json is generated from them by
# tools/textos.py (docs/futuro/25). Headless:
#   ~/bin/godot-4-fp --headless --path . --script tests/test_texts.gd
# Checks that the JSON is up to date with the Markdown and valid (controls, gaps, sizes), and that
# every text the code asks for by name exists.
const Texts = preload("res://scripts/texts.gd")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var output = []
	var code = OS.execute("python3",[ProjectSettings.globalize_path("res://tools/textos.py"),"--comprobar"],output,true)
	check(code == 0,"textos/es/*.md and data/textos.es.json agree and are valid: %s" % "\n".join(output))
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/textos.es.json"))
	check(entries.size() > 800,"The texts are there (%d)" % entries.size())
	var regex = RegEx.new()
	regex.compile("get_(?:text|rich)\\(\"([a-z_0-9]+)\"\\)")
	var missing = []
	var dir = DirAccess.open("res://scripts")
	for file in dir.get_files():
		if not file.ends_with(".gd"): continue
		for m in regex.search_all(FileAccess.get_file_as_string("res://scripts/"+file)):
			if not entries.has(m.get_string(1)) and not m.get_string(1) in missing: missing.append(m.get_string(1))
	check(missing.is_empty(),"Every text asked for by name exists (missing: %s)" % ", ".join(missing))
	check(Texts.get_text("academia_l1_titulo") != "academia_l1_titulo" and not Texts.get_text("entrar_fase").contains("{"),"Texts resolve, with their controls filled in")
	print("TEXT TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
