extends CanvasLayer

## Hướng dẫn ngắn trong lúc chơi. Hai luồng được thiết kế theo thứ tự ảnh:
## xá xị 73 -> 74, và thả món bằng Q 76 -> 75.
var _root: Control
var _title: Label
var _description: Label
var _key: Label
var _hide_tween: Tween
var _drink_step_shown := false
var _drop_step_shown := false


func _ready() -> void:
	layer = 9
	_build_ui()
	EventBus.drink_taken.connect(_on_drink_taken)
	EventBus.food_picked_up.connect(_on_food_picked_up)
	EventBus.food_manually_dropped.connect(_on_food_manually_dropped)
	EventBus.tutorial_dialogue_completed.connect(_on_tutorial_dialogue_completed)


func _on_tutorial_dialogue_completed() -> void:
	if not GameManager.should_show_new_player_guidelines:
		return
	_show(
		"HƯỚNG DẪN XÁ XỊ · 1/2",
		"Đến gần tủ lạnh và nhấn E để lấy lon xá xị khi tay đang trống.",
		"E",
		7.0
	)


func _on_drink_taken() -> void:
	if _drink_step_shown:
		return
	_drink_step_shown = true
	_show(
		"HƯỚNG DẪN XÁ XỊ · 2/2",
		"Mang lon xá xị đến vị khách gọi nước, rồi nhấn E để phục vụ đúng chỗ.",
		"E",
		8.0
	)


func _on_food_picked_up(_food_id: String) -> void:
	if _drop_step_shown:
		return
	_drop_step_shown = true
	_show(
		"THẢ ĐỒ ĂN · 1/2",
		"Khi đang cầm món, nhấn Q để thả món xuống nước. Hãy cẩn thận vì món có thể bị trôi mất.",
		"Q",
		8.0
	)


func _on_food_manually_dropped(_food_id: String) -> void:
	_show(
		"THẢ ĐỒ ĂN · 2/2",
		"Món đã được thả. Bạn có thể nhặt lại nếu còn kịp, hoặc chuẩn bị món mới để tiếp tục phục vụ.",
		"Q",
		7.0
	)


func _show(title_text: String, description_text: String, key_text: String, duration: float) -> void:
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_title.text = title_text
	_description.text = description_text
	_key.text = key_text
	_root.visible = true
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duration)
	tween.tween_property(_root, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_root):
			_root.visible = false)
	_hide_tween = tween


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.name = "GameplayGuidelines"
	_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_root.offset_left = 34.0
	_root.offset_top = -226.0
	_root.offset_right = 620.0
	_root.offset_bottom = -34.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_stylebox_override("panel", UIStyle.wood_panel(16, 18, true))
	add_child(_root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_root.add_child(row)

	_key = Label.new()
	_key.custom_minimum_size = Vector2(72, 72)
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.style_label(_key, 40, UIStyle.GOLD_TEXT, 6)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.12, 0.06, 0.02, 0.95)
	key_style.border_color = UIStyle.GOLD
	key_style.set_border_width_all(3)
	key_style.set_corner_radius_all(12)
	_key.add_theme_stylebox_override("normal", key_style)
	row.add_child(_key)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)

	_title = Label.new()
	UIStyle.style_title(_title, 20)
	text_box.add_child(_title)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.style_label(_description, 17, UIStyle.CREAM, 4)
	text_box.add_child(_description)
	_root.visible = false
