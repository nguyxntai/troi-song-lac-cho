extends CanvasLayer

## Màn tổng kết cuối ngày: panel gỗ miền Tây, huy chương "đóng dấu" có animation,
## điểm đếm tăng, kỷ lục, cấp bậc, nút Chơi lại / Về Menu.
## day_manager gọi show_results(); nút uỷ thác cho GameOverManager để tải lại scene.

const WOOD_DARK := Color(0.32, 0.20, 0.11, 0.98)
const WOOD_MID := Color(0.46, 0.30, 0.17, 1.0)
const CREAM := Color(1.0, 0.96, 0.86, 1.0)

var _root: Control
var _title_label: Label
var _medal_panel: Panel
var _medal_label: Label
var _score_label: Label
var _detail_label: Label
var _record_label: Label
var _rank_label: Label
var _replay_btn: Button
var _menu_btn: Button

var _gom: Node
var _shown: bool = false
var _score_display: int = 0
var _count_tween: Tween


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func show_results(results: Dictionary, is_win: bool, header: String) -> void:
	if _shown:
		return
	_shown = true
	_gom = get_tree().current_scene.find_child("GameOverManager", true, false)

	# Tạm dừng & âm thanh.
	AudioManager.stop_player_walking()
	AudioManager.stop_river_loop()
	_stop_chapter_music()
	if is_win:
		AudioManager.play_win()
	else:
		AudioManager.play_lose()

	_populate(results, is_win, header)
	_root.visible = true
	get_tree().paused = true
	_animate_in(results, is_win)


func _populate(results: Dictionary, is_win: bool, header: String) -> void:
	_title_label.text = header
	_title_label.add_theme_color_override("font_color", CREAM if is_win else Color(1.0, 0.7, 0.55))

	var medal: int = int(results.get("medal", 0))
	var medal_color: Color = results.get("medal_color", Color(0.7, 0.7, 0.7))
	_medal_label.text = String(results.get("medal_name", "Chưa đạt"))
	var sb: StyleBoxFlat = _medal_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.bg_color = medal_color.darkened(0.1)
		sb.border_color = CREAM
	_medal_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.0) if medal >= 2 else CREAM)

	var stars: int = clampi(int(results.get("five_stars", 0)), 0, 9)
	_detail_label.text = "%s  5 sao\nSai: %d   ·   Lỡ khách: %d" % [
		("★".repeat(stars) if stars > 0 else "0"),
		int(results.get("wrong", 0)),
		int(results.get("missed", 0)),
	]

	if bool(results.get("is_record", false)):
		_record_label.text = "★  KỶ LỤC MỚI!  ★"
		_record_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		_record_label.text = "Kỷ lục: %d" % int(results.get("best", 0))
		_record_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))

	_rank_label.text = "Cấp bậc: %s" % GameManager.get_rank_title()
	_score_display = 0
	_score_label.text = "0"


func _animate_in(results: Dictionary, is_win: bool) -> void:
	# Panel bật vào.
	var box: Control = _root.get_node("Box")
	box.scale = Vector2(0.7, 0.7)
	box.modulate.a = 0.0
	box.pivot_offset = Vector2(260, 270)
	var t := box.create_tween()
	t.set_parallel(true)
	t.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(box, "modulate:a", 1.0, 0.25)

	# Huy chương "đóng dấu".
	_medal_panel.pivot_offset = _medal_panel.size * 0.5
	_medal_panel.scale = Vector2(2.6, 2.6)
	_medal_panel.rotation = deg_to_rad(-18.0)
	_medal_panel.modulate.a = 0.0
	var mt := _medal_panel.create_tween()
	mt.tween_interval(0.35)
	mt.set_parallel(true)
	mt.tween_property(_medal_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mt.tween_property(_medal_panel, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_BACK)
	mt.tween_property(_medal_panel, "modulate:a", 1.0, 0.18)
	mt.chain().tween_callback(func():
		Juice.shake_small()
		AudioManager.play_combo_ding(int(results.get("medal", 0)) * 3))

	# Điểm đếm tăng.
	var target_score: int = int(results.get("score", 0))
	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_interval(0.6)
	_count_tween.tween_method(_set_score_display, 0, target_score, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if is_win:
		var player: Node = get_tree().current_scene.find_child("NamChef", true, false)
		if player is Node3D:
			Juice.confetti((player as Node3D).global_position + Vector3.UP * 2.2, 100)


func _set_score_display(value: float) -> void:
	_score_display = int(round(value))
	if _score_label:
		_score_label.text = "%d" % _score_display


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	_root.add_child(dim)

	# Hộp gỗ.
	var box := PanelContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(520, 540)
	box.offset_left = -260
	box.offset_top = -270
	box.offset_right = 260
	box.offset_bottom = 270
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = WOOD_DARK
	box_style.border_color = WOOD_MID
	box_style.set_border_width_all(6)
	box_style.set_corner_radius_all(22)
	box_style.set_content_margin_all(22)
	box_style.shadow_color = Color(0, 0, 0, 0.5)
	box_style.shadow_size = 16
	box.add_theme_stylebox_override("panel", box_style)
	_root.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)

	_title_label = _make_label("", 30, CREAM)
	vbox.add_child(_title_label)

	# Huy chương tròn.
	var medal_center := CenterContainer.new()
	vbox.add_child(medal_center)
	_medal_panel = Panel.new()
	_medal_panel.custom_minimum_size = Vector2(150, 150)
	var medal_style := StyleBoxFlat.new()
	medal_style.bg_color = Color(0.7, 0.7, 0.7)
	medal_style.set_corner_radius_all(75)
	medal_style.border_color = CREAM
	medal_style.set_border_width_all(5)
	_medal_panel.add_theme_stylebox_override("panel", medal_style)
	medal_center.add_child(_medal_panel)

	_medal_label = _make_label("", 22, CREAM)
	_medal_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_medal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_medal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_medal_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_medal_panel.add_child(_medal_label)

	_score_label = _make_label("0", 56, Color(1.0, 0.92, 0.45))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_score_label)
	var score_cap := _make_label("ĐIỂM", 16, Color(0.8, 0.75, 0.6))
	score_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_cap)

	_detail_label = _make_label("", 19, CREAM)
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_detail_label)

	_record_label = _make_label("", 22, Color(0.85, 0.82, 0.7))
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_record_label)

	_rank_label = _make_label("", 18, Color(0.95, 0.9, 0.75))
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_rank_label)

	# Nút.
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	_replay_btn = _make_button("Chơi lại", Color(0.85, 0.5, 0.2))
	_replay_btn.pressed.connect(_on_replay)
	btn_row.add_child(_replay_btn)

	_menu_btn = _make_button("Về Menu", Color(0.4, 0.45, 0.5))
	_menu_btn.pressed.connect(_on_menu)
	btn_row.add_child(_menu_btn)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.0, 1.0))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 54)
	b.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.15)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", CREAM)
	return b


func _on_replay() -> void:
	AudioManager.play_ui_click()
	if _gom and _gom.has_method("restart_current_scene"):
		_gom.call("restart_current_scene")
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_menu() -> void:
	AudioManager.play_ui_click()
	if _gom and _gom.has_method("go_to_menu"):
		_gom.call("go_to_menu")
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.scn")


func _stop_chapter_music() -> void:
	var music: Node = get_tree().current_scene.find_child("Chapter1Music", true, false)
	if music and music.has_method("stop"):
		music.call("stop")
