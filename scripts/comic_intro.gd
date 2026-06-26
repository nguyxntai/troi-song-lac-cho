extends Control

const LOADING_RING_SCRIPT: Script = preload("res://scripts/loading_ring.gd")
var gameplay_scene_path := ""
const REFERENCE_SIZE := Vector2(1672.0, 941.0)
const PAGE_TEXTURES := [
	"res://assets/comic/chapter1/page_01_full.png",
	"res://assets/comic/chapter1/page_02_full.png",
]
const SKIP_BUTTON_TEXTURE := "res://assets/comic/chapter1/skip_button.png"
const HINTS := [
	"Nhấn chuột hoặc Skip để chuyển nhanh qua trang truyện.",
	"Nam đang chuẩn bị trở về miền Tây.",
	"Phục vụ đúng món khách gọi để qua ngày.",
	"Đừng để Nam rơi khỏi ghe khi di chuyển.",
]

@export var page_duration: float = 10.0
@export var page_fade_duration: float = 0.42
@export var skip_button_width: float = 190.0
@export var bottom_ui_height: float = 96.0

var _page_root: Control
var _page_view: TextureRect
var _fade_rect: ColorRect
var _skip_button: TextureButton
var _loading_ring: Control
var _hint_label: Label
var _current_page := 0
var _page_elapsed := 0.0
var _hint_elapsed := 0.0
var _hint_index := 0
var _loading_elapsed := 0.0
var _is_transitioning := false
var _is_finishing := false
var _is_gameplay_loading := false
var _is_ready_to_transition := false


func _ready() -> void:
	AudioManager.stop_menu_music()
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_scene()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	_show_page(0, true)
	_start_intro()
	
	gameplay_scene_path = "res://scenes/chapter1.tscn" if SaveManager.has_completed_tutorial() else "res://scenes/tutorial.tscn"

	_loading_ring.call("set_progress", 0.0)
	var error: int = ResourceLoader.load_threaded_request(gameplay_scene_path)
	if error == OK:
		_is_gameplay_loading = true
	else:
		push_error("Cannot start threaded loading for %s. Error: %s" % [gameplay_scene_path, error])


func _process(delta: float) -> void:
	if _is_gameplay_loading:
		_poll_gameplay_load()

	if _is_finishing:
		return

	_update_hint(delta)
	_update_skip_button()

	if _is_transitioning or _is_last_page():
		return

	_page_elapsed += delta
	if _page_elapsed >= page_duration:
		_go_to_next_page()


func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing or _is_transitioning:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_advance_or_start_game()


func _gui_input(event: InputEvent) -> void:
	if _is_finishing or _is_transitioning:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_advance_or_start_game()


func _build_scene() -> void:
	_setup_background()
	_setup_page()
	_setup_bottom_ui()
	_setup_skip_button()
	_setup_fade()


func _setup_background() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.025, 0.023, 0.027, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)


func _setup_page() -> void:
	_page_root = Control.new()
	_page_root.name = "ComicPage"
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_root)

	_page_view = TextureRect.new()
	_page_view.name = "Page"
	_page_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_page_view.stretch_mode = TextureRect.STRETCH_SCALE
	_page_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(_page_view)


func _setup_bottom_ui() -> void:
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.74, 1.0))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	_hint_label.add_theme_constant_override("shadow_offset_x", 2)
	_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)

	_loading_ring = LOADING_RING_SCRIPT.new() as Control
	_loading_ring.name = "ComicLoadingRing"
	_loading_ring.set("ring_size", 42.0)
	_loading_ring.set("ring_width", 6.0)
	_loading_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loading_ring)


func _setup_skip_button() -> void:
	_skip_button = TextureButton.new()
	_skip_button.name = "SkipButton"
	_skip_button.texture_normal = load(SKIP_BUTTON_TEXTURE)
	_skip_button.texture_hover = _skip_button.texture_normal
	_skip_button.texture_pressed = _skip_button.texture_normal
	_skip_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_skip_button.ignore_texture_size = true
	_skip_button.tooltip_text = "Skip"
	_skip_button.pressed.connect(_advance_or_start_game)
	add_child(_skip_button)


func _setup_fade() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)


