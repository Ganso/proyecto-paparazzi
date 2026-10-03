extends Control
# Realistic camera finders (docs/futuro/07 §1): what surrounds the camera image and the data shown
# inside the finder, one design per body. Drawn in the interface, over the SubViewport, so nothing
# here reaches the photo or its score (take_photo() captures the viewport).
#   Réflex (1980s SLR): round rubber eyecup, image on the focusing screen, red 7-segment LED strip
#     under it (shutter, aperture, meter + ● −, focus confirmation, frames left), mirror blackout.
#   Telemétrica (1960s rangefinder): bright glass finder, bright-line frame of the focal length with
#     parallax correction, small red LED meter ▶ ● ◀ and shutter digits under the frame.
#   Compacta (2000s digital): rear LCD in a plastic body, white status icons, green AF box, zoom bar.
#   TLR (1950s 6×6, docs/futuro/21 §3): waist-level hood seen from above, square ground glass with
#     its grid, mirrored image (viewfinder_lens.gdshader), frame counter and a hand-held meter.
# The classic interface (interface_mode "clasica") hides all of it and shows the full-screen HUD.
const Photo = preload("res://scripts/photography.gd")
const Texts = preload("res://scripts/texts.gd")

var main
var body = -1
var mode = "camara"
var masks = {}
var font: Font
var blackout_time = 0.0
var blackout_total = 0.0
var lcd_freeze = 0.0
var led_red = Color(1.0,.18,.1)
var led_dim = Color(.25,.03,.02)
var lcd_white = Color(.95,.97,1.0)

# Image rectangle per body (1280×720 canvas, always 16:9 so the photo is never cropped).
const RECTS = {0: Rect2(70,82,904,508.5), 1: Rect2(96,40,1088,612), 2: Rect2(152,30,976,549), 3: Rect2(152,40,1024,576)}

# The TLR window: the central square of its image.
static func square_of(r: Rect2) -> Rect2:
	return Rect2(r.position.x+(r.size.x-r.size.y)*.5,r.position.y,r.size.y,r.size.y)

func _init(owner_main) -> void:
	main = owner_main

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font

func view_rect_for(b: int, interface: String) -> Rect2:
	if interface != "camara": return Rect2(Vector2.ZERO,Vector2(1280,720))
	return RECTS.get(b,Rect2(Vector2.ZERO,Vector2(1280,720)))

func blackout(shutter_seconds: float) -> void:
	# Mirror up and shutter: the SLR finder goes dark for the exposure plus the mirror travel.
	if body == 2:
		blackout_total = clampf(shutter_seconds+.07,.07,.6)
		blackout_time = blackout_total
	elif body == 0:
		lcd_freeze = .25      # the compact's LCD shows the frozen frame, then a black flash

