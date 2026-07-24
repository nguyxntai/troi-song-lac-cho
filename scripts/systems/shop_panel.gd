extends CanvasLayer

signal closed

## Shop nâng cấp cuối ngày (dựng bằng code). ResultsScreen mở shop sau khi thắng;
## mỗi ngày chỉ được mua một nâng cấp và tiến trình được lưu qua GameManager.

const TOGGLE_ACTION := &"toggle_shop"

# id, tên, mô tả, giá cơ bản, cấp tối đa, bước giá mỗi cấp
const UPGRADES := [
	{"id": "move_speed", "name": "Bước chân nhanh", "desc": "+8% tốc độ di chuyển", "cost": 70, "max": 3, "step": 45},
	{"id": "guest_patience", "name": "Phục vụ thân thiện", "desc": "+15% thời gian khách chờ", "cost": 65, "max": 3, "step": 40},
	{"id": "bowl_capacity", "name": "Thêm chồng tô", "desc": "+2 tô dùng được mỗi ngày", "cost": 55, "max": 3, "step": 35},
	{"id": "premium", "name": "Nguyên liệu cao cấp", "desc": "+5 VND mỗi món bán ra", "cost": 60, "max": 3, "step": 40},
	{"id": "tip_boost", "name": "Khéo chiều khách", "desc": "+3 tip mỗi sao", "cost": 50, "max": 3, "step": 35},
	{"id": "anti_slip", "name": "Ủng chống trượt", "desc": "Giảm tuột tay khi bão", "cost": 80, "max": 1, "step": 0},
	{"id": "canopy", "name": "Mái che", "desc": "Đồ lâu ngấm nước / nguội", "cost": 80, "max": 1, "step": 0},
]

var _panel: Control
var _money_label: Label
var _rows: Array = []
var _is_open: bool = false
var _is_day_end_mode: bool = false
var _purchases_remaining: int = 0
var _unlimited_purchases: bool = false
var _status_label: Label


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(TOGGLE_ACTION) and event.is_action_pressed(TOGGLE_ACTION):
		if _is_open:
			set_open(false)
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if _is_open:
		set_open(false)


func open_for_day_end(max_purchases: int = 1) -> void:
	_is_day_end_mode = true
	_unlimited_purchases = max_purchases < 0
	_purchases_remaining = maxi(max_purchases, 0)
	set_open(true)


func set_open(open: bool) -> void:
	_is_open = open
	_panel.visible = open
	if open:
		get_tree().paused = true
	elif not _is_day_end_mode:
		get_tree().paused = false
	if open:
		_refresh()
	else:
		_is_day_end_mode = false
		closed.emit()


func _build_ui() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_panel.add_child(dim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(600, 650)
	box.offset_left = -300
	box.offset_top = -325
	box.offset_right = 300
	box.offset_bottom = 325
	box.add_theme_stylebox_override("panel", UIStyle.wood_panel(18, 20, true))
	_panel.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	box.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "CỬA HÀNG NÂNG CẤP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.style_title(title, 28)
	header.add_child(title)

	_money_label = Label.new()
	UIStyle.style_label(_money_label, 24, UIStyle.GOLD_TEXT)
	header.add_child(_money_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_status_label, 16, UIStyle.CREAM_SOFT)
	vbox.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 470.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var rows_box := VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 8)
	scroll.add_child(rows_box)
	for data in UPGRADES:
		rows_box.add_child(_build_row(data))

	var close_btn := Button.new()
	close_btn.text = "Xong"
	close_btn.custom_minimum_size = Vector2(0, 42)
	UIStyle.style_button(close_btn, UIStyle.GOLD, 20)
	close_btn.pressed.connect(func(): set_open(false))
	vbox.add_child(close_btn)


func _build_row(data: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIStyle.wood_panel(10, 12))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = String(data["name"])
	UIStyle.style_label(name_label, 20, UIStyle.GOLD_TEXT)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = String(data["desc"])
	UIStyle.style_label(desc_label, 14, UIStyle.CREAM_SOFT, 3)
	info.add_child(desc_label)

	var level_label := Label.new()
	UIStyle.style_label(level_label, 14, UIStyle.CREAM_SOFT, 3)
	info.add_child(level_label)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(150, 50)
	UIStyle.style_button(buy_btn, UIStyle.GOLD, 18)
	buy_btn.pressed.connect(_on_buy.bind(data))
	hbox.add_child(buy_btn)

	_rows.append({"data": data, "level_label": level_label, "buy_btn": buy_btn})
	return row


func _cost_for(data: Dictionary, level: int) -> int:
	return int(data["cost"]) + int(data["step"]) * level


func _on_buy(data: Dictionary) -> void:
	if _is_day_end_mode and not _unlimited_purchases and _purchases_remaining <= 0:
		return
	var id: String = String(data["id"])
	var level: int = GameManager.get_upgrade_level(id)
	if level >= int(data["max"]):
		return
	var cost: int = _cost_for(data, level)
	if GameManager.spend_money(cost):
		GameManager.set_upgrade_level(id, level + 1)
		if _is_day_end_mode and not _unlimited_purchases:
			_purchases_remaining = maxi(_purchases_remaining - 1, 0)
		_refresh()


func _refresh() -> void:
	if _money_label:
		_money_label.text = Currency.format_vnd(GameManager.money)
	if _status_label:
		if _unlimited_purchases:
			_status_label.text = "Mua tuỳ ý — giới hạn là số tiền bạn có"
		else:
			_status_label.text = "Chọn 1 nâng cấp cho ngày tiếp theo" if _purchases_remaining > 0 else "Đã chọn nâng cấp cho ngày này"
	var cap_reached: bool = _is_day_end_mode and not _unlimited_purchases and _purchases_remaining <= 0
	for row in _rows:
		var data: Dictionary = row["data"]
		var id: String = String(data["id"])
		var level: int = GameManager.get_upgrade_level(id)
		var max_level: int = int(data["max"])
		row["level_label"].text = "Cấp: %d/%d" % [level, max_level]
		var btn: Button = row["buy_btn"]
		if level >= max_level:
			btn.text = "Đã tối đa"
			btn.disabled = true
		else:
			var cost: int = _cost_for(data, level)
			btn.text = "Mua  %s" % Currency.format_vnd(cost)
			btn.disabled = not GameManager.can_afford(cost) or cap_reached
