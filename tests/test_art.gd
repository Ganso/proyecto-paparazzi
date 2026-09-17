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
	quit(0 if failed == 0 else 1)