# ---- Masks (eyecup / glass finder / plastic body), generated once per body ----
func mask(b: int) -> ImageTexture:
	if masks.has(b): return masks[b]
	var w = 640
	var h = 360
	var img = Image.create(w,h,false,Image.FORMAT_RGBA8)
	var r: Rect2 = RECTS[b]
	if b == 3: r = square_of(r)
	var rect = Rect2(r.position*.5,r.size*.5)
	var rng = RandomNumberGenerator.new()
	rng.seed = 77+b
	for y in h:
		for x in w:
			var p = Vector2(x+.5,y+.5)
			var c = Color(0,0,0,0)
			# Signed distance to the rounded image window (negative inside).
			var radius = 10.0 if b == 2 else (6.0 if b == 1 else (2.0 if b == 3 else 3.0))
			var q = (p-rect.get_center()).abs()-(rect.size*.5-Vector2(radius,radius))
			var d = Vector2(maxf(q.x,0),maxf(q.y,0)).length()+minf(maxf(q.x,q.y),0.0)-radius
			match b:
				2:
					# Rubber eyecup: black around the window, a soft dark falloff inside its edge,
					# and the cup's rim catching a little light far out.
					var eye = (p-Vector2(w*.5,h*.47))/Vector2(w*.55,h*.62)
					var cup = eye.length()
					if d > 0:
						var rubber = .05+.035*smoothstep(.95,1.15,cup)*(1.0-smoothstep(1.15,1.5,cup))+rng.randf()*.012
						c = Color(rubber,rubber,rubber*1.05,1.0)
					else:
						c = Color(0,0,0,clampf(1.0-(-d)/14.0,0,1)*.55)
				1:
					# Bright glass finder: the window edge is a thin dark frame; dark body around.
					if d > 0:
						var g = .035+rng.randf()*.01
						c = Color(g,g,g,1.0)
					else:
						c = Color(0,0,0,clampf(1.0-(-d)/6.0,0,1)*.35)
				3:
					# Folding hood of a TLR seen from above: black crinkle metal with the four
					# side flaps catching a little light towards the window.
					if d > 0:
						var flap = .02+.06*(1.0-smoothstep(0.0,60.0,d))+rng.randf()*.015
						c = Color(flap,flap,flap*1.04,1.0)
					else:
						c = Color(0,0,0,clampf(1.0-(-d)/10.0,0,1)*.5)
				0:
					# Plastic body of a compact around the LCD, with a slight texture and a bevel.
					if d > 0:
						var t = .16+rng.randf()*.018-.04*smoothstep(0.0,4.0,d)*(1.0-smoothstep(4.0,10.0,d))
						c = Color(t,t*1.02,t*1.06,1.0)
					else:
						c = Color(0,0,0,clampf(1.0-(-d)/3.0,0,1)*.6)
			img.set_pixel(x,y,c)
	masks[b] = ImageTexture.create_from_image(img)
	return masks[b]

# ---- Seven-segment digits (drawn in code, no third-party fonts) ----
const SEGMENTS = {"0":"abcdef","1":"bc","2":"abged","3":"abgcd","4":"fgbc","5":"afgcd","6":"afgedc","7":"abc",
	"8":"abcdefg","9":"abcdfg","-":"g","F":"afge","E":"afged","o":"cdeg","H":"bcefg","P":"abefg"," ":""}

func seg_char(pos: Vector2, ch: String, h: float, color: Color, dim: Color) -> float:
	var w = h*.52
	var t = h*.13
	var lines = {"a":[Vector2(t,0),Vector2(w-t,0)],"b":[Vector2(w,t),Vector2(w,h*.5-t*.5)],"c":[Vector2(w,h*.5+t*.5),Vector2(w,h-t)],
		"d":[Vector2(t,h),Vector2(w-t,h)],"e":[Vector2(0,h*.5+t*.5),Vector2(0,h-t)],"f":[Vector2(0,t),Vector2(0,h*.5-t*.5)],"g":[Vector2(t,h*.5),Vector2(w-t,h*.5)]}
	if ch == ".":
		draw_circle(pos+Vector2(t*.6,h-t*.3),t*.55,color)
		return t*2.2
	var on: String = SEGMENTS.get(ch,"")
	for k in lines:
		var a = pos+lines[k][0]
		var b = pos+lines[k][1]
		if dim.a > 0: draw_line(a,b,dim,t,true)
		if on.contains(k):
			draw_line(a,b,Color(color.r,color.g,color.b,.3),t*2.2,true)
			draw_line(a,b,color,t,true)
	return w+t*2.6

func seg_text(pos: Vector2, text_value: String, h: float, color: Color, dim = Color(0,0,0,0)) -> float:
	var x = pos.x
	for ch in text_value: x += seg_char(Vector2(x,pos.y),ch,h,color,dim)
	return x-pos.x

func shutter_digits() -> String:
	var d = Photo.DENOMINATORS[main.t_index]
	return str(d)

func aperture_digits() -> String:
	var n: float = main.apertures()[main.n_index]
	return ("%.1f" % n) if n < 10 else str(int(n))

