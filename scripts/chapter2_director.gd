extends CanvasLayer
class_name Chapter2Director

const PANEL_COLOR := Color(0.18, 0.09, 0.04, 0.96)
const CREAM := Color(1.0, 0.95, 0.78)
const FUND_COLOR := Color(0.25, 0.88, 0.5)

@export var treatment_fund_goal: int = 900
@export var huyen_contribution: int = 120
@export_range(1.0, 2.0, 0.05) var huyen_patience_multiplier: float = 1.25
@export_range(0, 3, 1) var huyen_wrong_order_shields: int = 1
@export var dad_health_loss_per_day: int = 12

var _fund_panel: PanelContainer
var _fund_label: Label
var _fund_bar: ProgressBar
var _health_label: Label
var _health_bar: ProgressBar
var _support_label: Label
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
		"text": "Công việc vừa bắt đầu ổn định thì cha Nam đổ bệnh nặng. Tiền thuốc và viện phí trở thành gánh nặng mới của gia đình.",
		"voice": "res://assets/Voice/chapter2_01.mp3",
	},
	{
		"speaker": "Cha",
		"text": "Cha không sao đâu con. Con cứ giữ lấy chiếc ghe, đừng để việc buôn bán dang dở vì cha.",
	},
	{
		"speaker": "Huyền",
		"text": "Anh cứ tập trung nấu ăn. Em sẽ giúp quản lý khách, xử lý những tình huống rối và góp một phần tiền viện phí.",
	},
	{
		"speaker": "Mục tiêu Chương 2",
		"text": "Duy trì quán qua nhiều ngày và tích đủ quỹ viện phí cho cha Nam.",
		"voice": "res://assets/Voice/chapter2_04.mp3",
	},
]


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_mode = GameManager.chapter_index != 2
	if _preview_mode:
		GameManager.chapter_index = 2
		GameManager.day_index = 1
	GameManager.staff_patience_multiplier = huyen_patience_multiplier
	_build_ui()
	_apply_huyen_support()
	_ensure_chapter2_day_settings()
	# Quỹ giờ nạp bằng cách người chơi ĐÓNG GÓP (trừ tiền), không tự cộng theo doanh thu.
	if not EventBus.stage_fund_changed.is_connected(_on_stage_fund_changed):
		EventBus.stage_fund_changed.connect(_on_stage_fund_changed)
	if not EventBus.day_completed.is_connected(_on_day_completed):
		EventBus.day_completed.connect(_on_day_completed)
	_update_fund_hud()
	if SaveManager.get_chapter2_fund() >= treatment_fund_goal and not SaveManager.is_chapter_completed(2):
		_complete_chapter_goal()
	elif not _preview_mode and SaveManager.get_chapter2_dad_health() <= 0 and not SaveManager.is_chapter_completed(2):
		call_deferred("_trigger_dad_lost")
	call_deferred("_start_story_if_needed")


func _exit_tree() -> void:
	GameManager.staff_patience_multiplier = 1.0
	GameManager.is_tutorial_locked = false
	if EventBus.stage_fund_changed.is_connected(_on_stage_fund_changed):
		EventBus.stage_fund_changed.disconnect(_on_stage_fund_changed)
	if EventBus.day_completed.is_connected(_on_day_completed):
		EventBus.day_completed.disconnect(_on_day_completed)


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


func _ensure_chapter2_day_settings() -> void:
	# Giữ scene chạy đúng cả khi mở trực tiếp Chapter 2 từ editor với save cũ.
	var day_manager: Node = get_tree().current_scene.find_child("DayManager", true, false)
	if day_manager == null:
		return
	if int(day_manager.get("required_customers")) < 7:
		day_manager.set("required_customers", 7)
	if float(day_manager.get("day_duration")) < 330.0:
		day_manager.set("day_duration", 330.0)
		day_manager.set("_time_left", 330.0)
	if day_manager.has_method("_update_hud"):
		day_manager.call("_update_hud")
	if day_manager.has_method("_update_day_phase"):
		day_manager.call("_update_day_phase", true)


func _start_story_if_needed() -> void:
	if not _preview_mode and SaveManager.has_seen_chapter2_intro():
		return
	if not _preview_mode:
		SaveManager.set_chapter2_intro_seen(true)
		SaveManager.save_game()
	_dialogue_index = 0
	_dialogue_active = true
	GameManager.is_tutorial_locked = true
	get_tree().paused = true
	_show_dialogue_line()
	if huyen_contribution > 0 and not _preview_mode:
		GameManager.grant_money(huyen_contribution)


func _show_dialogue_line() -> void:
	if _dialogue_index < 0 or _dialogue_index >= INTRO_DIALOGUE.size():
		_finish_dialogue()
		return
	var line: Dictionary = INTRO_DIALOGUE[_dialogue_index]
	_speaker_label.text = String(line.get("speaker", ""))
	_dialogue_label.text = String(line.get("text", ""))
	_dialogue_root.visible = true
	AudioManager.play_voice_file(String(line.get("voice", "")), -1.0)


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= INTRO_DIALOGUE.size():
		_finish_dialogue()
	else:
		_show_dialogue_line()


func _finish_dialogue() -> void:
	_dialogue_active = false
	_dialogue_root.visible = false
	AudioManager.stop_voice()
	GameManager.is_tutorial_locked = false
	get_tree().paused = false


