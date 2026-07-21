extends CanvasLayer
class_name GameOverManager

const GAME_OVER_TEXTURE: Texture2D = preload("res://assets/UI/UIGameOver_vietnamese.png")
const GO_BTN_RETRY: Texture2D = preload("res://assets/UI/common_buttons/choi_lai.png")
const GO_BTN_HOME: Texture2D = preload("res://assets/UI/common_buttons/ve_menu.png")
const WIN_BG_TEXTURE: Texture2D = preload("res://assets/UI/win_menu/WinUI_vietnamese.png")
const WIN_BTN_REPLAY: Texture2D = preload("res://assets/UI/common_buttons/choi_lai.png")
const WIN_BTN_CONTINUE: Texture2D = preload("res://assets/UI/common_buttons/tiep_tuc.png")
const WIN_BTN_HOME: Texture2D = preload("res://assets/UI/common_buttons/ve_menu.png")
const LOADING_RING_SCRIPT: Script = preload("res://scripts/loading_ring.gd")

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
var _go_bg: TextureRect
var _go_btn_container: HBoxContainer
var _win_panel: Control

var _go_reason_label: Label
var _win_reason_label: Label
var _dim_bg: ColorRect

var _dev_popup_panel: Control
var _loading_panel: Control
var _loading_ring: Control
var _is_reloading_scene := false
var _reload_scene_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_node_or_null(player_path) as Node3D
	_build_ui()
	visible = false
	AudioManager.play_river_loop()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _process(delta: float) -> void:
	if _is_reloading_scene:
		_update_loading_ring(delta)
		_poll_replay_load()
		return

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
	
	_stop_chapter_music()
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	if reason_key == REASON_FELL_IN_RIVER:
		AudioManager.play_water_splash()
	AudioManager.play_lose()
	visible = true
	get_tree().paused = true


func show_custom_game_over(title: String, description: String) -> void:
	if _is_game_over:
		return

	_is_game_over = true
	_game_over_panel.visible = true
	_win_panel.visible = false
	_go_reason_label.text = "Lý do: %s\n%s" % [title, description]
	_stop_chapter_music()
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	AudioManager.play_lose()
	visible = true
	get_tree().paused = true


func show_win(description: String = "") -> void:
	if _is_game_over:
		return

	_is_game_over = true
	_game_over_panel.visible = false
	_win_panel.visible = true
	
	_win_reason_label.text = description
	
	_stop_chapter_music()
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	AudioManager.play_win()
	visible = true
	get_tree().paused = true


func restart_current_scene() -> void:
	if _is_reloading_scene:
		return

	_reload_scene_path = ""
	var current_scene := get_tree().current_scene
	if current_scene != null:
		_reload_scene_path = current_scene.scene_file_path

	_show_replay_loading()
	_stop_chapter_music()
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()

	if _reload_scene_path.is_empty():
		get_tree().paused = false
		get_tree().reload_current_scene()
		return

	_is_reloading_scene = true
	var error: int = ResourceLoader.load_threaded_request(_reload_scene_path)
	if error != OK:
		push_error("Cannot start threaded reload for %s. Error: %s" % [_reload_scene_path, error])
		_finish_replay_load_with_fallback()


func go_to_menu() -> void:
	var path := menu_scene_path if not menu_scene_path.is_empty() else "res://scenes/menu.scn"
	_stop_chapter_music()
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _poll_replay_load() -> void:
	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(_reload_scene_path, progress)

	if not progress.is_empty() and _loading_ring != null:
		_loading_ring.call("set_progress", maxf(float(progress[0]), 0.18))

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene_resource: Resource = ResourceLoader.load_threaded_get(_reload_scene_path) as Resource
			var packed_scene := scene_resource as PackedScene
			if packed_scene == null:
				_finish_replay_load_with_fallback()
				return

			get_tree().paused = false
			_is_reloading_scene = false
			var error: int = get_tree().change_scene_to_packed(packed_scene)
			if error != OK:
				push_error("Cannot reload scene %s. Error: %s" % [_reload_scene_path, error])
				_finish_replay_load_with_fallback()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to threaded reload scene: %s" % _reload_scene_path)
			_finish_replay_load_with_fallback()


func _finish_replay_load_with_fallback() -> void:
	_is_reloading_scene = false
	_hide_replay_loading()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_replay_loading() -> void:
	_ensure_loading_panel()
	if _loading_panel == null:
		return

	_loading_panel.visible = true
	_loading_panel.move_to_front()
	if _dev_popup_panel:
		_dev_popup_panel.visible = false
	if _loading_ring != null:
		_loading_ring.rotation = 0.0
		_loading_ring.call("set_progress", 0.18)


func _hide_replay_loading() -> void:
	if _loading_panel != null:
		_loading_panel.visible = false


func _update_loading_ring(delta: float) -> void:
	if _loading_ring == null or not _loading_ring.visible:
		return

	_loading_ring.pivot_offset = _loading_ring.size * 0.5
	_loading_ring.rotation += delta * TAU * 0.85


func _on_continue_pressed() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path.get_file() == "tutorial.tscn":
		_stop_chapter_music()
		AudioManager.stop_river_loop()
		AudioManager.stop_player_walking()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/chapter1.tscn")
	else:
		_show_dev_popup()


func _on_replay_pressed() -> void:
	restart_current_scene()


func _show_dev_popup() -> void:
	if _dev_popup_panel:
		_dev_popup_panel.visible = true


func _close_dev_popup() -> void:
	if _dev_popup_panel:
		_dev_popup_panel.visible = false


