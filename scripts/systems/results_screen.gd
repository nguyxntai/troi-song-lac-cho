extends CanvasLayer

## Màn tổng kết cuối ngày: panel gỗ miền Tây, huy chương "đóng dấu" có animation,
## điểm đếm tăng, kỷ lục, cấp bậc, nút Chơi lại / Về Menu.
## day_manager gọi show_results(); nút uỷ thác cho GameOverManager để tải lại scene.

const WOOD_DARK := Color(0.32, 0.20, 0.11, 0.98)
const WOOD_MID := Color(0.46, 0.30, 0.17, 1.0)
const CREAM := Color(1.0, 0.96, 0.86, 1.0)

var _root: Control
var _title_label: Label
var _box: PanelContainer
var _medal_panel: Panel
var _medal_label: Label
var _score_label: Label
var _detail_label: Label
var _record_label: Label
var _rank_label: Label
var _served_value: Label
var _five_star_value: Label
var _wrong_value: Label
var _missed_value: Label
var _best_value: Label
var _replay_btn: Button
var _upgrade_btn: Button
var _contribute_btn: Button
var _menu_btn: Button

var _contrib_panel: Control
var _contrib_info: Label

var _gom: Node
var _shown: bool = false
var _was_win: bool = false
var _was_tutorial: bool = false
var _day_completed: bool = false
var _base_header: String = ""
var _chapter_advanced: bool = false
var _chapter_completed: bool = false
var _next_scene_path: String = ""
var _completed_chapter_index: int = 0
var _score_display: int = 0
var _count_tween: Tween
var _layout_scale: float = 1.0


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_root.visible = false


func show_results(results: Dictionary, is_win: bool, header: String) -> void:
	if _shown:
		return
	_shown = true
	_was_win = is_win
	_was_tutorial = bool(results.get("is_tutorial", false))
	_day_completed = false
	_gom = get_tree().current_scene.find_child("GameOverManager", true, false)

	# Tạm dừng & âm thanh.
	AudioManager.stop_player_walking()
	AudioManager.stop_river_loop()
	_stop_chapter_music()
	if is_win:
		AudioManager.play_win()
	else:
		AudioManager.play_lose()

	_base_header = header
	_populate(results, is_win, header)
	_upgrade_btn.visible = is_win and not _was_tutorial
	_contribute_btn.visible = is_win and not _was_tutorial and GameManager.get_stage_money_goal() > 0 and not GameManager.is_stage_goal_met()
	_update_action_button()
	_root.visible = true
	get_tree().paused = true
	_animate_in(results, is_win)


## Cập nhật nhãn nút chính + tiêu đề theo trạng thái hoàn thành chương HIỆN TẠI
## (gọi lại sau khi người chơi đóng góp — vì đóng đủ mục tiêu là qua chương).
func _update_action_button() -> void:
	if _was_tutorial and _was_win:
		_replay_btn.text = "Tiếp tục"
		return
	if not _was_win:
		_replay_btn.text = "Chơi lại"
		return
	var ch: int = GameManager.chapter_index
	if SaveManager.is_chapter_completed(ch):
		_title_label.text = "CHƯƠNG %d HOÀN THÀNH!" % ch
		if ch >= 3:
			_replay_btn.text = "Xem kết thúc"
			_rank_label.text = "Nam và Huyền tổ chức đám cưới trên sông. Gia đình đoàn tụ và chiếc ghe trở thành quán ăn nổi tiếng nhất bến chợ."
		else:
			_replay_btn.text = "Sang Chương %d" % (ch + 1)
	else:
		_replay_btn.text = "Ngày tiếp"


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

	var stars: int = maxi(int(results.get("five_stars", 0)), 0)
	_detail_label.text = "HIỆU SUẤT PHỤC VỤ"
	_served_value.text = "%d khách" % int(results.get("served", 0))
	_five_star_value.text = "%d" % stars
	_wrong_value.text = "%d" % int(results.get("wrong", 0))
	_missed_value.text = "%d" % int(results.get("missed", 0))
	_best_value.text = "%d điểm" % int(results.get("best", 0))

	if bool(results.get("is_record", false)):
		_record_label.text = "★  KỶ LỤC MỚI!  ★"
		_record_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		_record_label.text = "Kỷ lục: %d" % int(results.get("best", 0))
		_record_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))

	var epilogue: String = String(results.get("story_epilogue", ""))
	_rank_label.text = epilogue if not epilogue.is_empty() else "Cấp bậc: %s" % GameManager.get_rank_title()
	_rank_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_display = 0
	_score_label.text = "0"


