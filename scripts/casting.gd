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
		# Accessories and glasses by weight ("peso" in the catalogue): most people carry nothing in
		# particular, an umbrella on a clear day is the rarest thing, and one in three wears glasses.
		# Glasses have their own slot, so they go with any accessory.
		t["accessory"] = 0 if runner else weighted(catalog.piezas.accesorio)
		t["glasses"] = weighted(catalog.piezas.get("gafas",[{}]))
		t["accessory_color"] = catalog.tonos_ropa.keys()[rng.randi_range(0,9)]
		if runner:
			t.upper = catalog.piezas.torso.find(catalog.piezas.torso.filter(func(p): return p.get("sport",false))[0])
			var sports = catalog.piezas.piernas.filter(func(p): return p.get("sport",false))
			t.lower = catalog.piezas.piernas.find(sports[rng.randi_range(0,sports.size()-1)])
			t.hair = rng.randi_range(0,5)
		t["gender"] = "f" if catalog.piezas.piernas[t.lower].id == "falda" or rng.randf() < .5 else "m"
		# Children wear children's clothes: no blazer, dress trousers or brimmed hat (solo_adultos).
		if catalog.perfiles[t.profile].id == "nino" and (catalog.piezas.torso[t.upper].get("solo_adultos",false) or catalog.piezas.piernas[t.lower].get("solo_adultos",false) or catalog.piezas.cabeza[t.hair].get("solo_adultos",false)): continue
		# A trench coat goes over trousers: with a skirt, the skirt's flare would come through its tails.
		if catalog.piezas.torso[t.upper].get("sin_falda",false) and catalog.piezas.piernas[t.lower].get("style","") == "skirt": continue
		# …and the shoulder bag would hang inside it.
		if catalog.piezas.accesorio[t.accessory].style in catalog.piezas.torso[t.upper].get("sin_accesorios",[]): continue
		if catalog.piezas.cabeza[t.hair].style == "bald" and (catalog.perfiles[t.profile].id == "nino" or t.gender == "f"): continue
		var signature = "|".join(descriptors(t))
		if not used.has(signature):
			used[signature] = true
			return t
	return {}

# Whether someone dressed like this can sit down or use both hands (the extras of the meadow, who
# sit at the picnic tables and on the swings, are drawn again until they can).
func free_to_sit(t: Dictionary) -> bool:
	var accessory: Dictionary = catalog.piezas.accesorio[t.get("accessory",0)]
	return not (accessory.get("no_se_sienta",false) or accessory.get("mano_ocupada",false) or catalog.piezas.torso[t.upper].get("no_se_sienta",false))

# Index of a piece of the list, drawn by its "peso" (1 if it has none).
func weighted(pieces: Array) -> int:
	var total = 0.0
	for piece in pieces: total += float(piece.get("peso",1))
	var roll = rng.randf()*total
	for i in pieces.size():
		roll -= float(pieces[i].get("peso",1))
		if roll < 0: return i
	return pieces.size()-1

func garment(piece: Dictionary, color_name: String, palette: Dictionary) -> String:
	var idx = ["m","f","mp","fp"].find(piece.genero)
	# Keep the compound name intact and insert the adjective before its complement.
	if piece.id == Texts.get_text("pantalon_de_vestir"): return Texts.get_text("pantalon_s_de_vestir") % palette[color_name].formas[idx]
	# Pieces whose name goes on after the colour («gorra roja hacia atrás») bring their own pattern.
	if piece.has("etiqueta_color"): return str(piece.etiqueta_color) % palette[color_name].formas[idx]
	return piece.etiqueta+" "+palette[color_name].formas[idx]

func descriptors(t: Dictionary) -> PackedStringArray:
	var head: Dictionary = catalog.piezas.cabeza[t.hair]
	return PackedStringArray([
		garment(catalog.piezas.torso[t.upper],t.upper_color,catalog.tonos_ropa),
		garment(catalog.piezas.piernas[t.lower],t.lower_color,catalog.tonos_ropa),
		Texts.get_text("cabeza_calva") if head.style == "bald" else garment(head,t.lower_color if head.zona_color == "tela_b" else t.hair_color,catalog.tonos_ropa if head.zona_color == "tela_b" else catalog.tonos_pelo),
		profile_description(t)+accessory_description(t)+(Texts.get_text("rasgo_corriendo") if t.get("runner",false) else "")
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

# « · con gafas de sol y mochila roja»: the glasses (their own slot, no colour of their own: the
# frame is the same for everyone) and the accessory with its colour, whichever of the two there are.
func accessory_description(t: Dictionary) -> String:
	var worn: Array = []
	var glasses: int = t.get("glasses",0)
	if glasses > 0 and catalog.piezas.has("gafas"): worn.append(catalog.piezas.gafas[glasses].etiqueta)
	var index: int = t.get("accessory",0)
	if index > 0: worn.append(garment(catalog.piezas.accesorio[index],t.get("accessory_color","rojo"),catalog.tonos_ropa))
	if worn.is_empty(): return ""
	return Texts.get_text("rasgo_con")+Texts.get_text("rasgo_y").join(worn)
