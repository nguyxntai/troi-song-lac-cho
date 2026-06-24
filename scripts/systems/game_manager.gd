extends Node

## Autoload: trạng thái phiên chơi (tiền, combo, uy tín, nâng cấp, hệ số sự kiện).
## Là nguồn dữ liệu trung tâm; các hệ thống khác đọc/ghi qua đây thay vì tự giữ riêng.

# ---------- Bảng giá & thưởng (cân bằng số liệu ở đây) ----------
const BASE_PRICE := {
	"bo_kho": 30,
	"nuoc_ngot": 15,
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
var day_index: int = 1
var combo_count: int = 0
var generous_remaining: int = 0
var popularity: float = 0.0

## Hệ số thu nhập do sự kiện (vd: đoàn du lịch x2). Nhiều sự kiện nhân dồn.
var earnings_multiplier: float = 1.0

## Nâng cấp đã mua. premium/tip_boost theo cấp; anti_slip/canopy là bật/tắt.
var upgrades: Dictionary = {
	"premium": 0,      # +giá mỗi món
	"tip_boost": 0,    # +tip mỗi sao
	"anti_slip": 0,    # ủng chống trượt (0/1)
	"canopy": 0,       # mái che (0/1)
}

# ---------- Tham số thời tiết (WeatherManager ghi vào, hệ khác đọc ra) ----------
var current_weather: int = 0
var slip_chance: float = 0.0          # xác suất/giây tuột tay khi đang cầm & di chuyển
var throw_deviation: float = 0.0      # độ lệch hướng khi quăng đồ (mùa bão)
var drink_demand_bias: float = 0.0    # >0: khách thiên về gọi nước (mùa khô)
var food_cooling_mult: float = 1.0    # hệ số nguội/ngấm nước nhanh hơn

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
		slip_chance *= 0.4


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


var _rank: int = 0


## Gọi khi vào màn chơi. reset_money=false để giữ tiền & nâng cấp giữa các ngày.
func start_session(reset_money: bool = false) -> void:
	if reset_money:
		money = 0
		day_index = 1
		upgrades = {"premium": 0, "tip_boost": 0, "anti_slip": 0, "canopy": 0}
		SaveManager.set_bank(0)
		SaveManager.save_game()
	else:
		# Nạp tiền tích luỹ từ file lưu để tiêu ở Shop xuyên suốt các lượt chơi.
		money = SaveManager.get_bank()
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
	guest_eat_speed_mult = 1.0
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


# ---------- Nâng cấp ----------
func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	upgrades[upgrade_id] = level
	EventBus.upgrade_purchased.emit(upgrade_id, level)


func has_anti_slip() -> bool:
	return get_upgrade_level("anti_slip") > 0


func has_canopy() -> bool:
	return get_upgrade_level("canopy") > 0


# ---------- Hệ số sự kiện ----------
func push_earnings_multiplier(factor: float) -> void:
	earnings_multiplier *= factor


func pop_earnings_multiplier(factor: float) -> void:
	if factor != 0.0:
		earnings_multiplier /= factor
	earnings_multiplier = maxf(earnings_multiplier, 0.01)
