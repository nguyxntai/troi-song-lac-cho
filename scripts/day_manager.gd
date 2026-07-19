extends CanvasLayer
class_name DayManager

const UI_GAMEPLAY_TEXTURE: Texture2D = preload("res://assets/UI/UIGameplay.png")

enum DayPhase {
	OPENING,
	STEADY,
	RUSH,
	CLOSING,
}

@export var required_customers: int = 5
@export var day_duration: float = 300.0
@export var max_wrong_orders: int = 3
@export var auto_start: bool = true
@export var game_over_manager_path: NodePath = NodePath("../GameOverManager")
@export_group("Day Pacing")
@export_range(0.1, 0.4, 0.01) var opening_end_ratio: float = 0.22
@export_range(0.4, 0.8, 0.01) var rush_start_ratio: float = 0.58
@export_range(0.75, 0.98, 0.01) var closing_start_ratio: float = 0.88
@export var opening_spawn_interval: float = 12.0
@export var steady_spawn_interval: float = 9.0
@export var rush_spawn_interval: float = 5.5
@export var closing_spawn_interval: float = 7.5
@export_range(0.0, 0.1, 0.005) var pace_gain_per_day: float = 0.035
@export_range(1, 5, 1) var add_customer_every_days: int = 2
@export_range(0, 10, 1) var max_extra_customers: int = 5
@export_group("Chapter 2")
@export var chapter2_base_customer_bonus: int = 2
@export var chapter2_day_duration: float = 330.0
@export_group("Chapter 3")
@export var chapter3_base_customer_bonus: int = 3
@export var chapter3_day_duration: float = 330.0

var _served_customers: int = 0
var _wrong_orders: int = 0
var _wrong_order_shields: int = 0
var _time_left: float = 0.0
var _is_finished: bool = false
var _is_running: bool = false
var _game_over_manager: GameOverManager
var _last_display_second: int = -1
var _current_phase: int = -1
var _guest_spawner: Node
var _phase_tween: Tween

# HUD elements
var _hud_bg: TextureRect
var _customer_label: Label
var _wrong_label: Label
var _timer_label: Label
var _phase_label: Label

# Kích thước HUD trên màn hình (scale từ 1536×1024 gốc).
const HUD_DISPLAY_WIDTH := 280.0
const HUD_ASPECT := 1536.0 / 1024.0


func _ready() -> void:
	add_to_group("day_manager")
	if GameManager.chapter_index == 2 and not _is_tutorial_scene():
		required_customers += maxi(chapter2_base_customer_bonus, 0)
		day_duration = maxf(chapter2_day_duration, day_duration)
	elif GameManager.chapter_index == 3 and not _is_tutorial_scene():
		required_customers += maxi(chapter3_base_customer_bonus, 0)
		day_duration = maxf(chapter3_day_duration, day_duration)
	if not _is_tutorial_scene() and add_customer_every_days > 0:
		var completed_steps: int = floori(float(GameManager.day_index - 1) / float(add_customer_every_days))
		required_customers += mini(completed_steps, max_extra_customers)
	_time_left = maxf(day_duration, 0.0)
	_is_running = auto_start
	_game_over_manager = get_node_or_null(game_over_manager_path) as GameOverManager
	if not _game_over_manager:
		_game_over_manager = get_tree().current_scene.find_child("GameOverManager", true, false) as GameOverManager

	_build_hud()
	_update_hud()

	# Tutorial: thời gian dài hơn, yêu cầu 3 khách tổng cộng (bao gồm khách đầu tiên).
	if get_tree().current_scene.scene_file_path.get_file() == "tutorial.tscn":
		required_customers = 3
		day_duration = 600.0
		_time_left = day_duration
		_update_hud()

	_guest_spawner = get_tree().current_scene.find_child("GuestSpawner", true, false)
	_update_day_phase(true)


func _process(delta: float) -> void:
	if _is_finished or not _is_running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	_update_day_phase()
	var display_second: int = int(ceil(_time_left))
	if display_second != _last_display_second:
		_update_hud()
	if _time_left <= 0.0:
		_finish_day_by_time()


func register_served_guest(_guest: Node = null) -> void:
	if _is_finished:
		return

	_served_customers += 1
	_update_hud()
	if _served_customers >= required_customers:
		_show_win()


func register_wrong_order(_guest: Node = null) -> void:
	if _is_finished:
		return
	if _wrong_order_shields > 0:
		_wrong_order_shields -= 1
		var player: Node3D = get_tree().current_scene.find_child("NamChef", true, false) as Node3D
		if player:
			Juice.popup_text(player.global_position + Vector3.UP * 2.2, "HUYỀN ĐÃ XỬ LÝ!", Color(0.45, 1.0, 0.75), 42, 1.2)
		return

	_wrong_orders += 1
	_update_hud()
	if _wrong_orders >= max_wrong_orders:
		_show_too_many_wrong_orders_game_over()


func set_wrong_order_shields(amount: int) -> void:
	_wrong_order_shields = maxi(amount, 0)


