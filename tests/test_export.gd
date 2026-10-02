extends SceneTree
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var presets = ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK,"export_presets.cfg readable")
	check(presets.get_value("preset.0","name","") == "Android" and presets.get_value("preset.0","platform","") == "Android","Android preset")
	check(presets.get_value("preset.0","export_path","") == "build/paparazzi-debug.apk","Versioned APK path")
	var include: String = presets.get_value("preset.0","include_filter","")
	check("data/*.json" in include and "data/piezas/*.json" in include,"JSON data packed")
	# Blender props are read at run time with GLTFDocument (docs/futuro/17): the "lo" meshes serve
	# the mobile profiles. Ground textures are only used by Ultra, which Android never runs.
	check("assets/parque/*.glb" in include,"Blender park props packed")
	var exclude: String = presets.get_value("preset.0","exclude_filter","")
	for folder in ["build/*","docs/*","tests/*","tools/*","assets/texturas/*"]:
		check(folder in exclude,"Excluded " + folder)
	var options = "preset.0.options"
	check(presets.get_value(options,"package/unique_name","") == "org.ganso.proyectopaparazzi","Package id")
	check(presets.get_value(options,"package/signed",false),"Signed APK")
	check(not presets.get_value(options,"gradle_build/use_gradle_build",true),"Template export without Gradle")
	check(presets.get_value(options,"architectures/arm64-v8a",false),"arm64-v8a enabled")
	for arch in ["armeabi-v7a","x86","x86_64"]:
		check(not presets.get_value(options,"architectures/" + arch,true),"Only arm64: " + arch)
	check(presets.get_value(options,"permissions/vibrate",false),"Vibrate permission")
	for permission in ["camera","record_audio","access_fine_location","internet"]:
		check(not presets.get_value(options,"permissions/" + permission,true),"No intrusive permission: " + permission)
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE,"Sensor landscape")
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"),"ETC2/ASTC import")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility","Mobile renderer")
	var ignore = Array(FileAccess.get_file_as_string("res://.gitignore").split("\n")).map(func(line): return line.strip_edges())
	check("!build/paparazzi-debug.apk" in ignore and not "build/" in ignore,"APK versioned")
	# Branding (tools/build_branding.sh): the loading screen and the icon exist and are shipped raw.
	for key in ["application/boot_splash/image","application/config/icon"]:
		var path: String = ProjectSettings.get_setting(key,"")
		check(path.begins_with("res://assets/marca/") and FileAccess.file_exists(path),"%s points at a file of assets/marca" % key)
		check(FileAccess.get_file_as_string(path+".import").contains("importer=\"texture\""),"%s is a normal texture (the exporter adds it itself: with importer keep it went twice into the APK)" % key)
	print("EXPORT TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
