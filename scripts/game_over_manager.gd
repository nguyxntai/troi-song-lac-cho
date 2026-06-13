extends CanvasLayer
class_name GameOverManager

const GAME_OVER_TEXTURE: Texture2D = preload("res://assets/UI/game_over.png")

const REASON_FELL_IN_RIVER := "fell_in_river"
const REASON_NOT_ENOUGH_CUSTOMERS := "not_enough_customers"
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

var _player: Node3D
var _is_game_over := false
var _reason_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_node_or_null(player_path) as Node3D
	_build_ui()
	visible = false


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
	_update_reason_label(reason_key, custom_description)
	visible = true
	get_tree().paused = true


func show_custom_game_over(title: String, description: String) -> void:
	if _is_game_over:
		return

	_is_game_over = true
	_reason_label.text = "Lý do: %s\n%s" % [title, description]
	visible = true
	get_tree().paused = true


func restart_current_scene() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	if menu_scene_path.is_empty():
		push_warning("GameOverManager chua duoc gan menu_scene_path.")
		return

	get_tree().paused = false
	get_tree().change_scene_to_file(menu_scene_path)


func _build_ui() -> void:
	var root := Control.new()
	root.name = "GameOverRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "DimBackground"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	root.add_child(dim)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -360.0
	content.offset_top = -250.0
	content.offset_right = 360.0
	content.offset_bottom = 250.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	root.add_child(content)

	var image_area := Control.new()
	image_area.name = "GameOverImageArea"
	image_area.custom_minimum_size = Vector2(621.0, 402.0)
	content.add_child(image_area)

	var image := TextureRect.new()
	image.name = "GameOverImage"
	image.texture = GAME_OVER_TEXTURE
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_area.add_child(image)

	var reload_icon_button := _create_icon_button(Vector2(165.0, 205.0), Vector2(150.0, 150.0))
	reload_icon_button.name = "ReloadIconButton"
	reload_icon_button.pressed.connect(restart_current_scene)
	image_area.add_child(reload_icon_button)

	var home_icon_button := _create_icon_button(Vector2(330.0, 205.0), Vector2(150.0, 150.0))
	home_icon_button.name = "HomeIconButton"
	home_icon_button.pressed.connect(go_to_menu)
	image_area.add_child(home_icon_button)

	_reason_label = Label.new()
	_reason_label.name = "ReasonLabel"
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.add_theme_font_size_override("font_size", 30)
	_reason_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	_reason_label.add_theme_color_override("font_outline_color", Color(0.22, 0.07, 0.03, 1.0))
	_reason_label.add_theme_constant_override("outline_size", 8)
	content.add_child(_reason_label)

func _create_icon_button(position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.flat = true
	button.add_theme_stylebox_override("normal", _make_empty_style())
	button.add_theme_stylebox_override("hover", _make_empty_style())
	button.add_theme_stylebox_override("pressed", _make_empty_style())
	return button


func _make_empty_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	return style


func _update_reason_label(reason_key: String, custom_description: String) -> void:
	var reason: Dictionary = GAME_OVER_REASONS.get(reason_key, GAME_OVER_REASONS[REASON_CUSTOM])
	var title: String = str(reason.get("title", "Thua cuộc"))
	var default_description: String = str(reason.get("description", "Nhiệm vụ thất bại."))
	var description: String = custom_description if not custom_description.is_empty() else default_description
	_reason_label.text = "Lý do: %s\n%s" % [title, description]