# ---- Per frame ----
func _process(dt: float) -> void:
	blackout_time = maxf(0.0,blackout_time-dt)
	lcd_freeze = maxf(0.0,lcd_freeze-dt)
	queue_redraw()

func _draw() -> void:
	if main == null or mode != "camara" or body < 0: return
	# Only while searching: behind a screen (briefing, result, pause…) the LEDs showed through the
	# frosted glass, sharp over the blurred park.
	if main.mode != "SEARCH": return
	draw_texture_rect(mask(body),Rect2(Vector2.ZERO,Vector2(1280,720)),false)
	var r: Rect2 = RECTS[body]
	match body:
		2: draw_slr(r)
		1: draw_rangefinder(r)
		0: draw_compact(r)
		3: draw_tlr(r)
	draw_assignment(r)
	if blackout_time > 0:
		draw_rect(r,Color(0,0,0,clampf(blackout_time/maxf(blackout_total,.001)*1.6,0,1)))
	if body == 0 and lcd_freeze > 0 and lcd_freeze < .08:
		draw_rect(r,Color(0,0,0,.92))

# The assignment line, small, out of the image (top of the surround) so it never covers the shot.
func draw_assignment(r: Rect2) -> void:
	var text_value: String = main.briefing.text
	if main.counter_label.visible: text_value = main.counter_label.text+" · "+text_value
	var y = r.position.y-10 if r.position.y > 26 else 18.0
	var hint = Texts.get_rich("visor_tab_controles")
	draw_string(font,Vector2(r.position.x,y),text_value,HORIZONTAL_ALIGNMENT_LEFT,r.size.x-230,13,Color(.78,.82,.74,.85))
	# Keys as keycaps, pad buttons round (scripts/glyph_label.gd).
	preload("res://scripts/glyph_label.gd").draw_rich(self,font,Vector2(r.end.x-200,y-13),hint,12,Color(.7,.74,.68,.85))

func meter_delta() -> float:
	return main.finder.delta_ev

