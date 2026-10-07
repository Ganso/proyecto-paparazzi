extends Node
# Sound effects (docs/futuro/24_SONIDOS_NECESARIOS.md): the takes that tools/audio/
# import_generated.py leaves in assets/audio/ (camara, interfaz, gente, ambiente), loaded at run
# time by name. A sound with variations is name_1.wav, name_2.wav…: one is taken at random, never
# the same twice running. Everything is optional: with a file missing, play() says so and the
# caller keeps its old synthesized tone.
#   play()      camera and interface, not placed in space
#   play_at()   from a point of the park (heard by the camera's listener, fading with distance)
#   loop_at()   a loop at a point, by key; stop_loop() ends it
# update_world() gives the park its people sounds: steps of whoever walks near, chats, laughs,
# pages, the dog, the ducks, the playground.
const DIR = "res://assets/audio/"
const FOLDERS = ["camara","interfaz","gente","ambiente"]
const STEP_RANGE = 9.0          # metres within which a walker's steps are heard
const STEP_VOICES = 5           # …and how many walkers at most, the nearest
var main
var world: Node                 # where the placed sounds live (the game's 3D viewport)
var streams = {}
var last_take = {}
var flat: Array[AudioStreamPlayer] = []
var spatial: Array[AudioStreamPlayer3D] = []
var loops = {}
var rng = RandomNumberGenerator.new()
var enabled = true
var hurry = 1.0                 # --sonidos-seguidos: the occasional sounds, more often (evidence)
var own_half = 0
var step_half = {}              # walker → half of the stride it was on
var timers = {}

func setup(game, where: Node) -> void:
	main = game
	world = where
	rng.seed = 2468
	for i in 8:
		var p = AudioStreamPlayer.new()
		add_child(p)
		flat.append(p)
	for i in 14:
		var p = AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.max_distance = 45.0
		world.add_child(p)
		spatial.append(p)

func takes(name: String) -> Array:
	if streams.has(name): return streams[name]
	var found = []
	for folder in FOLDERS:
		var single = DIR+folder+"/"+name+".wav"
		if FileAccess.file_exists(single): found.append(AudioStreamWAV.load_from_file(single))
		var k = 1
		while FileAccess.file_exists(DIR+folder+"/"+name+"_%d.wav" % k):
			found.append(AudioStreamWAV.load_from_file(DIR+folder+"/"+name+"_%d.wav" % k))
			k += 1
		if not found.is_empty(): break
	found = found.filter(func(s): return s != null)
	streams[name] = found
	return found

func has(name: String) -> bool:
	return enabled and not takes(name).is_empty()

func take(name: String) -> AudioStreamWAV:
	var list = takes(name)
	if list.is_empty(): return null
	var k = rng.randi()%list.size()
	if list.size() > 1 and k == int(last_take.get(name,-1)): k = (k+1)%list.size()
	last_take[name] = k
	return list[k]

func free_of(pool: Array):
	for p in pool:
		if not p.playing: return p
	return pool[0]

func play(name: String, db = 0.0, pitch = 1.0) -> bool:
	if not has(name): return false
	var p: AudioStreamPlayer = free_of(flat)
	p.stream = take(name)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
	return true

func play_at(name: String, pos: Vector3, db = 0.0, unit = 4.0, pitch = 1.0) -> bool:
	if not has(name) or world == null: return false
	var p: AudioStreamPlayer3D = free_of(spatial)
	p.stream = take(name)
	p.position = pos
	p.volume_db = db
	p.unit_size = unit
	p.pitch_scale = pitch
	p.play()
	return true

func looped(name: String) -> AudioStreamWAV:
	var list = takes(name)
	if list.is_empty(): return null
	var s: AudioStreamWAV = list[0]
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = maxi(1,int(s.get_length()*s.mix_rate)-1)   # (the last frame: see ambience.gd)
	return s

