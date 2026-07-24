extends CanvasLayer

## HUD kinh tế: tiền, thanh Uy Tín (Popularity), trạng thái combo "Khách sộp".
## Dựng bằng code, lắng nghe EventBus. Bootstrap thêm vào scene.

const UI_MONEY_TEXTURE: Texture2D = preload("res://assets/UI/UIMoneyGameplay.png")

# Kích thước hiển thị (scale từ 577×433 gốc).
const MONEY_HUD_WIDTH := 200.0
const MONEY_HUD_ASPECT := 577.0 / 433.0

var _money_container: Control
var _money_bg: TextureRect
var _money_label: Label
var _rank_label: Label
var _combo_label: Label
var _pop_bar: ProgressBar
var _pop_fill_style: StyleBoxFlat
var _pop_label: Label
var _event_panel: PanelContainer
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

	# Tiền (góc trên phải) — nền UIMoneyGameplay.png + label overlay.
	var money_hud_height := MONEY_HUD_WIDTH / MONEY_HUD_ASPECT

	_money_container = Control.new()
	_money_container.name = "MoneyContainer"
	_money_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_money_container.offset_left = -(MONEY_HUD_WIDTH - 5.0)
	_money_container.offset_top = -5.0
	_money_container.offset_right = 5.0
	_money_container.offset_bottom = -5.0 + money_hud_height
	_money_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_container.pivot_offset = Vector2(MONEY_HUD_WIDTH * 0.5, money_hud_height * 0.5)
	root.add_child(_money_container)

	_money_bg = TextureRect.new()
	_money_bg.name = "MoneyBg"
	_money_bg.texture = UI_MONEY_TEXTURE
	_money_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_money_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_money_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_money_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_container.add_child(_money_bg)

	_money_label = Label.new()
	_money_label.name = "MoneyLabel"
	_money_label.text = Currency.format_vnd(0)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_size_override("font_size", 20)
	_money_label.add_theme_color_override("font_color", Color(0.35, 0.18, 0.05, 1.0))
	_money_label.add_theme_color_override("font_outline_color", Color(0.95, 0.85, 0.65, 1.0))
	_money_label.add_theme_constant_override("outline_size", 2)
	_money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tinh chỉnh box để số liệu lọt vào chính giữa giấy.
	_money_label.position = Vector2(MONEY_HUD_WIDTH * 0.08, money_hud_height * 0.52)
	_money_label.size = Vector2(MONEY_HUD_WIDTH * 0.76, money_hud_height * 0.32)
	_money_container.add_child(_money_label)

	# Danh hiệu cấp bậc (dưới tiền).
	_rank_label = Label.new()
	_rank_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rank_label.offset_left = -300.0
	_rank_label.offset_top = 10.0 + money_hud_height + 6.0
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rank_label.add_theme_font_size_override("font_size", 14)
	_rank_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7, 1.0))
	_rank_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 1.0))
	_rank_label.add_theme_constant_override("outline_size", 5)
	_rank_label.text = "» " +GameManager.get_rank_title()
	root.add_child(_rank_label)

	# Combo "Khách sộp".
	_combo_label = Label.new()
	_combo_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_combo_label.offset_left = -300.0
	_combo_label.offset_top = 10.0 + money_hud_height + 28.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 16)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15, 1.0))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.0, 1.0))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.visible = false
	root.add_child(_combo_label)

	# Thanh Uy Tín (giữa trên) — khung gỗ đồng bộ.
	var pop_frame := PanelContainer.new()
	pop_frame.name = "PopFrame"
	pop_frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pop_frame.offset_left = -168.0
	pop_frame.offset_top = 14.0
	pop_frame.offset_right = 168.0
	pop_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_frame.add_theme_stylebox_override("panel", UIStyle.wood_panel(12, 10))
	root.add_child(pop_frame)

	var pop_vbox := VBoxContainer.new()
	pop_vbox.add_theme_constant_override("separation", 4)
	pop_frame.add_child(pop_vbox)

	var pop_title := Label.new()
	pop_title.text = "UY TÍN"
	pop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_title(pop_title, 16)
	pop_vbox.add_child(pop_title)

	var pop_bar_holder := Control.new()
	pop_bar_holder.custom_minimum_size = Vector2(300.0, 22.0)
	pop_vbox.add_child(pop_bar_holder)

	_pop_bar = ProgressBar.new()
	_pop_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop_bar.show_percentage = false
	_pop_bar.min_value = 0.0
	_pop_bar.max_value = 100.0
	_pop_bar.add_theme_stylebox_override("background", UIStyle.bar_track(7))
	_pop_fill_style = UIStyle.bar_fill(UIStyle.FILL_GOOD, 7)
	_pop_bar.add_theme_stylebox_override("fill", _pop_fill_style)
	pop_bar_holder.add_child(_pop_bar)

	_pop_label = Label.new()
	_pop_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.style_label(_pop_label, 15, UIStyle.CREAM, 4)
	pop_bar_holder.add_child(_pop_label)

	# Banner sự kiện (giữa, dưới uy tín) — khung gỗ.
	_event_panel = PanelContainer.new()
	_event_panel.name = "EventPanel"
	_event_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_event_panel.offset_left = -300.0
	_event_panel.offset_top = 78.0
	_event_panel.offset_right = 300.0
	_event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_panel.add_theme_stylebox_override("panel", UIStyle.wood_panel(12, 10, true))
	_event_panel.visible = false
	root.add_child(_event_panel)

	_event_label = Label.new()
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.style_label(_event_label, 22, UIStyle.GOLD_TEXT, 6)
	_event_panel.add_child(_event_label)