func draw_slr(r: Rect2) -> void:
	# Focusing screen of a manual SLR: microprism collar around the split-image circle (the split
	# image itself works in MF, see viewfinder.gd and focus_aid.gdshader).
	var c = r.get_center()
	var ring = r.size.y*.078
	draw_arc(c,ring*1.75,0,TAU,72,Color(1,1,1,.16),ring*.9*0.08+1.0,true)
	draw_arc(c,ring*1.02,0,TAU,64,Color(1,1,1,.22),1.2,true)
	for k in 48:
		var a0 = TAU*k/48.0
		draw_line(c+Vector2.from_angle(a0)*ring*1.12,c+Vector2.from_angle(a0)*ring*1.68,Color(1,1,1,.05),1.0)
	# Focal length, small in the corner of the screen (zoom lenses).
	draw_string(font,Vector2(r.position.x+12,r.end.y-12),"%d mm" % roundi(main.focal),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1,1,1,.5))
	# With the HUD bars unfolded (Tab, Academy lessons) the bottom bar covers half of the LED strip
	# and shows the same values: the strip is not drawn then.
	if not main.hud_bottom.is_empty() and main.hud_bottom[0].visible: return
	# LED strip under the focusing screen (red 7-segment, unlit segments faintly visible).
	var y = r.end.y+30
	var x = r.position.x+40
	var auto = main.equipment.auto_exposure
	x += seg_text(Vector2(x,y),shutter_digits(),30,led_red,led_dim)+30
	draw_string(font,Vector2(x-24,y+30),"s",HORIZONTAL_ALIGNMENT_LEFT,-1,14,led_red)
	x += 6
	draw_string(font,Vector2(x,y+30),"F",HORIZONTAL_ALIGNMENT_LEFT,-1,22,led_red)
	x += 20
	x += seg_text(Vector2(x,y),aperture_digits(),30,led_red,led_dim)+46
	# Match-LED meter: + ● − (the lit one tells where the exposure is; both ± blink when far off).
	var d = meter_delta()
	var blink = fmod(Time.get_ticks_msec()/1000.0,.5) < .25
	var plus_on = d > .34 and (d < 2.0 or blink)
	var minus_on = d < -.34 and (d > -2.0 or blink)
	var centre_on = absf(d) <= .7
	draw_string(font,Vector2(x,y+26),"+",HORIZONTAL_ALIGNMENT_LEFT,-1,30,led_red if plus_on else led_dim)
	draw_circle(Vector2(x+42,y+15),7,led_red if centre_on else led_dim)
	if centre_on: draw_circle(Vector2(x+42,y+15),12,Color(led_red.r,led_red.g,led_red.b,.25))
	draw_string(font,Vector2(x+64,y+26),"−",HORIZONTAL_ALIGNMENT_LEFT,-1,30,led_red if minus_on else led_dim)
	x += 120
	if auto:
		# Exposure mode letter: P program, A aperture priority, S shutter priority.
		draw_string(font,Vector2(x,y+26),main.equipment.exposure_mode(),HORIZONTAL_ALIGNMENT_LEFT,-1,24,led_red)
		x += 26
		var comp = main.equipment.exposure_compensation()
		if not is_zero_approx(comp):
			draw_string(font,Vector2(x,y+26),"±",HORIZONTAL_ALIGNMENT_LEFT,-1,22,led_red)
			x += 20
	x += 30
	# Focus confirmation (in-focus LED) and frames left.
	var focused = main.finder.mf_coincidence if main.equipment.focus_mode == "MF" else main.finder.success
	draw_circle(Vector2(x,y+15),6,Color(.3,1.0,.35) if focused else Color(.05,.18,.06))
	x += 40
	var frames = main.shots if not main.sandbox else 36
	seg_text(Vector2(r.end.x-90,y),"%02d" % clampi(frames,0,99),30,led_red,led_dim)
	draw_string(font,Vector2(r.end.x-130,y+26),"▣",HORIZONTAL_ALIGNMENT_LEFT,-1,18,led_red)

# Rangefinder parallax (fraction of the image): the finder window sits above-left of the lens, so
# at close range the frame lines move down and right to show what the lens takes.
func parallax() -> Vector2:
	var s: float = main.focus_distance
	if is_inf(s) or s <= 0: return Vector2.ZERO
	var f: float = main.focal
	return Vector2(.03*f/s/36.0,.025*f/s/20.25).clampf(0.0,.12)

func draw_rangefinder(r: Rect2) -> void:
	var p = parallax()*r.size
	# Bright-line frame for the mounted lens (white, slightly glowing), corrected for parallax.
	var inset = r.size*.035
	var frame = Rect2(r.position+inset+p,r.size-inset*2)
	var line = Color(1.0,.98,.9,.85)
	var arm = Vector2(frame.size.x*.12,frame.size.y*.12)
	for corner in [[frame.position,Vector2(1,1)],[Vector2(frame.end.x,frame.position.y),Vector2(-1,1)],[Vector2(frame.position.x,frame.end.y),Vector2(1,-1)],[frame.end,Vector2(-1,-1)]]:
		var c: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		for glow in [[4.0,.18],[1.6,1.0]]:
			var col = Color(line.r,line.g,line.b,line.a*glow[1])
			draw_line(c,c+Vector2(arm.x*dir.x,0),col,glow[0])
			draw_line(c,c+Vector2(0,arm.y*dir.y),col,glow[0])
	draw_string(font,frame.position+Vector2(8,18),"%d" % roundi(main.focal),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(line.r,line.g,line.b,.7))
	# LED meter under the frame: ▶ ● ◀ (both triangles = far off), shutter digits beside.
	var y = r.end.y+30
	var cx = r.get_center().x
	var d = meter_delta()
	var right_on = d < -.34    # underexposed: turn the dial (Leica convention: the arrow points the way)
	var left_on = d > .34
	draw_colored_polygon(PackedVector2Array([Vector2(cx-46,y-9),Vector2(cx-30,y),Vector2(cx-46,y+9)]),led_red if right_on else led_dim)
	draw_circle(Vector2(cx,y),6,led_red if absf(d) <= .5 else led_dim)
	draw_colored_polygon(PackedVector2Array([Vector2(cx+46,y-9),Vector2(cx+30,y),Vector2(cx+46,y+9)]),led_red if left_on else led_dim)
	seg_text(Vector2(cx+80,y-12),shutter_digits(),24,led_red,Color(0,0,0,0))
	seg_text(Vector2(cx-200,y-12),aperture_digits(),24,Color(.95,.85,.6,.75),Color(0,0,0,0))
	draw_string(font,Vector2(cx-232,y+10),"f/",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(.95,.85,.6,.75))

