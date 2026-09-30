extends Control
# Live diagrams of the Academy panel (docs/futuro/06): they read the camera state of main.gd every
# frame, so what the text explains moves as you turn the controls.
#   triangulo  the three exposure controls around the meter reading
#   pasos*     aperture, shutter and ISO scales (pasos_n / pasos_t / pasos_iso stress one row)
#   dof        top view: camera, focus distance and the sharp zone
#   movimiento the trail a runner leaves in the photo at the current shutter speed
#   tercios    frame with the thirds, crossings and lead room
#   compresion side view: what a 28 mm near and a 135 mm far see behind the subject
const Photo = preload("res://scripts/photography.gd")
var academy
var kind = "triangulo"
var font: Font
var ink = Color("c9d4bf")
var dim = Color("5d6b58")
var green = Color("b8d78c")
var amber = Color("f0c16a")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

func txt(pos: Vector2, s: String, size = 12, color = Color("c9d4bf"), align = HORIZONTAL_ALIGNMENT_LEFT, width = -1.0) -> void:
	draw_string(font,pos,s,align,width,size,color)

func _draw() -> void:
	if academy == null or academy.main == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,.25))
	match kind:
		"triangulo": draw_triangle()
		"pasos": draw_scales("")
		"pasos_n": draw_scales("n")
		"pasos_t": draw_scales("t")
		"pasos_iso": draw_scales("iso")
		"dof": draw_dof()
		"movimiento": draw_motion()
		"tercios": draw_thirds()
		"compresion": draw_compression()

func needle_color(delta: float) -> Color:
	return green if absf(delta) <= .34 else amber

func draw_triangle() -> void:
	var m = academy.main
	var c = Vector2(size.x*.5,size.y*.55)
	var pts = [c+Vector2(0,-44),c+Vector2(-70,36),c+Vector2(70,36)]
	draw_polyline(PackedVector2Array(pts+[pts[0]]),dim,2)
	var labels = ["f/%s" % str(m.apertures()[m.n_index]),"1/%d s" % Photo.DENOMINATORS[m.t_index],"ISO %d" % Photo.ISOS[m.iso_index]]
	var names = ["Diafragma","Velocidad","ISO"]
	for i in 3:
		draw_circle(pts[i],6,green)
		var off = Vector2(14,-10) if i == 0 else (Vector2(-72,6) if i == 1 else Vector2(10,6))
		txt(pts[i]+off,names[i],11,dim)
		txt(pts[i]+off+Vector2(0,14),labels[i],13,ink)
	var delta = m.finder.delta_ev
	txt(c+Vector2(-30,14),"%+.1f EV" % delta,16,needle_color(delta))

func draw_scales(stress: String) -> void:
	var m = academy.main
	var rows = [["n","Diafragma",m.apertures().map(func(n): return "f/%s" % str(n)),m.n_index,"más luz ◀"],
		["t","Velocidad",Array(Photo.DENOMINATORS).map(func(d): return "1/%d" % d),m.t_index,"menos luz ◀"],
		["iso","ISO",Array(Photo.ISOS).map(func(i): return str(i)),m.iso_index,"menos luz ◀"]]
	for r in rows.size():
		var row: Array = rows[r]
		var y = 20+r*36
		var strong = stress == "" or stress == row[0]
		txt(Vector2(6,y+4),row[1],11,ink if strong else dim)
		var items: Array = row[2]
		var x0 = 76.0
		var step = (size.x-x0-8)/maxf(1,items.size()-1)
		draw_line(Vector2(x0,y),Vector2(x0+step*(items.size()-1),y),dim,1)
		for i in items.size():
			var x = x0+i*step
			var current = i == row[3]
			draw_circle(Vector2(x,y),4.5 if current else 2.5,(green if strong else ink) if current else dim)
			if current or items.size() <= 7 or i%2 == 0:
				txt(Vector2(x-14,y+15),items[i],10 if not current else 11,(green if current else dim) if strong else dim)
	var delta = m.finder.delta_ev
	txt(Vector2(6,size.y-6),"Aguja: %+.1f EV · cada punto es un paso (el doble o la mitad de luz)" % delta,10,needle_color(delta))