func _ensure_loading_panel() -> void:
	if _loading_panel != null and _loading_ring != null:
		return

	_loading_panel = Control.new()
	_loading_panel.name = "ReplayLoadingPanel"
	_loading_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_panel.visible = false
	add_child(_loading_panel)

	var loading_dim := ColorRect.new()
	loading_dim.name = "ReplayLoadingDim"
	loading_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_dim.color = Color(0.0, 0.0, 0.0, 0.68)
	_loading_panel.add_child(loading_dim)

	var center_container := CenterContainer.new()
	center_container.name = "ReplayLoadingCenter"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_panel.add_child(center_container)

	_loading_ring = LOADING_RING_SCRIPT.new() as Control
	_loading_ring.name = "ReplayLoadingRing"
	_loading_ring.set("ring_size", 82.0)
	_loading_ring.set("ring_width", 9.0)
	_loading_ring.set("fill_color", Color(1.0, 0.58, 0.16, 1.0))
	_loading_ring.set("back_color", Color(1.0, 0.96, 0.86, 0.92))
	center_container.add_child(_loading_ring)


func _stop_chapter_music() -> void:
	AudioManager.stop_ingame_music()
	AudioManager.stop_scene_chapter_music()


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
	_game_over_panel.name = "GameOverPanel"
	_game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_game_over_panel)

	# Nền ảnh Game Over.
	_go_bg = TextureRect.new()
	_go_bg.name = "GameOverBg"
	_go_bg.texture = GAME_OVER_TEXTURE
	_go_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_go_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_go_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_panel.add_child(_go_bg)

	# Reason label — chồng lên vùng giấy giữa ảnh nền.
	_go_reason_label = Label.new()
	_go_reason_label.name = "GameOverReason"
	_go_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_reason_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_go_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_go_reason_label.add_theme_font_size_override("font_size", 24)
	_go_reason_label.add_theme_color_override("font_color", Color(0.35, 0.18, 0.05, 1.0))
	_go_reason_label.add_theme_color_override("font_outline_color", Color(0.95, 0.85, 0.65, 1.0))
	_go_reason_label.add_theme_constant_override("outline_size", 3)
	_go_bg.add_child(_go_reason_label)

	# Container nút bấm nằm ngang, bên trong ảnh nền Game Over.
	_go_btn_container = HBoxContainer.new()
	_go_btn_container.name = "GameOverButtons"
	_go_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_go_btn_container.add_theme_constant_override("separation", 20)
	_go_bg.add_child(_go_btn_container)

	_create_game_over_button(GO_BTN_RETRY, restart_current_scene, _go_btn_container)
	_create_game_over_button(GO_BTN_HOME, go_to_menu, _go_btn_container)


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
	UIStyle.style_button(dev_close_btn, UIStyle.GOLD, 20)
	dev_close_btn.pressed.connect(_close_dev_popup)
	dev_vbox.add_child(dev_close_btn)


func _create_game_over_button(tex: Texture2D, callback: Callable, parent: Control) -> TextureButton:
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
	var vp_size := get_viewport().get_visible_rect().size

	# --- Relayout Game Over Panel ---
	if _go_bg and GAME_OVER_TEXTURE:
		var go_base := GAME_OVER_TEXTURE.get_size()  # 577×433
		var go_scale := minf(vp_size.x / go_base.x * 0.75, vp_size.y / go_base.y * 0.75)
		var go_size := go_base * go_scale
		_go_bg.size = go_size
		_go_bg.position = Vector2((vp_size.x - go_size.x) * 0.5, (vp_size.y - go_size.y) * 0.5)

		# Reason label — vùng giấy giữa ảnh. Mở rộng vùng text.
		_go_reason_label.position = Vector2(go_size.x * 0.15, go_size.y * 0.28)
		_go_reason_label.size = Vector2(go_size.x * 0.70, go_size.y * 0.32)

		# Buttons bên trong ảnh nền, dời lên một chút (~63% dọc) để có chỗ cho nút to hơn nữa.
		var btn_height := go_size.y * 0.21
		var btn_aspect := 2.1
		if GO_BTN_RETRY and GO_BTN_RETRY.get_size().y > 0.0:
			btn_aspect = GO_BTN_RETRY.get_size().x / GO_BTN_RETRY.get_size().y
		var btn_width := btn_height * btn_aspect
		var btns_total_w := btn_width * 2.0 + 20.0
		_go_btn_container.position = Vector2(
			(go_size.x - btns_total_w) * 0.5,
			go_size.y * 0.63
		)
		_go_btn_container.size = Vector2(btns_total_w, btn_height)

		for btn_node in _go_btn_container.get_children():
			var t_btn := btn_node as TextureButton
			if not t_btn:
				continue
			t_btn.custom_minimum_size = Vector2(btn_width, btn_height)
			t_btn.size = t_btn.custom_minimum_size
			t_btn.scale = Vector2.ONE
			t_btn.pivot_offset = t_btn.custom_minimum_size * 0.5

	# --- Relayout Win Panel ---
	if not _win_panel:
		return

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
	var btn_h := final_bg_size.y * 0.095
	for btn in btn_container.get_children():
		var t_btn := btn as TextureButton
		if not t_btn: continue
		var aspect := 3.0
		if t_btn.texture_normal:
			aspect = t_btn.texture_normal.get_size().x / t_btn.texture_normal.get_size().y

		t_btn.custom_minimum_size = Vector2(btn_h * aspect, btn_h)
		t_btn.size = t_btn.custom_minimum_size
		t_btn.scale = Vector2.ONE
		t_btn.pivot_offset = t_btn.custom_minimum_size * 0.5
