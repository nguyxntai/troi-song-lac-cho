extends CanvasLayer

const BG_TEXTURE := preload("res://assets/UI/pause_menu/pause_bg.png")
const BTN_RESUME := preload("res://assets/UI/pause_menu/btn_resume.png")
const BTN_SETTINGS := preload("res://assets/UI/pause_menu/btn_settings.png")
const BTN_MAIN_MENU := preload("res://assets/UI/pause_menu/btn_main_menu.png")
const BTN_EXIT := preload("res://assets/UI/pause_menu/btn_exit.png")

@export var fade_duration: float = 0.2
@export var button_hover_scale: float = 1.08
@export var button_hover_duration: float = 0.1

var has_played_intro: bool = false

var _overlay: ColorRect
var _bg_rect: TextureRect
var _button_container: VBoxContainer
var _button_tweens: Dictionary = {}

var _btn_resume: TextureButton
var _btn_settings: TextureButton
var _btn_main_menu: TextureButton
var _btn_exit: TextureButton

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
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_bg_rect)
	
	# VBox for Buttons
	_button_container = VBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 16)
	_bg_rect.add_child(_button_container)
	
	# Create Buttons
	_btn_resume = _create_button(BTN_RESUME, _on_resume_pressed)
	_btn_settings = _create_button(BTN_SETTINGS, _on_settings_pressed)
	_btn_main_menu = _create_button(BTN_MAIN_MENU, _on_main_menu_pressed)
	_btn_exit = _create_button(BTN_EXIT, _on_exit_pressed)


func _create_button(tex: Texture2D, callback: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.texture_pressed = tex
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.ignore_texture_size = true
	
	# Scale setup
	btn.pivot_offset = btn.size * 0.5
	
	btn.pressed.connect(callback)
	
	# Hover effects
	var hover_in := Callable(self, "_animate_button_scale").bind(btn, button_hover_scale)
	var hover_out := Callable(self, "_animate_button_scale").bind(btn, 1.0)
	btn.mouse_entered.connect(hover_in)
	btn.mouse_exited.connect(hover_out)
	btn.focus_entered.connect(hover_in)
	btn.focus_exited.connect(hover_out)
	
	_button_container.add_child(btn)
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
	
	_bg_rect.size = final_bg_size
	_bg_rect.position = (vp_size - final_bg_size) * 0.5
	
	# Layout buttons container inside background
	# The buttons should go exactly where the empty space is in the background.
	# From the image, the empty scroll space is roughly the center-right.
	# We'll just center the VBoxContainer with a slight offset.
	_button_container.size = Vector2(final_bg_size.x * 0.6, final_bg_size.y * 0.6)
	_button_container.position = Vector2(final_bg_size.x * 0.25, final_bg_size.y * 0.25)
	
	# Size buttons relative to container
	var btn_height := final_bg_size.y * 0.11
	for btn in _button_container.get_children():
		var t_btn := btn as TextureButton
		if not t_btn: continue
		var aspect := 3.0
		if t_btn.texture_normal:
			aspect = t_btn.texture_normal.get_size().x / t_btn.texture_normal.get_size().y
		
		t_btn.custom_minimum_size = Vector2(btn_height * aspect, btn_height)
		t_btn.pivot_offset = t_btn.custom_minimum_size * 0.5


func _animate_button_scale(btn: TextureButton, target_scale: float) -> void:
	var existing_tween := _button_tweens.get(btn) as Tween
	if existing_tween != null:
		existing_tween.kill()

	var tween := create_tween()
	_button_tweens[btn] = tween
	tween.tween_property(
		btn,
		"scale",
		Vector2.ONE * target_scale,
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


func _on_resume_pressed() -> void:
	_toggle_pause()


func _on_settings_pressed() -> void:
	print("Settings menu clicked: Not implemented yet!")


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/menu.scn")


func _on_exit_pressed() -> void:
	get_tree().quit()