func _animate_in(results: Dictionary, is_win: bool) -> void:
	# Panel bật vào.
	_box.scale = Vector2.ONE * (_layout_scale * 0.7)
	_box.modulate.a = 0.0
	_box.pivot_offset = _box.size * 0.5
	var t := _box.create_tween()
	t.set_parallel(true)
	t.tween_property(_box, "scale", Vector2.ONE * _layout_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_box, "modulate:a", 1.0, 0.25)

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
	_box = PanelContainer.new()
	_box.name = "Box"
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.custom_minimum_size = Vector2(620, 650)
	_box.offset_left = -310
	_box.offset_top = -325
	_box.offset_right = 310
	_box.offset_bottom = 325
	_box.add_theme_stylebox_override("panel", UIStyle.wood_panel(20, 22, true))
	_root.add_child(_box)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_box.add_child(vbox)

	_title_label = _make_label("", 30, CREAM)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.custom_minimum_size = Vector2(0, 46)
	vbox.add_child(_title_label)

	var overview := HBoxContainer.new()
	overview.alignment = BoxContainer.ALIGNMENT_CENTER
	overview.add_theme_constant_override("separation", 18)
	overview.custom_minimum_size = Vector2(0, 350)
	overview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(overview)

	var score_column := VBoxContainer.new()
	score_column.alignment = BoxContainer.ALIGNMENT_CENTER
	score_column.custom_minimum_size = Vector2(190, 0)
	score_column.add_theme_constant_override("separation", 8)
	overview.add_child(score_column)

	var medal_center := CenterContainer.new()
	score_column.add_child(medal_center)
	_medal_panel = Panel.new()
	_medal_panel.custom_minimum_size = Vector2(164, 164)
	var medal_style := StyleBoxFlat.new()
	medal_style.bg_color = Color(0.7, 0.7, 0.7)
	medal_style.set_corner_radius_all(82)
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

	_score_label = _make_label("0", 54, Color(1.0, 0.92, 0.45))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_column.add_child(_score_label)
	var score_cap := _make_label("TỔNG ĐIỂM", 16, Color(0.8, 0.75, 0.6))
	score_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_column.add_child(score_cap)

	_record_label = _make_label("", 19, Color(0.85, 0.82, 0.7))
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_label.custom_minimum_size = Vector2(210, 32)
	score_column.add_child(_record_label)

	var divider := ColorRect.new()
	divider.color = Color(0.85, 0.66, 0.34, 0.45)
	divider.custom_minimum_size = Vector2(2, 286)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.add_child(divider)

	var summary_column := VBoxContainer.new()
	summary_column.custom_minimum_size = Vector2(348, 0)
	summary_column.add_theme_constant_override("separation", 12)
	overview.add_child(summary_column)

	_detail_label = _make_label("", 21, Color(1.0, 0.84, 0.28))
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_column.add_child(_detail_label)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 10)
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_column.add_child(stats_grid)
	_served_value = _add_stat_row(stats_grid, "Khách đã phục vụ")
	_five_star_value = _add_stat_row(stats_grid, "Đánh giá 5 sao")
	_wrong_value = _add_stat_row(stats_grid, "Giao sai món")
	_missed_value = _add_stat_row(stats_grid, "Khách bỏ đi")
	_best_value = _add_stat_row(stats_grid, "Kỷ lục ngày")

	var rank_divider := HSeparator.new()
	rank_divider.modulate = Color(0.85, 0.66, 0.34, 0.6)
	summary_column.add_child(rank_divider)

	_rank_label = _make_label("", 18, Color(0.95, 0.9, 0.75))
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rank_label.custom_minimum_size = Vector2(348, 96)
	summary_column.add_child(_rank_label)

	var btn_grid := GridContainer.new()
	btn_grid.columns = 2
	btn_grid.add_theme_constant_override("h_separation", 16)
	btn_grid.add_theme_constant_override("v_separation", 10)
	btn_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(btn_grid)

	_replay_btn = _make_button("Chơi lại", Color(0.85, 0.5, 0.2))
	_replay_btn.pressed.connect(_on_replay)
	btn_grid.add_child(_replay_btn)

	_contribute_btn = _make_button("Đóng góp", Color(0.82, 0.62, 0.18))
	_contribute_btn.pressed.connect(_on_contribute)
	btn_grid.add_child(_contribute_btn)

	_upgrade_btn = _make_button("Nâng cấp", Color(0.25, 0.62, 0.38))
	_upgrade_btn.pressed.connect(_on_upgrade)
	btn_grid.add_child(_upgrade_btn)

	_menu_btn = _make_button("Về Menu", Color(0.4, 0.45, 0.5))
	_menu_btn.pressed.connect(_on_menu)
	btn_grid.add_child(_menu_btn)


