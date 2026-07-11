@tool
extends Node3D
class_name KeepsakeLeaf

## Kỷ vật "chiếc nhẫn lá dừa" — Huyền thắt tặng Nam ngày nhỏ. Treo lặng lẽ ở góc ghe
## từ Chương 1 (motif xuyên suốt). Tới gần bấm E hiện một dòng ký ức để "chỉ điểm"
## cho người chơi. Chỉ THÊM chi tiết, không đụng mạch truyện đã có.

const KEEPSAKE_TEXTURE := preload("res://assets/props/la_dua_keepsake.png")
const INTERACT_BUTTON_TEXTURE := preload("res://assets/UI/e_button.png")

const MEMORY_LINES := [
	"Chiếc nhẫn lá dừa Huyền thắt tặng, từ ngày hai đứa còn thơ...",
	"Lá mỏng dễ gãy, nên Nam buộc nó nơi góc ghe — chỗ dễ thấy nhất.",
	"Bao mùa nước nổi trôi qua, anh chưa từng gỡ nó xuống.",
]

@export var interact_action: StringName = &"interact"
## Ảnh nhẫn 1254px → pixel_size nhỏ để nhẫn chỉ ~0.22m. Chỉnh trong Inspector nếu muốn.
@export var sprite_pixel_size: float = 0.00018
## Ch1–2 nhẫn hơi cũ (ngả nhẹ), Ch3 tươi mới → đóng vòng motif "kết trái".
@export var aged_tint: Color = Color(0.90, 0.94, 0.82)
@export var interact_area_size: Vector3 = Vector3(0.9, 1.1, 0.9)
@export var interact_area_offset: Vector3 = Vector3(0.0, 0.4, 0.0)
@export var banner_seconds: float = 5.0

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
	_sprite.name = "KeepsakeSprite"
	_sprite.texture = KEEPSAKE_TEXTURE
	_sprite.pixel_size = sprite_pixel_size
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.position.y = 0.12
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Tiến hoá màu: Ch3 tươi mới (trắng gốc), Ch1–2 hơi ngả cũ.
	_sprite.modulate = Color.WHITE if not Engine.is_editor_hint() and GameManager.chapter_index >= 3 else aged_tint
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
		Juice.burst(_sprite.global_position, Color(0.85, 0.72, 0.4), 8, 1.6)

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
	_banner_layer.name = "KeepsakeMemoryBanner"
	_banner_layer.layer = 6
	add_child(_banner_layer)

	_banner_panel = PanelContainer.new()
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_right = 0.5
	_banner_panel.anchor_top = 1.0
	_banner_panel.anchor_bottom = 1.0
	_banner_panel.offset_left = -420.0
	_banner_panel.offset_right = 420.0
	_banner_panel.offset_top = -150.0
	_banner_panel.offset_bottom = -80.0
	_banner_panel.add_theme_stylebox_override("panel", UIStyle.wood_panel(14, 18, true))
	_banner_panel.visible = false
	_banner_layer.add_child(_banner_panel)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.style_label(_banner_label, 24, UIStyle.CREAM, 5)
	_banner_panel.add_child(_banner_label)
