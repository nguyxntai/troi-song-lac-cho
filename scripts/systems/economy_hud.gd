extends CanvasLayer

## HUD kinh tế: tiền, thanh Uy Tín (Popularity), trạng thái combo "Khách sộp".
## Dựng bằng code, lắng nghe EventBus. Bootstrap thêm vào scene.

var _money_label: Label
var _rank_label: Label
var _combo_label: Label
var _pop_bg: ColorRect
var _pop_fill: ColorRect
var _pop_label: Label
var _event_label: Label
var _money_tween: Tween
var _bounce_tween: Tween


func _ready() -> void:
	layer = 5
	_build_ui()
	_connect_signals()
	_refresh_money(GameManager.money, 0)
	_refresh_popularity(GameManager.popularity)
	_refresh_combo(GameManager.combo_count, GameManager.generous_remaining > 0)


func _connect_signals() -> void:
	EventBus.money_changed.connect(_refresh_money)
	EventBus.popularity_changed.connect(_refresh_popularity)
	EventBus.combo_changed.connect(_refresh_combo)
	EventBus.game_event_started.connect(_on_event_started)
	EventBus.game_event_ended.connect(_on_event_ended)
	EventBus.rank_up.connect(_on_rank_up)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Tiền (góc trên phải).
	_money_label = Label.new()
	_money_label.text = "$0"
	_money_label.position = Vector2(-260.0, 20.0)
	_money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_money_label.offset_left = -260.0
	_money_label.offset_top = 20.0
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.add_theme_font_size_override("font_size", 34)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	_money_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0, 1.0))
	_money_label.add_theme_constant_override("outline_size", 8)
	_money_label.pivot_offset = Vector2(230, 20)
	root.add_child(_money_label)

	# Danh hiệu cấp bậc (dưới tiền).
	_rank_label = Label.new()
	_rank_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rank_label.offset_left = -300.0
	_rank_label.offset_top = 92.0
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rank_label.add_theme_font_size_override("font_size", 18)
	_rank_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7, 1.0))
	_rank_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 1.0))
	_rank_label.add_theme_constant_override("outline_size", 5)
	_rank_label.text = "» " +GameManager.get_rank_title()
	root.add_child(_rank_label)

	# Combo "Khách sộp".
	_combo_label = Label.new()
	_combo_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo_label.offset_left = -300.0
	_combo_label.offset_top = 62.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 22)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15, 1.0))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0, 1.0))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.visible = false
	root.add_child(_combo_label)

	# Thanh Uy Tín (giữa trên).
	var pop_root := Control.new()
	pop_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pop_root.offset_left = -150.0
	pop_root.offset_top = 18.0
	pop_root.offset_right = 150.0
	pop_root.offset_bottom = 54.0
	root.add_child(pop_root)

	var pop_title := Label.new()
	pop_title.text = "UY TÍN"
	pop_title.offset_top = -22.0
	pop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pop_title.add_theme_font_size_override("font_size", 16)
	pop_title.add_theme_color_override("font_color", Color(1.0, 0.97, 0.86, 1.0))
	pop_title.add_theme_color_override("font_outline_color", Color(0.13, 0.06, 0.02, 1.0))
	pop_title.add_theme_constant_override("outline_size", 5)
	pop_root.add_child(pop_title)

	_pop_bg = ColorRect.new()
	_pop_bg.color = Color(0.05, 0.05, 0.05, 0.7)
	_pop_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_root.add_child(_pop_bg)

	_pop_fill = ColorRect.new()
	_pop_fill.color = Color(0.2, 0.85, 0.4, 1.0)
	_pop_fill.anchor_left = 0.0
	_pop_fill.anchor_top = 0.0
	_pop_fill.anchor_right = 0.0
	_pop_fill.anchor_bottom = 1.0
	_pop_fill.offset_right = 0.0
	_pop_bg.add_child(_pop_fill)

	_pop_label = Label.new()
	_pop_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pop_label.add_theme_font_size_override("font_size", 16)
	_pop_label.add_theme_color_override("font_color", Color.WHITE)
	_pop_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_pop_label.add_theme_constant_override("outline_size", 4)
	_pop_bg.add_child(_pop_label)

	# Banner sự kiện (giữa, dưới uy tín).
	_event_label = Label.new()
	_event_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_event_label.offset_left = -260.0
	_event_label.offset_top = 64.0
	_event_label.offset_right = 260.0
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.add_theme_font_size_override("font_size", 22)
	_event_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_event_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0, 1.0))
	_event_label.add_theme_constant_override("outline_size", 6)
	_event_label.visible = false
	root.add_child(_event_label)


func _refresh_money(new_amount: int, delta: int) -> void:
	if _money_label == null:
		return
	_money_label.text = "$%d" % new_amount
	if delta != 0 and is_instance_valid(_money_label):
		var c: Color = Color(0.4, 1.0, 0.4) if delta > 0 else Color(1.0, 0.4, 0.4)
		_money_label.add_theme_color_override("font_color", c)
		if _money_tween and _money_tween.is_valid():
			_money_tween.kill()
		_money_tween = create_tween()
		_money_tween.tween_interval(0.25)
		_money_tween.tween_callback(func():
			if is_instance_valid(_money_label):
				_money_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0)))
		# Nảy scale cho "đã mắt".
		if _bounce_tween and _bounce_tween.is_valid():
			_bounce_tween.kill()
		_money_label.scale = Vector2.ONE * 1.3
		_bounce_tween = create_tween()
		_bounce_tween.tween_property(_money_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_popularity(ratio: float) -> void:
	if _pop_fill == null:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	_pop_fill.anchor_right = ratio
	if GameManager.is_market_busy():
		_pop_fill.color = Color(1.0, 0.6, 0.1, 1.0)
		_pop_label.text = "CHỢ ĐÔNG!"
	else:
		_pop_fill.color = Color(0.2, 0.85, 0.4, 1.0)
		_pop_label.text = "%d%%" % int(round(ratio * 100.0))


func _refresh_combo(count: int, is_generous: bool) -> void:
	if _combo_label == null:
		return
	if is_generous:
		_combo_label.visible = true
		_combo_label.text = "KHÁCH SỘP! Tip x2"
	elif count >= 2:
		_combo_label.visible = true
		_combo_label.text = "Combo %d★ x%d" % [5, count]
	else:
		_combo_label.visible = false


func _on_event_started(_event_id: String, title: String, duration: float) -> void:
	if _event_label == null:
		return
	_event_label.text = "%s (%ds)" % [title, int(round(duration))]
	_event_label.visible = true


func _on_event_ended(_event_id: String) -> void:
	if _event_label:
		_event_label.visible = false


func _on_rank_up(_rank: int, title: String) -> void:
	if _rank_label:
		_rank_label.text = "» " +title
	# Băng-rôn thăng cấp + pháo giấy ăn mừng.
	if _event_label:
		_event_label.text = "THĂNG CẤP: %s!" % title
		_event_label.visible = true
		var t := create_tween()
		t.tween_interval(3.5)
		t.tween_callback(func():
			if is_instance_valid(_event_label):
				_event_label.visible = false)
	AudioManager.play_combo_ding(8)
	var player: Node = get_tree().current_scene.find_child("NamChef", true, false)
	if player is Node3D:
		Juice.confetti((player as Node3D).global_position + Vector3.UP * 2.0)
