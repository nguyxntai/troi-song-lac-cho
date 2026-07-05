extends Control

const HOME_TEXTURE: Texture2D = preload("res://assets/UI/win_menu/Home.png")
const REPLAY_TEXTURE: Texture2D = preload("res://assets/UI/win_menu/ReplayLevel.png")
const SATISFIED_TEXTURE: Texture2D = preload("res://assets/satisfied_emoji.png")
const CONFETTI_COLORS := [
	Color(1.0, 0.35, 0.35),
	Color(1.0, 0.78, 0.2),
	Color(0.3, 0.9, 0.55),
	Color(0.35, 0.7, 1.0),
	Color(1.0, 0.55, 0.8),
]

var _confetti: Array[ColorRect] = []
var _velocities: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.stop_river_loop()
	AudioManager.stop_player_walking()
	AudioManager.play_win()
	_build_ui()
	_spawn_confetti(70)


func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for piece in _confetti:
		if not is_instance_valid(piece):
			continue
		var velocity: Vector2 = _velocities.get(piece, Vector2(0.0, 100.0))
		piece.position += velocity * delta
		piece.rotation += delta * velocity.x * 0.02
		if piece.position.y > viewport_size.y + 20.0:
			piece.position = Vector2(randf_range(0.0, viewport_size.x), randf_range(-180.0, -20.0))


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.12, 0.42, 0.55)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var river_band := ColorRect.new()
	river_band.anchor_top = 0.62
	river_band.anchor_right = 1.0
	river_band.anchor_bottom = 1.0
	river_band.color = Color(0.05, 0.28, 0.42)
	river_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(river_band)

	var title := Label.new()
	title.anchor_right = 1.0
	title.offset_top = 70.0
	title.offset_bottom = 145.0
	title.text = "ĐÁM CƯỚI TRÊN SÔNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.04))
	title.add_theme_constant_override("outline_size", 10)
	add_child(title)

	var story := Label.new()
	story.anchor_left = 0.5
	story.anchor_right = 0.5
	story.offset_left = -430.0
	story.offset_top = 165.0
	story.offset_right = 430.0
	story.offset_bottom = 305.0
	story.text = "Cha Nam bình phục, khoản nợ được xóa bỏ.\nGiữa tiếng máy ghe và lời chúc của bà con chợ nổi,\nNam và Huyền chính thức cùng nhau làm chủ bến ghe."
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story.add_theme_font_size_override("font_size", 24)
	story.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	story.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.16))
	story.add_theme_constant_override("outline_size", 6)
	add_child(story)

	_add_celebration_icon(Vector2(0.22, 0.48), -0.12)
	_add_celebration_icon(Vector2(0.78, 0.48), 0.12)

	var completion := Label.new()
	completion.anchor_left = 0.5
	completion.anchor_top = 0.68
	completion.anchor_right = 0.5
	completion.anchor_bottom = 0.68
	completion.offset_left = -360.0
	completion.offset_top = -42.0
	completion.offset_right = 360.0
	completion.offset_bottom = 42.0
	completion.text = "HOÀN THÀNH EARLY ACCESS"
	completion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	completion.add_theme_font_size_override("font_size", 30)
	completion.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	completion.add_theme_color_override("font_outline_color", Color(0.02, 0.12, 0.06))
	completion.add_theme_constant_override("outline_size", 7)
	add_child(completion)

	var buttons := HBoxContainer.new()
	buttons.anchor_left = 0.5
	buttons.anchor_top = 0.84
	buttons.anchor_right = 0.5
	buttons.anchor_bottom = 0.84
	buttons.offset_left = -210.0
	buttons.offset_top = -48.0
	buttons.offset_right = 210.0
	buttons.offset_bottom = 48.0
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 34)
	add_child(buttons)
	buttons.add_child(_make_texture_button(REPLAY_TEXTURE, "Chơi lại Chương 3", _replay_chapter))
	buttons.add_child(_make_texture_button(HOME_TEXTURE, "Về menu", _go_home))


func _add_celebration_icon(anchor: Vector2, rotation_value: float) -> void:
	var icon := TextureRect.new()
	icon.texture = SATISFIED_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_left = anchor.x
	icon.anchor_top = anchor.y
	icon.anchor_right = anchor.x
	icon.anchor_bottom = anchor.y
	icon.offset_left = -75.0
	icon.offset_top = -75.0
	icon.offset_right = 75.0
	icon.offset_bottom = 75.0
	icon.rotation = rotation_value
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)


func _make_texture_button(texture: Texture2D, tooltip: String, callback: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = texture
	button.texture_hover = texture
	button.texture_pressed = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(180.0, 90.0)
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	return button


func _spawn_confetti(count: int) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for index in range(count):
		var piece := ColorRect.new()
		piece.color = CONFETTI_COLORS[index % CONFETTI_COLORS.size()]
		piece.size = Vector2(randf_range(5.0, 10.0), randf_range(10.0, 20.0))
		piece.position = Vector2(randf_range(0.0, viewport_size.x), randf_range(-viewport_size.y, viewport_size.y))
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(piece)
		move_child(piece, 1)
		_confetti.append(piece)
		_velocities[piece] = Vector2(randf_range(-24.0, 24.0), randf_range(65.0, 135.0))


func _replay_chapter() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/chapter3.tscn")


func _go_home() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/menu.scn")
