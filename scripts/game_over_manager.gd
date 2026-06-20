extends CanvasLayer
class_name GameOverManager

const GAME_OVER_TEXTURE: Texture2D = preload("res://assets/UI/game_over.png")
const WIN_BG_TEXTURE: Texture2D = preload("res://assets/UI/win_menu/WinUI.png")
const WIN_BTN_REPLAY: Texture2D = preload("res://assets/UI/win_menu/ReplayLevel.png")
const WIN_BTN_CONTINUE: Texture2D = preload("res://assets/UI/win_menu/Continue.png")
const WIN_BTN_HOME: Texture2D = preload("res://assets/UI/win_menu/Home.png")

const REASON_FELL_IN_RIVER := "fell_in_river"
const REASON_NOT_ENOUGH_CUSTOMERS := "not_enough_customers"
const REASON_TOO_MANY_WRONG_ORDERS := "too_many_wrong_orders"
const REASON_CUSTOM := "custom"

const GAME_OVER_REASONS := {
	REASON_FELL_IN_RIVER: {
		"title": "Té sông",
		"description": "NamChef đã rơi xuống nước."
	},
	REASON_NOT_ENOUGH_CUSTOMERS: {
		"title": "Không đủ khách",
		"description": "Không phục vụ đủ số lượng khách yêu cầu."
	},
	REASON_TOO_MANY_WRONG_ORDERS: {
		"title": "Sai món quá nhiều",
		"description": "Đưa sai món quá số lượt cho phép."
	},
	REASON_CUSTOM: {
		"title": "Thua cuộc",
		"description": "Nhiệm vụ thất bại."
	}
}

@export var player_path: NodePath = NodePath("../NamChef")
@export var fall_y: float = -1.4
@export var watch_player_fall: bool = true
@export var restart_action: StringName = &"ui_accept"
@export_file("*.tscn") var menu_scene_path: String = ""

# Hover animation settings
@export var button_hover_scale: float = 1.08
@export var button_hover_duration: float = 0.1

var _player: Node3D
var _is_game_over := false
var _button_tweens: Dictionary = {}

var _game_over_panel: Control
var _win_panel: Control

var _go_reason_label: Label
var _win_reason_label: Label
var _dim_bg: ColorRect

var _dev_popup_panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_node_or_null(player_path) as Node3D
	_build_ui()
	visible = false
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _process(_delta: float) -> void:
	if _is_game_over:
		if Input.is_action_just_pressed(restart_action):
			restart_current_scene()
		return

	if watch_player_fall and _player and _player.global_position.y < fall_y:
		show_game_over(REASON_FELL_IN_RIVER)


func show_game_over(reason_key: String = REASON_CUSTOM, custom_description: String = "") -> void:
	if _is_game_over:
		return

	_is_game_over = true
	_game_over_panel.visible = true
	_win_panel.visible = false
	
	var reason: Dictionary = GAME_OVER_REASONS.get(reason_key, GAME_OVER_REASONS[REASON_CUSTOM])
	var title: String = str(reason.get("title", "Thua cuộc"))
	var default_description: String = str(reason.get("description", "Nhiệm vụ thất bại."))
	var description: String = custom_description if not custom_description.is_empty() else default_description
	_go_reason_label.text = "Lý do: %s\n%s" % [title, description]
	
	visible = true
	get_tree().paused = true


func show_custom_game_over(title: String, description: String) -> void:
	if _is_game_over:
		return

	_is_game_over = true
	_game_over_panel.visible = true
	_win_panel.visible = false
	_go_reason_label.text = "Lý do: %s\n%s" % [title, description]
	visible = true
	get_tree().paused = true


func show_win(description: String = "") -> void:
	if _is_game_over:
		return

	_is_game_over = true
	_game_over_panel.visible = false
	_win_panel.visible = true
	
	_win_reason_label.text = description
	
	visible = true
	get_tree().paused = true


func restart_current_scene() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	var path := menu_scene_path if not menu_scene_path.is_empty() else "res://scenes/menu.scn"
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _on_continue_pressed() -> void:
	_show_dev_popup()