func _relayout() -> void:
	if not _box:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var available_size: Vector2 = viewport_size - Vector2(24.0, 24.0)
	_layout_scale = minf(1.0, minf(available_size.x / 620.0, available_size.y / 650.0))
	_box.pivot_offset = _box.size * 0.5
	_box.scale = Vector2.ONE * _layout_scale


func _add_stat_row(grid: GridContainer, title: String) -> Label:
	var title_label := _make_label(title, 18, Color(0.88, 0.84, 0.72))
	grid.add_child(title_label)
	var value_label := _make_label("0", 19, CREAM)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value_label)
	return value_label


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	UIStyle.style_label(l, size, color)
	return l


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 50)
	UIStyle.style_button(b, color, 20)
	return b


func _on_replay() -> void:
	AudioManager.play_ui_click()
	var tree := get_tree()

	# Tutorial xong -> vào Chương 1.
	if _was_tutorial and _was_win:
		tree.paused = false
		tree.change_scene_to_file("res://scenes/chapter1.tscn")
		return

	# Chốt ngày Ở ĐÂY (sau khi đã đóng góp), để việc qua chương phản ánh đúng.
	_ensure_day_completed()
	tree.paused = false

	# Hoàn thành Chương 3 -> màn đám cưới.
	if GameManager.chapter_completed_after_last_day and GameManager.last_completed_chapter_index == 3:
		tree.change_scene_to_file("res://scenes/wedding_finale.tscn")
		return
	# Vừa qua chương mới -> vào chương kế.
	if GameManager.chapter_advanced_after_last_day:
		tree.change_scene_to_file(GameManager.get_active_chapter_scene())
		return
	# Thắng nhưng chưa qua chương -> ngày kế (nạp lại scene chương hiện tại).
	if _was_win:
		if _gom and _gom.has_method("restart_current_scene"):
			_gom.call("restart_current_scene")
		else:
			tree.reload_current_scene()
		return
	# Thua -> chơi lại ngày đó.
	if _gom and _gom.has_method("restart_current_scene"):
		_gom.call("restart_current_scene")
	else:
		tree.reload_current_scene()


func _ensure_day_completed() -> void:
	if _day_completed:
		return
	_day_completed = true
	GameManager.complete_day(_was_win)


