extends RefCounted
# Focal lengths are 35 mm equivalents, matching the simulator's reference sensor.
const CAMERAS = ["Compacta", "Telemétrica", "Réflex"]
const LENSES = [
	[{"name":"Zoom 24–120 · f/2.8–5.6", "min":24.0,"max":120.0,"wide":2.8,"long":5.6,"stop":8.0},
	 {"name":"Fijo 35 · f/2.8", "min":35.0,"max":35.0,"wide":2.8,"long":2.8,"stop":8.0}],
	[{"name":"Fijo 35 · f/2", "min":35.0,"max":35.0,"wide":2.0,"long":2.0,"stop":16.0},
	 {"name":"Fijo 50 · f/1.4", "min":50.0,"max":50.0,"wide":1.4,"long":1.4,"stop":16.0},
	 {"name":"Fijo 90 · f/2.8", "min":90.0,"max":90.0,"wide":2.8,"long":2.8,"stop":22.0}],
	[{"name":"Zoom 24–105 · f/4", "min":24.0,"max":105.0,"wide":4.0,"long":4.0,"stop":22.0},
	 {"name":"Zoom 70–200 · f/2.8", "min":70.0,"max":200.0,"wide":2.8,"long":2.8,"stop":22.0},
	 {"name":"Fijo 50 · f/1.8", "min":50.0,"max":50.0,"wide":1.8,"long":1.8,"stop":22.0}]
]
const STOPS = [1.4,1.8,2.0,2.8,4.0,5.6,8.0,11.0,16.0,22.0]
var film = false
var film_iso_index = 2 # ISO 400 loaded film; changed only in equipment selector.
var body = 0
var lens_index = 0
var focus_mode = "AF matricial"
var auto_exposure = true
func lens() -> Dictionary:
	return LENSES[body][lens_index]
func zoom() -> bool:
	return lens().min != lens().max
func focus_modes() -> Array:
	return ["MF"] if body == 1 else ["AF matricial", "AF puntual", "MF"]
func apertures(focal: float) -> Array:
	var l = lens()
	var minimum = lerpf(l.wide,l.long,inverse_lerp(l.min,l.max,focal)) if zoom() else float(l.wide)
	return STOPS.filter(func(n): return n >= minimum-.001 and n <= l.stop)
func preset(index: int) -> void:
	film = false
	body = index
	lens_index = 0
	focus_mode = ["AF matricial","MF","AF puntual"][index]
	auto_exposure = index == 0