func draw_tlr(r: Rect2) -> void:
	var sq = square_of(r)
	# Ground glass grid (thin dark lines in thirds) and the clear central spot.
	for k in [1,2]:
		var gx = sq.position.x+sq.size.x*k/3.0
		var gy = sq.position.y+sq.size.y*k/3.0
		draw_line(Vector2(gx,sq.position.y),Vector2(gx,sq.end.y),Color(0,0,0,.28),1.0)
		draw_line(Vector2(sq.position.x,gy),Vector2(sq.end.x,gy),Color(0,0,0,.28),1.0)
	if main.tlr_loupe:
		draw_string(font,sq.position+Vector2(12,24),Texts.get_text("tlr_lupa")+" 3×",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1,1,1,.7))
	# Frame counter window (right) and crank state; hand-held meter (left): a needle over −2…+2.
	var cream = Color(.92,.88,.78)
	var frames = main.tlr_frames if main.sandbox else main.shots
	var cx = sq.end.x+90
	draw_circle(Vector2(cx,sq.position.y+110),34,Color(.08,.08,.085))
	draw_arc(Vector2(cx,sq.position.y+110),34,0,TAU,40,Color(.3,.3,.32),2)
	draw_string(font,Vector2(cx-30,sq.position.y+122),str(frames),HORIZONTAL_ALIGNMENT_CENTER,60,30,cream)
	draw_string(font,Vector2(cx-60,sq.position.y+168),"Nº",HORIZONTAL_ALIGNMENT_CENTER,120,14,Color(cream.r,cream.g,cream.b,.6))
	if main.sandbox and not main.tlr_wound:
		draw_string(font,Vector2(cx-80,sq.position.y+220),"K ↻",HORIZONTAL_ALIGNMENT_CENTER,160,22,Color(1,.6,.4))
	# The hand-held meter on the right, under the frame counter: the left side holds the subject
	# miniature and the on-screen help.
	var mx = sq.end.x+90
	var my = sq.position.y+300
	draw_rect(Rect2(mx-60,my-70,120,110),Color(.12,.12,.13))
	draw_rect(Rect2(mx-52,my-62,104,70),cream)
	for i in range(-2,3):
		var a = deg_to_rad(-90+i*22)
		draw_line(Vector2(mx,my)+Vector2.from_angle(a)*48,Vector2(mx,my)+Vector2.from_angle(a)*56,Color(.15,.15,.15),2)
	var needle = deg_to_rad(-90+clampf(meter_delta(),-2.5,2.5)*22)
	draw_line(Vector2(mx,my),Vector2(mx,my)+Vector2.from_angle(needle)*54,Color(.75,.1,.08),2)
	draw_string(font,Vector2(mx-60,my+30),"%s · f/%s" % [shutter_digits(),aperture_digits()],HORIZONTAL_ALIGNMENT_CENTER,120,13,cream)

