extends RefCounted
# Graphics settings (docs/futuro/23_GRAFICOS_PERSONALIZADOS.md). The four profiles (Bajo, Medio,
# Alto, Ultra) are tables of the same parameters, and "Personalizado" is a table the player edits
# by hand, kept in user://graficos.cfg. It can go beyond Ultra: supersampling, MSAA 8×, TAA, SMAA,
# more SDFGI cascades and rays, ultra soft shadows, bigger shadow maps…
# park.gd and main.gd read everything from settings(): no profile name decides an effect by itself.
#   scale          3D resolution as a fraction of the window (> 1 = supersampling)
#   upscaler       "fsr2", "fsr1" or "bilinear" (used when scale < 1)
#   msaa           0, 2, 4 or 8 · taa · screen_aa "no", "fxaa" or "smaa"
#   sdfgi          cascades (0 = off, flat calibrated ambient) · sdfgi_rays  −1 = project default
#   ssao           −1 off, else quality 0…4 · ssil, ssr, volumetric, glow
#   shadow_distance  0 = no sun shadows · shadow_atlas · shadow_filter (−1 default, 0 hard … 5 ultra)
#   penumbra       sun's angular size (soft contact-hardening shadows)
#   lamp_shadows   0 none, 1 the inner ones, 2 all · lamp_atlas
#   grass          fraction of the blades · dof  viewfinder depth of field · lens  vignette and CA
#   patterns       procedural wood and cloth on the mannequins
#   tonemap        "aces", "agx" or "filmic"
#   lod            mesh LOD threshold in pixels (0 = always full detail)
#   aniso          anisotropic filtering of the ground textures (0 off, 2, 4, 8 or 16 samples)
# (PAPARAZZI_GFX_CFG points tests and capture tools at another file, never the player's.)
static var SAVE = OS.get_environment("PAPARAZZI_GFX_CFG") if OS.has_environment("PAPARAZZI_GFX_CFG") else "user://graficos.cfg"
const CUSTOM = "Personalizado"
const PRESETS = {
	"Bajo": {"scale":.5,"upscaler":"fsr2","msaa":0,"taa":false,"screen_aa":"no","sdfgi":0,"sdfgi_rays":-1,"ssao":-1,"ssil":false,"ssr":false,"volumetric":false,"glow":true,
		"shadow_distance":0.0,"shadow_atlas":2048,"shadow_filter":-1,"penumbra":false,"lamp_shadows":0,"lamp_atlas":2048,"grass":.2,"dof":false,"lens":false,"patterns":false,"tonemap":"aces","aniso":2,"lod":1.0},
	"Medio": {"scale":.7,"upscaler":"fsr2","msaa":0,"taa":false,"screen_aa":"no","sdfgi":3,"sdfgi_rays":-1,"ssao":2,"ssil":false,"ssr":false,"volumetric":false,"glow":true,
		"shadow_distance":30.0,"shadow_atlas":2048,"shadow_filter":-1,"penumbra":false,"lamp_shadows":0,"lamp_atlas":2048,"grass":.45,"dof":false,"lens":true,"patterns":true,"tonemap":"aces","aniso":4,"lod":1.0},
	"Alto": {"scale":.85,"upscaler":"fsr2","msaa":0,"taa":false,"screen_aa":"no","sdfgi":4,"sdfgi_rays":-1,"ssao":2,"ssil":false,"ssr":false,"volumetric":true,"glow":true,
		"shadow_distance":38.0,"shadow_atlas":4096,"shadow_filter":-1,"penumbra":true,"lamp_shadows":1,"lamp_atlas":4096,"grass":.7,"dof":true,"lens":true,"patterns":true,"tonemap":"aces","aniso":8,"lod":1.0},
	"Ultra": {"scale":1.0,"upscaler":"fsr2","msaa":4,"taa":false,"screen_aa":"no","sdfgi":4,"sdfgi_rays":-1,"ssao":2,"ssil":true,"ssr":true,"volumetric":true,"glow":true,
		"shadow_distance":48.0,"shadow_atlas":4096,"shadow_filter":-1,"penumbra":true,"lamp_shadows":2,"lamp_atlas":4096,"grass":1.0,"dof":true,"lens":true,"patterns":true,"tonemap":"aces","aniso":16,"lod":1.0},
}
# The settings screen: [key, text key of its name, [[label, value], …], group text key].
# Labels starting with "@" are text keys (sí / no…); the rest are shown as they are.
const OPTIONS = [
	["scale","gfx_scale",[["50 %",.5],["60 %",.6],["70 %",.7],["85 %",.85],["100 %",1.0],["125 %",1.25],["150 %",1.5],["200 %",2.0]],"gfx_g_imagen"],
	["upscaler","gfx_upscaler",[["FSR 2","fsr2"],["FSR 1","fsr1"],["@gfx_bilineal","bilinear"]],"gfx_g_imagen"],
	["msaa","gfx_msaa",[["@gfx_no",0],["2×",2],["4×",4],["8×",8]],"gfx_g_imagen"],
	["taa","gfx_taa",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_imagen"],
	["screen_aa","gfx_screen_aa",[["@gfx_no","no"],["FXAA","fxaa"],["SMAA","smaa"]],"gfx_g_imagen"],
	["tonemap","gfx_tonemap",[["ACES","aces"],["AgX","agx"],["Filmic","filmic"]],"gfx_g_imagen"],
	["sdfgi","gfx_sdfgi",[["@gfx_no",0],["2",2],["3",3],["4",4],["6",6],["8",8]],"gfx_g_luz"],
	["sdfgi_rays","gfx_sdfgi_rays",[["@gfx_normal",-1],["16",2],["32",3],["64",4],["96",5],["128",6]],"gfx_g_luz"],
	["ssao","gfx_ssao",[["@gfx_no",-1],["@gfx_baja",1],["@gfx_media",2],["@gfx_alta",3],["Ultra",4]],"gfx_g_luz"],
	["ssil","gfx_ssil",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_luz"],
	["ssr","gfx_ssr",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_luz"],
	["volumetric","gfx_volumetric",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_luz"],
	["glow","gfx_glow",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_luz"],
	["shadow_distance","gfx_shadow_distance",[["@gfx_no",0.0],["30 m",30.0],["38 m",38.0],["48 m",48.0],["64 m",64.0],["80 m",80.0]],"gfx_g_sombras"],
	["shadow_atlas","gfx_shadow_atlas",[["2048",2048],["4096",4096],["8192",8192],["16384",16384]],"gfx_g_sombras"],
	["shadow_filter","gfx_shadow_filter",[["@gfx_normal",-1],["@gfx_duras",0],["@gfx_baja",2],["@gfx_media",3],["@gfx_alta",4],["Ultra",5]],"gfx_g_sombras"],
	["penumbra","gfx_penumbra",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_sombras"],
	["lamp_shadows","gfx_lamp_shadows",[["@gfx_ninguna",0],["@gfx_interiores",1],["@gfx_todas",2]],"gfx_g_sombras"],
	["lamp_atlas","gfx_lamp_atlas",[["2048",2048],["4096",4096],["8192",8192]],"gfx_g_sombras"],
	["grass","gfx_grass",[["0 %",0.0],["20 %",.2],["45 %",.45],["70 %",.7],["100 %",1.0]],"gfx_g_detalle"],
	["patterns","gfx_patterns",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_detalle"],
	["aniso","gfx_aniso",[["@gfx_no",0],["2×",2],["4×",4],["8×",8],["16×",16]],"gfx_g_detalle"],
	["lod","gfx_lod",[["@gfx_normal",1.0],["@gfx_maximo",0.0]],"gfx_g_detalle"],
	["dof","gfx_dof",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_camara"],
	["lens","gfx_lens",[["@gfx_no",false],["@gfx_si",true]],"gfx_g_camara"],
]
static var custom: Dictionary = {}

static func is_custom(preset: String) -> bool:
	return preset == CUSTOM

# The values of a profile (a copy). Unknown names fall back to Ultra.
static func settings(preset: String) -> Dictionary:
	if is_custom(preset):
		if custom.is_empty(): load_custom()
		return custom.duplicate()
	return PRESETS.get(preset,PRESETS["Ultra"]).duplicate()

# Personalizado starts as a copy of a profile and keeps whatever the player saved; keys added in
# later versions take Ultra's value.
static func load_custom(base = "Ultra") -> void:
	custom = PRESETS.get(base,PRESETS["Ultra"]).duplicate()
	var config = ConfigFile.new()
	if config.load(SAVE) != OK: return
	for key in custom:
		if config.has_section_key("personalizado",key): custom[key] = config.get_value("personalizado",key)

static func has_saved_custom() -> bool:
	var config = ConfigFile.new()
	return config.load(SAVE) == OK and config.has_section("personalizado")

static func save_custom() -> void:
	var config = ConfigFile.new()
	for key in custom: config.set_value("personalizado",key,custom[key])
	config.save(SAVE)

static func set_custom(key: String, value) -> void:
	if custom.is_empty(): load_custom()
	custom[key] = value
	save_custom()

static func copy_to_custom(preset: String) -> void:
	custom = PRESETS.get(preset,PRESETS["Ultra"]).duplicate()
	save_custom()

# Index of the current value among an option's choices (nearest for numbers).
static func choice_index(option: Array, value) -> int:
	var choices: Array = option[2]
	for i in choices.size():
		if typeof(choices[i][1]) == typeof(value) and choices[i][1] == value: return i
	if value is float or value is int:
		var best = 0
		for i in choices.size():
			if absf(float(choices[i][1])-float(value)) < absf(float(choices[best][1])-float(value)): best = i
		return best
	return 0

# ---- Display (any profile): window mode, window size and vertical sync ----
const WINDOW_MODES = [["@gfx_ventana","ventana"],["@gfx_sin_bordes","sin_bordes"],["@gfx_completa","completa"]]
# In a window the size is the window's; in full screen it is the resolution of the 3D image (the
# desktop's resolution is never changed: the image is scaled to fill the screen), or the screen's own.
const WINDOW_SIZES = [["@gfx_nativa","nativa"],["1280 × 720","1280x720"],["1600 × 900","1600x900"],["1920 × 1080","1920x1080"],["2560 × 1440","2560x1440"],["3840 × 2160","3840x2160"]]
static var display = {"mode":"ventana","size":"1440x810","vsync":true,"fps":false}

static func load_display() -> bool:
	var config = ConfigFile.new()
	if config.load(SAVE) != OK or not config.has_section("pantalla"): return false
	for key in display: display[key] = config.get_value("pantalla",key,display[key])
	return true

static func save_display() -> void:
	var config = ConfigFile.new()
	config.load(SAVE)
	for key in display: config.set_value("pantalla",key,display[key])
	config.save(SAVE)

# Windowed (with the chosen size, centred on its screen), a borderless window that fills the
# screen, or exclusive full screen. The 3D view follows the window's pixels by itself.
static func apply_display(window: Window) -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"): return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if display.vsync else DisplayServer.VSYNC_DISABLED)
	match display.mode:
		"completa": window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		"sin_bordes": window.mode = Window.MODE_FULLSCREEN
		_:
			window.mode = Window.MODE_WINDOWED
			if "--touch" in OS.get_cmdline_user_args() and "--resolution" in OS.get_cmdline_args(): return   # (a phone's shape, for the touch tests)
			var parts = str(display.size if display.size != "nativa" else "1440x810").split("x")
			var size = Vector2i(int(parts[0]),int(parts[1]))
			var screen = DisplayServer.screen_get_usable_rect(window.current_screen)
			size = Vector2i(mini(size.x,screen.size.x),mini(size.y,screen.size.y))
			window.size = size
			window.position = screen.position+(screen.size-size)/2

# Height in pixels the 3D image is limited to in full screen (0 = no limit, the screen's own).
static func fullscreen_height() -> int:
	if display.mode == "ventana" or display.size == "nativa": return 0
	return int(str(display.size).split("x")[1])
