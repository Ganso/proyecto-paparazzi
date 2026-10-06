extends Node3D
# Ambient sound of the park (docs/futuro/19_VIDA_EN_EL_PARQUE.md §6). The WAVs are the generated
# takes that tools/audio/import_generated.py leaves in assets/audio/ambiente/ (until 06-10-2026
# they were synthesized by tools/audio/build_ambience.py), loaded at run time (no import step). Birds sing in the
# trees by day and at golden hour, crickets take over at night, the fountain is heard from its
# side of the park, pigeons coo and flutter off. No wind or city noise bed: the user found the
# constant hiss annoying (01-10-2026).
const DIR = "res://assets/audio/ambiente/"
const BIRD_SPOTS = [20.0, 110.0, 200.0, 290.0]
const CRICKET_SPOTS = [60.0, 180.0, 300.0]

var park
var pigeons
# Where the sounds come from (the big park passes its own; defaults: the classic park).
var fountain_pos = Vector3.ZERO
var bird_points: Array = []
var cricket_points: Array = []
var streams = {}
var birds: Array[AudioStreamPlayer3D] = []
var crickets: Array[AudioStreamPlayer3D] = []
var fountain: AudioStreamPlayer3D
var coo_players: Array[AudioStreamPlayer3D] = []
var coo_timers: Array[float] = []
var flock_states: Array = []
var rng = RandomNumberGenerator.new()
var current_bed = "pajaros_dia"

static func polar(theta: float, r: float) -> Vector3:
	return Vector3(sin(deg_to_rad(theta))*r,0,-cos(deg_to_rad(theta))*r)

func stream(name: String, loop: bool) -> AudioStreamWAV:
	if streams.has(name): return streams[name]
	var path = DIR+name+".wav"
	if not FileAccess.file_exists(path): return null
	var wav = AudioStreamWAV.load_from_file(path)
	if wav == null: return null
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# The last frame, by the stream's own length: «bytes / 2» pointed one past the end (and was
		# wrong for anything but 16-bit mono), and the Android mixer read beyond the buffer and crashed.
		wav.loop_end = maxi(1,int(wav.get_length()*wav.mix_rate)-1)
	streams[name] = wav
	return wav

func player3d(name: String, pos: Vector3, loop: bool, unit: float, db: float) -> AudioStreamPlayer3D:
	var s = stream(name,loop)
	var player = AudioStreamPlayer3D.new()
	player.stream = s
	player.position = pos
	player.unit_size = unit
	player.volume_db = db
	player.max_distance = 80.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.set_meta("db",db)
	add_child(player)
	return player

func build(park_node, pigeons_node) -> void:
	park = park_node
	pigeons = pigeons_node
	rng.seed = 5150
	if stream("pajaros_dia",true) == null: return   # no audio files (e.g. a trimmed export)
	if bird_points.is_empty(): bird_points = BIRD_SPOTS.map(func(a): return polar(a,15.0)+Vector3.UP*5.0)
	if cricket_points.is_empty(): cricket_points = CRICKET_SPOTS.map(func(a): return polar(a,10.5)+Vector3.UP*.3)
	if fountain_pos == Vector3.ZERO: fountain_pos = polar(245.0,21.0)+Vector3.UP*.8
	for i in bird_points.size():
		var b = player3d("pajaros_dia",bird_points[i],true,10.0,-2.0)
		b.pitch_scale = [1.0,.93,1.07,.97,1.03,.95][i%6]
		birds.append(b)
	for i in cricket_points.size():
		var c = player3d("grillos_noche",cricket_points[i],true,7.0,-6.0)
		c.pitch_scale = [1.0,1.04,.96][i%3]
		crickets.append(c)
	fountain = player3d("fuente",fountain_pos,true,12.0,0.0)
	if pigeons and not pigeons.flocks.is_empty():
		for f in pigeons.flocks.size():
			var p = player3d("zureo_1",pigeons.flocks[f].center,false,4.0,-4.0)
			coo_players.append(p)
			coo_timers.append(rng.randf_range(2,8))
			flock_states.append(pigeons.flocks[f].state)
	for node in [fountain]+birds+crickets:
		if node is AudioStreamPlayer3D: node.play(rng.randf_range(0,4))
		else: node.play()
	apply_time(true)

# Per time of day: birds by day (quieter at golden hour), crickets at night.
func apply_time(immediate = false, dt = 0.0) -> void:
	var tod = park.time_of_day
	# Each light has its own recording: day birds, the sparser ones of the golden hour, and the
	# last birds over the first crickets at the blue hour. At night, crickets alone.
	var bed = {"day":"pajaros_dia","golden":"pajaros_atardecer","blue":"hora_azul"}.get(tod,"")
	if bed != current_bed and bed != "":
		current_bed = bed
		for b in birds:
			b.stream = stream(bed,true)
			b.play(rng.randf_range(0,8))
	var bird_db = {"day":0.0,"golden":-2.0,"blue":-3.0,"night":-80.0}.get(tod,0.0)
	var cricket_db = {"night":0.0}.get(tod,-80.0)
	for b in birds: fade(b,b.get_meta("db")+bird_db,immediate,dt)
	for c in crickets: fade(c,c.get_meta("db")+cricket_db,immediate,dt)

func fade(player: Node, target: float, immediate: bool, dt: float) -> void:
	player.volume_db = target if immediate else move_toward(player.volume_db,target,dt*20.0)

func update(dt: float) -> void:
	if fountain == null: return
	apply_time(false,dt)
	if pigeons == null: return
	for f in coo_players.size():
		var flock = pigeons.flocks[f]
		var player = coo_players[f]
		player.position = flock.center
		coo_timers[f] -= dt
		if coo_timers[f] <= 0 and flock.state == "suelo":
			coo_timers[f] = rng.randf_range(3,10)
			player.stream = stream("zureo_%d" % (1+rng.randi()%2),false)
			player.pitch_scale = rng.randf_range(.9,1.1)
			player.play()
		if flock.state == "vuelo" and flock_states[f] != "vuelo":
			player.stream = stream("aleteo_bandada_1",false)
			player.pitch_scale = rng.randf_range(.9,1.1)
			player.play()
		flock_states[f] = flock.state
