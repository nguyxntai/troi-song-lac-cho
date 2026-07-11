@tool
extends Node3D
class_name LoveManual

## Kỷ vật "cuốn bí kíp tán gái" — mảnh backstory TRƯỚC chiếc nhẫn lá dừa. Nam chép trong đó
## bài thơ "Vịnh Tình Lục" (do tác giả game sáng tác) thuở mới thương Huyền. Tới gần bấm E
## hiện lần lượt từng khổ thơ. Chỉ THÊM chi tiết, không đụng mạch truyện đã có.

const MANUAL_TEXTURE := preload("res://assets/props/bi_kip_tan_gai.png")
const INTERACT_BUTTON_TEXTURE := preload("res://assets/UI/e_button.png")

## Bài "Vịnh Tình Lục" — chèn nguyên văn, mỗi lần bấm E hiện một khổ.
const MEMORY_LINES := [
	"Ra đường không mang theo phòng bị\nVa phải visual quá kiêu kỳ\nGặp em tự nhiên tim loạn nhịp\nHigh cortisol đỡ kiểu gì?",
	"Lần hai là do lướt phải thôi\nChẳng tính làm quen chẳng tính mời\nVậy mà nhìn xong tim cứ rối\nThế này chắc phải thương mất rồi",
	"Chẳng có gì để nói\nChỉ là tự thấy vui\nGặp là thấy dễ chịu\nVậy thôi cũng đủ rồi",
	"Đường anh đi vốn dư một chỗ\nTình cờ thấy em hợp lối này\nKhông hẹn không mời cũng chẳng ép\nChỉ cần em bước, trọn vòng tay",
]

@export var interact_action: StringName = &"interact"
## Ảnh 1024px, cuốn sổ chiếm ~55% khung → pixel_size nhỏ. Chỉnh trong Inspector nếu muốn.
@export var sprite_pixel_size: float = 0.0005
## Sổ giấy cũ ngả vàng nhẹ cho hợp không khí hoài niệm.
@export var aged_tint: Color = Color(0.96, 0.93, 0.86)
@export var interact_area_size: Vector3 = Vector3(0.9, 1.1, 0.9)
@export var interact_area_offset: Vector3 = Vector3(0.0, 0.4, 0.0)
@export var banner_seconds: float = 7.0

var _sprite: Sprite3D
var _prompt: Sprite3D
var _player_in_range: Node3D
var _banner_layer: CanvasLayer
var _banner_panel: PanelContainer
var _banner_label: Label
var _banner_tween: Tween
var _memory_index: int = 0


func _ready() -> void:
	add_to_group("memory_prop")
	_build_visual()
	_build_interact_area()
	_build_prompt()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_prompt()
	if _can_interact() and _is_closest_prop() and Input.is_action_just_pressed(interact_action):
		_show_memory()


## Khoảng cách tới người chơi nếu đang trong tầm & tương tác được, ngược lại -1.
func interact_distance() -> float:
	if not _can_interact():
		return -1.0
	return global_position.distance_to(_player_in_range.global_position)


## Chỉ vật gần người chơi nhất mới phản hồi E (tránh bấm 1 lần trúng cả 2 vật).
func _is_closest_prop() -> bool:
	var my_d: float = global_position.distance_to(_player_in_range.global_position)
	for other in get_tree().get_nodes_in_group("memory_prop"):
		if other == self or not other.has_method("interact_distance"):
			continue
		var od: float = other.interact_distance()
		if od < 0.0:
			continue
		if od < my_d or (is_equal_approx(od, my_d) and other.get_instance_id() < get_instance_id()):
			return false
	return true


func _can_interact() -> bool:
	if _player_in_range == null or not is_instance_valid(_player_in_range):
		return false
	if _is_tutorial_scene() or GameManager.is_tutorial_locked:
		return false
	return true


func _is_tutorial_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.get_file() == "tutorial.tscn"


func _build_visual() -> void:
	_sprite = Sprite3D.new()
	_sprite.name = "ManualSprite"
	_sprite.texture = MANUAL_TEXTURE
	_sprite.pixel_size = sprite_pixel_size
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.position.y = 0.12
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.modulate = aged_tint
	add_child(_sprite)


func _build_interact_area() -> void:
	var area := Area3D.new()
	area.name = "InteractArea"
	area.position = interact_area_offset
	add_child(area)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = interact_area_size
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _build_prompt() -> void:
	_prompt = Sprite3D.new()
	_prompt.name = "InteractPrompt"
	_prompt.texture = INTERACT_BUTTON_TEXTURE
	_prompt.pixel_size = 0.0007
	_prompt.position = Vector3(0.0, 0.45, 0.0)
	_prompt.visible = false
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	add_child(_prompt)


func _update_prompt() -> void:
	if _prompt:
		_prompt.visible = _can_interact()


func _on_body_entered(body: Node3D) -> void:
	if body.name == "NamChef":
		_player_in_range = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null


func _show_memory() -> void:
	_ensure_banner()
	_banner_label.text = String(MEMORY_LINES[_memory_index])
	_memory_index = (_memory_index + 1) % MEMORY_LINES.size()
	AudioManager.play_ui_click()
	if _sprite:
		Juice.burst(_sprite.global_position, Color(0.90, 0.45, 0.45), 8, 1.6)

	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_panel.modulate.a = 0.0
	_banner_panel.visible = true
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_panel, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(maxf(banner_seconds, 1.0))
	_banner_tween.tween_property(_banner_panel, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(func() -> void: _banner_panel.visible = false)


func _ensure_banner() -> void:
	if _banner_layer != null:
		return
	_banner_layer = CanvasLayer.new()
	_banner_layer.name = "LoveManualMemoryBanner"
	_banner_layer.layer = 6
	add_child(_banner_layer)

	_banner_panel = PanelContainer.new()
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.anchor_top = 1.0
	_banner_panel.anchor_bottom = 1.0
	_banner_panel.offset_left = -440.0
	_banner_panel.offset_right = 440.0
	_banner_panel.offset_top = -330.0
	_banner_panel.offset_bottom = -70.0
	_banner_panel.add_theme_stylebox_override("panel", UIStyle.wood_panel(14, 20, true))
	_banner_panel.visible = false
	_banner_layer.add_child(_banner_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_banner_panel.add_child(vbox)

	var title := Label.new()
	title.name = "PoemTitle"
	title.text = "Vịnh Tình Lục"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_title(title, 20)
	vbox.add_child(title)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_constant_override("line_spacing", 6)
	UIStyle.style_label(_banner_label, 24, UIStyle.CREAM, 5)
	vbox.add_child(_banner_label)