func _refresh_money(new_amount: int, delta: int) -> void:
	if _money_label == null:
		return
	_money_label.text = Currency.format_vnd(new_amount)
	if delta != 0 and is_instance_valid(_money_label):
		var c: Color = Color(0.15, 0.55, 0.15) if delta > 0 else Color(0.7, 0.2, 0.2)
		_money_label.add_theme_color_override("font_color", c)
		if _money_tween and _money_tween.is_valid():
			_money_tween.kill()
		_money_tween = create_tween()
		_money_tween.tween_interval(0.25)
		_money_tween.tween_callback(func():
			if is_instance_valid(_money_label):
				_money_label.add_theme_color_override("font_color", Color(0.35, 0.18, 0.05, 1.0)))
		# Nảy scale container cho "đã mắt".
		if _bounce_tween and _bounce_tween.is_valid():
			_bounce_tween.kill()
		if is_instance_valid(_money_container):
			_money_container.scale = Vector2.ONE * 1.15
			_bounce_tween = create_tween()
			_bounce_tween.tween_property(_money_container, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_popularity(ratio: float) -> void:
	if _pop_bar == null or _pop_fill_style == null:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	_pop_bar.value = ratio * 100.0
	if GameManager.is_market_busy():
		_pop_fill_style.bg_color = UIStyle.FILL_BUSY
		_pop_label.text = "CHỢ ĐÔNG!"
	else:
		_pop_fill_style.bg_color = UIStyle.FILL_GOOD
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
	_event_panel.visible = true


func _on_event_ended(_event_id: String) -> void:
	if _event_panel:
		_event_panel.visible = false


func _on_rank_up(_rank: int, title: String) -> void:
	if _rank_label:
		_rank_label.text = "» " +title
	# Băng-rôn thăng cấp + pháo giấy ăn mừng.
	if _event_label:
		_event_label.text = "THĂNG CẤP: %s!" % title
		_event_panel.visible = true
		var t := create_tween()
		t.tween_interval(3.5)
		t.tween_callback(func():
			if is_instance_valid(_event_panel):
				_event_panel.visible = false)
	AudioManager.play_combo_ding(8)
	var player: Node = get_tree().current_scene.find_child("NamChef", true, false)
	if player is Node3D:
		Juice.confetti((player as Node3D).global_position + Vector3.UP * 2.0)