# A loop by key; pos == null plays it unplaced (the zoom motor). Loops never start or stop dead:
# they come in over a third of a second and go out over one (a chat that ended was cut mid-word;
# the same went for the dog's panting, the swing and the children when walking away from them).
const FADE_IN = 90.0            # dB per second
const FADE_OUT = 45.0
const SILENT = -45.0
var loop_target = {}            # key → level it is heading for (SILENT: on its way out)
func loop_at(key: String, name: String, pos, db = 0.0, unit = 4.0, pitch = 1.0) -> void:
	if not enabled: return
	if not loops.has(key):
		var s = looped(name)
		if s == null: return
		var p = AudioStreamPlayer.new() if pos == null else AudioStreamPlayer3D.new()
		p.stream = s
		if pos == null: add_child(p)
		else:
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			p.max_distance = 45.0
			p.unit_size = unit
			world.add_child(p)
		p.pitch_scale = pitch
		loops[key] = p
	var player = loops[key]
	if pos != null: player.position = pos
	loop_target[key] = db
	if not player.playing:
		player.volume_db = db-30.0
		player.play()

# quick: the zoom motor, which stops with its own tick.
func stop_loop(key: String, quick = false) -> void:
	if not loops.has(key) or not loops[key].playing: return
	if quick:
		loops[key].stop()
		loop_target.erase(key)
	else: loop_target[key] = SILENT

func _process(dt: float) -> void:
	for key in loop_target.keys():
		var player = loops[key]
		var target: float = loop_target[key]
		player.volume_db = move_toward(player.volume_db,target,dt*(FADE_OUT if target <= SILENT else FADE_IN))
		if target <= SILENT and player.volume_db <= SILENT+.5:
			player.stop()
			loop_target.erase(key)

func stop_world() -> void:
	for key in loops.keys(): stop_loop(key)

# true once every `every` seconds or so (a random wait between `least` and `most`).
func due(key: String, dt: float, least: float, most: float) -> bool:
	if not timers.has(key): timers[key] = rng.randf_range(least*.3,most)
	timers[key] -= dt
	if timers[key] > 0: return false
	timers[key] = rng.randf_range(least,most)*hurry
	return true

# What a foot lands on: paving on the paths and plazas of both parks (a trainer's stride for
# whoever runs on it), grass everywhere else in the big park. (The gravel takes wait for a
# gravel path: every path of the two parks is paved.)
func step_on(pos: Vector3, running = false) -> String:
	if main.crowd != null and main.park.path_distance(pos) > .1: return "paso_cesped"
	return "paso_corredor" if running else "paso_losa"

