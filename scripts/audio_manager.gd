extends Node

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const VOICE_BUS: StringName = &"Voice"

const WATER_SPLASH: AudioStream = preload("res://assets/SFX/alex_jauk-water-splash-147014.ogg")
const RIVER: AudioStream = preload("res://assets/SFX/dragon-studio-river-sounds-420904.ogg")
const BOILING_FOOD: AudioStream = preload("res://assets/SFX/freesound_community-boiling-food-81761.ogg")
const WRONG_FOOD: AudioStream = preload("res://assets/SFX/freesound_community-oh-disappointed-89251.ogg")
const RIGHT_FOOD: AudioStream = preload("res://assets/SFX/freesound_community-shouting-yeah-7043.ogg")
const WALKING_ON_WOOD: AudioStream = preload("res://assets/SFX/freesounds123-walking-on-wood-363349.ogg")
const LOSE: AudioStream = preload("res://assets/SFX/Lose_funny_retro_video-game-80925.ogg")
const WIN: AudioStream = preload("res://assets/SFX/puyopuyomegafan1234-winner-game-sound-404167.ogg")
const TAKE_EMPTY_BOWL: AudioStream = preload("res://assets/SFX/taking-an-empty-bowl-sound-effect-316443.ogg")
const TAKE_FOOD_FROM_POT: AudioStream = preload("res://assets/SFX/Taking-food-from-the-steel-pot-sound-effect-360686.ogg")
const UI_CLICK: AudioStream = preload("res://assets/SFX/u_u4pf5h7zip-click-345983.ogg")
const FRIDGE: AudioStream = preload("res://assets/SFX/freesound_community-fridge-94795.ogg")
const MENU_MUSIC_TRACKS: Array[AudioStream] = [
	preload("res://assets/Music/Mekong-Drift-Chill.ogg"),
	preload("res://assets/Music/Mekong-Drift-EDM.ogg"),
]
const INGAME_MUSIC_TRACKS: Array[AudioStream] = [
	preload("res://assets/Music/Floating Market Morning.mp3"),
	preload("res://assets/Music/Stir Fry Sprint (Chapter1backgroundmusic).ogg"),
]
## Nhạc "ký ức" êm đềm — nổi lên khi Nam vào vùng kỷ vật sau tủ lạnh.
const MEMORY_THEME: AudioStream = preload("res://assets/Music/beautiful_dream.mp3")

# Mức âm khi vào/ra chế độ ký ức.
const INGAME_BASE_DB := -14.0
const INGAME_DUCK_DB := -30.0
const RIVER_BASE_DB := -18.0
const RIVER_DUCK_DB := -34.0
const MEMORY_LOUD_DB := -3.0
const MEMORY_SILENT_DB := -40.0
const MEMORY_FADE_IN := 1.3
const MEMORY_FADE_OUT := 1.1

var _menu_music_player: AudioStreamPlayer
var _ingame_music_player: AudioStreamPlayer
var _river_player: AudioStreamPlayer
var _walking_player: AudioStreamPlayer
var _memory_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _menu_music_should_loop := false
var _ingame_music_should_loop := false
var _ingame_track_index := -1
var _river_should_loop := false
var _walking_should_loop := false
var _memory_should_loop := false
var _memory_mode_active := false
var _ingame_music_tween: Tween
var _memory_tween: Tween
var _river_duck_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_audio_buses()
	_setup_loop_players()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_connect_existing_buttons")
	call_deferred("_assign_existing_audio_buses")


func play_water_splash() -> void:
	_play_one_shot(WATER_SPLASH, -2.0)


func play_wrong_food() -> void:
	_play_one_shot(WRONG_FOOD, -3.0)


func play_right_food() -> void:
	_play_one_shot(RIGHT_FOOD, -3.0)


func play_lose() -> void:
	_play_one_shot(LOSE, -4.0)


func play_win() -> void:
	_play_one_shot(WIN, -3.0)


func play_take_empty_bowl() -> void:
	_play_one_shot(TAKE_EMPTY_BOWL, -5.0)


func play_take_food_from_pot() -> void:
	_play_one_shot(TAKE_FOOD_FROM_POT, -5.0)


func play_ui_click() -> void:
	_play_one_shot(UI_CLICK, -8.0)


func play_fridge() -> void:
	_play_one_shot(FRIDGE, -5.0)


