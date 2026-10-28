extends SceneTree
# The texts are edited in textos/<idioma>/*.md and data/textos.<idioma>.json is generated from them
# by tools/textos.py (docs/futuro/25). Headless:
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
	var py = "python" if OS.has_feature("windows") else "python3"
	var code = OS.execute(py,[ProjectSettings.globalize_path("res://tools/textos.py"),"--comprobar"],output,true)
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
	check(Texts.get_text("academia_exposicion_titulo") != "academia_exposicion_titulo" and not Texts.get_text("entrar_fase").contains("{"),"Texts resolve, with their controls filled in")
	# English (docs/futuro/25 §4): complete, the same keys as Spanish, and every control and every
	# name drawn in code has its English too.
	var english: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/textos.en.json"))
	var untranslated = entries.keys().filter(func(k): return not english.has(k))
	check(untranslated.is_empty(),"Every text is in English (missing: %s)" % ", ".join(untranslated.slice(0,10)))
	check(english.keys().all(func(k): return entries.has(k)),"English has no key that Spanish lacks")
	var Glyphs = preload("res://scripts/input_glyphs.gd")
	check(Glyphs.CONTROLS.keys() == Glyphs.CONTROLS_EN.keys() and Glyphs.TOUCH.keys() == Glyphs.TOUCH_EN.keys(),"Every control has its English names, keyboard, pads and touch")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalogo.json"))
	var unnamed = []
	for slot in catalog.piezas:
		for piece in catalog.piezas[slot]:
			if str(piece.get("en","")) == "": unnamed.append(piece.id)
	for palette in ["tonos_ropa","tonos_pelo"]:
		for colour in catalog[palette]:
			if str(catalog[palette][colour].get("en","")) == "": unnamed.append(colour)
	for profile in catalog.perfiles:
		if str(profile.get("en","")) == "": unnamed.append(profile.id)
	check(unnamed.is_empty(),"Every garment, colour and build has its English name (missing: %s)" % ", ".join(unnamed))
	# The language switches and comes back; the one on show is never saved by a test.
	var before = Texts.current()
	Texts.set_language("en",false)
	check(Texts.get_text("modo_entrar") == "Enter" and Texts.get_text("menu_album") == "Album","English loads over Spanish")
	var Casting = preload("res://scripts/casting.gd")
	var cast_en = Casting.new(6174)
	var people_en = []
	for i in 21: people_en.append(cast_en.generate())
	var described_en = cast_en.descriptors(people_en[3])
	Texts.set_language("es",false)
	check(Texts.get_text("modo_entrar") == "Entrar","Spanish comes back")
	var cast_es = Casting.new(6174)
	var people_es = []
	for i in 21: people_es.append(cast_es.generate())
	check(people_es == people_en,"The cast is the same in every language (who is told apart from whom is decided in Spanish)")
	check(cast_es.predicates_for(people_es[5],people_es).size() == cast_en.predicates_for(people_en[5],people_en).size(),"An assignment names as many traits in either language")
	check(not described_en[0].contains("camiseta") and not described_en[2].contains("pelo"),"Descriptions in English are English: %s" % ", ".join(described_en))
	Texts.set_language(before,false)
	print("TEXT TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
