extends CanvasLayer

## Shop nâng cấp (dựng bằng code). Mở/đóng bằng phím (action "toggle_shop", mặc định B).
## Tạm dừng game khi mở. Tiêu tiền nâng cấp, lưu vào GameManager.

const TOGGLE_ACTION := &"toggle_shop"

# id, tên, mô tả, giá cơ bản, cấp tối đa, bước giá mỗi cấp
const UPGRADES := [
	{"id": "premium", "name": "Nguyên liệu cao cấp", "desc": "+5$ mỗi món bán ra", "cost": 60, "max": 3, "step": 40},
	{"id": "tip_boost", "name": "Khéo chiều khách", "desc": "+3 tip mỗi sao", "cost": 50, "max": 3, "step": 35},
	{"id": "anti_slip", "name": "Ủng chống trượt", "desc": "Giảm tuột tay khi bão", "cost": 80, "max": 1, "step": 0},
	{"id": "canopy", "name": "Mái che", "desc": "Đồ lâu ngấm nước / nguội", "cost": 80, "max": 1, "step": 0},
]

var _panel: Control
var _money_label: Label
var _rows: Array = []
var _is_open: bool = false


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(TOGGLE_ACTION) and event.is_action_pressed(TOGGLE_ACTION):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_open(not _is_open)


func set_open(open: bool) -> void:
	_is_open = open
	_panel.visible = open
	get_tree().paused = open
	if open:
		_refresh()


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
	box.custom_minimum_size = Vector2(540, 470)
	box.offset_left = -270
	box.offset_top = -235
	box.offset_right = 270
	box.offset_bottom = 235
	_panel.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	box.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "CỬA HÀNG NÂNG CẤP"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 24)
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(_money_label)

	for data in UPGRADES:
		vbox.add_child(_build_row(data))

	var close_btn := Button.new()
	close_btn.text = "Đóng (B)"
	close_btn.custom_minimum_size = Vector2(0, 42)
	close_btn.pressed.connect(func(): set_open(false))
	vbox.add_child(close_btn)


func _build_row(data: Dictionary) -> Control:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = String(data["name"])
	name_label.add_theme_font_size_override("font_size", 20)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = String(data["desc"])
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	info.add_child(desc_label)

	var level_label := Label.new()
	level_label.add_theme_font_size_override("font_size", 14)
	info.add_child(level_label)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(150, 50)
	buy_btn.pressed.connect(_on_buy.bind(data))
	hbox.add_child(buy_btn)

	_rows.append({"data": data, "level_label": level_label, "buy_btn": buy_btn})
	return row


func _cost_for(data: Dictionary, level: int) -> int:
	return int(data["cost"]) + int(data["step"]) * level


func _on_buy(data: Dictionary) -> void:
	var id: String = String(data["id"])
	var level: int = GameManager.get_upgrade_level(id)
	if level >= int(data["max"]):
		return
	var cost: int = _cost_for(data, level)
	if GameManager.spend_money(cost):
		GameManager.set_upgrade_level(id, level + 1)
		_refresh()


func _refresh() -> void:
	if _money_label:
		_money_label.text = "$%d" % GameManager.money
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
			btn.text = "Mua  $%d" % cost
			btn.disabled = not GameManager.can_afford(cost)