func _on_stage_fund_changed(_fund: int, _goal: int) -> void:
	if _preview_mode:
		return
	_update_fund_hud()
	if SaveManager.get_chapter2_fund() >= treatment_fund_goal:
		_complete_chapter_goal()


## Cuối mỗi ngày thắng mà chưa gom đủ viện phí → sức khỏe bố giảm.
func _on_day_completed(_day_index: int, is_win: bool) -> void:
	if _preview_mode or not is_win or SaveManager.is_chapter_completed(2):
		return
	if SaveManager.get_chapter2_fund() >= treatment_fund_goal:
		return
	var health: int = SaveManager.get_chapter2_dad_health() - dad_health_loss_per_day
	SaveManager.set_chapter2_dad_health(health)
	SaveManager.save_game()
	_update_fund_hud()


func _trigger_dad_lost() -> void:
	var gom: Node = get_tree().current_scene.find_child("GameOverManager", true, false)
	if gom and gom.has_method("show_custom_game_over"):
		gom.call("show_custom_game_over", "Không kịp cứu cha",
			"Sức khỏe của cha đã cạn trước khi gom đủ viện phí. Hãy thử lại và ưu tiên đóng góp sớm hơn.")
	elif gom and gom.has_method("show_game_over"):
		gom.call("show_game_over", "custom", "Không kịp gom đủ viện phí cho cha.")


func _complete_chapter_goal() -> void:
	if SaveManager.is_chapter_completed(2):
		return
	SaveManager.complete_chapter(2)
	SaveManager.save_game()
	_completion_banner.text = "ĐÃ ĐỦ VIỆN PHÍ CHO CHA!\nHoàn thành ngày hôm nay để kết thúc Chương 2."
	_completion_banner.visible = true
	_completion_banner.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_completion_banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(3.5)
	tween.tween_property(_completion_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: _completion_banner.visible = false)
	var player: Node3D = get_tree().current_scene.find_child("NamChef", true, false) as Node3D
	if player:
		Juice.confetti(player.global_position + Vector3.UP * 2.2, 100)


func _update_fund_hud() -> void:
	if not _fund_label or not _fund_bar:
		return
	var fund: int = SaveManager.get_chapter2_fund()
	_fund_label.text = "QUỸ VIỆN PHÍ  %d / %d" % [mini(fund, treatment_fund_goal), treatment_fund_goal]
	_fund_bar.max_value = maxf(float(treatment_fund_goal), 1.0)
	_fund_bar.value = minf(float(fund), float(treatment_fund_goal))

	if _health_label and _health_bar:
		var health: int = SaveManager.get_chapter2_dad_health()
		_health_label.text = "SỨC KHỎE CHA  %d / 100" % health
		_health_bar.value = float(health)
		var fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color = UIStyle.FILL_HEALTH_LOW if health <= 36 else UIStyle.FILL_HEALTH


func _build_ui() -> void:
	_build_fund_hud()
	_build_dialogue()
	_build_completion_banner()


func _build_fund_hud() -> void:
	_fund_panel = PanelContainer.new()
	_fund_panel.name = "TreatmentFundHud"
	_fund_panel.anchor_left = 1.0
	_fund_panel.anchor_right = 1.0
	_fund_panel.offset_left = -390.0
	_fund_panel.offset_top = 185.0
	_fund_panel.offset_right = -24.0
	_fund_panel.offset_bottom = 355.0
	_fund_panel.add_theme_stylebox_override("panel", UIStyle.wood_panel(12, 14))
	add_child(_fund_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_fund_panel.add_child(content)

	_fund_label = Label.new()
	_fund_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_fund_label, UIStyle.FS_BODY, UIStyle.CREAM)
	content.add_child(_fund_label)

	_fund_bar = ProgressBar.new()
	_fund_bar.custom_minimum_size = Vector2(330.0, 18.0)
	_fund_bar.show_percentage = false
	_fund_bar.add_theme_stylebox_override("background", UIStyle.bar_track())
	_fund_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(UIStyle.FILL_GOOD))
	content.add_child(_fund_bar)

	_health_label = Label.new()
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_health_label, 18, Color(1.0, 0.82, 0.74))
	content.add_child(_health_label)

	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(330.0, 16.0)
	_health_bar.show_percentage = false
	_health_bar.max_value = 100.0
	_health_bar.add_theme_stylebox_override("background", UIStyle.bar_track())
	_health_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(UIStyle.FILL_HEALTH))
	content.add_child(_health_bar)

	_support_label = Label.new()
	_support_label.text = "Huyền hỗ trợ: khách kiên nhẫn hơn · cứu 1 lượt giao sai"
	_support_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_support_label, UIStyle.FS_SMALL, Color(0.72, 1.0, 0.82))
	content.add_child(_support_label)


func _build_dialogue() -> void:
	_dialogue_root = Control.new()
	_dialogue_root.name = "Chapter2Story"
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
	box_style.border_color = Color(0.82, 0.5, 0.2)
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
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
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
	_completion_banner.name = "Chapter2CompletionBanner"
	_completion_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_completion_banner.position = Vector2(-350.0, 160.0)
	_completion_banner.size = Vector2(700.0, 110.0)
	_completion_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_completion_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_completion_banner.add_theme_font_size_override("font_size", 28)
	_completion_banner.add_theme_color_override("font_color", Color(0.45, 1.0, 0.58))
	_completion_banner.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.01))
	_completion_banner.add_theme_constant_override("outline_size", 8)
	_completion_banner.visible = false
	add_child(_completion_banner)
