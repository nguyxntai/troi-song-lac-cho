extends Node3D
class_name DriftingCameo

## Cameo hài: cụm "nhân vật ngồi gõ máy tính trên xuồng" (kiểu meme). Thỉnh thoảng tự trôi
## ngang qua map từ mép này sang mép kia rồi ẩn đi, chờ một lúc lại trôi (đổi chiều mỗi
## lượt). Kéo StartPoint / EndPoint trong editor để định đường trôi. Cụm hình do node Rig
## (CameoRig) dựng.

@export var rig_path: NodePath
@export var start_point_path: NodePath
@export var end_point_path: NodePath
@export var travel_time: float = 26.0
## Khoảng nghỉ ngẫu nhiên giữa 2 lượt trôi (giây) — "thỉnh thoảng mới qua".
@export var min_gap: float = 25.0
@export var max_gap: float = 55.0
@export var bob_amplitude: float = 0.10
@export var bob_speed: float = 1.2
## Góc quay Y cố định của cụm để mặt Nam/laptop hướng ra camera. Chỉnh cho khớp trong editor.
@export var face_yaw_degrees: float = 0.0

var _rig: Node3D
var _from: Vector3
var _to: Vector3
var _t: float = 0.0
var _gap: float = 0.0
var _drifting: bool = false
var _flip: bool = false
var _bob_phase: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_rig = get_node_or_null(rig_path) as Node3D
	_resolve_points()
	if _rig != null:
		_rig.visible = false
		_rig.rotation.y = deg_to_rad(face_yaw_degrees)
	_gap = _rng.randf_range(maxf(min_gap * 0.3, 4.0), max_gap)


func _resolve_points() -> void:
	var a := get_node_or_null(start_point_path) as Node3D
	var b := get_node_or_null(end_point_path) as Node3D
	_from = a.global_position if a != null else global_position + Vector3(-18.0, 0.0, 0.0)
	_to = b.global_position if b != null else global_position + Vector3(18.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if _rig == null:
		return

	if _drifting:
		_t += delta / maxf(travel_time, 0.5)
		_bob_phase += delta * bob_speed
		var pos: Vector3 = _from.lerp(_to, clampf(_t, 0.0, 1.0))
		pos.y += sin(_bob_phase) * bob_amplitude
		_rig.global_position = pos
		if _t >= 1.0:
			_drifting = false
			_rig.visible = false
			_flip = not _flip
			_gap = _rng.randf_range(min_gap, max_gap)
	else:
		_gap -= delta
		if _gap <= 0.0:
			_begin_drift()


func _begin_drift() -> void:
	_resolve_points()
	if _flip:
		var tmp: Vector3 = _from
		_from = _to
		_to = tmp
	_t = 0.0
	_bob_phase = 0.0
	_rig.rotation.y = deg_to_rad(face_yaw_degrees)
	_rig.global_position = _from
	_rig.visible = true
	_drifting = true
