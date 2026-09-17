class_name Casting
extends RefCounted
const Texts = preload("res://scripts/texts.gd")
var catalog: Dictionary
var rng = RandomNumberGenerator.new()
var used = {}

func _init(seed_value = 6174) -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalogo.json"))
	rng.seed = seed_value

func generate(runner = false) -> Dictionary:
	while true:
		var t = {"profile":rng.randi_range(0,3), "upper":rng.randi_range(0,catalog.piezas.torso.size()-1), "lower":rng.randi_range(0,catalog.piezas.piernas.size()-1), "hair":rng.randi_range(0,catalog.piezas.cabeza.size()-1), "skin":catalog.tonos_piel.keys()[rng.randi_range(0,3)], "hair_color":catalog.tonos_pelo.keys()[rng.randi_range(0,4)], "upper_color":catalog.tonos_ropa.keys()[rng.randi_range(0,9)], "lower_color":catalog.tonos_ropa.keys()[rng.randi_range(0,9)]}
		t["runner"] = runner
		t["accessory"] = 0 if runner else rng.randi_range(0,catalog.piezas.accesorio.size()-1)
		t["accessory_color"] = catalog.tonos_ropa.keys()[rng.randi_range(0,9)]
		if runner:
			t.upper = catalog.piezas.torso.find(catalog.piezas.torso.filter(func(p): return p.get("sport",false))[0])
			var sports = catalog.piezas.piernas.filter(func(p): return p.get("sport",false))
			t.lower = catalog.piezas.piernas.find(sports[rng.randi_range(0,sports.size()-1)])
			t.hair = rng.randi_range(0,5)
		t["gender"] = "f" if catalog.piezas.piernas[t.lower].id == "falda" or rng.randf() < .5 else "m"
		if catalog.piezas.cabeza[t.hair].style == "bald" and (catalog.perfiles[t.profile].id == "nino" or t.gender == "f"): continue
		var signature = "|".join(descriptors(t))
		if not used.has(signature):
			used[signature] = true
			return t
	return {}

func garment(piece: Dictionary, color_name: String, palette: Dictionary) -> String:
	var idx = ["m","f","mp","fp"].find(piece.genero)
	# Keep the compound name intact and insert the adjective before its complement.
	if piece.id == Texts.get_text("pantalon_de_vestir"): return Texts.get_text("pantalon_s_de_vestir") % palette[color_name].formas[idx]
	return piece.etiqueta+" "+palette[color_name].formas[idx]

func descriptors(t: Dictionary) -> PackedStringArray:
	var head: Dictionary = catalog.piezas.cabeza[t.hair]
	return PackedStringArray([
		garment(catalog.piezas.torso[t.upper],t.upper_color,catalog.tonos_ropa),
		garment(catalog.piezas.piernas[t.lower],t.lower_color,catalog.tonos_ropa),
		Texts.get_text("cabeza_calva") if head.style == "bald" else garment(head,t.lower_color if head.style in ["cap","hat","beanie"] else t.hair_color,catalog.tonos_ropa if head.style in ["cap","hat","beanie"] else catalog.tonos_pelo),
		profile_description(t)+accessory_description(t)+( " · corriendo" if t.get("runner",false) else "")
	])

func predicates_for(target: Dictionary, all_traits: Array) -> PackedStringArray:
	var desc = descriptors(target)
	for count in [3,4]:
		var unique = true
		for other in all_traits:
			if other == target: continue
			var other_desc = descriptors(other)
			var matches = true
			for i in count:
				if other_desc[i] != desc[i]: matches = false
			if matches:
				unique = false
				break
		if unique: return desc.slice(0,count)
	return PackedStringArray()

func profile_description(t: Dictionary) -> String:
	var description: String = catalog.perfiles[t.profile].etiqueta
	if t.get("gender","m") == "f":
		description = description.replace("adulto","adulta").replace("delgado","delgada").replace("robusto","robusta").replace("niño","niña")
	return description

func accessory_description(t: Dictionary) -> String:
	var index: int = t.get("accessory",0)
	if index == 0: return ""
	return " · con "+garment(catalog.piezas.accesorio[index],t.get("accessory_color","rojo"),catalog.tonos_ropa)