func draw_compact(r: Rect2) -> void:
	var white = lcd_white
	var shadow = Color(0,0,0,.6)
	var txt = func(pos: Vector2, s: String, size: int, align = HORIZONTAL_ALIGNMENT_LEFT, width = -1.0, color = white) -> void:
		draw_string(font,pos+Vector2(1,1),s,align,width,size,shadow)
		draw_string(font,pos,s,align,width,size,color)
	var auto = main.equipment.auto_exposure
	txt.call(r.position+Vector2(16,28),main.equipment.exposure_mode(),22)
	txt.call(r.position+Vector2(46,27),Texts.get_text("visor_compacta_" + ("af" if main.equipment.focus_mode != "MF" else "mf")),14)
	# Battery and shots left, top right.
	var bx = r.end.x-62
	draw_rect(Rect2(bx,r.position.y+14,34,16),white,false,2)
	draw_rect(Rect2(bx+3,r.position.y+17,28,10),white)
	draw_rect(Rect2(bx+34,r.position.y+18,4,8),white)
	var frames = main.shots if not main.sandbox else 999
	txt.call(Vector2(r.end.x-160,r.position.y+28),"[%d]" % frames,16,HORIZONTAL_ALIGNMENT_RIGHT,90.0)
	# Bottom bar: shutter, aperture, ISO, exposure scale.
	var y = r.end.y-18
	draw_rect(Rect2(r.position.x,r.end.y-46,r.size.x,46),Color(0,0,0,.35))
	txt.call(Vector2(r.position.x+16,y),"1/%d" % Photo.DENOMINATORS[main.t_index],22)
	txt.call(Vector2(r.position.x+130,y),"F%s" % aperture_digits(),22)
	txt.call(Vector2(r.position.x+232,y),"ISO %d" % Photo.ISOS[main.iso_index],18)
	var sx = r.position.x+380
	var d = meter_delta()
	for i in range(-2,3):
		var tx = sx+(i+2)*36
		draw_line(Vector2(tx,y-10),Vector2(tx,y-2),white,2)
		txt.call(Vector2(tx-6,y-14),("%+d" % i) if i != 0 else "0",11)
	var needle = sx+72+clampf(d,-2,2)*36
	draw_colored_polygon(PackedVector2Array([Vector2(needle-6,y+4),Vector2(needle+6,y+4),Vector2(needle,y-4)]),Color(1,.85,.3) if absf(d) > .5 else Color(.5,1,.5))
	if auto:
		var comp = main.equipment.exposure_compensation()
		txt.call(Vector2(sx+200,y),"±%.1f" % comp if not is_zero_approx(comp) else "±0",16)
	# Zoom bar (W–T) on the right edge of the LCD.
	var lens = main.equipment.lens()
	if lens.max > lens.min:
		var zx = r.end.x-26
		var top = r.position.y+70
		var bottom = r.end.y-80
		draw_line(Vector2(zx,top),Vector2(zx,bottom),white,2)
		txt.call(Vector2(zx-6,top-6),"T",12)
		txt.call(Vector2(zx-6,bottom+16),"W",12)
		var k = inverse_lerp(lens.min,lens.max,main.focal)
		draw_rect(Rect2(zx-6,lerpf(bottom,top,k)-3,12,6),white)
	# The real controls of a compact sit on its back, to the right of the screen (decorative).
	var bx2 = r.end.x+60
	for i in 4:
		var c = Vector2(bx2+80,r.position.y+120+i*90)
		draw_circle(c,24,Color(.11,.115,.12))
		draw_arc(c,24,0,TAU,32,Color(.25,.26,.28),2)
	draw_circle(Vector2(bx2+80,r.end.y+50),36,Color(.1,.105,.11))
	draw_arc(Vector2(bx2+80,r.end.y+50),36,0,TAU,40,Color(.26,.27,.29),2)
	draw_string(font,Vector2(r.position.x,r.end.y+40),Texts.get_text("visor_compacta_marca"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(.42,.44,.47))
