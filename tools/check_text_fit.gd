extends SceneTree
# Walks every screen of every mode and checks that no text overflows: each Label, Button, glyph
# label and RichTextLabel must stay inside the panel that holds it (or the 1280×720 screen) and
# must not run over another text. Saves a capture of every screen with a problem, the offending
# texts framed in red.
#   ~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1280x720 --script tools/check_text_fit.gd [-- --out=<dir>] [--all-shots]
const Main = preload("res://main.tscn")
const GlyphLabel = preload("res://scripts/glyph_label.gd")
const Glyphs = preload("res://scripts/input_glyphs.gd")
var out_dir = "/tmp/paparazzi-textos"
var all_shots = false
var game
var problems = 0
var screens = 0
var marks: Control

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

# The rectangle the text really takes (global), or an empty one if the control has no text.
func text_rect(c: Control) -> Rect2:
	var origin = c.get_global_transform().origin
	var scale = c.get_global_transform().get_scale()
	if c is Label:
		if c.text.strip_edges() == "": return Rect2()
		var font = c.get_theme_font("font")
		var fs = c.get_theme_font_size("font_size")
		var wrap = c.autowrap_mode != TextServer.AUTOWRAP_OFF
		var need = font.get_multiline_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,c.size.x if wrap else -1.0,fs)
		var pos = Vector2.ZERO
		if c.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: pos.x = (c.size.x-need.x)*.5
		elif c.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: pos.x = c.size.x-need.x
		if c.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: pos.y = (c.size.y-need.y)*.5
		elif c.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: pos.y = c.size.y-need.y
		return Rect2(origin+pos*scale,need*scale)
	if c is Button:
		if c.text.strip_edges() == "": return Rect2()
		var font = c.get_theme_font("font")
		var fs = c.get_theme_font_size("font_size")
		var need = font.get_multiline_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,-1.0,fs)
		return Rect2(origin+(c.size-need)*.5*scale,need*scale)
	if c.get_script() == GlyphLabel:
		if str(c.rich).strip_edges() == "": return Rect2()
		var need = GlyphLabel.measure(c.font,c.rich,c.font_size,c.size.x)
		var x = (c.size.x-need.x)*.5 if c.align_center and c.size.x > 0 else 0.0
		return Rect2(origin+Vector2(x,0)*scale,need*scale)
	if c is RichTextLabel:
		if c.get_parsed_text().strip_edges() == "": return Rect2()
		return Rect2(origin,Vector2(c.size.x,c.get_content_height())*scale)
	return Rect2()

# What a scroll area lets see of a text inside it.
func clipped(c: Control, r: Rect2) -> Rect2:
	var p = c.get_parent()
	while p != null and p != root:
		if p is ScrollContainer:
			var window = Rect2(p.get_global_transform().origin,p.size*p.get_global_transform().get_scale())
			r = r.intersection(window) if r.intersects(window) else Rect2()
		p = p.get_parent()
	return r

func label_of(c: Control) -> String:
	var t = str(c.rich) if c.get_script() == GlyphLabel else (c.get_parsed_text() if c is RichTextLabel else str(c.get("text")))
	t = t.replace("\n"," ⏎ ")
	return "«"+(t if t.length() <= 70 else t.substr(0,67)+"…")+"»"

# The box a text must stay in: the nearest panel or button above it, else the screen.
func frame_of(c: Control) -> Rect2:
	var p = c.get_parent()
	while p != null and p != root:
		if p is ScrollContainer: return Rect2(-INF,-INF,INF,INF)
		if p is Control and (p is Panel or p is PanelContainer or p is Button or p.clip_contents) and p.size.x > 8 and p.size.y > 8:
			return Rect2(p.get_global_transform().origin,p.size*p.get_global_transform().get_scale())
		p = p.get_parent()
	return Rect2(0,0,1280,720)

func collect(node: Node, out: Array) -> void:
	if node is CanvasItem and not node.visible: return
	if node is Control and node != marks:
		var r = text_rect(node)
		r = clipped(node,r)
		if r.size.x > 1 and r.size.y > 1 and node.modulate.a > .05 and node.self_modulate.a > .05: out.append([node,r])
	if node is SubViewport: return
	for child in node.get_children(): collect(child,out)

func related(a: Node, b: Node) -> bool:
	return a.is_ancestor_of(b) or b.is_ancestor_of(a)

