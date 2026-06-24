extends Node

## Autoload: kênh signal trung tâm giúp các hệ thống giao tiếp lỏng lẻo (decoupled).
## Bất kỳ script nào cũng có thể: EventBus.guest_served.emit(...) hoặc
## EventBus.guest_served.connect(callable) mà không cần tham chiếu trực tiếp lẫn nhau.

# ----- Kinh tế / phục vụ -----
signal guest_served(stars: int, tip: int, food_id: String)
signal guest_left_unhappy(reason: String)        # bỏ về, sai món, hết kiên nhẫn...
signal wrong_order()
signal money_changed(new_amount: int, delta: int)
signal popularity_changed(ratio: float)           # 0..1
signal combo_changed(count: int, is_generous: bool)

# ----- Thủy kích -----
signal food_dropped_in_water(food_id: String)
signal food_rescued(food_id: String, quality: float)
signal food_lost_in_water(food_id: String)

# ----- Thời tiết -----
signal weather_changed(weather_type: int)         # WeatherManager.Weather

# ----- Sự kiện -----
signal game_event_started(event_id: String, title: String, duration: float)
signal game_event_ended(event_id: String)

# ----- Vòng đời ngày chơi / nâng cấp -----
signal day_started(day_index: int)
signal upgrade_purchased(upgrade_id: String, level: int)

# ----- Tiến trình / điểm số -----
signal rank_up(rank: int, title: String)
signal score_changed(day_score: int)
signal day_results(results: Dictionary)
