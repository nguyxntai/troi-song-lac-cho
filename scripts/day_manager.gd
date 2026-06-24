extends CanvasLayer
class_name DayManager

@export var required_customers: int = 5
@export var day_duration: float = 300.0
@export var max_wrong_orders: int = 3
@export var auto_start: bool = true
@export var game_over_manager_path: NodePath = NodePath("../GameOverManager")

var _served_customers: int = 0
var _wrong_orders: int = 0
var _time_left: float = 0.0
var _is_finished: bool = false
var _is_running: bool = false
var _game_over_manager: GameOverManager
var _hud_label: Label
var _last_display_second: int = -1


func _ready() -> void:
	add_to_group("day_manager")
	_time_left = maxf(day_duration, 0.0)
	_is_running = auto_start
	_game_over_manager = get_node_or_null(game_over_manager_path) as GameOverManager
	if not _game_over_manager:
		_game_over_manager = get_tree().current_scene.find_child("GameOverManager", true, false) as GameOverManager

	_build_hud()
	_update_hud()


func _process(delta: float) -> void:
	if _is_finished or not _is_running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
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

	_wrong_orders += 1
	_update_hud()
	if _wrong_orders >= max_wrong_orders:
		_show_too_many_wrong_orders_game_over()


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
	_present_results(results, false, header, GameOverManager.REASON_TOO_MANY_WRONG_ORDERS)


func _show_win() -> void:
	if _is_finished:
		return

	_is_finished = true
	_is_running = false
	var header: String = "Đã phục vụ đủ %d/%d khách!" % [_served_customers, required_customers]
	var results: Dictionary = ScoreManager.finalize(GameManager.day_index)
	_present_results(results, true, header, "")


func _show_not_enough_customers_game_over() -> void:
	if _is_finished:
		return

	_is_finished = true
	_is_running = false
	var header: String = "Hết ngày, mới phục vụ %d/%d khách." % [_served_customers, required_customers]
	var results: Dictionary = ScoreManager.finalize(GameManager.day_index)
	_present_results(results, false, header, GameOverManager.REASON_NOT_ENOUGH_CUSTOMERS)


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
	_hud_label = Label.new()
	_hud_label.name = "DayHudLabel"
	_hud_label.position = Vector2(24.0, 20.0)
	_hud_label.add_theme_font_size_override("font_size", 28)
	_hud_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.86, 1.0))
	_hud_label.add_theme_color_override("font_outline_color", Color(0.13, 0.06, 0.02, 1.0))
	_hud_label.add_theme_constant_override("outline_size", 7)
	add_child(_hud_label)


func _update_hud() -> void:
	if not _hud_label:
		return

	_last_display_second = int(ceil(_time_left))
	_hud_label.text = "Khách: %d/%d\nSai món: %d/%d\nThời gian: %s" % [
		_served_customers,
		required_customers,
		_wrong_orders,
		max_wrong_orders,
		_format_time(_time_left),
	]


func _format_time(seconds_left: float) -> String:
	var total_seconds: int = maxi(0, int(ceil(seconds_left)))
	var minutes: int = floori(float(total_seconds) / 60.0)
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
