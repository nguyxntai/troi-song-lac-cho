extends Node

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

var _menu_music_player: AudioStreamPlayer
var _river_player: AudioStreamPlayer
var _walking_player: AudioStreamPlayer
var _menu_music_should_loop := false
var _river_should_loop := false
var _walking_should_loop := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_loop_players()
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_connect_existing_buttons")


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
	_menu_music_player.finished.connect(_restart_menu_music)
	add_child(_menu_music_player)

	_river_player = AudioStreamPlayer.new()
	_river_player.name = "RiverSFX"
	_river_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_river_player.finished.connect(_restart_river_loop)
	add_child(_river_player)

	_walking_player = AudioStreamPlayer.new()
	_walking_player.name = "WalkingOnWoodSFX"
	_walking_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_walking_player.finished.connect(_restart_walking_loop)
	add_child(_walking_player)


func _restart_menu_music() -> void:
	if _menu_music_should_loop and _menu_music_player != null:
		var track: AudioStream = MENU_MUSIC_TRACKS.pick_random()
		_menu_music_player.stream = _duplicate_looped_stream(track)
		_menu_music_player.play()


func _restart_river_loop() -> void:
	if _river_should_loop and _river_player != null:
		_river_player.play()


func _restart_walking_loop() -> void:
	if _walking_should_loop and _walking_player != null:
		_walking_player.play()


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
	player.pitch_scale = clampf(pitch, 0.1, 4.0)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Ding combo: cao độ tăng dần theo số combo (rất "đã tai").
func play_combo_ding(combo: int) -> void:
	var pitch: float = clampf(1.0 + float(combo) * 0.12, 1.0, 2.4)
	play_pitched(UI_CLICK, -3.0, pitch)


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
