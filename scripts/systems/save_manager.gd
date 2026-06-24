extends Node

## Autoload: lưu trữ bền vững (user://troi_song_save.json).
## Giữ tiền tích luỹ (bank), tổng kiếm được (cho cấp bậc), kỷ lục điểm theo ngày,
## danh hiệu đã đạt, và các mục đã mở khoá. Đây là xương sống của tính replay.

const SAVE_PATH := "user://troi_song_save.json"
const SAVE_VERSION := 1

var data: Dictionary = {
	"version": SAVE_VERSION,
	"bank": 0,
	"total_earned": 0,
	"best_scores": {},      # { "1": 2400, "2": ... } theo day_index
	"best_rank": 0,
	"unlocks": {},          # { upgrade_id/cosmetic_id: true }
}

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
		"total_earned": 0,
		"best_scores": {},
		"best_rank": 0,
		"unlocks": {},
	}
	save_game()
