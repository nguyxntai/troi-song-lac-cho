extends CanvasLayer
class_name Chapter3Director

const PANEL_COLOR := Color(0.16, 0.07, 0.10, 0.96)
const CREAM := Color(1.0, 0.95, 0.82)
const FUND_COLOR := Color(1.0, 0.62, 0.28)
const HAPPY_COLOR := Color(0.38, 0.9, 0.55)

@export var wedding_fund_goal: int = 1200
@export var happy_guest_goal: int = 20
@export_range(1.0, 2.0, 0.05) var huyen_patience_multiplier: float = 1.15
@export_range(0, 3, 1) var huyen_wrong_order_shields: int = 1

var _progress_panel: PanelContainer
var _fund_label: Label
var _fund_bar: ProgressBar
var _happy_label: Label
var _happy_bar: ProgressBar
var _dialogue_root: Control
var _speaker_label: Label
var _dialogue_label: Label
var _completion_banner: Label
var _dialogue_index: int = 0
var _dialogue_active: bool = false
var _preview_mode: bool = false

const INTRO_DIALOGUE := [
	{
		"speaker": "Người dẫn chuyện",
		"text": "Nhờ tiền viện phí kịp thời, cha Nam dần bình phục. Việc buôn bán cũng khởi sắc và khoản nợ cũ cuối cùng đã được thanh toán.",
	},
	{
		"speaker": "Cha",
		"text": "Con đã giữ được chiếc ghe và danh tiếng của gia đình. Bây giờ hãy xây dựng tương lai của chính con.",
	},
	{
		"speaker": "Huyền",
		"text": "Mình cùng làm cho quán thật đông vui nhé. Khi đủ tiền và được mọi người yêu quý, chúng ta sẽ tổ chức đám cưới ngay trên sông.",
	},
	{
		"speaker": "Mục tiêu Chương 3",
		"text": "Tích đủ quỹ cưới và phục vụ thật nhiều khách hài lòng để chuẩn bị ngày vui của Nam và Huyền.",
	},
]


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_mode = GameManager.chapter_index != 3
	if _preview_mode:
		GameManager.chapter_index = 3
		GameManager.day_index = 1
	GameManager.staff_patience_multiplier = huyen_patience_multiplier
	_build_ui()
	_apply_huyen_support()
	_ensure_chapter3_day_settings()
	# Quỹ cưới nạp bằng ĐÓNG GÓP (trừ tiền); vẫn đếm khách hài lòng qua guest_served.
	if not EventBus.stage_fund_changed.is_connected(_on_stage_fund_changed):
		EventBus.stage_fund_changed.connect(_on_stage_fund_changed)
	if not EventBus.guest_served.is_connected(_on_guest_served):
		EventBus.guest_served.connect(_on_guest_served)
	_update_progress_hud()
	_check_chapter_goal()
	call_deferred("_start_story_if_needed")


func _exit_tree() -> void:
	GameManager.staff_patience_multiplier = 1.0
	GameManager.is_tutorial_locked = false
	if EventBus.stage_fund_changed.is_connected(_on_stage_fund_changed):
		EventBus.stage_fund_changed.disconnect(_on_stage_fund_changed)
	if EventBus.guest_served.is_connected(_on_guest_served):
		EventBus.guest_served.disconnect(_on_guest_served)


func _unhandled_input(event: InputEvent) -> void:
	if not _dialogue_active:
		return
	var advance: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		advance = advance or (mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed)
	if advance:
		_advance_dialogue()
		get_viewport().set_input_as_handled()


func _apply_huyen_support() -> void:
	var day_manager: Node = get_tree().current_scene.find_child("DayManager", true, false)
	if day_manager and day_manager.has_method("set_wrong_order_shields"):
		day_manager.call("set_wrong_order_shields", huyen_wrong_order_shields)


func _ensure_chapter3_day_settings() -> void:
	var day_manager: Node = get_tree().current_scene.find_child("DayManager", true, false)
	if day_manager == null:
		return
	if int(day_manager.get("required_customers")) < 8:
		day_manager.set("required_customers", 8)
	if float(day_manager.get("day_duration")) < 330.0:
		day_manager.set("day_duration", 330.0)
		day_manager.set("_time_left", 330.0)
	if day_manager.has_method("_update_hud"):
		day_manager.call("_update_hud")
	if day_manager.has_method("_update_day_phase"):
		day_manager.call("_update_day_phase", true)


func _start_story_if_needed() -> void:
	if not _preview_mode and SaveManager.has_seen_chapter3_intro():
		return
	if not _preview_mode:
		SaveManager.set_chapter3_intro_seen(true)
		SaveManager.save_game()
	_dialogue_index = 0
	_dialogue_active = true
	GameManager.is_tutorial_locked = true
	get_tree().paused = true
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	if _dialogue_index < 0 or _dialogue_index >= INTRO_DIALOGUE.size():
		_finish_dialogue()
		return
	var line: Dictionary = INTRO_DIALOGUE[_dialogue_index]
	_speaker_label.text = String(line.get("speaker", ""))
	_dialogue_label.text = String(line.get("text", ""))
	_dialogue_root.visible = true


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= INTRO_DIALOGUE.size():
		_finish_dialogue()
	else:
		_show_dialogue_line()


func _finish_dialogue() -> void:
	_dialogue_active = false
	_dialogue_root.visible = false
	GameManager.is_tutorial_locked = false
	get_tree().paused = false