func _on_replay_pressed() -> void:
	_show_dev_popup()


func _show_dev_popup() -> void:
	if _dev_popup_panel:
		_dev_popup_panel.visible = true


func _close_dev_popup() -> void:
	if _dev_popup_panel:
		_dev_popup_panel.visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.name = "GameOverRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	_dim_bg = ColorRect.new()
	_dim_bg.name = "DimBackground"
	_dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_bg.color = Color(0.0, 0.0, 0.0, 0.58)
	root.add_child(_dim_bg)

	# --- Game Over Panel ---
	_game_over_panel = Control.new()
	_game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_game_over_panel)
	
	var go_content := VBoxContainer.new()
	go_content.set_anchors_preset(Control.PRESET_CENTER)
	go_content.offset_left = -360.0
	go_content.offset_top = -250.0
	go_content.offset_right = 360.0
	go_content.offset_bottom = 250.0
	go_content.alignment = BoxContainer.ALIGNMENT_CENTER
	go_content.add_theme_constant_override("separation", 20)
	_game_over_panel.add_child(go_content)

	var go_image_area := Control.new()
	go_image_area.custom_minimum_size = Vector2(621.0, 402.0)
	go_content.add_child(go_image_area)

	var go_image := TextureRect.new()
	go_image.texture = GAME_OVER_TEXTURE
	go_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	go_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	go_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	go_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go_image_area.add_child(go_image)

	var reload_icon_button := _create_invisible_icon_button(Vector2(165.0, 205.0), Vector2(150.0, 150.0))
	reload_icon_button.pressed.connect(restart_current_scene)
	go_image_area.add_child(reload_icon_button)

	var home_icon_button := _create_invisible_icon_button(Vector2(330.0, 205.0), Vector2(150.0, 150.0))
	home_icon_button.pressed.connect(go_to_menu)
	go_image_area.add_child(home_icon_button)

	_go_reason_label = Label.new()
	_go_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_go_reason_label.add_theme_font_size_override("font_size", 30)
	_go_reason_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	_go_reason_label.add_theme_color_override("font_outline_color", Color(0.22, 0.07, 0.03, 1.0))
	_go_reason_label.add_theme_constant_override("outline_size", 8)
	go_content.add_child(_go_reason_label)


	# --- Win Panel ---
	_win_panel = Control.new()
	_win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_win_panel)
	
	var win_bg = TextureRect.new()
	win_bg.name = "WinBg"
	win_bg.texture = WIN_BG_TEXTURE
	win_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	win_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_win_panel.add_child(win_bg)
	
	var win_content = VBoxContainer.new()
	win_content.name = "WinContent"
	win_content.alignment = BoxContainer.ALIGNMENT_CENTER
	win_content.add_theme_constant_override("separation", 12)
	win_bg.add_child(win_content)
	
	_win_reason_label = Label.new()
	_win_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_win_reason_label.add_theme_font_size_override("font_size", 28)
	_win_reason_label.add_theme_color_override("font_color", Color(0.2, 0.05, 0.0, 1.0))
	_win_reason_label.add_theme_color_override("font_outline_color", Color(1.0, 0.9, 0.8, 1.0))
	_win_reason_label.add_theme_constant_override("outline_size", 4)
	win_content.add_child(_win_reason_label)
	
	var btn_container = VBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 8)
	win_content.add_child(btn_container)
	
	_create_win_button(WIN_BTN_CONTINUE, _on_continue_pressed, btn_container)
	_create_win_button(WIN_BTN_REPLAY, _on_replay_pressed, btn_container)
	_create_win_button(WIN_BTN_HOME, go_to_menu, btn_container)

	# --- In-Development Popup ---
	_dev_popup_panel = Control.new()
	_dev_popup_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dev_popup_panel.visible = false
	root.add_child(_dev_popup_panel)
	
	var dev_dim = ColorRect.new()
	dev_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_dim.color = Color(0.0, 0.0, 0.0, 0.7)
	_dev_popup_panel.add_child(dev_dim)
	
	var dev_box = ColorRect.new()
	dev_box.color = Color(0.15, 0.15, 0.15, 1.0)
	dev_box.custom_minimum_size = Vector2(400, 200)
	dev_box.set_anchors_preset(Control.PRESET_CENTER)
	dev_box.offset_left = -200
	dev_box.offset_top = -100
	dev_box.offset_right = 200
	dev_box.offset_bottom = 100
	_dev_popup_panel.add_child(dev_box)
	
	var dev_vbox = VBoxContainer.new()
	dev_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	dev_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dev_vbox.add_theme_constant_override("separation", 20)
	dev_box.add_child(dev_vbox)
	
	var dev_label = Label.new()
	dev_label.text = "Chức năng đang được phát triển!"
	dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_label.add_theme_font_size_override("font_size", 24)
	dev_label.add_theme_color_override("font_color", Color.WHITE)
	dev_vbox.add_child(dev_label)
	
	var dev_close_btn = Button.new()
	dev_close_btn.text = "OK"
	dev_close_btn.custom_minimum_size = Vector2(100, 40)
	dev_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dev_close_btn.pressed.connect(_close_dev_popup)
	dev_vbox.add_child(dev_close_btn)


