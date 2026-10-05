extends SceneTree
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
const Texts = preload("res://scripts/texts.gd")
var failed = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var casting = Cast.new()
	var maximum = 0
	var count = 0
	for profile in 4:
		for upper in casting.catalog.piezas.torso.size():
			for lower in casting.catalog.piezas.piernas.size():
				for hair in casting.catalog.piezas.cabeza.size():
					for accessory in casting.catalog.piezas.accesorio.size():
						var person = Person.new()
						root.add_child(person)
						var traits = casting.generate()
						traits.profile = profile
						traits.upper = upper
						traits.lower = lower
						traits.hair = hair
						traits.accessory = accessory
						traits["glasses"] = casting.catalog.piezas.gafas.size()-1   # (sunglasses: the heaviest pair)
						person.setup(traits,casting.catalog,100)
						maximum = maxi(maximum,person.triangle_count)
						if person.triangle_count > 2000 or person.rig.get_bone_count() != 20:
							failed += 1
							push_error("Geometry or skeleton budget exceeded")
						var arrays = person.mesh.surface_get_arrays(0)
						var weights = arrays[Mesh.ARRAY_WEIGHTS]
						for i in range(0,weights.size(),4):
							if weights[i] != 1 or weights[i+1] != 0 or weights[i+2] != 0 or weights[i+3] != 0: failed += 1
						if person.mesh.get_surface_count() != 1: failed += 1
						person.free()
						count += 1
	print("ART TESTS: %d assemblies, maximum %d triangles/person, %d failures" % [count,maximum,failed])
	garment_checks(casting)
	quit(0 if failed == 0 else 1)

var garment_count = 0
var garment_failed = 0
func check(ok: bool, message: String) -> void:
	garment_count += 1
	if not ok:
		failed += 1
		garment_failed += 1
		push_error(message)

func max_y(geometry: Array, bone: String) -> float:
	var top = -INF
	for shape in geometry:
		if shape.bone == bone and shape.type == "mesh":
			for v in shape.vertices: top = maxf(top,v[1])
	return top

# Cross-section radius of the bare (wood) meshes of a limb segment near its lower end, where
# it meets the next joint.
func max_radius(geometry: Array, bone: String, bare: bool) -> float:
	var lowest = 0.0
	for shape in geometry:
		if shape.bone == bone and shape.type == "mesh" and (shape.color == "piel") == bare:
			for v in shape.vertices: lowest = minf(lowest,v[1])
	var widest = 0.0
	for shape in geometry:
		if shape.bone == bone and shape.type == "mesh" and (shape.color == "piel") == bare:
			for v in shape.vertices:
				if v[1] <= lowest*.8: widest = maxf(widest,Vector2(v[0],v[2]).length())
		if shape.bone == bone and shape.type == "segment" and (shape.color == "piel") == bare:
			widest = maxf(widest,maxf(shape.radius_a,shape.radius_b))
	return widest

func max_x(geometry: Array, bone: String) -> float:
	var widest = 0.0
	for shape in geometry:
		if shape.bone == bone and shape.type == "mesh":
			for v in shape.vertices: widest = maxf(widest,absf(v[0]))
	return widest

# Half-width of the skirt body at the hip joint height (y = 0), interpolated between its rings.
func skirt_half_width(geometry: Array) -> float:
	var body = geometry.filter(func(s): return s.bone == "caderas" and s.type == "mesh")[1]
	var rings = {}
	for v in body.vertices:
		var y = snappedf(v[1],.000001)
		rings[y] = maxf(rings.get(y,0.0),absf(v[0]))
	var below = -INF
	var above = INF
	for y in rings:
		if y <= 0: below = maxf(below,y)
		else: above = minf(above,y)
	return lerpf(rings[below],rings[above],-below/(above-below))

