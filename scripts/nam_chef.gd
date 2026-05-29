extends CharacterBody3D

@export var MOVE_SPEED: float = 2.5 # Tốc độ đi lại của Nam trên ghe
@export var ROTATION_SPEED: float = 15.0 # Tốc độ xoay người của Nam
@export var GRAVITY: float = 9.8 # Trọng lực giúp Nam chạm sàn
@export var JUMP_SPEED: float = 3.5 # Lực nhảy của Nam

# Đường dẫn chuẩn đi vào mô hình Nam để lấy bộ phát Animation
@onready var anim_player: AnimationPlayer = $Nam/AnimationPlayer

func _physics_process(delta: float) -> void:
	# ==========================================
	# 1. XỬ LÝ VẬT LÝ (DI CHUYỂN, NHẢY, TRỌNG LỰC)
	# ==========================================
	# Áp dụng trọng lực để Nam luôn đứng trên sàn ghe
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	# Nhảy khi đang đứng trên sàn và bấm nút ui_accept (Space)
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
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
		# Khi đang ở trên không trung -> Giữ animation nhảy mượt mà
		if anim_player.current_animation != "jump":
			# Tham số 0.15 giúp chuyển đổi từ dáng chạy/đứng sang dáng nhảy êm hơn
			anim_player.play("jump", 0.15)
	else:
		# Khi đang đứng chạm sàn ghe ổn định
		if direction != Vector3.ZERO:
			# Nếu đang di chuyển -> Phát hoạt ảnh đi bộ
			if anim_player.current_animation != "walk":
				# Hòa trộn 0.15 giây giúp Nam từ tư thế đứng im chuyển sang chạy không bị giật mình
				anim_player.play("walk", 0.15)
		else:
			# Nếu đứng yên không bấm nút -> Trả về hoạt ảnh đứng im nghỉ ngơi dập dềnh
			if anim_player.current_animation != "idle":
				# QUAN TRỌNG: Hòa trộn 0.25 giây giúp Nam từ tư thế chạy "hãm phanh" từ từ mượt mà về tư thế idle
				anim_player.play("idle", 0.25)