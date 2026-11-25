extends "res://scripts/equipment.gd"
# Paparazzi's ideal camera (docs/futuro/29 §1): the compact, automatic in everything, with a
# 24–600 mm zoom and no lens character (no vignetting, no colour fringes). It takes main.equipment's
# place while a run is on, so update_camera(), the wheel, the keys, the stick and the pinch accept
# 600 mm without asking; the player's own camera is kept aside and comes back when the run ends.
const IDEAL = {"name":"Ideal 24–600","ca":0.0,"min":24.0,"max":600.0,"wide":2.8,"long":2.8,"stop":22.0}

func lens() -> Dictionary:
	return IDEAL