func _create_invisible_icon_button(position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.flat = true
	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	return button


func _create_win_button(tex: Texture2D, callback: Callable, parent: Control) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.texture_hover = tex
	btn.texture_pressed = tex
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.ignore_texture_size = true
	
	btn.pressed.connect(callback)
	
	var hover_in := Callable(self, "_animate_button_scale").bind(btn, button_hover_scale)
	var hover_out := Callable(self, "_animate_button_scale").bind(btn, 1.0)
	btn.mouse_entered.connect(hover_in)
	btn.mouse_exited.connect(hover_out)
	btn.focus_entered.connect(hover_in)
	btn.focus_exited.connect(hover_out)
	
	parent.add_child(btn)
	return btn


func _animate_button_scale(btn: TextureButton, target_scale: float) -> void:
	var existing_tween := _button_tweens.get(btn) as Tween
	if existing_tween != null:
		existing_tween.kill()

	var tween := create_tween()
	_button_tweens[btn] = tween
	tween.tween_property(
		btn,
		"scale",
		Vector2.ONE * target_scale,
		button_hover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _relayout() -> void:
	if not _win_panel:
		return
		
	var vp_size := get_viewport().get_visible_rect().size
	var win_bg := _win_panel.get_node_or_null("WinBg") as TextureRect
	if not win_bg: return
	
	var base_bg_size := Vector2(1000.0, 750.0)
	if WIN_BG_TEXTURE:
		base_bg_size = WIN_BG_TEXTURE.get_size()
		
	var scale_factor := minf(vp_size.x / base_bg_size.x * 0.8, vp_size.y / base_bg_size.y * 0.9)
	var final_bg_size := base_bg_size * scale_factor
	
	win_bg.size = final_bg_size
	win_bg.position = (vp_size - final_bg_size) * 0.5
	
	var win_content := win_bg.get_node("WinContent") as Control
	
	win_content.size = Vector2(final_bg_size.x * 0.56, final_bg_size.y * 0.56)
	win_content.position = Vector2(final_bg_size.x * 0.22, final_bg_size.y * 0.30)
	_win_reason_label.custom_minimum_size = Vector2(win_content.size.x, final_bg_size.y * 0.13)
	
	var btn_container := win_content.get_child(1) as Container
	var btn_height := final_bg_size.y * 0.095
	for btn in btn_container.get_children():
		var t_btn := btn as TextureButton
		if not t_btn: continue
		var aspect := 3.0
		if t_btn.texture_normal:
			aspect = t_btn.texture_normal.get_size().x / t_btn.texture_normal.get_size().y
		
		t_btn.custom_minimum_size = Vector2(btn_height * aspect, btn_height)
		t_btn.size = t_btn.custom_minimum_size
		t_btn.scale = Vector2.ONE
		t_btn.pivot_offset = t_btn.custom_minimum_size * 0.5
