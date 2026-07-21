extends Camera3D

@export var target_path: NodePath = NodePath("../NamChef")
@export var shoulder_offset: Vector3 = Vector3(0.75, 1.55, 2.9)
@export var look_offset: Vector3 = Vector3(0.0, 1.35, 0.0)
@export var follow_speed: float = 12.0
@export_range(50.0, 100.0, 1.0) var third_person_fov: float = 78.0
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export_range(-60.0, -5.0, 1.0) var min_pitch_degrees: float = -35.0
@export_range(5.0, 75.0, 1.0) var max_pitch_degrees: float = 18.0

var _target: Node3D
var _base_pos: Vector3
var _yaw: float = 0.0
var _pitch: float = deg_to_rad(8.0)
var _mouse_manually_unlocked := false


func _ready() -> void:
	# Xử lý chuột ngay cả khi game tạm dừng (để mở khoá con trỏ cho UI).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target = get_node_or_null(target_path)
	if _target == null:
		printerr("CameraFollow: Khong tim thay target '", target_path, "'!")
		return

	fov = third_person_fov
	_apply_mouse_mode()
	_base_pos = _get_desired_camera_position()
	global_position = _base_pos
	look_at(_target.global_position + look_offset)


func _exit_tree() -> void:
	# Rời màn chơi (về menu...) thì luôn trả con trỏ về hiển thị.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Quy tắc chuột thống nhất: game tạm dừng (mọi UI: ESC / thắng / thua / kết quả /
## shop / hội thoại) -> hiện con trỏ để bấm; đang chơi -> khoá để xoay camera.
func _process(_delta: float) -> void:
	_apply_mouse_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and _is_alt_key(key_event):
			if not get_tree().paused:
				_mouse_manually_unlocked = not _mouse_manually_unlocked
				_apply_mouse_mode()
			get_viewport().set_input_as_handled()
			return

	# Chỉ xoay camera khi đang chơi (con trỏ đang bị khoá).
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		_pitch = clamp(
			_pitch - deg_to_rad(event.relative.y * mouse_sensitivity),
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)


func _physics_process(delta: float) -> void:
	if _target == null or get_tree().paused:
		return

	var target_pos: Vector3 = _get_desired_camera_position()
	_base_pos = _base_pos.lerp(target_pos, clamp(follow_speed * delta, 0.0, 1.0))
	global_position = _base_pos + Juice.get_shake_offset()
	look_at(_target.global_position + look_offset)


func get_flat_forward() -> Vector3:
	var forward := (_target.global_position + look_offset) - global_position
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func get_flat_right() -> Vector3:
	var right := get_flat_forward().cross(Vector3.UP)
	if right.length_squared() <= 0.0001:
		return Vector3.RIGHT
	return right.normalized()


func _apply_mouse_mode() -> void:
	var desired: int = Input.MOUSE_MODE_VISIBLE if get_tree().paused or _mouse_manually_unlocked else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != desired:
		Input.mouse_mode = desired


func _is_alt_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_ALT or event.physical_keycode == KEY_ALT


func _get_desired_camera_position() -> Vector3:
	var pivot: Vector3 = _target.global_position + look_offset
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var pitch_basis := Basis(Vector3.RIGHT, _pitch)
	var rotated_offset := yaw_basis * (pitch_basis * shoulder_offset)
	return pivot + rotated_offset
