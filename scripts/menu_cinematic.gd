extends Node3D

const LOADING_RING_SCRIPT: Script = preload("res://scripts/loading_ring.gd")
const LOGO_TEXTURE: Texture2D = preload("res://assets/UI/LogoGame.png")

@export var camera_path: NodePath = ^"MainCamera"
@export var nam_chef_path: NodePath = ^"NamChef"
@export var animation_player_path: NodePath = ^"NamChef/Nam/AnimationPlayer"
@export var idle_animation: StringName = &"idle"
@export var play_button_path: NodePath = ^"MenuUI/MenuButtons/PlayButton"
@export var settings_button_path: NodePath = ^"MenuUI/MenuButtons/SettingsButton"
@export var credits_button_path: NodePath = ^"MenuUI/MenuButtons/CreditsButton"
@export var exit_button_path: NodePath = ^"MenuUI/MenuButtons/ExitButton"
@export var menu_buttons_path: NodePath = ^"MenuUI/MenuButtons"
@export_file("*.tscn") var gameplay_scene_path: String = "res://scenes/comic_intro.tscn"
var direct_gameplay_scene_path: String = ""
@export var intro_duration: float = 4.2
@export var menu_fade_duration: float = 0.8
@export_range(0.5, 1.2, 0.05) var button_idle_scale: float = 0.8
@export_range(0.5, 1.3, 0.05) var button_hover_scale: float = 0.92
@export_range(0.05, 0.5, 0.01) var button_hover_duration: float = 0.12
@export var button_vertical_offset: float = 0.0
@export var start_offset: Vector3 = Vector3(0.0, 10.5, 12.0)
@export var end_offset: Vector3 = Vector3(-0.8, 2.15, 4.8)
@export var look_offset: Vector3 = Vector3(-1.25, 1.2, 0.0)
@export var start_fov: float = 68.0
@export var end_fov: float = 52.0

var _camera: Camera3D
var _nam_chef: Node3D
var _menu_buttons: Control
var _intro_tween: Tween
var _button_paths: Array[NodePath] = []
var _button_tweens: Dictionary = {}
var _button_base_sizes: Dictionary = {}
var _is_loading_gameplay := false
var _loading_canvas: CanvasLayer
var _loading_ring: Control
var _logo_rect: TextureRect

func _ready() -> void:
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	AudioManager.play_menu_music()
	_camera = get_node_or_null(camera_path) as Camera3D
	_nam_chef = get_node_or_null(nam_chef_path) as Node3D
	_menu_buttons = get_node_or_null(menu_buttons_path) as Control
	_button_paths = [
		play_button_path,
		settings_button_path,
		credits_button_path,
		exit_button_path,
	]

	if _camera == null or _nam_chef == null:
		push_warning("Menu cinematic needs MainCamera and NamChef in the menu scene.")
		return

	_prepare_logo()
	_prepare_menu_visibility()
	_prepare_nam_chef()
	_prepare_camera_intro()
	_prepare_menu_buttons()


func _process(_delta: float) -> void:
	_look_at_nam_chef()
	if _is_loading_gameplay:
		_poll_gameplay_load()


func _prepare_logo() -> void:
	var menu_ui = get_node_or_null("MenuUI")
	if menu_ui == null:
		return
	
	_logo_rect = TextureRect.new()
	_logo_rect.name = "LogoRect"
	_logo_rect.texture = LOGO_TEXTURE
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.texture_filter = Control.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	
	_logo_rect.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_logo_rect.offset_left = -520.0
	_logo_rect.offset_top = 20.0
	_logo_rect.offset_right = -20.0
	_logo_rect.offset_bottom = 270.0
	
	menu_ui.add_child(_logo_rect)


func _prepare_nam_chef() -> void:
	if _nam_chef is CharacterBody3D:
		(_nam_chef as CharacterBody3D).velocity = Vector3.ZERO

	# The menu owns NamChef's pose; gameplay movement will be re-enabled in gameplay scenes.
	_nam_chef.set_process(false)
	_nam_chef.set_physics_process(false)

	var animation_player := get_node_or_null(animation_player_path) as AnimationPlayer
	if animation_player != null and animation_player.has_animation(idle_animation):
		animation_player.play(idle_animation)


