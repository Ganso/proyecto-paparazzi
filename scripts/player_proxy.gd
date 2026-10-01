extends Node3D
# The photographer as the pedestrians see them (crowd_graph.gd, main.travel_clear()): someone
# standing or walking to avoid and keep clear of. Only position, state and velocity are read.
var state = "DETENIDO"
var actual_velocity = Vector3.ZERO
