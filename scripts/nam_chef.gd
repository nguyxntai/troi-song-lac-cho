extends CharacterBody3D

@export var MOVE_SPEED: float = 2.5 # Tốc độ đi lại của Nam trên ghe
@export var ROTATION_SPEED: float = 15.0 # Tốc độ xoay người của Nam
@export var GRAVITY: float = 9.8 # Trọng lực giúp Nam chạm sàn
@export var JUMP_SPEED: float = 3.5 # Lực nhảy của Nam

# Đường dẫn chuẩn đi vào mô hình Nam để lấy bộ phát Animation
@onready var anim_player: AnimationPlayer = $Nam/AnimationPlayer

func _ready() -> void:
	# ==========================================
	# CẤU HÌNH TRIỆT TIÊU LỖI NẢY THÀNH TÀU & QUÁN TÍNH
	# ==========================================
	slide_on_ceiling = false
	floor_max_angle = deg_to_rad(45.0)
	floor_snap_length = 0.1
	
	# Khóa cứng cơ chế tắt quán tính nền khi rời sàn thuyền dập dềnh
	platform_on_leave = PlatformOnLeave.PLATFORM_ON_LEAVE_DO_NOTHING

func _physics_process(delta: float) -> void:
	# ==========================================
	# 1. XỬ LÝ VẬT LÝ (DI CHUYỂN, NHẢY, TRỌNG LỰC)
	# ==========================================
	# Áp dụng trọng lực để Nam luôn đứng trên sàn ghe
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		# Lực âm nhỏ giúp khóa chặt chân Nam vào Moving Platform của thuyền
		velocity.y = -0.1

	# Nhảy khi đang đứng trên sàn và bấm nút ui_accept (Space)
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		# Lực nhảy thuần túy cố định, không bị ảnh hưởng bởi vận tốc thuyền
		velocity.y = JUMP_SPEED

	# Lấy hướng bấm nút di chuyển (W, A, S, D)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Xử lý vận tốc di chuyển và xoay hướng mặt
	if direction != Vector3.ZERO:
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
		
		# Nam chạy hướng nào thì lập tức xoay mặt nhìn thẳng về hướng đó
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, ROTATION_SPEED * delta)
	else:
		# Buông tay thì dừng lại ngay lập tức
		velocity.x = 0.0
		velocity.z = 0.0

	# Thực thi di chuyển vật lý của Godot
	move_and_slide()

	# ==========================================
	# 2. XỬ LÝ QUẢN LÝ ANIMATION (HÒA TRỘN MƯỢT MÀ)
	# ==========================================
	if not is_on_floor():
		if anim_player.current_animation != "jump":
			anim_player.play("jump", 0.15)
	else:
		if direction != Vector3.ZERO:
			if anim_player.current_animation != "walk":
				anim_player.play("walk", 0.15)
		else:
			if anim_player.current_animation != "idle":
				anim_player.play("idle", 0.25)
