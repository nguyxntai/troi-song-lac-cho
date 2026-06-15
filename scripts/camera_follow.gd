extends Camera3D

## Nhân vật mà camera sẽ bám theo
@export var target_path: NodePath = NodePath("../NamChef")

## Khoảng cách offset từ nhân vật đến camera (X=ngang, Y=cao, Z=lùi ra sau)
@export var offset: Vector3 = Vector3(0, 7, 3)

## Tốc độ nội suy mượt mà (càng cao càng bám sát, càng thấp càng mềm mại)
@export var follow_speed: float = 8.0

var _target: Node3D

func _ready() -> void:
	_target = get_node_or_null(target_path)
	if _target == null:
		printerr("CameraFollow: Không tìm thấy target '", target_path, "'!")
	else:
		# Đặt vị trí khởi đầu ngay tức thì (không lag ở frame đầu)
		global_position = _target.global_position + offset
		# Khóa hướng nhìn thẳng vào nhân vật từ đầu
		look_at(_target.global_position)

# ĐÃ SỬA: Chuyển từ _process sang _physics_process để đồng bộ 100% với luồng vật lý của Thuyền và Người
func _physics_process(delta: float) -> void:
	if _target == null:
		return

	# Vị trí đích mà camera cần đến
	var target_pos = _target.global_position + offset

	# Nội suy mượt mà vị trí camera từ vị trí hiện tại đến vị trí đích trong luồng Physics
	global_position = global_position.lerp(target_pos, follow_speed * delta)
	
	# ĐÃ THÊM: Buộc camera luôn luôn khóa mục tiêu nhìn thẳng vào NamChef, 
	# giữ trục nhìn ổn định bất kể mạn thuyền có lắc lư nghiêng trái/phải
	look_at(_target.global_position)
