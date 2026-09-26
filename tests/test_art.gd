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
				if piece.style == "skirt": check(thigh <= .0001,"Thighs stay below a skirt waist: "+piece.recurso)
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
	print("GARMENT CHECKS: %d checks, %d failures" % [garment_count,garment_failed])