# Regressions of the visible seams fixed in tools/build_catalog.py (see docs/PERSONAJES_Y_CINEMATICA.md).
func garment_checks(casting) -> void:
	for profile in casting.catalog.perfiles:
		for piece in profile.piezas:
			var geometry: Array = JSON.parse_string(FileAccess.get_file_as_string(piece.recurso)).geometry
			if piece.ranura == "piernas":
				var feet = geometry.filter(func(s): return s.bone.begins_with("pie."))
				check(not feet.is_empty(),"Legwear has feet: "+piece.recurso)
				for s in feet: check(s.color == ("acento" if piece.get("sport",false) else "calzado"),"Footwear uses its own colour zone: "+piece.recurso)
				# The first hip mesh is the seat; its lowest ring is raised at the leg openings.
				var seat = geometry.filter(func(s): return s.bone == "caderas" and s.type == "mesh")[0]
				var opening = -INF
				for i in 8: opening = maxf(opening,seat.vertices[i][1])
				var thigh = max_y(geometry,"muslo.I")
				if piece.style == "skirt":
					check(thigh <= .0001,"Thighs stay below a skirt waist: "+piece.recurso)
					check(skirt_half_width(geometry) >= profile.hombros*.22+max_x(geometry,"muslo.I"),"Skirt covers the thighs at the hip: "+piece.recurso)
				else: check(thigh >= opening,"Thigh fills the seat leg opening: "+piece.recurso)
			if piece.ranura == "cabeza" and piece.style == "cap":
				# The peak is the last head mesh; a ring reaching behind the forehead read as a halo.
				var peak = geometry.filter(func(s): return s.bone == "cabeza" and s.type == "mesh")[-1]
				var back = -INF
				for v in peak.vertices: back = maxf(back,v[2])
				check(back < 0,"Cap peak only projects forwards: "+piece.recurso)
			if piece.ranura == "torso":
				for side in ["I","D"]:
					var sleeve = 0.0
					for s in geometry:
						if s.bone == "brazo."+side and s.type == "mesh":
							for v in s.vertices: sleeve = maxf(sleeve,Vector2(v[0],v[2]).length())
					for s in geometry:
						if s.bone == "brazo."+side and s.type == "ellipsoid" and s.color != "piel": check(s.size[0]*.5 <= sleeve+.0001,"Shoulder cap no wider than its sleeve: "+piece.recurso)
	var colors: Array = casting.catalog.tonos_calzado.keys()
	for i in 200:
		var t = casting.generate()
		var shoe = Person.shoe_color(t,casting.catalog)
		check(shoe in colors and shoe == Person.shoe_color(t.duplicate(),casting.catalog),"Shoe colour is a deterministic palette entry")
		if casting.catalog.piezas.piernas[t.lower].get("style","") == "formal": check(shoe in ["negro","marrón"],"Dress trousers take dark shoes")
	# Wooden mannequin (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md, subphases 2.1 and 2.2).
	var mannequin = Person.new()
	root.add_child(mannequin)
	mannequin.setup({"profile":3,"upper":0,"lower":2,"hair":0,"skin":"oscura","hair_color":"moreno","upper_color":"rojo","lower_color":"vaquero","accessory":0,"accessory_color":"rojo","runner":false},casting.catalog,5)
	var material = mannequin.mesh.surface_get_material(0)
	# Realistic varnished wood and cloth, without ink outline (docs/futuro/17 fase 5, 30-09-2026).
	check(material is ShaderMaterial and material.shader.resource_path.ends_with("mannequin_pbr.gdshader"),"Mannequins use the realistic wood and cloth shader")
	check(material.next_pass == null,"No ink outline pass")
	var arrays_uv = mannequin.mesh.surface_get_arrays(0)
	check(arrays_uv[Mesh.ARRAY_TEX_UV] != null and arrays_uv[Mesh.ARRAY_TEX_UV2] != null,"Mannequins carry bone-space UVs for the procedural patterns")
	check(material == Person.mannequin_material(),"One shared mannequin material")
	var wood = Color(casting.catalog.tonos_madera[casting.catalog.madera_por_tono["oscura"]])
	var body_colours = mannequin.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var wood_found = false
	for c in body_colours:
		if absf(c.r/maxf(c.g,.001)-wood.r/wood.g) < .01 and absf(c.b/maxf(c.g,.001)-wood.b/wood.g) < .01: wood_found = true
		for tone in casting.catalog.tonos_piel.values():
			var skin = Color(tone)
			if absf(c.r/maxf(c.g,.001)-skin.r/skin.g) < .002 and absf(c.b/maxf(c.g,.001)-skin.b/skin.g) < .002: check(false,"No vertex keeps a skin tone")
	check(wood_found,"Bare body parts take the mapped wood finish")
	mannequin.free()
	for profile in casting.catalog.perfiles:
		for piece in profile.piezas:
			var geometry: Array = JSON.parse_string(FileAccess.get_file_as_string(piece.recurso)).geometry
			for shape in geometry:
				if shape.type == "mesh" and not shape.get("collision",true) and shape.normals.size() > 0 and shape.normals.count(shape.normals[0]) == shape.normals.size():
					check(not shape.get("outline",true),"Double-sided panels skip the outline: "+piece.recurso)
			# Bare joints are ball joints: a darker sphere wider than the limb it joins.
			var joints = {"antebrazo":"brazo","pierna":"muslo"}
			for bone in joints:
				for shape in geometry:
					if shape.bone == bone+".I" and shape.type == "ellipsoid" and shape.color == "piel":
						check(shape.get("darken",0) > 0 and shape.size[0]*.5 > max_radius(geometry,joints[bone]+".I",shape.color == "piel"),"Bare "+bone+" joint reads as a ball joint: "+piece.recurso)
	# Baked occlusion: bounded, leaves lit tops untouched and darkens undersides near the ground.
	var probe = Person.new()
	probe.height = 1.75
	check(is_equal_approx(probe.occlusion(Vector3(0,1.6,0),Vector3.UP),1.0),"Upward faces keep their zone colour")
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var shade = probe.occlusion(Vector3(rng.randf_range(-.3,.3),rng.randf_range(0,1.8),rng.randf_range(-.2,.2)),Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized())
		check(shade >= .6 - .0001 and shade <= 1.0,"Occlusion stays within 40 %")
	check(probe.occlusion(Vector3(.1,.05,0),Vector3.DOWN) < probe.occlusion(Vector3(.1,1.2,0),Vector3.DOWN),"Lower parts read darker than upper ones")
	probe.free()
	# Children wear children's clothes and do children's things (no blazer, dress trousers, brimmed
	# hat, newspaper, coffee or camera).
	var cast = Casting.new(4242)
	var children = 0
	var dressed_up = 0
	for i in 600:
		var t = cast.generate(i%7 == 0)
		if cast.catalog.perfiles[t.profile].id != "nino": continue
		children += 1
		if cast.catalog.piezas.torso[t.upper].get("solo_adultos",false) or cast.catalog.piezas.piernas[t.lower].get("solo_adultos",false) or cast.catalog.piezas.cabeza[t.hair].get("solo_adultos",false): dressed_up += 1
	check(children > 60 and dressed_up == 0,"No child wears adults-only pieces (%d of %d)" % [dressed_up,children])
	var kid = Person.new()
	var kid_traits = cast.generate()
	kid_traits.profile = 3
	kid.setup(kid_traits,cast.catalog,5)
	for pair in [["leer",""],["cafe",""],["foto","mirar"],["movil","movil"],["palomas","palomas"]]:
		kid.activity = pair[0]
		check(kid.activity == pair[1],"A child asked to «%s» does «%s»" % [pair[0],pair[1]])
	kid.free()
	# The wardrobe of 05-10-2026 (docs/PERSONAJES_Y_CINEMATICA.md §7): glasses in a slot of their
	# own, the rules of the trench coat, the backpack and the umbrella, and how they are described.
	var catalog: Dictionary = cast.catalog
	var styles = func(slot): return catalog.piezas[slot].map(func(p): return p.style)
	check("coat" in styles.call("torso") and "tank" in styles.call("torso"),"Trench coat and tank top are in the catalogue")
	for style in ["bun","curly","beret","cap_back"]: check(style in styles.call("cabeza"),"Head piece «%s» is in the catalogue" % style)
	check("backpack" in styles.call("accesorio") and "umbrella" in styles.call("accesorio"),"Backpack and umbrella are accessories")
	check(styles.call("gafas") == ["none","glasses","sunglasses"],"Glasses have their own slot: none, clear and dark")
	for profile in catalog.perfiles:
		for index in [1,2]:
			var path = "res://data/piezas/%s_gafas_%d.json" % [profile.id,index]
			var hd_path = path.replace("/piezas/","/piezas_hd/")
			check(FileAccess.file_exists(path) and FileAccess.file_exists(hd_path),"Glasses %d exist in both detail levels for «%s»" % [index,profile.id])
			var zones = JSON.parse_string(FileAccess.get_file_as_string(path)).geometry.map(func(s): return s.color)
			check(("cristal" in zones) == (index == 2),"Only sunglasses have dark lenses (%s)" % path)
	var seen = {"glasses_with_accessory":0,"glasses":0,"umbrella":0,"people":0}
	var wardrobe = Casting.new(777)
	for i in 900:
		var t = wardrobe.generate(i%9 == 0)
		var upper: Dictionary = catalog.piezas.torso[t.upper]
		var accessory: Dictionary = catalog.piezas.accesorio[t.accessory]
		seen.people += 1
		if t.glasses > 0: seen.glasses += 1
		if t.glasses > 0 and t.accessory > 0: seen.glasses_with_accessory += 1
		if accessory.style == "umbrella": seen.umbrella += 1
		if upper.style == "coat":
			check(catalog.piezas.piernas[t.lower].style != "skirt" and accessory.style != "bag" and catalog.perfiles[t.profile].id != "nino","A trench coat goes without skirt or shoulder bag, on adults")
		if t.runner: check(t.accessory == 0,"Runners carry no accessory")
		var text = wardrobe.accessory_description(t)
		if t.glasses > 0 and t.accessory > 0: check(text.contains(catalog.piezas.gafas[t.glasses].etiqueta+Texts.get_text("rasgo_y")),"Glasses and accessory are joined in the description («%s»)" % text)
	check(seen.glasses > seen.people/6 and seen.glasses < seen.people/2 and seen.glasses_with_accessory > 20,"About one in three wears glasses, with any accessory (%d of %d, %d with one)" % [seen.glasses,seen.people,seen.glasses_with_accessory])
	check(seen.umbrella > 0 and seen.umbrella < seen.people/8,"The umbrella is the rarest accessory (%d of %d)" % [seen.umbrella,seen.people])
	check(wardrobe.garment(catalog.piezas.cabeza[styles.call("cabeza").find("cap_back")],"rojo",catalog.tonos_ropa) == "gorra roja hacia atrás","The backwards cap puts its colour in the middle")
	for item in [["accesorio","backpack","never_sits"],["accesorio","umbrella","hand_busy"],["torso","coat","never_sits"]]:
		var who = Person.new()
		var t = wardrobe.generate()
		t.profile = 0
		t.lower = 0
		t.accessory = 0
		t[{"accesorio":"accessory","torso":"upper"}[item[0]]] = styles.call(item[0]).find(item[1])
		who.setup(t,catalog,9)
		check(who.get(item[2]),"«%s» sets %s" % [item[1],item[2]])
		if item[1] == "umbrella":
			who.activity = "movil"
			check(who.activity == "mirar","A hand holding the umbrella does not take the phone")
			var bare = Person.new()
			var plain = t.duplicate()
			plain.accessory = 0
			bare.setup(plain,catalog,9)
			check(who.colliders["mano.I"].get_child_count() == bare.colliders["mano.I"].get_child_count(),"The umbrella adds no collider to the hand (a photo's rays pass it)")
			bare.free()
		who.free()
	print("GARMENT CHECKS: %d checks, %d failures" % [garment_count,garment_failed])