func play_menu_music() -> void:
	if _menu_music_player == null:
		return
	_menu_music_should_loop = true
	if _menu_music_player.playing:
		return

	var track: AudioStream = MENU_MUSIC_TRACKS.pick_random()
	_menu_music_player.stream = _duplicate_looped_stream(track)
	_menu_music_player.volume_db = -12.0
	_menu_music_player.play()


func stop_menu_music() -> void:
	_menu_music_should_loop = false
	if _menu_music_player != null:
		_menu_music_player.stop()


func play_ingame_music_for_level() -> void:
	if _ingame_music_player == null or INGAME_MUSIC_TRACKS.is_empty():
		return

	stop_menu_music()
	stop_scene_chapter_music()
	_ingame_music_should_loop = true
	_play_ingame_track(_pick_random_ingame_track(false))


func change_ingame_music() -> void:
	if _ingame_music_player == null or INGAME_MUSIC_TRACKS.is_empty():
		return

	_ingame_music_should_loop = true
	_play_ingame_track(_pick_random_ingame_track(true))


func stop_ingame_music() -> void:
	_ingame_music_should_loop = false
	_ingame_track_index = -1
	if _ingame_music_tween and _ingame_music_tween.is_valid():
		_ingame_music_tween.kill()
	if _ingame_music_player != null:
		_ingame_music_player.stop()


func set_ingame_music_paused(is_paused: bool) -> void:
	if _ingame_music_player != null:
		_ingame_music_player.stream_paused = is_paused


func is_ingame_music_playing() -> bool:
	return _ingame_music_player != null and _ingame_music_player.playing


func stop_scene_chapter_music() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var legacy_music := scene.find_child("Chapter1Music", true, false) as AudioStreamPlayer
	if legacy_music != null:
		legacy_music.stop()
		legacy_music.stream_paused = true


func play_river_loop() -> void:
	if _river_player == null:
		return
	_river_should_loop = true
	if _river_player.playing:
		return

	_river_player.stream = _duplicate_looped_stream(RIVER)
	_river_player.volume_db = -18.0
	_river_player.play()


func stop_river_loop() -> void:
	_river_should_loop = false
	if _river_player != null:
		_river_player.stop()


func set_player_walking(is_walking: bool) -> void:
	if _walking_player == null:
		return

	if is_walking:
		_walking_should_loop = true
		if not _walking_player.playing:
			_walking_player.stream = _duplicate_looped_stream(WALKING_ON_WOOD)
			_walking_player.volume_db = -12.0
			_walking_player.play()
	else:
		_walking_should_loop = false
		_walking_player.stop()


func stop_player_walking() -> void:
	_walking_should_loop = false
	if _walking_player != null:
		_walking_player.stop()


func play_boiling_loop(parent: Node) -> AudioStreamPlayer3D:
	if parent == null:
		return null

	var player := AudioStreamPlayer3D.new()
	player.name = "BoKhoBoilingSFX"
	player.stream = _duplicate_looped_stream(BOILING_FOOD)
	player.volume_db = -10.0
	player.bus = SFX_BUS
	player.max_distance = 9.0
	parent.add_child(player)
	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.play()
	)
	player.play()
	return player


func _setup_loop_players() -> void:
	_menu_music_player = AudioStreamPlayer.new()
	_menu_music_player.name = "MenuMusic"
	_menu_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_music_player.bus = MUSIC_BUS
	_menu_music_player.finished.connect(_restart_menu_music)
	add_child(_menu_music_player)

	_ingame_music_player = AudioStreamPlayer.new()
	_ingame_music_player.name = "IngameMusic"
	_ingame_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ingame_music_player.bus = MUSIC_BUS
	_ingame_music_player.finished.connect(_restart_ingame_music)
	add_child(_ingame_music_player)

	_river_player = AudioStreamPlayer.new()
	_river_player.name = "RiverSFX"
	_river_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_river_player.bus = SFX_BUS
	_river_player.finished.connect(_restart_river_loop)
	add_child(_river_player)

	_walking_player = AudioStreamPlayer.new()
	_walking_player.name = "WalkingOnWoodSFX"
	_walking_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_walking_player.bus = SFX_BUS
	_walking_player.finished.connect(_restart_walking_loop)
	add_child(_walking_player)

	_memory_player = AudioStreamPlayer.new()
	_memory_player.name = "MemoryTheme"
	# PAUSABLE: nhạc ký ức tự im khi mở ESC (game pause), không phát đè menu tạm dừng.
	_memory_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_memory_player.bus = MUSIC_BUS
	_memory_player.finished.connect(_restart_memory_theme)
	add_child(_memory_player)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoiceOver"
	_voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_voice_player.bus = VOICE_BUS
	add_child(_voice_player)


