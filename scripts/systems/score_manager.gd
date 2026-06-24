extends Node

## Autoload: điểm hiệu suất trong ngày + huy chương + kỷ lục.
## Điểm tách biệt với tiền: tiền để mua nâng cấp, điểm để so kỷ lục & nhận medal.

const MEDAL_NONE := 0
const MEDAL_BRONZE := 1
const MEDAL_SILVER := 2
const MEDAL_GOLD := 3

const MEDAL_NAMES := {
	MEDAL_NONE: "Chưa đạt",
	MEDAL_BRONZE: "HẠNG ĐỒNG",
	MEDAL_SILVER: "HẠNG BẠC",
	MEDAL_GOLD: "HẠNG VÀNG",
}
const MEDAL_COLORS := {
	MEDAL_NONE: Color(0.7, 0.7, 0.7),
	MEDAL_BRONZE: Color(0.80, 0.50, 0.25),
	MEDAL_SILVER: Color(0.85, 0.85, 0.9),
	MEDAL_GOLD: Color(1.0, 0.84, 0.2),
}

# Mốc điểm để đạt medal (ngày demo 5 khách). Có thể cân bằng lại sau.
const THRESHOLD_BRONZE := 600
const THRESHOLD_SILVER := 1200
const THRESHOLD_GOLD := 2000

# Điểm cơ bản theo sao + thưởng combo.
const POINTS_PER_STAR := 120
const COMBO_BONUS := 25

var day_score: int = 0
var served_count: int = 0
var five_star_count: int = 0
var wrong_count: int = 0
var missed_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.guest_served.connect(_on_guest_served)
	EventBus.guest_left_unhappy.connect(_on_guest_unhappy)
	EventBus.day_started.connect(_on_day_started)


func _on_day_started(_day_index: int) -> void:
	reset()


func reset() -> void:
	day_score = 0
	served_count = 0
	five_star_count = 0
	wrong_count = 0
	missed_count = 0
	EventBus.score_changed.emit(day_score)


func _on_guest_served(stars: int, _tip: int, _food_id: String) -> void:
	var pts: int = stars * POINTS_PER_STAR
	pts += maxi(GameManager.combo_count - 1, 0) * COMBO_BONUS
	if GameManager.generous_remaining > 0:
		pts = int(round(pts * 1.25))
	day_score += pts
	served_count += 1
	if stars >= 5:
		five_star_count += 1
	EventBus.score_changed.emit(day_score)


func _on_guest_unhappy(reason: String) -> void:
	if reason == "wrong_order":
		wrong_count += 1
	else:
		missed_count += 1


func get_medal(score: int) -> int:
	if score >= THRESHOLD_GOLD:
		return MEDAL_GOLD
	if score >= THRESHOLD_SILVER:
		return MEDAL_SILVER
	if score >= THRESHOLD_BRONZE:
		return MEDAL_BRONZE
	return MEDAL_NONE


## Chốt điểm cuối ngày: lưu kỷ lục, trả về dict kết quả cho màn hình tổng kết.
func finalize(day_index: int) -> Dictionary:
	var medal: int = get_medal(day_score)
	var previous_best: int = SaveManager.get_best_score(day_index)
	var is_record: bool = SaveManager.submit_score(day_index, day_score)
	SaveManager.save_game()

	var results := {
		"day_index": day_index,
		"score": day_score,
		"medal": medal,
		"medal_name": String(MEDAL_NAMES.get(medal, "")),
		"medal_color": MEDAL_COLORS.get(medal, Color.WHITE),
		"best": maxi(previous_best, day_score),
		"is_record": is_record,
		"served": served_count,
		"five_stars": five_star_count,
		"wrong": wrong_count,
		"missed": missed_count,
		"next_medal_at": _next_medal_threshold(day_score),
	}
	EventBus.day_results.emit(results)
	return results


func _next_medal_threshold(score: int) -> int:
	if score < THRESHOLD_BRONZE:
		return THRESHOLD_BRONZE
	if score < THRESHOLD_SILVER:
		return THRESHOLD_SILVER
	if score < THRESHOLD_GOLD:
		return THRESHOLD_GOLD
	return 0