func _on_upgrade() -> void:
	if not _was_win:
		return
	var shop: Node = get_tree().current_scene.find_child("ShopPanel", true, false)
	if shop == null or not shop.has_method("open_for_day_end"):
		return
	AudioManager.play_ui_click()
	_root.visible = false
	var close_callback := Callable(self, "_on_shop_closed")
	if shop.has_signal("closed") and not shop.is_connected("closed", close_callback):
		shop.connect("closed", close_callback)
	shop.call("open_for_day_end", -1)


func _on_shop_closed() -> void:
	_root.visible = true


# ---------- Đóng góp mục tiêu (trừ tiền khỏi ví chung) ----------
func _on_contribute() -> void:
	if GameManager.get_stage_money_goal() <= 0:
		return
	AudioManager.play_ui_click()
	_ensure_contrib_panel()
	_refresh_contrib()
	_root.visible = false
	_contrib_panel.visible = true


func _ensure_contrib_panel() -> void:
	if _contrib_panel != null:
		return

	_contrib_panel = Control.new()
	_contrib_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contrib_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_contrib_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_contrib_panel.visible = false
	add_child(_contrib_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	_contrib_panel.add_child(dim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(460, 300)
	box.offset_left = -230
	box.offset_top = -150
	box.offset_right = 230
	box.offset_bottom = 150
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = WOOD_DARK
	box_style.border_color = WOOD_MID
	box_style.set_border_width_all(5)
	box_style.set_corner_radius_all(18)
	box_style.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", box_style)
	_contrib_panel.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)

	var title := _make_label("ĐÓNG GÓP MỤC TIÊU", 26, Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_contrib_info = _make_label("", 20, CREAM)
	_contrib_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contrib_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_contrib_info)

	var amount_row := HBoxContainer.new()
	amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_row.add_theme_constant_override("separation", 12)
	vbox.add_child(amount_row)
	var btn100 := _make_button("+100 VND", Color(0.82, 0.62, 0.18))
	btn100.pressed.connect(_contribute_amount.bind(100))
	amount_row.add_child(btn100)
	var btn300 := _make_button("+300 VND", Color(0.82, 0.62, 0.18))
	btn300.pressed.connect(_contribute_amount.bind(300))
	amount_row.add_child(btn300)
	var btn_all := _make_button("Đóng hết", Color(0.85, 0.45, 0.2))
	btn_all.pressed.connect(_contribute_amount.bind(999999))
	amount_row.add_child(btn_all)

	var done := _make_button("Xong", Color(0.4, 0.45, 0.5))
	done.pressed.connect(_on_contrib_done)
	vbox.add_child(done)


func _contribute_amount(amount: int) -> void:
	var paid: int = GameManager.contribute_to_goal(amount)
	if paid > 0:
		AudioManager.play_combo_ding(2)
	_refresh_contrib()


func _refresh_contrib() -> void:
	if _contrib_info == null:
		return
	var goal: int = GameManager.get_stage_money_goal()
	var fund: int = GameManager.get_stage_fund()
	_contrib_info.text = "Ví của bạn: %s\nMục tiêu: %s / %s\nCòn thiếu: %s" % [
		Currency.format_vnd(GameManager.money), Currency.format_vnd(mini(fund, goal)), Currency.format_vnd(goal), Currency.format_vnd(GameManager.get_stage_fund_remaining()),
	]


func _on_contrib_done() -> void:
	AudioManager.play_ui_click()
	_contrib_panel.visible = false
	# Nếu đã đóng đủ mục tiêu thì ẩn luôn nút Đóng góp.
	if GameManager.is_stage_goal_met():
		_contribute_btn.visible = false
	# Đóng đủ mục tiêu có thể vừa hoàn thành chương -> cập nhật nhãn nút ("Sang Chương").
	_update_action_button()
	_root.visible = true


func _on_menu() -> void:
	AudioManager.play_ui_click()
	if not _was_tutorial:
		_ensure_day_completed()
	if _gom and _gom.has_method("go_to_menu"):
		_gom.call("go_to_menu")
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.scn")


func _stop_chapter_music() -> void:
	AudioManager.stop_ingame_music()
	AudioManager.stop_scene_chapter_music()