func _prepare_camera_intro() -> void:
	if _intro_tween != null:
		_intro_tween.kill()

	_camera.current = true
	_camera.set_process(false)
	_camera.set_physics_process(false)
	_camera.fov = start_fov

	var target_origin := _nam_chef.global_position
	_camera.global_position = target_origin + start_offset
	_look_at_nam_chef()

	_intro_tween = create_tween()
	_intro_tween.tween_property(
		_camera,
		"global_position",
		target_origin + end_offset,
		intro_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.parallel().tween_property(
		_camera,
		"fov",
		end_fov,
		intro_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(_finish_camera_intro)


func _finish_camera_intro() -> void:
	_camera.global_position = _nam_chef.global_position + end_offset
	_camera.fov = end_fov
	_look_at_nam_chef()
	_show_menu_buttons()


func _look_at_nam_chef() -> void:
	if _camera == null or _nam_chef == null:
		return

	_camera.look_at(_nam_chef.global_position + look_offset)


func _prepare_menu_buttons() -> void:
	_connect_button(play_button_path, _on_play_pressed)
	_connect_button(settings_button_path, _on_settings_pressed)
	_connect_button(credits_button_path, _on_credits_pressed)
	_connect_button(exit_button_path, _on_exit_pressed)

	for button_path in _button_paths:
		var button := get_node_or_null(button_path) as BaseButton
		if button != null:
			_prepare_button_hover(button)

	_recenter_menu_buttons()


func _connect_button(button_path: NodePath, callback: Callable) -> void:
	var button := get_node_or_null(button_path) as BaseButton
	if button == null:
		return

	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _prepare_button_hover(button: BaseButton) -> void:
	var base_size := button.custom_minimum_size
	if base_size == Vector2.ZERO:
		base_size = button.size

	_button_base_sizes[button] = base_size
	button.custom_minimum_size = base_size * button_idle_scale
	button.size = button.custom_minimum_size
	button.scale = Vector2.ONE
	call_deferred("_refresh_button_pivot", button)

	var hover_scale := button_hover_scale / button_idle_scale
	var hover_in := Callable(self, "_animate_button_scale").bind(button, hover_scale)
	var hover_out := Callable(self, "_animate_button_scale").bind(button, 1.0)

	if not button.mouse_entered.is_connected(hover_in):
		button.mouse_entered.connect(hover_in)
	if not button.mouse_exited.is_connected(hover_out):
		button.mouse_exited.connect(hover_out)
	if not button.focus_entered.is_connected(hover_in):
		button.focus_entered.connect(hover_in)
	if not button.focus_exited.is_connected(hover_out):
		button.focus_exited.connect(hover_out)


func _animate_button_scale(button: BaseButton, target_scale: float) -> void:
	button.pivot_offset = button.size * 0.5

	var existing_tween := _button_tweens.get(button) as Tween
	if existing_tween != null:
		existing_tween.kill()

	var tween := create_tween()
	_button_tweens[button] = tween
	tween.tween_property(
		button,
		"scale",
		Vector2.ONE * target_scale,
		button_hover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_button_pivot(button: BaseButton) -> void:
	if is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


func _recenter_menu_buttons() -> void:
	if _menu_buttons == null:
		return

	var separation := _menu_buttons.get_theme_constant("separation")
	var total_height := 0.0
	var max_width := 0.0
	var visible_button_count := 0

	for button_path in _button_paths:
		var button := get_node_or_null(button_path) as Control
		if button == null:
			continue

		var button_size := button.custom_minimum_size
		total_height += button_size.y
		max_width = max(max_width, button_size.x)
		visible_button_count += 1

	if visible_button_count > 1:
		total_height += separation * (visible_button_count - 1)

	_menu_buttons.custom_minimum_size = Vector2(max_width, total_height)
	_menu_buttons.size = Vector2(max_width, total_height)
	_menu_buttons.offset_top = -total_height * 0.5 + button_vertical_offset
	_menu_buttons.offset_bottom = total_height * 0.5 + button_vertical_offset
	_menu_buttons.offset_left = 0.0
	_menu_buttons.offset_right = max_width

	for button_path in _button_paths:
		var button := get_node_or_null(button_path) as BaseButton
		if button != null:
			call_deferred("_refresh_button_pivot", button)


func _prepare_menu_visibility() -> void:
	if _menu_buttons != null:
		_menu_buttons.modulate.a = 0.0
	if _logo_rect != null:
		_logo_rect.modulate.a = 0.0

	for button_path in _button_paths:
		var button := get_node_or_null(button_path) as BaseButton
		if button != null:
			button.disabled = true


func _show_menu_buttons() -> void:
	if _menu_buttons != null:
		var fade_tween := create_tween()
		fade_tween.tween_property(_menu_buttons, "modulate:a", 1.0, menu_fade_duration)
		if _logo_rect != null:
			fade_tween.parallel().tween_property(_logo_rect, "modulate:a", 1.0, menu_fade_duration)
		fade_tween.tween_callback(_enable_menu_buttons)
	else:
		_enable_menu_buttons()


func _enable_menu_buttons() -> void:
	if _is_loading_gameplay:
		return

	for button_path in _button_paths:
		var button := get_node_or_null(button_path) as BaseButton
		if button != null:
			button.disabled = false


func _on_play_pressed() -> void:
	if _is_loading_gameplay:
		return

	AudioManager.stop_menu_music()

	if PauseMenu.has_played_intro:
		gameplay_scene_path = "res://scenes/chapter1.tscn" if SaveManager.has_completed_tutorial() else "res://scenes/tutorial.tscn"
	else:
		PauseMenu.has_played_intro = true

	_is_loading_gameplay = true
	_set_menu_buttons_disabled(true)
	_show_loading_ring(0.0)

	var error: int = ResourceLoader.load_threaded_request(gameplay_scene_path)
	if error != OK:
		push_error("Cannot start threaded loading for %s. Error: %s" % [gameplay_scene_path, error])
		_is_loading_gameplay = false
		_hide_loading_ring()
		_set_menu_buttons_disabled(false)


func _poll_gameplay_load() -> void:
	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(gameplay_scene_path, progress)

	if not progress.is_empty():
		_show_loading_ring(float(progress[0]))

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene_resource: Resource = ResourceLoader.load_threaded_get(gameplay_scene_path) as Resource
			var packed_scene := scene_resource as PackedScene
			if packed_scene == null:
				push_error("Loaded gameplay resource is not a PackedScene: %s" % gameplay_scene_path)
				_is_loading_gameplay = false
				_hide_loading_ring()
				_set_menu_buttons_disabled(false)
				return

			_is_loading_gameplay = false
			var error: int = get_tree().change_scene_to_packed(packed_scene)
			if error != OK:
				push_error("Cannot change to gameplay scene %s. Error: %s" % [gameplay_scene_path, error])
				_is_loading_gameplay = false
				_hide_loading_ring()
				_set_menu_buttons_disabled(false)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to load gameplay scene: %s" % gameplay_scene_path)
			_is_loading_gameplay = false
			_hide_loading_ring()
			_set_menu_buttons_disabled(false)


func _set_menu_buttons_disabled(is_disabled: bool) -> void:
	for button_path in _button_paths:
		var button := get_node_or_null(button_path) as BaseButton
		if button != null:
			button.disabled = is_disabled


func _show_loading_ring(progress: float) -> void:
	_ensure_loading_ring()
	if _loading_canvas == null or _loading_ring == null:
		return

	_loading_ring.call("set_progress", progress)
	_loading_canvas.visible = true


func _hide_loading_ring() -> void:
	if _loading_canvas != null:
		_loading_canvas.visible = false


func _ensure_loading_ring() -> void:
	if _loading_canvas != null and _loading_ring != null:
		return

	_loading_canvas = CanvasLayer.new()
	_loading_canvas.name = "LoadingCanvas"
	_loading_canvas.layer = 50
	add_child(_loading_canvas)

	var ring := LOADING_RING_SCRIPT.new() as Control
	ring.name = "LoadingRing"
	ring.anchor_left = 1.0
	ring.anchor_top = 1.0
	ring.anchor_right = 1.0
	ring.anchor_bottom = 1.0
	ring.offset_left = -78.0
	ring.offset_top = -78.0
	ring.offset_right = -24.0
	ring.offset_bottom = -24.0
	_loading_canvas.add_child(ring)

	_loading_ring = ring
	_loading_canvas.visible = false


func _on_settings_pressed() -> void:
	print("Settings menu is not implemented yet.")


func _on_credits_pressed() -> void:
	print("Credits menu is not implemented yet.")


func _on_exit_pressed() -> void:
	get_tree().quit()
