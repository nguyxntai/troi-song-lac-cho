extends Node

## Autoload: trạng thái phiên chơi (tiền, combo, uy tín, nâng cấp, hệ số sự kiện).
## Là nguồn dữ liệu trung tâm; các hệ thống khác đọc/ghi qua đây thay vì tự giữ riêng.

# ---------- Bảng giá & thưởng (cân bằng số liệu ở đây) ----------
const BASE_PRICE := {
	"bo_kho": 30,
	"nuoc_ngot": 18,
}

# Mục tiêu tiền của từng giai đoạn (đóng góp bằng tiền trong ví).
const STAGE_MONEY_GOAL := {
	1: 600,   # Chương 1 - Trả nợ gia đình
	2: 900,   # Chương 2 - Viện phí
	3: 1200,  # Chương 3 - Quỹ cưới
}
const DEFAULT_PRICE := 20
const TIP_BY_STARS := {5: 15, 4: 8, 3: 3, 2: 0, 1: 0}

const COMBO_THRESHOLD := 3          # số khách 5 sao liên tiếp để kích hoạt "Khách sộp"
const GENEROUS_GUEST_COUNT := 3     # số khách kế tiếp được x2 tip
const GENEROUS_TIP_MULTIPLIER := 2.0

const POPULARITY_GAIN := 0.12
const POPULARITY_LOSS := 0.06
const POPULARITY_BUSY_THRESHOLD := 0.85

# ---------- Cấp bậc theo tổng tiền kiếm được cả đời (bám cốt truyện) ----------
const RANKS := [
	{"title": "Cử nhân thất nghiệp", "threshold": 0},
	{"title": "Phụ bếp tập sự", "threshold": 200},
	{"title": "Đầu bếp ghe", "threshold": 600},
	{"title": "Chủ bến ghe", "threshold": 1500},
	{"title": "Danh tiếng chợ nổi", "threshold": 3500},
	{"title": "Vua Đầu Bếp Miền Tây", "threshold": 7000},
]

# ---------- Trạng thái phiên ----------
var money: int = 0
var chapter_index: int = 1
var day_index: int = 1
var combo_count: int = 0
var generous_remaining: int = 0
var popularity: float = 0.0

var is_tutorial_locked: bool = false
var staff_patience_multiplier: float = 1.0
var chapter_advanced_after_last_day: bool = false
var chapter_completed_after_last_day: bool = false
var last_completed_chapter_index: int = 0

## Hệ số thu nhập do sự kiện (vd: đoàn du lịch x2). Nhiều sự kiện nhân dồn.
var earnings_multiplier: float = 1.0

## Nâng cấp đã mua. premium/tip_boost theo cấp; anti_slip/canopy là bật/tắt.
const DEFAULT_UPGRADES := {
	"premium": 0,      # +giá mỗi món
	"tip_boost": 0,    # +tip mỗi sao
	"anti_slip": 0,    # ủng chống trượt (0/1)
	"canopy": 0,       # mái che (0/1)
	"move_speed": 0,   # Nam di chuyển nhanh hơn
	"guest_patience": 0, # khách chờ món lâu hơn
	"bowl_capacity": 0,  # thêm tô cho mỗi ngày
}
var upgrades: Dictionary = DEFAULT_UPGRADES.duplicate(true)

# ---------- Tham số thời tiết (WeatherManager ghi vào, hệ khác đọc ra) ----------
var current_weather: int = 0
var slip_chance: float = 0.0          # xác suất/giây tuột tay khi đang cầm & di chuyển
var throw_deviation: float = 0.0      # độ lệch hướng khi quăng đồ (mùa bão)
var drink_demand_bias: float = 0.0    # >0: khách thiên về gọi nước (mùa khô)
var food_cooling_mult: float = 1.0    # hệ số nguội/ngấm nước nhanh hơn
## Số lần trượt còn lại trong ngày mưa. Đặt giới hạn để gameplay có bất ngờ
## nhưng không thể tạo chuỗi rơi đồ vô hạn do RNG xấu.
var weather_slip_budget: int = 0

