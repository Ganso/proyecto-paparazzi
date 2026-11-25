extends "res://scripts/equipment.gd"
# The Paparazzi mode's ideal camera, for the technical probes (tools/paparazzi_sondas.gd,
# docs/futuro/29 §23): the compact with a 24–600 mm zoom and no lens character. Plugged into a
# running game as main.equipment, so update_camera() and the zoom clamps accept 600 mm without
# touching the game's code.
const IDEAL = {"name":"Ideal 24–600","ca":0.0,"min":24.0,"max":600.0,"wide":2.8,"long":2.8,"stop":22.0}

func lens() -> Dictionary:
	return IDEAL
