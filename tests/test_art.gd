extends SceneTree
const Person = preload("res://scripts/person.gd")
const Cast = preload("res://scripts/casting.gd")
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
						person.setup(traits,casting.catalog,100)
						maximum = maxi(maximum,person.triangle_count)
						if person.triangle_count > 1900 or person.rig.get_bone_count() != 20:
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
						if s.bone == "brazo."+side and s.type == "ellipsoid": check(s.size[0]*.5 <= sleeve+.0001,"Shoulder cap no wider than its sleeve: "+piece.recurso)
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
	check(material is ShaderMaterial and material.shader.resource_path.ends_with("cel_shading.gdshader"),"Mannequins use the toon shader")
	check(material.next_pass is ShaderMaterial and material.next_pass.shader.resource_path.ends_with("cel_outline.gdshader"),"Toon material carries the ink outline pass")
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
	print("GARMENT CHECKS: %d checks, %d failures" % [garment_count,garment_failed])