# ---------- Tham số sự kiện ----------
var guest_eat_speed_mult: float = 1.0 # <1: khách ăn chậm (cò đất quấy rối)

# ---------- Cờ bật/tắt hệ thống (để dễ debug từng phần) ----------
var enable_water_risk: bool = true
var enable_weather: bool = true
var enable_random_events: bool = true


## WeatherManager gọi để cập nhật tham số môi trường dùng chung.
func set_weather_params(weather: int, slip: float, deviation: float, drink_bias: float, cooling: float) -> void:
	current_weather = weather
	slip_chance = maxf(slip, 0.0)
	throw_deviation = maxf(deviation, 0.0)
	drink_demand_bias = clampf(drink_bias, -1.0, 1.0)
	food_cooling_mult = maxf(cooling, 0.1)
	if has_anti_slip():
		# Ủng là nâng cấp phòng thủ rõ rệt: vẫn còn cảm giác mưa trơn,
		# nhưng gần như không biến thành rơi món vô lý.
		slip_chance *= 0.35


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Nạp sớm để các node gameplay đọc đúng nâng cấp ngay trong _ready(), trước
	# khi SystemsBootstrap gọi start_session ở cuối scene tree.
	money = SaveManager.get_bank()
	chapter_index = SaveManager.get_current_chapter()
	day_index = SaveManager.get_current_day()
	upgrades = SaveManager.get_upgrades(DEFAULT_UPGRADES)


var _rank: int = 0


## Gọi khi vào màn chơi. reset_money=false để giữ tiền & nâng cấp giữa các ngày.
func start_session(reset_money: bool = false) -> void:
	if reset_money:
		money = 0
		chapter_index = 1
		day_index = 1
		upgrades = DEFAULT_UPGRADES.duplicate(true)
		SaveManager.set_bank(0)
		SaveManager.set_current_chapter(chapter_index)
		SaveManager.set_current_day(day_index)
		SaveManager.set_upgrades(upgrades)
		SaveManager.save_game()
	else:
		# Nạp tiền tích luỹ từ file lưu để tiêu ở Shop xuyên suốt các lượt chơi.
		money = SaveManager.get_bank()
		chapter_index = SaveManager.get_current_chapter()
		day_index = SaveManager.get_current_day()
		upgrades = SaveManager.get_upgrades(DEFAULT_UPGRADES)
	_rank = _compute_rank(SaveManager.get_total_earned())
	combo_count = 0
	generous_remaining = 0
	popularity = 0.0
	earnings_multiplier = 1.0
	# Reset tham số môi trường/sự kiện để replay sạch sẽ.
	current_weather = 0
	slip_chance = 0.0
	throw_deviation = 0.0
	drink_demand_bias = 0.0
	food_cooling_mult = 1.0
	weather_slip_budget = 0
	guest_eat_speed_mult = 1.0
	staff_patience_multiplier = 1.0
	chapter_advanced_after_last_day = false
	chapter_completed_after_last_day = false
	last_completed_chapter_index = 0
	EventBus.day_started.emit(day_index)
	EventBus.money_changed.emit(money, 0)
	EventBus.popularity_changed.emit(popularity)
	EventBus.combo_changed.emit(combo_count, generous_remaining > 0)


## Reset toàn bộ (về menu / chơi mới).
func reset_all() -> void:
	start_session(true)


