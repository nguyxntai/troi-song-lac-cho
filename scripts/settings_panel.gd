extends CanvasLayer
class_name SettingsPanel

signal closed

const SETTINGS_PATH := "user://settings.cfg"

var _root: Control
var _music_slider: HSlider
var _sfx_slider: HSlider
var _voice_slider: HSlider
var _music_value: Label
var _sfx_value: Label
var _voice_value: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func open() -> void:
	_load_values()
	visible = true


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.64)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_close())
	_root.add_child(dim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(540.0, 390.0)
	box.offset_left = -270.0
	box.offset_top = -195.0
	box.offset_right = 270.0
	box.offset_bottom = 195.0
	box.add_theme_stylebox_override("panel", UIStyle.wood_panel(16, 22, true))
	_root.add_child(box)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	box.add_child(content)

	var title := Label.new()
	title.text = "CÀI ĐẶT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_title(title, 30)
	content.add_child(title)

	_music_slider = _create_audio_row(content, "Nhạc nền", _on_music_changed)
	_sfx_slider = _create_audio_row(content, "Hiệu ứng", _on_sfx_changed)
	_voice_slider = _create_audio_row(content, "Lồng tiếng", _on_voice_changed)

	var close_button := Button.new()
	close_button.text = "Xong"
	close_button.custom_minimum_size = Vector2(180.0, 54.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.style_button(close_button, UIStyle.GOLD, 22)
	close_button.pressed.connect(_close)
	content.add_child(close_button)


func _load_values() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	var music_volume := 0.8
	var sfx_volume := 0.8
	var voice_volume := 0.8
	if err == OK:
		music_volume = float(config.get_value("audio", "music_volume", music_volume))
		sfx_volume = float(config.get_value("audio", "sfx_volume", sfx_volume))
		voice_volume = float(config.get_value("audio", "voice_volume", voice_volume))
	_music_slider.set_value_no_signal(clampf(music_volume, 0.0, 1.0))
	_sfx_slider.set_value_no_signal(clampf(sfx_volume, 0.0, 1.0))
	_voice_slider.set_value_no_signal(clampf(voice_volume, 0.0, 1.0))
	_apply_audio_values()


func _create_audio_row(content: VBoxContainer, title: String, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(140.0, 38.0)
	UIStyle.style_label(label, UIStyle.FS_BODY)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(230.0, 38.0)
	UIStyle.style_slider_wood(slider)
	slider.value_changed.connect(callback)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58.0, 38.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.style_label(value_label, 18, UIStyle.GOLD_TEXT)
	row.add_child(value_label)
	match title:
		"Nhạc nền": _music_value = value_label
		"Hiệu ứng": _sfx_value = value_label
		"Lồng tiếng": _voice_value = value_label
	return slider


func _on_music_changed(_value: float) -> void:
	_apply_audio_values()
	_save_values()


func _on_sfx_changed(_value: float) -> void:
	_apply_audio_values()
	_save_values()


func _on_voice_changed(_value: float) -> void:
	_apply_audio_values()
	_save_values()


func _apply_audio_values() -> void:
	AudioManager.set_music_volume(_music_slider.value)
	AudioManager.set_sfx_volume(_sfx_slider.value)
	AudioManager.set_voice_volume(_voice_slider.value)
	_music_value.text = "%d%%" % int(round(_music_slider.value * 100.0))
	_sfx_value.text = "%d%%" % int(round(_sfx_slider.value * 100.0))
	_voice_value.text = "%d%%" % int(round(_voice_slider.value * 100.0))


func _save_values() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", _music_slider.value)
	config.set_value("audio", "sfx_volume", _sfx_slider.value)
	config.set_value("audio", "voice_volume", _voice_slider.value)
	config.save(SETTINGS_PATH)


func _close() -> void:
	visible = false
	closed.emit()