func check(name: String) -> void:
	await frames(6)
	screens += 1
	var items = []
	# A full-screen menu hides the camera interface behind it: only what is on top counts.
	if is_instance_valid(game.modal) and game.modal.is_visible_in_tree(): collect(game.modal,items)
	else: collect(game,items)
	var found = []
	var bad = []
	for item in items:
		var c: Control = item[0]
		var r: Rect2 = item[1]
		var f = frame_of(c)
		if f.position.x == -INF: continue
		var over = [f.position.x-r.position.x,f.position.y-r.position.y,r.end.x-f.end.x,r.end.y-f.end.y]
		var worst = maxf(maxf(over[0],over[1]),maxf(over[2],over[3]))
		if worst > 1.5:
			var side = ["izquierda","arriba","derecha","abajo"][over.find(worst)]
			found.append("  SE SALE %.0f px por %s: %s  [%s]" % [worst,side,label_of(c),c.get_path()])
			bad.append(r)
	for i in items.size():
		for j in range(i+1,items.size()):
			var a = items[i]
			var b = items[j]
			if related(a[0],b[0]): continue
			if frame_of(a[0]).position.x == -INF and frame_of(b[0]).position.x == -INF: pass
			var x = a[1].grow(-1.5).intersection(b[1].grow(-1.5))
			if x.size.x > 2 and x.size.y > 2:
				found.append("  SE PISAN %.0f×%.0f px: %s y %s  [%s | %s]" % [x.size.x,x.size.y,label_of(a[0]),label_of(b[0]),a[0].get_path(),b[0].get_path()])
				bad.append(a[1])
				bad.append(b[1])
	if not found.is_empty():
		problems += found.size()
		print("PANTALLA "+name)
		for line in found: print(line)
	if not found.is_empty() or all_shots:
		marks.set_meta("rects",bad)
		marks.queue_redraw()
		await frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(name+".png"))
		marks.set_meta("rects",[])
		marks.queue_redraw()

# The scene reloads itself when the scenario changes: follow the new one, and keep its saves away
# from the player's files.
func guard() -> void:
	game.academy.progress_path = out_dir.path_join("guardado/academia.cfg")
	game.academy.load_progress()

func sync() -> void:
	await frames(3)
	if current_scene != game and current_scene != null:
		game = current_scene
		guard()
		await frames(40)

func draw_marks() -> void:
	for r in marks.get_meta("rects",[]): marks.draw_rect(r.grow(2),Color(1,0,0),false,2.0)