# ---- The park: who is heard from where the camera is ----
func update_world(dt: float) -> void:
	if not enabled or main == null or not is_instance_valid(main.camera): return
	if main.mode != "SEARCH":
		for key in ["charla","jadeo"]: stop_loop(key)
		return
	var ear: Vector3 = main.camera.global_position
	var big: bool = main.crowd != null
	# Steps: the nearest walkers, one sound per foot that lands (the stride is two steps).
	var near = []
	for p in main.people:
		if not p.visible or p.state != "CAMINANDO": continue
		var d = p.global_position.distance_to(ear)
		if d < STEP_RANGE: near.append([d,p])
	near.sort_custom(func(a,b): return a[0] < b[0])
	for k in mini(STEP_VOICES,near.size()):
		var p = near[k][1]
		var half = int(p.phase/PI)
		if step_half.get(p,half) != half:
			play_at(step_on(p.global_position,p.runner),p.global_position,-13.0 if p.runner else -14.0,2.5,rng.randf_range(.92,1.08))
		step_half[p] = half
	# Whoever walks on the meadow (the extras of the classic park, the child after the ball).
	if main.extras and is_instance_valid(main.extras):
		for p in main.extras.extras:
			if not p.visible or p.state != "CAMINANDO" or p.global_position.distance_to(ear) > STEP_RANGE*1.6: continue
			var half = int(p.phase/PI)
			if step_half.get(p,half) != half: play_at("paso_cesped",p.global_position,-8.0,3.0,rng.randf_range(.92,1.08))
			step_half[p] = half
	# The photographer's own steps, walking the big park: under the feet, not placed anywhere.
	if big and main.player != null:
		var half = int(main.walk_phase/PI)
		if half != own_half and main.player.velocity.length() > .2:
			var running: bool = main.player.velocity.length() > main.WALK_SPEED*1.25
			play(step_on(main.player.global_position,running),-13.0 if running else -12.0,rng.randf_range(.94,1.06))
		own_half = half
	# What people do where they stop: a chat (one loop, the nearest), a laugh, a page, a cup.
	var chat = null
	var chat_d = 16.0
	for p in main.people:
		if not p.visible or p.state == "CAMINANDO": continue
		var d = p.global_position.distance_to(ear)
		if d > 16.0: continue
		var at: Vector3 = p.global_position+Vector3.UP*1.2
		match str(p.activity):
			"charla":
				if d < chat_d:
					chat_d = d
					chat = p
				if due("risa",dt,14.0,40.0): play_at("risa",at,-8.0,3.0,rng.randf_range(.95,1.05))
			"leer":
				if due("periodico%d" % p.get_instance_id(),dt,9.0,22.0): play_at("periodico",at,-12.0,2.0)
			"cafe":
				if due("taza%d" % p.get_instance_id(),dt,14.0,30.0): play_at("taza",at,-10.0,2.0)
			"movil":
				if due("movil%d" % p.get_instance_id(),dt,18.0,45.0): play_at("movil",at,-10.0,2.0)
			"palomas":
				if due("migas%d" % p.get_instance_id(),dt,5.0,11.0): play_at("migas",p.global_position+Vector3.UP*.2,-10.0,2.0)
	if chat != null: loop_at("charla","charla",chat.global_position+Vector3.UP*1.3,-10.0,3.0)
	else: stop_loop("charla")
	# The dog: it pants beside its owner and barks now and then.
	if main.dog and is_instance_valid(main.dog) and main.dog.visible:
		var at: Vector3 = main.dog.global_position+Vector3.UP*.3
		if at.distance_to(ear) < 12.0:
			loop_at("jadeo","perro_jadeo",at,-14.0,2.0)
			if due("ladrido",dt,25.0,70.0): play_at("perro_ladrido",at,-9.0,5.0,rng.randf_range(.95,1.05))
		else: stop_loop("jadeo")
	# The playground: children's voices, the swing's chains at its own rhythm, the slide, the ball.
	var extras = main.extras
	if extras and is_instance_valid(extras):
		if extras.swing_pivot != null and extras.swing_pivot.visible and extras.swing_pivot.global_position.distance_to(ear) < 30.0:
			loop_at("columpio","columpio",extras.swing_pivot.global_position,-8.0,4.0)
			loop_at("ninos","ninos_jugando",extras.swing_pivot.global_position+Vector3(1.5,1,0),-12.0,6.0)
		else:
			stop_loop("columpio")
			stop_loop("ninos")
		if extras.slides != int(timers.get("slides",extras.slides)): play_at("tobogan",extras.slide_origin+Vector3.UP,-6.0,4.0)
		timers["slides"] = extras.slides
		if extras.kicks != int(timers.get("kicks",extras.kicks)) and extras.ball != null: play_at("balon_patada",extras.ball.global_position,-6.0,4.0,rng.randf_range(.94,1.06))
		timers["kicks"] = extras.kicks
		if extras.bounces != int(timers.get("bounces",extras.bounces)) and extras.ball != null: play_at("balon_bote",extras.ball.global_position,-10.0,3.0)
		timers["bounces"] = extras.bounces
	# The ducks of the pond.
	if main.ducks and is_instance_valid(main.ducks) and not main.ducks.ducks.is_empty() and main.park.time_of_day != "night":
		if due("pato",dt,9.0,26.0):
			var duck: Dictionary = main.ducks.ducks[rng.randi()%main.ducks.ducks.size()]
			var node = duck.get("body",null)
			var at: Vector3 = node.global_position if node is Node3D else main.ducks.global_position
			play_at("pato" if rng.randf() < .7 else "pato_agua",at,-2.0,7.0,rng.randf_range(.92,1.08))