func draw_dof() -> void:
	var m = academy.main
	var n = m.apertures()[m.n_index]
	var s = m.focus_distance
	var range = Photo.dof(m.focal,n,s if not is_inf(s) else 1000.0)
	var max_d = 16.0
	var x0 = 26.0
	var w = size.x-x0-12
	var y = size.y*.5
	var to_x = func(d: float) -> float: return x0+w*clampf(d/max_d,0,1)
	# Lanes of the park for reference.
	for lane in [1.8,4.0,7.0,11.5]:
		var lx = to_x.call(lane)
		draw_line(Vector2(lx,y-26),Vector2(lx,y+26),Color(1,1,1,.07),6)
	var near_x = to_x.call(range.x)
	var far_x = to_x.call(range.y if not is_inf(range.y) else max_d)
	draw_rect(Rect2(near_x,y-18,maxf(2,far_x-near_x),36),Color(.72,.84,.55,.35))
	draw_line(Vector2(x0,y),Vector2(x0+w,y),dim,1)
	# Camera.
	draw_colored_polygon(PackedVector2Array([Vector2(8,y-9),Vector2(24,y-9),Vector2(24,y+9),Vector2(8,y+9)]),ink)
	draw_colored_polygon(PackedVector2Array([Vector2(24,y-5),Vector2(30,y-7),Vector2(30,y+7),Vector2(24,y+5)]),ink)
	if not is_inf(s):
		var fx = to_x.call(s)
		draw_line(Vector2(fx,y-24),Vector2(fx,y+24),green,2)
		txt(Vector2(fx-18,y-28),"%.1f m" % s,11,green)
	for d in [0,4,8,12,16]:
		txt(Vector2(to_x.call(d)-4,size.y-6),str(d),9,dim)
	var depth = (range.y-range.x) if not is_inf(range.y) else INF
	txt(Vector2(8,16),"f/%s · %.0f mm · zona nítida: %s" % [str(n),m.focal,"hasta el infinito" if is_inf(depth) else "%.2f m" % depth],11,ink)

func draw_motion() -> void:
	var m = academy.main
	var t = 1.0/Photo.DENOMINATORS[m.t_index]
	var v = 2.8
	var d = 7.0
	var trail_mm = v*t*m.focal/d
	var limit = Photo.C
	var y = size.y*.55
	txt(Vector2(8,16),"Corredor a %.1f m/s, a %.0f m · 1/%d s" % [v,d,Photo.DENOMINATORS[m.t_index]],11,ink)
	# The runner moving during the exposure: ghosts spread over the trail.
	var trail_px = clampf(trail_mm/0.6*60.0,2,size.x-60)
	var x0 = 40.0
	var ghosts = 6
	for k in ghosts:
		var x = x0+trail_px*k/float(ghosts-1)
		var a = .2+.8*float(k)/ghosts
		draw_circle(Vector2(x,y-26),6,Color(ink.r,ink.g,ink.b,a))
		draw_line(Vector2(x,y-20),Vector2(x,y+4),Color(ink.r,ink.g,ink.b,a),3)
		draw_line(Vector2(x,y+4),Vector2(x-7,y+20),Color(ink.r,ink.g,ink.b,a),3)
		draw_line(Vector2(x,y+4),Vector2(x+7,y+20),Color(ink.r,ink.g,ink.b,a),3)
	var frozen = trail_mm <= limit*4
	txt(Vector2(8,size.y-22),"Rastro en la foto: %.3f mm" % trail_mm,12,green if frozen else amber)
	txt(Vector2(8,size.y-7),"Congelado si no pasa de ~0,1 mm · regla del pulso: 1/%d o más rápida" % roundi(maxf(m.focal,1)),10,dim)

