extends Node
# Music of the menus (user, 25-11-2026): a light jazz loop (assets/audio/musica/menu_jazz.ogg,
# 40 bars at 107 BPM cut so the loop does not skip a beat) under the main menu and the screens
# opened from it (arcade, Academy, badges, album, graphics and equipment). It comes in with a
# short fade, fades out when a phase starts and comes back where it was left.
const STREAM = "res://assets/audio/musica/menu_jazz.ogg"
const VOLUME_DB = -9.0          # (the take is mastered loud: it sits under the park's ambience)
const FADE_IN = 2.5             # seconds from silence
const FADE_OUT = .9
const SILENT_DB = -60.0
const MENU_MODES = ["INTRO","ARCADE","ACADEMY","BADGES","ALBUM"]

var main
var player: AudioStreamPlayer
var enabled = true
var level = 0.0                 # 0 silent … 1 full, faded linearly in decibels' amplitude

func _init(owner_main) -> void:
	main = owner_main

func _ready() -> void:
	player = AudioStreamPlayer.new()
	if ResourceLoader.exists(STREAM):
		var stream = load(STREAM)
		if stream is AudioStreamOggVorbis: stream.loop = true
		player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)

# Whether the screen in front of the player is a menu.
func in_menu() -> bool:
	var mode: String = main.mode
	if mode in MENU_MODES: return true
	if mode == "GRAPHICS": return main.graphics_return == "INTRO"
	if mode == "EQUIPMENT": return main.equipment_return == "INTRO"
	return false

func update(dt: float) -> void:
	if player.stream == null: return
	var wanted = enabled and in_menu()
	level = move_toward(level,1.0 if wanted else 0.0,dt/(FADE_IN if wanted else FADE_OUT))
	if level > 0.0:
		if not player.playing: player.play()
		elif player.stream_paused: player.stream_paused = false
		# An even fade to the ear: linear in amplitude, not in decibels.
		player.volume_db = VOLUME_DB+linear_to_db(maxf(level,.001))
	elif player.playing and not player.stream_paused:
		player.stream_paused = true      # (it comes back where it was left)