func run() -> void:
	var only = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg == "--all-shots": all_shots = true
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Nothing of the player's is written: progress, badges and album go to a scratch folder, and
	# the interface file (theme, help) is put back as it was at the end.
	var scratch = out_dir.path_join("guardado")
	DirAccess.make_dir_recursive_absolute(scratch)
	preload("res://scripts/arcade.gd").SAVE = scratch.path_join("arcade.cfg")
	preload("res://scripts/badges.gd").SAVE = scratch.path_join("insignias.cfg")
	preload("res://scripts/album.gd").DIR = scratch.path_join("album")
	# Not the player's display settings either (vsync on a hidden window crawls at 2 fps).
	preload("res://scripts/graphics.gd").SAVE = scratch.path_join("graficos.cfg")
	var ui_file = FileAccess.get_file_as_bytes("user://interfaz.cfg")
	game = Main.instantiate()
	root.add_child(game)
	current_scene = game
	guard()
	var layer = CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	marks = Control.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(draw_marks)
	layer.add_child(marks)
	await frames(40)
	for device in ["teclado","mando"]:
		Glyphs.device = device
		game.pad_polling = false
		var d = device+"_"
		if only == "" or only == "menu":
			# --- Menu and its screens ---
			for k in 6:
				game.intro()
				game.modal.current = k
				game.modal.build_card()
				await check(d+"menu_"+game.modal.MODES[k])
			for body in 4:
				game.intro()
				game.equipment.preset(body)
				game.show_equipment()
				await check(d+"equipo_%d" % body)
			game.equipment.preset(2)
			game.intro()
			game.show_graphics_settings()
			await check(d+"graficos")
			game.intro()
			game.show_badges()
			await check(d+"insignias")
			game.intro()
			game.show_album()
			await check(d+"album")
			if game.has_method("show_album_photo") and not preload("res://scripts/album.gd").list().is_empty():
				game.show_album_photo(0)
				await check(d+"album_foto")
		if only == "" or only == "libre":
			# --- Free session: briefing, both interfaces with every body, help, pause, result ---
			for tod in ["day","golden","blue","night"]:
				game.intro()
				game.start_session(tod)
				await check(d+"encargo_"+tod)
			for body in 4:
				game.equipment.preset(body)
				game.apply_equipment()
				for face in ["clasica","camara"]:
					game.intro()
					game.start_session("day")
					game.begin_assignment()
					game.set_interface(face)
					await frames(20)
					await check(d+"busqueda_%s_%d" % [face,body])
			game.equipment.preset(2)
			game.apply_equipment()
			game.show_help()
			await check(d+"ayuda")
			game.resume_search()
			game.show_pause()
			await check(d+"pausa")
			game.show_pause(true)
			await check(d+"pausa_confirmar")
			game.resume_search()
			for shot in 3:
				game.angle = fposmod(game.angle+70.0,360)
				game.update_camera()
				await game.take_photo()
				await check(d+"resultado_%d" % shot)
				if game.mode == "RESULT" and shot < 2: game.resume_search()
			game.finish_assignment()
			await check(d+"resumen")
			game.intro()
			game.start_session("day",true)
			game.show_sandbox_controls()
			await check(d+"sandbox_controles")
			game.resume_search()
			await check(d+"sandbox_busqueda")
			await game.take_photo()
			await check(d+"sandbox_resultado")
		if only == "" or only == "grande":
			# --- The big park: walking, camera at the eye, help, result, sandbox ---
			game.intro()
			game.start_in("grande","day",false)
			await sync()
			await check(d+"grande_encargo")
			game.begin_assignment()
			await frames(20)
			await check(d+"grande_paseo")
			game.toggle_raise()
			await frames(50)
			await check(d+"grande_camara")
			game.show_help()
			await check(d+"grande_ayuda")
			game.resume_search()
			await game.take_photo()
			await check(d+"grande_resultado")
			game.intro()
			game.start_in("clasico","day",false)
			await sync()
		if only == "" or only == "arcade":
			# --- Arcade: the list, every briefing, the finder of every level, a result and the end ---
			preload("res://scripts/arcade.gd").all_open = true
			game.intro()
			game.show_arcade()
			await check(d+"arcade")
			for n in preload("res://scripts/arcade.gd").LEVELS.size():
				game.intro()
				game.start_level(n)
				await sync()
				await check(d+"nivel_%02d_encargo" % (n+1))
				game.begin_assignment()
				await frames(20)
				await check(d+"nivel_%02d_busqueda" % (n+1))
				if game.equipment.tlr() and not game.tlr_wound: game.wind_film()
				await game.take_photo()
				await check(d+"nivel_%02d_resultado" % (n+1))
				game.end_level()
				await check(d+"nivel_%02d_fin" % (n+1))
		if only == "" or only == "tutorial":
			game.intro()
			game.start_tutorial()
			for k in game.tutorial.STEPS.size():
				game.tutorial.step = k
				game.tutorial.enter_step()
				game.tutorial.update_panel()
				await check(d+"tutorial_%02d" % (k+1))
			await check(d+"tutorial_fin_pantalla")
			game.tutorial.stop()
		if only == "" or only == "academia":
			game.intro()
			game.open_academy()
			await sync()
			await check(d+"academia")
			for n in range(1,game.academy.LESSONS+1):
				for k in game.academy.THEORY_PAGES[game.academy.ORDER[n-1]]:
					game.intro()
					game.academy.begin(n,"teoria")
					game.academy.page = k
					game.academy.update_panel()
					await check(d+"academia_l%d_teoria_%d" % [n,k+1])
				for ph in ["demo","practica","examen"]:
					game.intro()
					game.academy.begin(n,ph)
					await frames(90 if ph == "demo" else 30)   # the demo: with its first caption on
					await check(d+"academia_l%d_%s" % [n,ph])
					if ph != "demo":
						await game.take_photo()
						await check(d+"academia_l%d_%s_foto" % [n,ph])
				game.academy.stop()
	if not ui_file.is_empty():
		var f = FileAccess.open("user://interfaz.cfg",FileAccess.WRITE)
		f.store_buffer(ui_file)
		f.close()
	print("TEXTOS: %d pantallas revisadas, %d problemas (capturas en %s)" % [screens,problems,out_dir])
	quit()