func draw_thirds() -> void:
	var m = academy.main
	var frame = Rect2(40,12,size.x-80,(size.x-80)*9.0/16.0)
	if frame.size.y > size.y-20:
		frame.size.y = size.y-20
		frame.size.x = frame.size.y*16.0/9.0
		frame.position.x = (size.x-frame.size.x)*.5
	draw_rect(frame,dim,false,1)
	for k in [1,2]:
		draw_line(Vector2(frame.position.x+frame.size.x*k/3,frame.position.y),Vector2(frame.position.x+frame.size.x*k/3,frame.end.y),Color(1,1,1,.25),1)
		draw_line(Vector2(frame.position.x,frame.position.y+frame.size.y*k/3),Vector2(frame.end.x,frame.position.y+frame.size.y*k/3),Color(1,1,1,.25),1)
	for cx in [1,2]:
		for cy in [1,2]:
			draw_circle(frame.position+Vector2(frame.size.x*cx/3,frame.size.y*cy/3),3,amber)
	# A walker on the right third, walking left, with air in front.
	var head = frame.position+Vector2(frame.size.x*2/3,frame.size.y/3)
	draw_circle(head,6,green)
	draw_line(head+Vector2(0,6),head+Vector2(0,36),green,3)
	draw_line(head+Vector2(0,36),head+Vector2(-8,56),green,3)
	draw_line(head+Vector2(0,36),head+Vector2(8,56),green,3)
	draw_line(head+Vector2(-14,20),head+Vector2(-60,20),amber,2)
	draw_colored_polygon(PackedVector2Array([head+Vector2(-66,20),head+Vector2(-58,15),head+Vector2(-58,25)]),amber)
	txt(head+Vector2(-120,40),"aire delante",11,amber)
	if academy.phase == "practica" and academy.lesson == 4:
		var state = m.academy_last_thirds
		txt(Vector2(8,size.y-4),{"":"Nadie cerca en el encuadre","cruce":"Cabeza fuera de los cruces","aire":"Cruce correcto, pero sin aire delante","listo":"¡Perfecto!"}.get(state,""),11,green if state == "listo" else ink)

func draw_compression() -> void:
	var m = academy.main
	var y = size.y-26.0
	draw_line(Vector2(6,y),Vector2(size.x-6,y),dim,1)
	# Tree curtain at the back.
	var tree_x = size.x-34.0
	draw_rect(Rect2(tree_x-4,y-18,8,18),Color("6b5436"))
	draw_circle(Vector2(tree_x,y-38),22,Color("4f7a3b"))
	var tele = m.focal >= 90.0
	var cam_x = 10.0 if tele else 150.0
	var subj_x = 210.0
	# Camera and field of view reaching the trees.
	var half = atan(18.0/m.focal)
	var reach = tree_x-cam_x
	draw_colored_polygon(PackedVector2Array([Vector2(cam_x+10,y-18),Vector2(tree_x,y-18-tan(half)*reach),Vector2(tree_x,y-18+tan(half)*reach)]),Color(.72,.84,.55,.15))
	draw_rect(Rect2(cam_x,y-24,12,10),ink)
	draw_circle(Vector2(subj_x,y-36),5,green)
	draw_line(Vector2(subj_x,y-31),Vector2(subj_x,y-10),green,3)
	var d_subject = (subj_x-cam_x)/20.0
	var d_tree = (tree_x-cam_x)/20.0
	txt(Vector2(8,14),"%.0f mm · el árbol se ve %.1f veces la altura de la persona" % [m.focal,(4.0/d_tree)/(1.7/d_subject) if d_tree > 0 else 0.0],10,ink)
	txt(Vector2(8,28),"Tele de lejos: fondo grande y pegado" if tele else "Angular de cerca: fondo pequeño y lejano",11,green)
