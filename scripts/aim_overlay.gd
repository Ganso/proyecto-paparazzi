extends Control
# Paparazzi's aim marks brought to the other modes (docs/futuro/29 §24): the brackets on whoever the
# camera is following while a turn key is held (with «Esperando / Siguiendo al sujeto»), and — with
# the extra aids of Options — the arrow towards the person asked for in the big park's arcade, once
# the search takes long. Drawn in main.ui's coordinates, clipped to the camera's image (view_rect).
const UiStyle = preload("res://scripts/ui_style.gd")
const FOLLOW = Color("9ad8ff")
const ARROW_AFTER = 20.0          # seconds without the person on screen before the arrow shows

var main
var lost_time = 0.0               # seconds searching without the person asked for on screen

func _init(owner_main) -> void:
	main = owner_main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20

func _process(dt: float) -> void:
	visible = main.mode == "SEARCH" and not main.paparazzi_active()
	if not visible: return
	if arrow_wanted() and not on_screen(main.target): lost_time += dt
	else: lost_time = 0.0
	queue_redraw()

# The arcade in the big park, a person asked for, and the option on.
func arrow_wanted() -> bool:
	return main.extra_aids and main.crowd != null and main.arcade_level >= 0 and not main.anyone_level() and is_instance_valid(main.target)

func arrow_on() -> bool:
	return arrow_wanted() and lost_time >= ARROW_AFTER

func on_screen(p) -> bool:
	var chest: Vector3 = p.control_points()[1]
	if main.camera.is_position_behind(chest): return false
	var at: Vector2 = main.camera.unproject_position(chest)/Vector2(main.viewport.size)
	return at.x > .02 and at.x < .98 and at.y > .02 and at.y < .98

func _draw() -> void:
	var clip: Rect2 = main.view_rect.grow(-8)
	var pulse = .55+.45*sin(Time.get_ticks_msec()/1000.0*TAU*1.2)
	if main.follow_state != "" and is_instance_valid(main.follow_subject) and main.eye_ready():
		var box: Rect2 = main.body_box(main.follow_subject).intersection(clip)
		var colour = FOLLOW
		# (fixed while waiting, pulsing while following, as the label)
		if main.follow_state == "siguiendo": colour.a = .55+.45*pulse
		if box.has_area(): brackets(box,colour)
	if arrow_on():
		var direction = arrow_direction()
		var tip = arrow(clip,direction,pulse)
		var metres = "%d m" % roundi(main.camera.global_position.distance_to(main.target.global_position))
		var font = UiStyle.font("Roboto-Medium")
		var at = tip-direction*58+Vector2(-40,6)
		draw_string(font,at+Vector2(1.5,1.5),metres,HORIZONTAL_ALIGNMENT_CENTER,80,15,Color(0,0,0,.7))
		draw_string(font,at,metres,HORIZONTAL_ALIGNMENT_CENTER,80,15,Color.WHITE)

# The four brackets of a box, corners of 18 px (as Paparazzi's).
func brackets(box: Rect2, colour: Color) -> void:
	var arm = minf(18.0,minf(box.size.x,box.size.y)*.4)
	for c in [box.position,Vector2(box.end.x,box.position.y),Vector2(box.position.x,box.end.y),box.end]:
		var sx = 1.0 if c.x <= box.get_center().x else -1.0
		var sy = 1.0 if c.y <= box.get_center().y else -1.0
		draw_polyline(PackedVector2Array([c+Vector2(0,arm*sy),c,c+Vector2(arm*sx,0)]),colour,3.0)

# The direction of the person from the middle of the image (y down); straight to a side if behind.
func arrow_direction() -> Vector2:
	var local: Vector3 = main.camera.global_transform.affine_inverse()*main.target.control_points()[1]
	if local.z > 0.0: return Vector2(1.0 if local.x >= 0.0 else -1.0,0.0)
	var d = Vector2(local.x,-local.y)
	return d.normalized() if d.length() > .001 else Vector2.RIGHT

# A triangle at the edge of the image pointing where the person is.
func arrow(clip: Rect2, direction: Vector2, pulse: float) -> Vector2:
	var half = clip.size*.5-Vector2(40,40)
	var t = minf(half.x/maxf(absf(direction.x),.001),half.y/maxf(absf(direction.y),.001))
	var tip = clip.get_center()+direction*t
	var back = tip-direction*28
	var side = Vector2(-direction.y,direction.x)*13
	draw_colored_polygon(PackedVector2Array([tip,back+side,back-side]),Color(UiStyle.SKY,.55+.45*pulse))
	return tip
