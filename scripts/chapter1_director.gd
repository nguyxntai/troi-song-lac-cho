extends CanvasLayer
class_name Chapter1Director

## Chương 1 – Trả nợ. Hiển thị HUD khoản nợ gia đình và hoàn thành chương khi
## người chơi đóng góp đủ tiền trả nợ (đóng góp ở màn kết quả cuối ngày).
## Được SystemsBootstrap sinh ra chỉ khi đang ở Chương 1 (không phải tutorial).

const PANEL_COLOR := Color(0.16, 0.10, 0.05, 0.96)
const CREAM := Color(1.0, 0.95, 0.78)
const DEBT_COLOR := Color(0.95, 0.55, 0.30)

var _debt_goal: int = 600
var _fund_panel: PanelContainer
var _fund_label: Label
var _fund_bar: ProgressBar
var _hint_label: Label
var _completion_banner: Label


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debt_goal = GameManager.get_stage_money_goal()
	if _debt_goal <= 0:
		_debt_goal = 600
	_build_hud()
	_build_completion_banner()
	if not EventBus.stage_fund_changed.is_connected(_on_stage_fund_changed):
		EventBus.stage_fund_changed.connect(_on_stage_fund_changed)
	_update_hud()
	if SaveManager.get_chapter1_debt_paid() >= _debt_goal and not SaveManager.is_chapter_completed(1):
		_complete_chapter_goal()


func _exit_tree() -> void:
	if EventBus.stage_fund_changed.is_connected(_on_stage_fund_changed):
		EventBus.stage_fund_changed.disconnect(_on_stage_fund_changed)


func _on_stage_fund_changed(_fund: int, _goal: int) -> void:
	_update_hud()
	if SaveManager.get_chapter1_debt_paid() >= _debt_goal:
		_complete_chapter_goal()


func _complete_chapter_goal() -> void:
	if SaveManager.is_chapter_completed(1):
		return
	SaveManager.complete_chapter(1)
	SaveManager.save_game()
	_completion_banner.text = "ĐÃ TRẢ HẾT NỢ GIA ĐÌNH!\nHoàn thành ngày hôm nay để sang Chương 2."
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


func _update_hud() -> void:
	if not _fund_label or not _fund_bar:
		return
	var paid: int = SaveManager.get_chapter1_debt_paid()
	_fund_label.text = "NỢ GIA ĐÌNH  %d / %d" % [mini(paid, _debt_goal), _debt_goal]
	_fund_bar.max_value = maxf(float(_debt_goal), 1.0)
	_fund_bar.value = minf(float(paid), float(_debt_goal))


func _build_hud() -> void:
	_fund_panel = PanelContainer.new()
	_fund_panel.name = "DebtHud"
	_fund_panel.anchor_left = 1.0
	_fund_panel.anchor_right = 1.0
	_fund_panel.offset_left = -390.0
	_fund_panel.offset_top = 185.0
	_fund_panel.offset_right = -24.0
	_fund_panel.offset_bottom = 285.0
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = Color(0.78, 0.48, 0.18)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_fund_panel.add_theme_stylebox_override("panel", style)
	add_child(_fund_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_fund_panel.add_child(content)

	_fund_label = Label.new()
	_fund_label.add_theme_font_size_override("font_size", 20)
	_fund_label.add_theme_color_override("font_color", CREAM)
	_fund_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_fund_label)

	_fund_bar = ProgressBar.new()
	_fund_bar.custom_minimum_size = Vector2(330.0, 18.0)
	_fund_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.03, 0.02, 0.9)
	bar_bg.set_corner_radius_all(6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = DEBT_COLOR
	bar_fill.set_corner_radius_all(6)
	_fund_bar.add_theme_stylebox_override("background", bar_bg)
	_fund_bar.add_theme_stylebox_override("fill", bar_fill)
	content.add_child(_fund_bar)

	_hint_label = Label.new()
	_hint_label.text = "Cuối ngày bấm \"Đóng góp\" để trả nợ bằng tiền kiếm được"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.6))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint_label)


func _build_completion_banner() -> void:
	_completion_banner = Label.new()
	_completion_banner.name = "Chapter1CompletionBanner"
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
