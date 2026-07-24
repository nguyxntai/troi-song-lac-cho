extends Node

## Sự kiện ngẫu nhiên (data-driven). Theo chu kỳ chọn 1 sự kiện buff/debuff,
## áp hiệu ứng khi bắt đầu (apply) và gỡ bỏ khi kết thúc (revert).
## Thêm sự kiện mới = thêm 1 mục vào EVENTS + 2 nhánh match — không đụng code lõi.

const EVENTS := [
	{
		"id": "tourists",
		"title": "Đoàn khách du lịch! Thu nhập x2",
		"duration": 20.0,
		"weight": 1.0,
	},
	{
		"id": "speedboat",
		"title": "Xuồng máy bốc đầu! Sóng lớn",
		"duration": 8.0,
		"weight": 1.0,
	},
	{
		"id": "land_shark",
		"title": "Cò đất quấy rối! Khách ăn chậm",
		"duration": 15.0,
		"weight": 1.0,
	},
]

@export var first_event_delay: float = 25.0
@export var gap_between_events: float = 30.0

var _timer: float = 0.0
var _active_id: String = ""
var _active_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()
var _wave_accumulator: float = 0.0
var _active_boat_multiplier: float = 1.0


func _ready() -> void:
	_rng.randomize()
	_timer = first_event_delay + (20.0 if GameManager.day_index <= 1 else (10.0 if GameManager.day_index == 2 else 0.0))


func _process(delta: float) -> void:
	if not GameManager.enable_random_events:
		return

	if _active_id != "":
		_active_remaining -= delta
		_process_active(delta)
		if _active_remaining <= 0.0:
			_end_event()
		return

	_timer -= delta
	if _timer <= 0.0:
		_start_random_event()


func _start_random_event() -> void:
	var data: Dictionary = _pick_event()
	_active_id = String(data["id"])
	var duration_scale: float = lerpf(0.55, 1.0, _get_adverse_scale()) if _is_adverse_event(_active_id) else 1.0
	_active_remaining = float(data["duration"]) * duration_scale
	_apply_event(_active_id)
	EventBus.game_event_started.emit(_active_id, String(data["title"]), _active_remaining)


func _end_event() -> void:
	var ended: String = _active_id
	_revert_event(ended)
	_active_id = ""
	_timer = gap_between_events + (15.0 if GameManager.day_index <= 1 else (7.0 if GameManager.day_index == 2 else 0.0))
	EventBus.game_event_ended.emit(ended)


func _pick_event() -> Dictionary:
	var total := 0.0
	for e in EVENTS:
		var event_id := String(e.get("id", ""))
		var weight_scale: float = _get_adverse_scale() if _is_adverse_event(event_id) else 1.0
		total += float(e.get("weight", 1.0)) * weight_scale
	var roll := _rng.randf() * total
	for e in EVENTS:
		var event_id := String(e.get("id", ""))
		var weight_scale: float = _get_adverse_scale() if _is_adverse_event(event_id) else 1.0
		roll -= float(e.get("weight", 1.0)) * weight_scale
		if roll <= 0.0:
			return e
	return EVENTS[0]


# ---------- apply / revert ----------
func _apply_event(id: String) -> void:
	match id:
		"tourists":
			GameManager.push_earnings_multiplier(2.0)
		"land_shark":
			GameManager.guest_eat_speed_mult = lerpf(1.0, 0.5, _get_adverse_scale())
		"speedboat":
			_wave_accumulator = 0.0
			_active_boat_multiplier = lerpf(1.0, 2.5, _get_adverse_scale())
			_boost_boats(_active_boat_multiplier)
		_:
			pass


func _revert_event(id: String) -> void:
	match id:
		"tourists":
			GameManager.pop_earnings_multiplier(2.0)
		"land_shark":
			GameManager.guest_eat_speed_mult = 1.0
		"speedboat":
			_boost_boats(1.0 / maxf(_active_boat_multiplier, 0.01))
			_active_boat_multiplier = 1.0
		_:
			pass


func _process_active(delta: float) -> void:
	# Xuồng máy: sóng dồn dập, theo nhịp có cơ hội hất đồ trên tay Nam xuống sông.
	if _active_id == "speedboat":
		_wave_accumulator += delta
		var knock_interval: float = lerpf(4.0, 2.0, _get_adverse_scale())
		if _wave_accumulator >= knock_interval:
			_wave_accumulator = 0.0
			_try_knock_player_item()


func _try_knock_player_item() -> void:
	var player: Node = get_tree().current_scene.find_child("NamChef", true, false)
	if player and player.has_method("drop_carried_item"):
		if _rng.randf() < lerpf(0.15, 0.6, _get_adverse_scale()):
			var dropped: bool = bool(player.call("drop_carried_item", lerpf(0.45, 0.8, _get_adverse_scale())))
			if dropped and player.has_method("knock_down"):
				player.call("knock_down")


func _boost_boats(mult: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for boat_name in ["KitchenBoat", "GuestBoat"]:
		var boat: Node = scene.find_child(boat_name, true, false)
		if boat and boat.get("float_amplitude") != null:
			boat.set("float_amplitude", float(boat.get("float_amplitude")) * mult)
			if boat.get("rotation_amplitude") != null:
				boat.set("rotation_amplitude", float(boat.get("rotation_amplitude")) * mult)


func _get_adverse_scale() -> float:
	if GameManager.day_index <= 1:
		return 0.25
	if GameManager.day_index == 2:
		return 0.55
	return 1.0


func _is_adverse_event(event_id: String) -> bool:
	return event_id == "speedboat" or event_id == "land_shark"