func _restart_menu_music() -> void:
	if _menu_music_should_loop and _menu_music_player != null:
		var track: AudioStream = MENU_MUSIC_TRACKS.pick_random()
		_menu_music_player.stream = _duplicate_looped_stream(track)
		_menu_music_player.play()


func _restart_ingame_music() -> void:
	if _ingame_music_should_loop and _ingame_music_player != null:
		_ingame_music_player.play()


func _restart_river_loop() -> void:
	if _river_should_loop and _river_player != null:
		_river_player.play()


func _restart_walking_loop() -> void:
	if _walking_should_loop and _walking_player != null:
		_walking_player.play()


# ---------- Chế độ "ký ức" (vùng kỷ vật sau tủ lạnh) ----------
## Vào vùng ký ức: hạ tiếng sông xuống, nổi nhạc êm đềm lên to hơn.
func enter_memory_mode() -> void:
	_memory_should_loop = true
	_memory_mode_active = true
	if _ingame_music_player != null and _ingame_music_player.playing:
		if _ingame_music_tween and _ingame_music_tween.is_valid():
			_ingame_music_tween.kill()
		_ingame_music_tween = create_tween()
		_ingame_music_tween.tween_property(_ingame_music_player, "volume_db", INGAME_DUCK_DB, MEMORY_FADE_IN)
	# Hạ tiếng sông.
	if _river_player != null:
		if _river_duck_tween and _river_duck_tween.is_valid():
			_river_duck_tween.kill()
		_river_duck_tween = create_tween()
		_river_duck_tween.tween_property(_river_player, "volume_db", RIVER_DUCK_DB, MEMORY_FADE_IN)
	# Nổi nhạc ký ức.
	if _memory_player != null:
		if _memory_player.stream == null:
			_memory_player.stream = _duplicate_looped_stream(MEMORY_THEME)
		if not _memory_player.playing:
			_memory_player.volume_db = MEMORY_SILENT_DB
			_memory_player.play()
		if _memory_tween and _memory_tween.is_valid():
			_memory_tween.kill()
		_memory_tween = create_tween()
		_memory_tween.tween_property(_memory_player, "volume_db", MEMORY_LOUD_DB, MEMORY_FADE_IN)


## Rời vùng ký ức: trả tiếng sông về cũ, mờ dần rồi tắt nhạc ký ức.
func exit_memory_mode() -> void:
	_memory_should_loop = false
	_memory_mode_active = false
	if _ingame_music_player != null and _ingame_music_player.playing:
		if _ingame_music_tween and _ingame_music_tween.is_valid():
			_ingame_music_tween.kill()
		_ingame_music_tween = create_tween()
		_ingame_music_tween.tween_property(_ingame_music_player, "volume_db", INGAME_BASE_DB, MEMORY_FADE_OUT)
	if _river_player != null:
		if _river_duck_tween and _river_duck_tween.is_valid():
			_river_duck_tween.kill()
		_river_duck_tween = create_tween()
		_river_duck_tween.tween_property(_river_player, "volume_db", RIVER_BASE_DB, MEMORY_FADE_OUT)
	if _memory_player != null:
		if _memory_tween and _memory_tween.is_valid():
			_memory_tween.kill()
		_memory_tween = create_tween()
		_memory_tween.tween_property(_memory_player, "volume_db", MEMORY_SILENT_DB, MEMORY_FADE_OUT)
		_memory_tween.tween_callback(func() -> void:
			if is_instance_valid(_memory_player):
				_memory_player.stop())


func _restart_memory_theme() -> void:
	if _memory_should_loop and _memory_player != null:
		_memory_player.play()


func _play_one_shot(stream: AudioStream, volume_db: float = 0.0) -> void:
	play_pitched(stream, volume_db, 1.0)


