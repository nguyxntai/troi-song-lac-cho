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


func _ready() -> void:
	_target = get_node_or_null(target_path)
	if _target == null:
		printerr("CameraFollow: Khong tim thay target '", target_path, "'!")
		return

	fov = third_person_fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_base_pos = _get_desired_camera_position()
	global_position = _base_pos
	look_at(_target.global_position + look_offset)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= deg_to_rad(event.relative.x * mouse_sensitivity)
		_pitch = clamp(
			_pitch - deg_to_rad(event.relative.y * mouse_sensitivity),
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if _target == null:
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


func _get_desired_camera_position() -> Vector3:
	var pivot: Vector3 = _target.global_position + look_offset
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var pitch_basis := Basis(Vector3.RIGHT, _pitch)
	var rotated_offset := yaw_basis * (pitch_basis * shoulder_offset)
	return pivot + rotated_offset