func _relayout() -> void:
	if not _page_root:
		return

	var viewport_size := get_viewport_rect().size
	var available_height := maxf(viewport_size.y - bottom_ui_height, 1.0)
	var scale_factor := minf(viewport_size.x / REFERENCE_SIZE.x, available_height / REFERENCE_SIZE.y)
	var page_size := REFERENCE_SIZE * scale_factor
	_page_root.position = Vector2((viewport_size.x - page_size.x) * 0.5, maxf((available_height - page_size.y) * 0.5, 0.0))
	_page_root.size = page_size
	_page_root.pivot_offset = page_size * 0.5

	_page_view.position = Vector2.ZERO
	_page_view.size = page_size

	var bottom_top := viewport_size.y - bottom_ui_height
	_hint_label.position = Vector2(0.0, bottom_top + 24.0)
	_hint_label.size = Vector2(viewport_size.x, 42.0)

	var ring_size := Vector2(56.0, 56.0)
	_loading_ring.size = ring_size

	var skip_aspect := 3.0
	if _skip_button.texture_normal:
		var texture_size := _skip_button.texture_normal.get_size()
		if texture_size.y > 0.0:
			skip_aspect = texture_size.x / texture_size.y
	var skip_size := Vector2(skip_button_width, skip_button_width / skip_aspect)
	var skip_margin := Vector2(22.0, 18.0)
	
	_loading_ring.position = Vector2(viewport_size.x - ring_size.x - skip_margin.x, viewport_size.y - ring_size.y - skip_margin.y)

	_skip_button.size = skip_size
	_skip_button.position = Vector2(viewport_size.x - skip_size.x - skip_margin.x, skip_margin.y)
	_skip_button.pivot_offset = skip_size * 0.5


func _start_intro() -> void:
	_set_hint(0)
	var fade_tween := create_tween()
	fade_tween.tween_property(_fade_rect, "color:a", 0.0, 0.45)


func _show_page(index: int, instant: bool = false) -> void:
	_current_page = clampi(index, 0, PAGE_TEXTURES.size() - 1)
	_page_elapsed = 0.0
	_page_view.texture = load(String(PAGE_TEXTURES[_current_page]))
	_page_view.modulate = Color.WHITE
	if instant:
		_page_root.scale = Vector2.ONE


func _advance_or_start_game() -> void:
	if _is_last_page():
		_start_gameplay()
	else:
		_go_to_next_page()


func _go_to_next_page() -> void:
	if _is_transitioning or _is_finishing:
		return

	_is_transitioning = true
	var next_page := mini(_current_page + 1, PAGE_TEXTURES.size() - 1)
	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(_page_view, "modulate:a", 0.0, page_fade_duration * 0.7)
	tween_out.tween_property(_page_root, "scale", Vector2.ONE * 1.018, page_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

	_show_page(next_page)
	_page_root.scale = Vector2.ONE * 0.985
	var tween_in := create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(_page_view, "modulate:a", 1.0, page_fade_duration)
	tween_in.tween_property(_page_root, "scale", Vector2.ONE, page_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween_in.finished
	_is_transitioning = false


func _start_gameplay() -> void:
	if _is_finishing:
		return
	_is_finishing = true
	_skip_button.disabled = true

	var exit_tween := create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(_skip_button, "modulate:a", 0.0, 0.18)
	exit_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.18)
	exit_tween.tween_property(_page_root, "scale", Vector2.ONE * 1.025, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	exit_tween.tween_property(_fade_rect, "color:a", 0.6, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await exit_tween.finished
	
	_is_ready_to_transition = true
	
	if not _is_gameplay_loading:
		get_tree().change_scene_to_file(gameplay_scene_path)


func _poll_gameplay_load() -> void:
	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(gameplay_scene_path, progress)

	if not progress.is_empty():
		_loading_ring.call("set_progress", float(progress[0]))

	if not _is_ready_to_transition:
		return

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene_resource: Resource = ResourceLoader.load_threaded_get(gameplay_scene_path) as Resource
			var packed_scene := scene_resource as PackedScene
			if packed_scene:
				_is_gameplay_loading = false
				get_tree().change_scene_to_packed(packed_scene)
			else:
				push_error("Loaded gameplay resource is not a PackedScene: %s" % gameplay_scene_path)
				_is_gameplay_loading = false
				get_tree().change_scene_to_file(gameplay_scene_path)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_gameplay_loading = false
			get_tree().change_scene_to_file(gameplay_scene_path)


func _update_hint(delta: float) -> void:
	_hint_elapsed += delta
	if _hint_elapsed >= 5.0:
		_hint_elapsed = 0.0
		_set_hint((_hint_index + 1) % HINTS.size())


func _set_hint(index: int) -> void:
	_hint_index = index
	_hint_label.text = String(HINTS[_hint_index])
	var tween := create_tween()
	tween.tween_property(_hint_label, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void: _hint_label.text = String(HINTS[_hint_index]))
	tween.tween_property(_hint_label, "modulate:a", 1.0, 0.18)


func _update_skip_button() -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 3.0) * 0.025
	_skip_button.scale = Vector2.ONE * pulse


func _is_last_page() -> bool:
	return _current_page >= PAGE_TEXTURES.size() - 1