func _finish_day_by_time() -> void:
	if _served_customers >= required_customers:
		_show_win()
	else:
		_show_not_enough_customers_game_over()


func _show_too_many_wrong_orders_game_over() -> void:
	if _is_finished:
		return

	_is_finished = true
	_is_running = false
	var header: String = "Đưa sai món %d/%d lượt." % [_wrong_orders, max_wrong_orders]
	var results: Dictionary = ScoreManager.finalize(GameManager.day_index)
	# Chốt ngày (complete_day) được dời sang lúc rời màn kết quả, sau khi người chơi
	# có cơ hội đóng góp mục tiêu — để việc qua chương phản ánh đúng.
	_present_results(results, false, header, GameOverManager.REASON_TOO_MANY_WRONG_ORDERS)


func _show_win() -> void:
	if _is_finished:
		return

	_is_finished = true
	_is_running = false
	var header: String = "Đã phục vụ đủ %d/%d khách!" % [_served_customers, required_customers]
	var results: Dictionary = ScoreManager.finalize(GameManager.day_index)
	results["is_tutorial"] = _is_tutorial_scene()
	_present_results(results, true, header, "")


func _show_not_enough_customers_game_over() -> void:
	if _is_finished:
		return

	_is_finished = true
	_is_running = false
	var header: String = "Hết ngày, mới phục vụ %d/%d khách." % [_served_customers, required_customers]
	var results: Dictionary = ScoreManager.finalize(GameManager.day_index)
	_present_results(results, false, header, GameOverManager.REASON_NOT_ENOUGH_CUSTOMERS)


func _update_day_phase(force: bool = false) -> void:
	if day_duration <= 0.0:
		return
	var elapsed_ratio: float = clampf(1.0 - (_time_left / day_duration), 0.0, 1.0)
	var served_ratio: float = float(_served_customers) / float(maxi(required_customers, 1))
	# Người chơi giỏi vẫn đi qua đủ nhịp ngày thay vì thắng khi phase mới chỉ mở bán.
	var day_progress: float = maxf(elapsed_ratio, served_ratio)
	var next_phase: int = DayPhase.OPENING
	if day_progress >= closing_start_ratio:
		next_phase = DayPhase.CLOSING
	elif day_progress >= rush_start_ratio:
		next_phase = DayPhase.RUSH
	elif day_progress >= opening_end_ratio:
		next_phase = DayPhase.STEADY
	if not force and next_phase == _current_phase:
		return

	_current_phase = next_phase
	var title: String = _get_phase_title(next_phase)
	var interval: float = _get_phase_spawn_interval(next_phase)
	var day_pace: float = maxf(0.72, 1.0 - float(GameManager.day_index - 1) * pace_gain_per_day)
	interval *= day_pace
	if _guest_spawner and _guest_spawner.has_method("set_spawn_pace"):
		_guest_spawner.call("set_spawn_pace", interval, next_phase)
	EventBus.day_phase_changed.emit(next_phase, title, interval)
	_show_phase_banner(title)


func _get_phase_title(phase: int) -> String:
	match phase:
		DayPhase.STEADY:
			return "CHỢ BẮT ĐẦU ĐÔNG"
		DayPhase.RUSH:
			return "GIỜ CAO ĐIỂM!"
		DayPhase.CLOSING:
			return "SẮP HẾT NGÀY"
		_:
			return "MỞ BÁN - NGÀY %d" % GameManager.day_index


func _get_phase_spawn_interval(phase: int) -> float:
	match phase:
		DayPhase.STEADY:
			return steady_spawn_interval
		DayPhase.RUSH:
			return rush_spawn_interval
		DayPhase.CLOSING:
			return closing_spawn_interval
		_:
			return opening_spawn_interval


func _is_tutorial_scene() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path.get_file() == "tutorial.tscn"


