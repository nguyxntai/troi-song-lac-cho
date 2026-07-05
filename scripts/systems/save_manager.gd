extends Node

## Autoload: lưu trữ bền vững (user://troi_song_save.json).
## Giữ tiền tích luỹ (bank), tổng kiếm được (cho cấp bậc), kỷ lục điểm theo ngày,
## danh hiệu đã đạt, và các mục đã mở khoá. Đây là xương sống của tính replay.

const SAVE_PATH := "user://troi_song_save.json"
const SAVE_VERSION := 4

var data: Dictionary = {
	"version": SAVE_VERSION,
	"bank": 0,
	"current_chapter": 1,
	"current_day": 1,
	"completed_chapters": {},
	"chapter1_debt_paid": 0,
	"chapter2_fund": 0,
	"chapter2_dad_health": 100,
	"chapter2_intro_seen": false,
	"chapter3_wedding_fund": 0,
	"chapter3_happy_guests": 0,
	"chapter3_intro_seen": false,
	"total_earned": 0,
	"upgrades": {},
	"best_scores": {},      # { "1": 2400, "2": ... } theo day_index
	"best_rank": 0,
	"unlocks": {},          # { upgrade_id/cosmetic_id: true }
	"has_started_game": false,
	"has_completed_tutorial": false,
}

const DAD_HEALTH_MAX := 100

var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		# Trộn để giữ key mặc định nếu file cũ thiếu trường.
		for key in parsed.keys():
			data[key] = parsed[key]


