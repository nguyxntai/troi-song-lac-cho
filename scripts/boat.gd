extends AnimatableBody3D

# Các thông số điều chỉnh độ nhấp nhô ngoài Inspector
@export var float_speed: float = 2.0 # Tốc độ dập dềnh (Càng cao thuyền lắc càng nhanh)
@export var float_amplitude: float = 0.08 # Độ cao nhấp nhô (0.08 mét là vừa đủ nhẹ nhàng)
@export var rotation_amplitude: float = 1.5 # Độ nghiêng nhẹ của thuyền khi gặp sóng (tính bằng độ)

var time_passed: float = 0.0
var initial_y: float = 0.0

func _ready():
	# Lưu lại vị trí độ cao Y ban đầu của con thuyền khi bắt đầu game
	initial_y = global_position.y

func _physics_process(delta: float):
	# Cộng dồn thời gian trôi qua theo delta vật lý
	time_passed += delta * float_speed
	
	# 1. Tính toán vị trí Y mục tiêu tiếp theo bằng hàm sin
	var target_y = initial_y + sin(time_passed) * float_amplitude
	
	# Tính toán và gán vận tốc tịnh tiến (Linear Velocity) cho StaticBody3D.
	# Đây là chìa khóa để kéo chân NamChef di chuyển lên xuống theo sàn thuyền!
	constant_linear_velocity.y = (target_y - global_position.y) / delta
	
	# 2. Tính toán độ nghiêng lắc mạn thuyền theo trục Z
	var target_rotation_z = cos(time_passed) * deg_to_rad(rotation_amplitude)
	var next_rotation_z = lerp_angle(rotation.z, target_rotation_z, delta * 5.0)
	
	# Tính toán và gán vận tốc góc (Angular Velocity) để chân NamChef nghiêng đồng bộ theo sàn gỗ
	constant_angular_velocity.z = (next_rotation_z - rotation.z) / delta
	
	# Cập nhật tọa độ thực tế của thuyền (vì Sync To Physics đã bật nên việc gán này cực kỳ an toàn)
	global_position.y = target_y
	rotation.z = next_rotation_z