## Phát SFX với cao độ tuỳ chỉnh (dùng cho ding combo lên tông dần).
func play_pitched(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "OneShotSFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = volume_db
	player.bus = SFX_BUS
	player.pitch_scale = clampf(pitch, 0.1, 4.0)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_voice(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or _voice_player == null:
		return
	_voice_player.stop()
	_voice_player.stream = stream
	_voice_player.volume_db = volume_db
	_voice_player.play()


func play_voice_file(path: String, volume_db: float = 0.0) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	play_voice(load(path) as AudioStream, volume_db)


func stop_voice() -> void:
	if _voice_player != null:
		_voice_player.stop()


func set_music_volume(value: float) -> void:
	_set_bus_volume(MUSIC_BUS, value)


func set_sfx_volume(value: float) -> void:
	_set_bus_volume(SFX_BUS, value)


func set_voice_volume(value: float) -> void:
	_set_bus_volume(VOICE_BUS, value)


func get_music_volume() -> float:
	return _get_bus_volume(MUSIC_BUS)


func get_sfx_volume() -> float:
	return _get_bus_volume(SFX_BUS)


func get_voice_volume() -> float:
	return _get_bus_volume(VOICE_BUS)


func _ensure_audio_buses() -> void:
	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)
	_ensure_audio_bus(VOICE_BUS)


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clampf(value, 0.0, 1.0), 0.001)))


func _get_bus_volume(bus_name: StringName) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.8
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func _assign_existing_audio_buses() -> void:
	_assign_audio_bus_recursive(get_tree().root)


func _assign_audio_bus_recursive(node: Node) -> void:
	_assign_known_audio_bus(node)
	for child in node.get_children():
		_assign_audio_bus_recursive(child)


func _assign_known_audio_bus(node: Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer3D):
		return
	var name_lower := node.name.to_lower()
	if "music" in name_lower or "theme" in name_lower:
		node.set("bus", MUSIC_BUS)


## Ding combo: cao độ tăng dần theo số combo (rất "đã tai").
func play_combo_ding(combo: int) -> void:
	var pitch: float = clampf(1.0 + float(combo) * 0.12, 1.0, 2.4)
	play_pitched(UI_CLICK, -3.0, pitch)


func _play_ingame_track(track_index: int) -> void:
	if track_index < 0 or track_index >= INGAME_MUSIC_TRACKS.size():
		return

	_ingame_track_index = track_index
	_ingame_music_player.stop()
	_ingame_music_player.stream = _duplicate_looped_stream(INGAME_MUSIC_TRACKS[track_index])
	_ingame_music_player.stream_paused = false
	_ingame_music_player.volume_db = INGAME_DUCK_DB if _memory_mode_active else INGAME_BASE_DB
	_ingame_music_player.play()


func _pick_random_ingame_track(avoid_current: bool) -> int:
	if INGAME_MUSIC_TRACKS.is_empty():
		return -1
	if INGAME_MUSIC_TRACKS.size() == 1:
		return 0

	var candidates: Array[int] = []
	for index in range(INGAME_MUSIC_TRACKS.size()):
		if not avoid_current or index != _ingame_track_index:
			candidates.append(index)
	if candidates.is_empty():
		return _rng.randi_range(0, INGAME_MUSIC_TRACKS.size() - 1)
	return int(candidates[_rng.randi_range(0, candidates.size() - 1)])


func _duplicate_looped_stream(source: AudioStream) -> AudioStream:
	if source == null:
		return null

	var stream := source.duplicate() as AudioStream
	if stream == null:
		return source

	_set_property_if_exists(stream, "loop", true)
	return stream


func _set_property_if_exists(object: Object, property_name: String, value: Variant) -> void:
	for property_info in object.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			object.set(property_name, value)
			return


func _on_node_added(node: Node) -> void:
	_assign_known_audio_bus(node)
	if node is BaseButton:
		call_deferred("_connect_button", node)


func _connect_existing_buttons() -> void:
	_connect_buttons_recursive(get_tree().root)


func _connect_buttons_recursive(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)

	for child in node.get_children():
		_connect_buttons_recursive(child)


func _connect_button(node: Node) -> void:
	var button := node as BaseButton
	if button == null or not is_instance_valid(button):
		return
	if bool(button.get_meta("audio_click_connected", false)):
		return

	button.set_meta("audio_click_connected", true)
	button.pressed.connect(play_ui_click)