func save_game() -> void:
	data["version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: không mở được file để lưu.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_dirty = false


func mark_dirty_and_save() -> void:
	_dirty = true
	save_game()


# ---------- Bank / tổng kiếm ----------
func get_bank() -> int:
	return int(data.get("bank", 0))


func set_bank(amount: int) -> void:
	data["bank"] = maxi(amount, 0)


func add_total_earned(amount: int) -> void:
	if amount <= 0:
		return
	data["total_earned"] = int(data.get("total_earned", 0)) + amount


func get_total_earned() -> int:
	return int(data.get("total_earned", 0))


# ---------- Ngày chơi / nâng cấp ----------
func get_current_day() -> int:
	return maxi(int(data.get("current_day", 1)), 1)


func set_current_day(day_index: int) -> void:
	data["current_day"] = maxi(day_index, 1)


func get_current_chapter() -> int:
	return maxi(int(data.get("current_chapter", 1)), 1)


func set_current_chapter(chapter_index: int) -> void:
	data["current_chapter"] = maxi(chapter_index, 1)


func is_chapter_completed(chapter_index: int) -> bool:
	var completed: Dictionary = data.get("completed_chapters", {})
	return bool(completed.get(str(chapter_index), false))


func complete_chapter(chapter_index: int) -> void:
	var completed: Dictionary = data.get("completed_chapters", {})
	completed[str(chapter_index)] = true
	data["completed_chapters"] = completed


func get_chapter1_debt_paid() -> int:
	return maxi(int(data.get("chapter1_debt_paid", 0)), 0)


func add_chapter1_debt_paid(amount: int) -> int:
	if amount > 0:
		data["chapter1_debt_paid"] = get_chapter1_debt_paid() + amount
	return get_chapter1_debt_paid()


func get_chapter2_fund() -> int:
	return maxi(int(data.get("chapter2_fund", 0)), 0)


func add_chapter2_fund(amount: int) -> int:
	if amount > 0:
		data["chapter2_fund"] = get_chapter2_fund() + amount
	return get_chapter2_fund()


func get_chapter2_dad_health() -> int:
	return clampi(int(data.get("chapter2_dad_health", DAD_HEALTH_MAX)), 0, DAD_HEALTH_MAX)


func set_chapter2_dad_health(value: int) -> void:
	data["chapter2_dad_health"] = clampi(value, 0, DAD_HEALTH_MAX)


func has_seen_chapter2_intro() -> bool:
	return bool(data.get("chapter2_intro_seen", false))


func set_chapter2_intro_seen(seen: bool) -> void:
	data["chapter2_intro_seen"] = seen


func get_chapter3_wedding_fund() -> int:
	return maxi(int(data.get("chapter3_wedding_fund", 0)), 0)


func add_chapter3_wedding_fund(amount: int) -> int:
	if amount > 0:
		data["chapter3_wedding_fund"] = get_chapter3_wedding_fund() + amount
	return get_chapter3_wedding_fund()


func get_chapter3_happy_guests() -> int:
	return maxi(int(data.get("chapter3_happy_guests", 0)), 0)


func add_chapter3_happy_guest(amount: int = 1) -> int:
	if amount > 0:
		data["chapter3_happy_guests"] = get_chapter3_happy_guests() + amount
	return get_chapter3_happy_guests()


func has_seen_chapter3_intro() -> bool:
	return bool(data.get("chapter3_intro_seen", false))


func set_chapter3_intro_seen(seen: bool) -> void:
	data["chapter3_intro_seen"] = seen


func get_upgrades(defaults: Dictionary = {}) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	var saved: Variant = data.get("upgrades", {})
	if saved is Dictionary:
		for key in (saved as Dictionary).keys():
			result[key] = maxi(int((saved as Dictionary)[key]), 0)
	return result


func set_upgrades(upgrades: Dictionary) -> void:
	data["upgrades"] = upgrades.duplicate(true)


# ---------- Kỷ lục điểm ----------
func get_best_score(day_index: int) -> int:
	var scores: Dictionary = data.get("best_scores", {})
	return int(scores.get(str(day_index), 0))


## Trả về true nếu đây là kỷ lục mới.
func submit_score(day_index: int, score: int) -> bool:
	var scores: Dictionary = data.get("best_scores", {})
	var key := str(day_index)
	var previous := int(scores.get(key, 0))
	if score > previous:
		scores[key] = score
		data["best_scores"] = scores
		return true
	return false


func get_chapter_best_score(chapter_index: int, day_index: int) -> int:
	var scores: Dictionary = data.get("best_scores", {})
	return int(scores.get("chapter_%d_day_%d" % [chapter_index, day_index], 0))


func submit_chapter_score(chapter_index: int, day_index: int, score: int) -> bool:
	var scores: Dictionary = data.get("best_scores", {})
	var key: String = "chapter_%d_day_%d" % [chapter_index, day_index]
	var previous: int = int(scores.get(key, 0))
	if score > previous:
		scores[key] = score
		data["best_scores"] = scores
		return true
	return false


# ---------- Cấp bậc ----------
func get_best_rank() -> int:
	return int(data.get("best_rank", 0))


func set_best_rank(rank: int) -> void:
	if rank > get_best_rank():
		data["best_rank"] = rank


# ---------- Mở khoá ----------
func is_unlocked(id: String) -> bool:
	var unlocks: Dictionary = data.get("unlocks", {})
	return bool(unlocks.get(id, false))


func unlock(id: String) -> void:
	var unlocks: Dictionary = data.get("unlocks", {})
	unlocks[id] = true
	data["unlocks"] = unlocks


func reset_all_progress() -> void:
	data = {
		"version": SAVE_VERSION,
		"bank": 0,
		"current_chapter": 1,
		"current_day": 1,
		"completed_chapters": {},
		"chapter1_debt_paid": 0,
		"chapter2_fund": 0,
		"chapter2_dad_health": 100,
		"chapter2_intro_seen": false,
		"chapter3_wedding_fund": 0,
		"chapter3_happy_guests": 0,
		"chapter3_intro_seen": false,
		"total_earned": 0,
		"upgrades": {},
		"best_scores": {},
		"best_rank": 0,
		"unlocks": {},
		"has_started_game": false,
		"has_completed_tutorial": false,
	}
	save_game()


# ---------- Tutorial ----------
func has_started_game() -> bool:
	if bool(data.get("has_started_game", false)):
		return true
	# Tương thích save cũ chưa có cờ này.
	return (
		has_completed_tutorial()
		or get_current_chapter() > 1
		or get_current_day() > 1
		or get_total_earned() > 0
		or get_chapter1_debt_paid() > 0
		or get_chapter2_fund() > 0
		or get_chapter3_wedding_fund() > 0
	)


func set_game_started(val: bool) -> void:
	data["has_started_game"] = val
	save_game()


func has_completed_tutorial() -> bool:
	return bool(data.get("has_completed_tutorial", false))

func set_tutorial_completed(val: bool) -> void:
	data["has_completed_tutorial"] = val
	save_game()
