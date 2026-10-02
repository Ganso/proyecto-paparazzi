extends SceneTree
# Side view of the playground's slide (docs/futuro/19 §10): one whole loop of the child climbing
# the ladder, crossing the platform, sliding down and walking round, to check the animation against
# the rungs and the chute. Saves frames; tools/capture_slide.sh joins them into an MP4.
#   ~/bin/godot-4-fp --path . --disable-vsync --rendering-method forward_plus --resolution 1280x720 --script tools/capture_slide.gd -- --out=<dir> [--view=lado|frente] [--step=<n>]
const MainScript = preload("res://scripts/main.gd")
var out_dir = "user://slide"
var view = "lado"
var every = 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--view="): view = arg.trim_prefix("--view=")
		if arg.begins_with("--step="): every = int(arg.trim_prefix("--step="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	MainScript.scenario = "grande"
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 30: await process_frame
	game.start_session("day",true)
	game.mode = "TEST"
	game.ui.visible = false
	game.set_raised(true)
	game.raise_anim = 1.0
	game.place_view()
	var slide = game.park.PLAYGROUND_POS+Vector3(2.0,0,.6)
	# Its own camera: the game's follows the photographer every frame.
	var cam = Camera3D.new()
	game.viewport.add_child(cam)
	cam.current = true
	if game.dof_pass: game.dof_pass.visible = false
	game.park.environment.environment.glow_enabled = false     # (no DoF pass on this camera to tame stray highlights)
	var target = slide+Vector3(0,1.3,.5)
	# The side we look at is in the shade: a soft fill light from the camera, without shadows.
	var fill = DirectionalLight3D.new()
	fill.light_energy = .9
	fill.shadow_enabled = false
	game.viewport.add_child(fill)
	# From the side, between the slide and the bench behind it (3.5 m away), or from the chute's end.
	var from = target+(Vector3(3.1,.05,0) if view == "lado" else Vector3(0,.5,6.5))
	# Only the slide's child: the runners cross right in front of the camera.
	for p in game.extras.extras:
		if p.has_meta("route"): p.visible = false
	var total = 0.0
	for ph in game.extras.SLIDE_PHASES: total += ph[1]
	game.extras.slide_time = 0.0
	var dt = 1.0/30
	var frames = int(total/dt)
	var n = 0
	for f in frames:
		game.extras.update(dt)
		cam.global_position = from
		cam.look_at(target)
		cam.fov = 54.0 if view == "lado" else 30.0
		fill.global_transform = cam.global_transform
		if f % every == 0:
			await process_frame
			await RenderingServer.frame_post_draw
			game.viewport.get_texture().get_image().save_png(out_dir.path_join("f_%04d.png" % n))
			n += 1
	print("SLIDE FRAMES: %d in %s (loop of %.2f s)" % [n,out_dir,total])
	quit()