# ---------- Tiền ----------
func add_money(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	SaveManager.set_bank(money)
	if amount > 0:
		SaveManager.add_total_earned(amount)
		_check_rank_up()
	EventBus.money_changed.emit(money, amount)


## Khoản hỗ trợ/cốt truyện: cộng vào ngân quỹ nhưng không tính là doanh thu nghề nghiệp.
func grant_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	SaveManager.set_bank(money)
	SaveManager.save_game()
	EventBus.money_changed.emit(money, amount)


func can_afford(cost: int) -> bool:
	return money >= cost


func spend_money(cost: int) -> bool:
	if not can_afford(cost):
		return false
	money -= cost
	SaveManager.set_bank(money)
	SaveManager.save_game()
	EventBus.money_changed.emit(money, -cost)
	return true


# ---------- Cấp bậc ----------
func _compute_rank(total_earned: int) -> int:
	var rank := 0
	for i in range(RANKS.size()):
		if total_earned >= int(RANKS[i]["threshold"]):
			rank = i
	return rank


func get_rank() -> int:
	return _rank


func get_rank_title() -> String:
	return String(RANKS[clampi(_rank, 0, RANKS.size() - 1)]["title"])


func _check_rank_up() -> void:
	var new_rank := _compute_rank(SaveManager.get_total_earned())
	if new_rank > _rank:
		_rank = new_rank
		SaveManager.set_best_rank(_rank)
		EventBus.rank_up.emit(_rank, get_rank_title())


# ---------- Báo cáo 1 khách được phục vụ ----------
## guest_ai gọi hàm này với số sao đã chấm. Trả về tổng tiền khách trả.
func report_served_guest(stars: int, food_id: String) -> int:
	stars = clampi(stars, 1, 5)
	var base_price: int = int(BASE_PRICE.get(food_id, DEFAULT_PRICE))
	base_price += int(upgrades.get("premium", 0)) * 5

	var tip: int = int(TIP_BY_STARS.get(stars, 0))
	if tip > 0:
		tip += int(upgrades.get("tip_boost", 0)) * 3

	var is_generous: bool = generous_remaining > 0
	if is_generous and tip > 0:
		tip = int(round(tip * GENEROUS_TIP_MULTIPLIER))

	var total: int = int(round((base_price + tip) * earnings_multiplier))
	add_money(total)

	_update_combo(stars)
	_update_popularity(stars)
	if is_generous:
		generous_remaining -= 1
		EventBus.combo_changed.emit(combo_count, generous_remaining > 0)

	EventBus.guest_served.emit(stars, tip, food_id)
	return total


func report_unhappy_guest(reason: String) -> void:
	combo_count = 0
	_update_popularity(1)
	generous_remaining = maxi(generous_remaining, 0)
	EventBus.combo_changed.emit(combo_count, generous_remaining > 0)
	EventBus.guest_left_unhappy.emit(reason)


func _update_combo(stars: int) -> void:
	if stars >= 5:
		combo_count += 1
		if combo_count >= COMBO_THRESHOLD and generous_remaining <= 0:
			generous_remaining = GENEROUS_GUEST_COUNT
	elif stars <= 3:
		combo_count = 0
	EventBus.combo_changed.emit(combo_count, generous_remaining > 0)


func _update_popularity(stars: int) -> void:
	if stars >= 4:
		popularity = clampf(popularity + POPULARITY_GAIN, 0.0, 1.0)
	elif stars <= 2:
		popularity = clampf(popularity - POPULARITY_LOSS, 0.0, 1.0)
	EventBus.popularity_changed.emit(popularity)


func is_market_busy() -> bool:
	return popularity >= POPULARITY_BUSY_THRESHOLD


# ---------- Mục tiêu tiền của giai đoạn (ví chung, đóng góp trừ tiền) ----------
func get_stage_money_goal() -> int:
	return int(STAGE_MONEY_GOAL.get(chapter_index, 0))


func get_stage_fund() -> int:
	if chapter_index == 1:
		return SaveManager.get_chapter1_debt_paid()
	if chapter_index == 2:
		return SaveManager.get_chapter2_fund()
	if chapter_index == 3:
		return SaveManager.get_chapter3_wedding_fund()
	return 0


func get_stage_fund_remaining() -> int:
	return maxi(get_stage_money_goal() - get_stage_fund(), 0)


func is_stage_goal_met() -> bool:
	var goal: int = get_stage_money_goal()
	return goal > 0 and get_stage_fund() >= goal


## Đóng góp tiền trong ví vào mục tiêu (trả nợ / viện phí / quỹ cưới).
## Trả về số tiền thực sự đã đóng (đã trừ khỏi ví). Không đóng quá phần còn thiếu.
func contribute_to_goal(amount: int) -> int:
	var goal: int = get_stage_money_goal()
	if goal <= 0:
		return 0
	amount = mini(amount, money)
	amount = mini(amount, get_stage_fund_remaining())
	if amount <= 0:
		return 0
	if not spend_money(amount):
		return 0
	if chapter_index == 1:
		SaveManager.add_chapter1_debt_paid(amount)
	elif chapter_index == 2:
		SaveManager.add_chapter2_fund(amount)
	elif chapter_index == 3:
		SaveManager.add_chapter3_wedding_fund(amount)
	SaveManager.save_game()
	EventBus.stage_fund_changed.emit(get_stage_fund(), goal)
	return amount


# ---------- Nâng cấp ----------
func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var safe_level: int = maxi(level, 0)
	upgrades[upgrade_id] = safe_level
	SaveManager.set_upgrades(upgrades)
	SaveManager.save_game()
	EventBus.upgrade_purchased.emit(upgrade_id, safe_level)


func complete_day(is_win: bool) -> void:
	var completed_day: int = day_index
	chapter_advanced_after_last_day = false
	chapter_completed_after_last_day = false
	last_completed_chapter_index = 0
	if is_win:
		if chapter_index == 1 and SaveManager.is_chapter_completed(1):
			last_completed_chapter_index = 1
			SaveManager.unlock("chapter_2")
			chapter_index = 2
			day_index = 1
			chapter_advanced_after_last_day = true
			SaveManager.set_current_chapter(chapter_index)
		elif chapter_index == 2 and SaveManager.is_chapter_completed(2):
			last_completed_chapter_index = 2
			SaveManager.unlock("chapter_3")
			chapter_index = 3
			day_index = 1
			chapter_advanced_after_last_day = true
			SaveManager.set_current_chapter(chapter_index)
		elif chapter_index == 3 and SaveManager.is_chapter_completed(3):
			last_completed_chapter_index = 3
			chapter_completed_after_last_day = true
		else:
			day_index += 1
		SaveManager.set_current_day(day_index)
	SaveManager.set_upgrades(upgrades)
	SaveManager.save_game()
	EventBus.day_completed.emit(completed_day, is_win)


func get_move_speed_multiplier() -> float:
	return 1.0 + float(get_upgrade_level("move_speed")) * 0.08


func get_guest_patience_multiplier() -> float:
	return (1.0 + float(get_upgrade_level("guest_patience")) * 0.15) * staff_patience_multiplier


func get_bowl_capacity_bonus() -> int:
	return get_upgrade_level("bowl_capacity") * 2


func set_active_chapter(new_chapter: int, reset_day: bool = false) -> void:
	chapter_index = maxi(new_chapter, 1)
	if reset_day:
		day_index = 1
	SaveManager.set_current_chapter(chapter_index)
	SaveManager.set_current_day(day_index)
	SaveManager.save_game()


func get_active_chapter_scene() -> String:
	if chapter_index >= 3:
		return "res://scenes/chapter3.tscn"
	if chapter_index == 2:
		return "res://scenes/chapter2.tscn"
	return "res://scenes/chapter1.tscn"


func has_anti_slip() -> bool:
	return get_upgrade_level("anti_slip") > 0


func has_canopy() -> bool:
	return get_upgrade_level("canopy") > 0


func set_weather_slip_budget(amount: int) -> void:
	weather_slip_budget = maxi(amount, 0)


func can_trigger_weather_slip() -> bool:
	return weather_slip_budget > 0


func consume_weather_slip() -> void:
	weather_slip_budget = maxi(weather_slip_budget - 1, 0)


# ---------- Hệ số sự kiện ----------
func push_earnings_multiplier(factor: float) -> void:
	earnings_multiplier *= factor


func pop_earnings_multiplier(factor: float) -> void:
	if factor != 0.0:
		earnings_multiplier /= factor
	earnings_multiplier = maxf(earnings_multiplier, 0.01)
