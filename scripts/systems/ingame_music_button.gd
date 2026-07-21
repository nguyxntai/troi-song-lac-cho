extends CanvasLayer

const BUTTON_SIZE := Vector2(48.0, 48.0)
const BUTTON_OFFSET := Vector2(-266.0, 18.0)

var _button: Button
var _hover_tween: Tween


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_visibility()


func _process(_delta: float) -> void:
	_refresh_visibility()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_button = Button.new()
	_button.name = "MusicSwapIcon"
	_button.text = String.chr(0x266B)
	_button.tooltip_text = "Doi nhac nen"
	_button.custom_minimum_size = BUTTON_SIZE
	_button.size = BUTTON_SIZE
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_button.offset_left = BUTTON_OFFSET.x
	_button.offset_top = BUTTON_OFFSET.y
	_button.offset_right = BUTTON_OFFSET.x + BUTTON_SIZE.x
	_button.offset_bottom = BUTTON_OFFSET.y + BUTTON_SIZE.y
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.add_theme_font_size_override("font_size", 28)
	_button.add_theme_color_override("font_color", UIStyle.GOLD_TEXT)
	_button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.54))
	_button.add_theme_color_override("font_pressed_color", Color(0.85, 0.52, 0.12))
	_button.add_theme_color_override("font_outline_color", UIStyle.OUTLINE_DARK)
	_button.add_theme_constant_override("outline_size", 4)
	_button.add_theme_stylebox_override("normal", _button_style(Color(0.20, 0.11, 0.05, 0.90), UIStyle.GOLD))
	_button.add_theme_stylebox_override("hover", _button_style(Color(0.30, 0.17, 0.07, 0.96), Color(1.0, 0.74, 0.30)))
	_button.add_theme_stylebox_override("pressed", _button_style(Color(0.14, 0.08, 0.04, 0.96), Color(0.72, 0.42, 0.14)))
	_button.pressed.connect(_on_pressed)
	_button.mouse_entered.connect(_animate.bind(1.08))
	_button.mouse_exited.connect(_animate.bind(1.0))
	root.add_child(_button)


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _on_pressed() -> void:
	AudioManager.change_ingame_music()
	_animate(1.0)


func _animate(target_scale: float) -> void:
	if _button == null:
		return
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_button.pivot_offset = _button.size * 0.5
	_hover_tween = create_tween()
	_hover_tween.tween_property(_button, "scale", Vector2.ONE * target_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_visibility() -> void:
	visible = AudioManager.is_ingame_music_playing() and not get_tree().paused