func _on_stage_fund_changed(_fund: int, _goal: int) -> void:
	if _preview_mode or SaveManager.is_chapter_completed(3):
		return
	_update_progress_hud()
	_check_chapter_goal()


func _on_guest_served(stars: int, _tip: int, _food_id: String) -> void:
	if _preview_mode or stars < 4 or SaveManager.is_chapter_completed(3):
		return
	SaveManager.add_chapter3_happy_guest()
	SaveManager.save_game()
	_update_progress_hud()
	_check_chapter_goal()


func _check_chapter_goal() -> void:
	if SaveManager.is_chapter_completed(3):
		return
	if SaveManager.get_chapter3_wedding_fund() < wedding_fund_goal:
		return
	if SaveManager.get_chapter3_happy_guests() < happy_guest_goal:
		return
	SaveManager.complete_chapter(3)
	SaveManager.save_game()
	_show_completion_banner()


func _show_completion_banner() -> void:
	_completion_banner.text = "MỌI THỨ ĐÃ SẴN SÀNG CHO ĐÁM CƯỚI!\nHoàn thành ngày hôm nay để dự ngày vui của Nam và Huyền."
	_completion_banner.visible = true
	_completion_banner.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_completion_banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(3.5)
	tween.tween_property(_completion_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: _completion_banner.visible = false)
	var player: Node3D = get_tree().current_scene.find_child("NamChef", true, false) as Node3D
	if player:
		Juice.confetti(player.global_position + Vector3.UP * 2.2, 120)


func _update_progress_hud() -> void:
	if not _fund_label or not _happy_label:
		return
	var fund: int = SaveManager.get_chapter3_wedding_fund()
	var happy: int = SaveManager.get_chapter3_happy_guests()
	_fund_label.text = "QUỸ CƯỚI  %d / %d" % [mini(fund, wedding_fund_goal), wedding_fund_goal]
	_fund_bar.max_value = maxf(float(wedding_fund_goal), 1.0)
	_fund_bar.value = minf(float(fund), float(wedding_fund_goal))
	_happy_label.text = "KHÁCH HÀI LÒNG  %d / %d" % [mini(happy, happy_guest_goal), happy_guest_goal]
	_happy_bar.max_value = maxf(float(happy_guest_goal), 1.0)
	_happy_bar.value = minf(float(happy), float(happy_guest_goal))


func _build_ui() -> void:
	_build_progress_hud()
	_build_dialogue()
	_build_completion_banner()


func _build_progress_hud() -> void:
	_progress_panel = PanelContainer.new()
	_progress_panel.name = "WeddingProgressHud"
	_progress_panel.anchor_left = 1.0
	_progress_panel.anchor_right = 1.0
	_progress_panel.offset_left = -390.0
	_progress_panel.offset_top = 185.0
	_progress_panel.offset_right = -24.0
	_progress_panel.offset_bottom = 335.0
	_progress_panel.add_theme_stylebox_override("panel", UIStyle.wood_panel(12, 14))
	add_child(_progress_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_progress_panel.add_child(content)
	_fund_label = _make_progress_label()
	content.add_child(_fund_label)
	_fund_bar = _make_progress_bar(FUND_COLOR)
	content.add_child(_fund_bar)
	_happy_label = _make_progress_label()
	content.add_child(_happy_label)
	_happy_bar = _make_progress_bar(HAPPY_COLOR)
	content.add_child(_happy_bar)


func _make_progress_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(label, 17, UIStyle.CREAM)
	return label


func _make_progress_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(330.0, 16.0)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UIStyle.bar_track())
	bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(color))
	return bar


func _build_dialogue() -> void:
	_dialogue_root = Control.new()
	_dialogue_root.name = "Chapter3Story"
	_dialogue_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialogue_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dialogue_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	_dialogue_root.add_child(dim)

	var box := PanelContainer.new()
	box.anchor_left = 0.5
	box.anchor_top = 1.0
	box.anchor_right = 0.5
	box.anchor_bottom = 1.0
	box.offset_left = -460.0
	box.offset_top = -260.0
	box.offset_right = 460.0
	box.offset_bottom = -45.0
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = PANEL_COLOR
	box_style.border_color = Color(0.95, 0.5, 0.3)
	box_style.set_border_width_all(5)
	box_style.set_corner_radius_all(8)
	box_style.set_content_margin_all(24)
	box.add_theme_stylebox_override("panel", box_style)
	_dialogue_root.add_child(box)

	var dialogue_content := VBoxContainer.new()
	dialogue_content.add_theme_constant_override("separation", 14)
	box.add_child(dialogue_content)
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 28)
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.35))
	dialogue_content.add_child(_speaker_label)
	_dialogue_label = Label.new()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 21)
	_dialogue_label.add_theme_color_override("font_color", CREAM)
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_content.add_child(_dialogue_label)
	_dialogue_root.visible = false


func _build_completion_banner() -> void:
	_completion_banner = Label.new()
	_completion_banner.name = "Chapter3CompletionBanner"
	_completion_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_completion_banner.position = Vector2(-390.0, 150.0)
	_completion_banner.size = Vector2(780.0, 120.0)
	_completion_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_completion_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_completion_banner.add_theme_font_size_override("font_size", 27)
	_completion_banner.add_theme_color_override("font_color", Color(1.0, 0.68, 0.3))
	_completion_banner.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.04))
	_completion_banner.add_theme_constant_override("outline_size", 8)
	_completion_banner.visible = false
	add_child(_completion_banner)
