extends CanvasLayer

const BG_TEXTURE := preload("res://assets/UI/pause_menu/pause_vietnamese_clean.png")
const BTN_RESUME: Texture2D = preload("res://assets/UI/pause_menu/buttons/resume.png")
const BTN_SETTINGS: Texture2D = preload("res://assets/UI/pause_menu/buttons/settings.png")
const BTN_MAIN_MENU: Texture2D = preload("res://assets/UI/pause_menu/buttons/main_menu.png")
const BTN_EXIT: Texture2D = preload("res://assets/UI/pause_menu/buttons/exit.png")

# Vùng bấm theo tỉ lệ artwork mới: resume, settings, menu, exit.
const BUTTON_RECTS := [
	Rect2(0.339, 0.302, 0.322, 0.145),
	Rect2(0.339, 0.474, 0.322, 0.145),
	Rect2(0.339, 0.645, 0.322, 0.145),
	Rect2(0.339, 0.814, 0.322, 0.145),
]
const SETTINGS_PANEL_SCRIPT: Script = preload("res://scripts/settings_panel.gd")

@export var fade_duration: float = 0.2
@export var button_hover_scale: float = 1.08
@export var button_hover_duration: float = 0.1
@export var button_hover_lift: float = 10.0

var has_played_intro: bool = false

var _overlay: ColorRect
var _bg_rect: TextureRect
var _button_tweens: Dictionary = {}

var _buttons: Array[TextureButton] = []
var _button_base_positions: Dictionary = {}
var _btn_resume: TextureButton
var _btn_settings: TextureButton
var _btn_main_menu: TextureButton
var _btn_exit: TextureButton
var _settings_panel: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	
	_build_ui()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _build_ui() -> void:
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	
	# Background Board
	_bg_rect = TextureRect.new()
	_bg_rect.texture = BG_TEXTURE
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_bg_rect)
	
	# Nút thật được đặt lên artwork để có thể nhô lên khi hover.
	_btn_resume = _create_button(BTN_RESUME, "Trở lại trò chơi", _on_resume_pressed)
	_btn_settings = _create_button(BTN_SETTINGS, "Cài đặt chung", _on_settings_pressed)
	_btn_main_menu = _create_button(BTN_MAIN_MENU, "Menu chính", _on_main_menu_pressed)
	_btn_exit = _create_button(BTN_EXIT, "Thoát game", _on_exit_pressed)


func _create_button(texture: Texture2D, tooltip: String, callback: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = texture
	btn.texture_hover = texture
	btn.texture_pressed = texture
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.tooltip_text = tooltip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.z_index = 2
	
	btn.pressed.connect(callback)
	
	# Hover effects
	var hover_in := Callable(self, "_animate_button_scale").bind(btn, button_hover_scale)
	var hover_out := Callable(self, "_animate_button_scale").bind(btn, 1.0)
	btn.mouse_entered.connect(hover_in)
	btn.mouse_exited.connect(hover_out)
	btn.focus_entered.connect(hover_in)
	btn.focus_exited.connect(hover_out)
	
	_bg_rect.add_child(btn)
	_buttons.append(btn)
	return btn


func _relayout() -> void:
	if not _bg_rect:
		return
		
	var vp_size := get_viewport().get_visible_rect().size
	
	# Scale background to fit reasonably on screen
	var base_bg_size := Vector2(1154.0, 866.0) # approximate original scale
	if BG_TEXTURE:
		base_bg_size = BG_TEXTURE.get_size()
		
	var scale_factor := minf(vp_size.x / base_bg_size.x * 0.8, vp_size.y / base_bg_size.y * 0.9)
	var final_bg_size := base_bg_size * scale_factor
	
	# Đặt _bg_rect khớp đúng kích thước texture đã scale, canh giữa viewport.
	# Dùng EXPAND_IGNORE_SIZE + STRETCH_SCALE để texture lấp đầy rect, không padding.
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_rect.size = final_bg_size
	_bg_rect.position = (vp_size - final_bg_size) * 0.5
	
	for index in _buttons.size():
		var rect: Rect2 = BUTTON_RECTS[index] as Rect2
		var btn: TextureButton = _buttons[index]
		btn.position = rect.position * final_bg_size
		btn.size = rect.size * final_bg_size
		btn.scale = Vector2.ONE
		btn.pivot_offset = btn.size * 0.5
		_button_base_positions[btn] = btn.position


func _animate_button_scale(btn: TextureButton, target_scale: float) -> void:
	var existing_tween := _button_tweens.get(btn) as Tween
	if existing_tween != null:
		existing_tween.kill()

	var tween := create_tween()
	_button_tweens[btn] = tween
	var base_position: Vector2 = _button_base_positions.get(btn, btn.position)
	var target_position := base_position
	if target_scale > 1.0:
		target_position.y -= button_hover_lift
	tween.set_parallel(true)
	tween.tween_property(
		btn,
		"scale",
		Vector2.ONE * target_scale,
		button_hover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		btn,
		"position",
		target_position,
		button_hover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Only allow pause in gameplay scenes (e.g. not main menu)
		var root := get_tree().current_scene
		if root and (root.name == "Chapter1" or "chapter" in root.name.to_lower()):
			var gom: Node = root.find_child("GameOverManager", true, false)
			if gom and gom.get("_is_game_over") == true:
				return
			
			_toggle_pause()


func _toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	
	if tree.paused:
		AudioManager.set_ingame_music_paused(true)
		_relayout() # Ensure sizing is correct on show
		visible = true
		_overlay.color.a = 0.0
		_bg_rect.modulate.a = 0.0
		var tween := create_tween()
		tween.parallel().tween_property(_overlay, "color:a", 0.6, fade_duration)
		tween.parallel().tween_property(_bg_rect, "modulate:a", 1.0, fade_duration)
	else:
		var tween := create_tween()
		tween.parallel().tween_property(_overlay, "color:a", 0.0, fade_duration)
		tween.parallel().tween_property(_bg_rect, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(func(): visible = false)
		AudioManager.set_ingame_music_paused(false)


func _on_resume_pressed() -> void:
	_toggle_pause()


func _on_settings_pressed() -> void:
	if _settings_panel == null:
		_settings_panel = SETTINGS_PANEL_SCRIPT.new() as Node
		add_child(_settings_panel)
	_settings_panel.call("open")


func _on_main_menu_pressed() -> void:
	AudioManager.stop_ingame_music()
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/menu.scn")


func _on_exit_pressed() -> void:
	get_tree().quit()