func _show_phase_banner(title: String) -> void:
	if not _phase_label:
		return
	if _phase_tween and _phase_tween.is_valid():
		_phase_tween.kill()
	_phase_label.text = title
	_phase_label.visible = true
	_phase_label.modulate.a = 0.0
	_phase_label.scale = Vector2(0.86, 0.86)
	_phase_tween = create_tween()
	_phase_tween.tween_property(_phase_label, "modulate:a", 1.0, 0.2)
	_phase_tween.parallel().tween_property(_phase_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_phase_tween.tween_interval(1.5)
	_phase_tween.tween_property(_phase_label, "modulate:a", 0.0, 0.35)
	_phase_tween.tween_callback(func() -> void: _phase_label.visible = false)


## Ưu tiên màn ResultsScreen đẹp; nếu thiếu thì fallback panel cũ của GameOverManager.
func _present_results(results: Dictionary, is_win: bool, header: String, reason_key: String) -> void:
	if _game_over_manager:
		_game_over_manager.watch_player_fall = false
	var results_screen: Node = get_tree().current_scene.find_child("ResultsScreen", true, false)
	if results_screen and results_screen.has_method("show_results"):
		results_screen.call("show_results", results, is_win, header)
		return
	if _game_over_manager:
		if is_win:
			_game_over_manager.show_win(header + "\n" + _build_results_text(results))
		else:
			_game_over_manager.show_game_over(reason_key, header + "\n\n" + _build_results_text(results))


## Dựng đoạn text tổng kết: điểm, huy chương, kỷ lục, thống kê.
func _build_results_text(results: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Điểm: %d" % int(results.get("score", 0)))
	var medal_name: String = String(results.get("medal_name", ""))
	if int(results.get("medal", 0)) > 0:
		lines.append("Huy chương: %s" % medal_name)
	else:
		var next_at: int = int(results.get("next_medal_at", 0))
		if next_at > 0:
			lines.append("Còn %d điểm nữa để đạt huy chương!" % maxi(next_at - int(results.get("score", 0)), 0))
	if bool(results.get("is_record", false)):
		lines.append("★ KỶ LỤC MỚI! ★")
	else:
		lines.append("Kỷ lục: %d" % int(results.get("best", 0)))
	lines.append("5★: %d  ·  Sai: %d  ·  Lỡ: %d" % [
		int(results.get("five_stars", 0)),
		int(results.get("wrong", 0)),
		int(results.get("missed", 0)),
	])
	lines.append("Cấp bậc: %s" % GameManager.get_rank_title())
	return "\n".join(lines)


func _celebrate_win() -> void:
	var player: Node = get_tree().current_scene.find_child("NamChef", true, false)
	if player is Node3D:
		var pos: Vector3 = (player as Node3D).global_position + Vector3.UP * 2.2
		Juice.confetti(pos, 90)
		Juice.popup_text(pos + Vector3.UP * 0.8, "HOÀN THÀNH!", Color(1.0, 0.85, 0.2), 60, 1.2)


func _build_hud() -> void:
	var hud_height := HUD_DISPLAY_WIDTH / HUD_ASPECT

	# Nền ảnh UIGameplay.
	_hud_bg = TextureRect.new()
	_hud_bg.name = "GameplayHudBg"
	_hud_bg.texture = UI_GAMEPLAY_TEXTURE
	_hud_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hud_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hud_bg.position = Vector2(-5.0, -5.0)
	_hud_bg.size = Vector2(HUD_DISPLAY_WIDTH, hud_height)
	_hud_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_bg)

	# Tạo 3 label overlay cho 3 ô trống trong ảnh.
	# Vị trí ước tính theo tỷ lệ ảnh gốc (1536×1024):
	# - Ô 1 (khách): nằm ở ~55%-92% ngang, ~8%-30% dọc
	# - Ô 2 (sai món): nằm ở ~55%-92% ngang, ~36%-58% dọc
	# - Ô 3 (timer): nằm ở ~55%-92% ngang, ~64%-86% dọc

	_customer_label = _create_hud_label()
	_customer_label.name = "CustomerLabel"
	_hud_bg.add_child(_customer_label)

	_wrong_label = _create_hud_label()
	_wrong_label.name = "WrongLabel"
	_hud_bg.add_child(_wrong_label)

	_timer_label = _create_hud_label()
	_timer_label.name = "TimerLabel"
	_hud_bg.add_child(_timer_label)

	# Đặt vị trí các label dựa trên kích thước HUD.
	_layout_hud_labels()

	_phase_label = Label.new()
	_phase_label.name = "DayPhaseBanner"
	_phase_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_phase_label.position = Vector2(-210.0, 28.0)
	_phase_label.size = Vector2(420.0, 58.0)
	_phase_label.pivot_offset = _phase_label.size * 0.5
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 28)
	_phase_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	_phase_label.add_theme_color_override("font_outline_color", Color(0.16, 0.07, 0.01, 1.0))
	_phase_label.add_theme_constant_override("outline_size", 7)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.visible = false
	add_child(_phase_label)


func _create_hud_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.35, 0.18, 0.05, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.95, 0.85, 0.65, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout_hud_labels() -> void:
	var w := _hud_bg.size.x
	var h := _hud_bg.size.y

	# Ô 1: Khách hàng.
	_customer_label.position = Vector2(w * 0.42, h * 0.16)
	_customer_label.size = Vector2(w * 0.46, h * 0.18)

	# Ô 2: Sai món.
	_wrong_label.position = Vector2(w * 0.42, h * 0.39)
	_wrong_label.size = Vector2(w * 0.46, h * 0.18)

	# Ô 3: Thời gian.
	_timer_label.position = Vector2(w * 0.42, h * 0.65)
	_timer_label.size = Vector2(w * 0.46, h * 0.18)


func _update_hud() -> void:
	_last_display_second = int(ceil(_time_left))

	if _customer_label:
		_customer_label.text = "%d / %d" % [_served_customers, required_customers]
	if _wrong_label:
		_wrong_label.text = "%d / %d" % [_wrong_orders, max_wrong_orders]
	if _timer_label:
		_timer_label.text = _format_time(_time_left)


func _format_time(seconds_left: float) -> String:
	var total_seconds: int = maxi(0, int(ceil(seconds_left)))
	var minutes: int = floori(float(total_seconds) / 60.0)
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
