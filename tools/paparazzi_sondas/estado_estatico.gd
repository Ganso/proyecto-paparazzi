extends RefCounted
# A static that must survive get_tree().reload_current_scene(), as the run of the Paparazzi mode
# will (docs/futuro/29 §14). The probe «recarga» writes it, reloads the scene and reads it back.
static var data = {}
