extends Area3D
class_name MemoryZone

## Vùng "ký ức" quanh 2 kỷ vật (nhẫn lá dừa + cuốn thơ) sau tủ lạnh. Khi Nam bước vào:
## nhạc nền chương + tiếng sông nhỏ lại, bản nhạc êm đềm nổi lên to hơn — cảm giác bình
## yên khi nhớ về kỷ niệm. Rời vùng thì mọi thứ trở lại như cũ.

@export var zone_size: Vector3 = Vector3(2.8, 3.0, 3.2)
## Nhạc nền chương sẽ hạ xuống mức này khi ở trong vùng.
@export var ducked_music_db: float = -30.0
@export var fade_seconds: float = 1.2
## Tên node nhạc nền chương để hạ tiếng (kế thừa cho cả 3 chương).
@export var scene_music_name: StringName = &"Chapter1Music"

var _music: AudioStreamPlayer
var _music_base_db: float = -14.0
var _music_tween: Tween
var _inside: bool = false


func _ready() -> void:
	monitoring = true
	_build_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_resolve_music()


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = zone_size
	shape.shape = box
	add_child(shape)


func _resolve_music() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_music = scene.find_child(String(scene_music_name), true, false) as AudioStreamPlayer
	if _music != null:
		_music_base_db = _music.volume_db


func _on_body_entered(body: Node3D) -> void:
	if body == null or body.name != "NamChef" or _inside:
		return
	if _is_tutorial_scene():
		return
	_inside = true
	_tween_music(ducked_music_db)
	AudioManager.enter_memory_mode()


func _on_body_exited(body: Node3D) -> void:
	if body == null or body.name != "NamChef" or not _inside:
		return
	_inside = false
	_tween_music(_music_base_db)
	AudioManager.exit_memory_mode()


func _tween_music(target_db: float) -> void:
	if _music == null or not is_instance_valid(_music):
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", target_db, fade_seconds)


func _is_tutorial_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.get_file() == "tutorial.tscn"


func _exit_tree() -> void:
	# An toàn: nếu vùng bị huỷ khi đang bên trong, trả âm thanh về bình thường.
	if _inside:
		_inside = false
		if _music != null and is_instance_valid(_music):
			_music.volume_db = _music_base_db
		AudioManager.exit_memory_mode()
