extends CharacterBody3D

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_JUMP: StringName = &"jump"
const ANIM_CARRY_IDLE: StringName = &"carrying idle"
const ANIM_CARRY_WALK: StringName = &"carrying walk generated"
const ANIM_CARRY_JUMP: StringName = &"carrying jump generated"

@export var MOVE_SPEED: float = 2.5 # Tốc độ đi lại của Nam trên ghe
@export var ROTATION_SPEED: float = 15.0 # Tốc độ xoay người của Nam
@export var GRAVITY: float = 9.8 # Trọng lực giúp Nam chạm sàn
@export var JUMP_SPEED: float = 3.5 # Lực nhảy của Nam
@export_range(0.1, 2.0, 0.05) var CARRY_ANIMATION_SPEED: float = 0.85
@export_range(0.1, 1.0, 0.05) var CARRY_MOVE_SPEED_MULTIPLIER: float = 0.8
@export var carry_socket_position: Vector3 = Vector3(0.0, 0.58, 0.18)
@export var carry_socket_rotation: Vector3 = Vector3(-6.0, 0.0, 0.0)

# Đường dẫn chuẩn đi vào mô hình Nam để lấy bộ phát Animation
@onready var model_root: Node3D = $Nam
@onready var anim_player: AnimationPlayer = $Nam/AnimationPlayer
@onready var hand_slot: Node = find_child("HandSlot", true, false)
@onready var carry_socket: Node3D = _ensure_carry_socket()
@onready var skeleton: Skeleton3D = $Nam/Armature/Skeleton3D

@export var enable_manual_drop: bool = true   # phím Q thả đồ (test Thủy Kích)
@export var drop_action: StringName = &"drop_food"

var _root_bone_pose_position: Vector3 = Vector3.ZERO
var _slip_accumulator: float = 0.0


func _exit_tree() -> void:
	AudioManager.stop_player_walking()


func _ready() -> void:
	# ==========================================
	# CẤU HÌNH TRIỆT TIÊU LỖI NẢY THÀNH TÀU & QUÁN TÍNH
	# ==========================================
	slide_on_ceiling = false
	floor_max_angle = deg_to_rad(45.0)
	floor_snap_length = 0.1
	
	# Khóa cứng cơ chế tắt quán tính nền khi rời sàn thuyền dập dềnh
	platform_on_leave = PlatformOnLeave.PLATFORM_ON_LEAVE_DO_NOTHING
	if skeleton:
		_root_bone_pose_position = skeleton.get_bone_pose_position(0)
	_prepare_carry_animations()
	_lock_model_root_transform()


func _process(_delta: float) -> void:
	_lock_model_root_transform()

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
	var is_carrying: bool = _is_carrying_item()
	var current_move_speed: float = MOVE_SPEED * (CARRY_MOVE_SPEED_MULTIPLIER if is_carrying else 1.0)
	AudioManager.set_player_walking(direction != Vector3.ZERO and is_on_floor())
	
	# Xử lý vận tốc di chuyển và xoay hướng mặt
	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_move_speed
		velocity.z = direction.z * current_move_speed
		
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
	# 1B. THỦY KÍCH: THẢ ĐỒ & TUỘT TAY KHI BÃO
	# ==========================================
	_handle_drop_and_slip(delta, is_carrying, direction != Vector3.ZERO)

	# ==========================================
	# 2. XỬ LÝ QUẢN LÝ ANIMATION (HÒA TRỘN MƯỢT MÀ)
	# ==========================================
	if is_carrying:
		if not is_on_floor():
			_play_animation(ANIM_CARRY_JUMP, 0.12)
		elif direction != Vector3.ZERO:
			_play_animation(ANIM_CARRY_WALK, 0.12, CARRY_ANIMATION_SPEED)
		else:
			_play_animation(ANIM_CARRY_IDLE, 0.18, CARRY_ANIMATION_SPEED)
	elif not is_on_floor():
		_play_animation(ANIM_JUMP, 0.15)
	else:
		if direction != Vector3.ZERO:
			_play_animation(ANIM_WALK, 0.15)
		else:
			_play_animation(ANIM_IDLE, 0.25)

	_lock_model_root_transform()


func _is_carrying_item() -> bool:
	return hand_slot != null and hand_slot.get_child_count() > 0


func _handle_drop_and_slip(delta: float, is_carrying: bool, is_moving: bool) -> void:
	if not is_carrying:
		_slip_accumulator = 0.0
		return

	# Thả đồ thủ công (test): phím Q.
	if enable_manual_drop and InputMap.has_action(drop_action) and Input.is_action_just_pressed(drop_action):
		drop_carried_item(1.0)
		return

	# Tuột tay ngẫu nhiên khi mùa bão (slip_chance do WeatherManager set).
	var slip_chance: float = GameManager.slip_chance if is_moving else GameManager.slip_chance * 0.25
	if slip_chance <= 0.0:
		return
	_slip_accumulator += delta
	if _slip_accumulator >= 0.5:
		_slip_accumulator = 0.0
		if randf() < slip_chance * 0.5:
			drop_carried_item(0.6)


## Làm rớt món đang cầm xuống sông. Trả về true nếu có thả.
func drop_carried_item(strength: float = 1.0) -> bool:
	if hand_slot == null or hand_slot.get_child_count() == 0:
		return false

	var holder: Node = hand_slot.get_child(0)
	var visual: Node3D = null
	if holder.has_meta(FoodMeta.CARRY_VISUAL):
		var v: Variant = holder.get_meta(FoodMeta.CARRY_VISUAL)
		if v is Node3D and is_instance_valid(v):
			visual = v as Node3D

	# Gom dữ liệu để có thể tái tạo khi vớt.
	var data: Dictionary = {
		"food_id": String(holder.get_meta(FoodMeta.FOOD_ID, "")) if holder.has_meta(FoodMeta.FOOD_ID) else "",
		"is_servable": FoodMeta.is_servable(holder),
		"food_stage": int(holder.get_meta(FoodMeta.FOOD_STAGE)) if holder.has_meta(FoodMeta.FOOD_STAGE) else FoodMeta.STAGE_FULL_BOWL,
		"water_quality": FoodMeta.get_water_quality(holder),
	}
	for key in [FoodMeta.TABLE_POSITION, FoodMeta.TABLE_ROTATION, FoodMeta.TABLE_SCALE]:
		if holder.has_meta(key):
			var short_key: String = "table_pos"
			if key == FoodMeta.TABLE_ROTATION:
				short_key = "table_rot"
			elif key == FoodMeta.TABLE_SCALE:
				short_key = "table_scale"
			data[short_key] = holder.get_meta(key)
	if visual:
		data["carry_pos"] = visual.position
		data["carry_rot"] = visual.rotation_degrees
		data["carry_scale"] = visual.scale

	var spawn_pos: Vector3 = visual.global_position if visual else global_position + Vector3.UP * 0.6
	var forward: Vector3 = -global_transform.basis.z
	var deviation: float = GameManager.throw_deviation
	if deviation > 0.0:
		forward = forward.rotated(Vector3.UP, randf_range(-deviation, deviation))
	var throw_velocity: Vector3 = forward * (1.4 * strength) + Vector3.UP * 1.2

	# Tách visual ra khỏi tay, dọn holder.
	if visual:
		var p: Node = visual.get_parent()
		if p:
			p.remove_child(visual)
	holder.queue_free()

	WaterSystem.drop_food(visual, data, spawn_pos, throw_velocity)
	return true


func _play_animation(animation_name: StringName, blend_time: float, custom_speed: float = 1.0) -> void:
	if not anim_player.has_animation(animation_name):
		if animation_name == ANIM_CARRY_WALK or animation_name == ANIM_CARRY_JUMP:
			animation_name = ANIM_CARRY_IDLE
		else:
			return

	if anim_player.current_animation == animation_name:
		anim_player.speed_scale = custom_speed
		return

	anim_player.speed_scale = custom_speed
	anim_player.play(animation_name, blend_time)


func _ensure_carry_socket() -> Node3D:
	var existing_socket: Node3D = find_child("CarrySocket", true, false) as Node3D
	if existing_socket:
		return existing_socket

	var socket: Node3D = Node3D.new()
	socket.name = "CarrySocket"
	socket.position = carry_socket_position
	socket.rotation_degrees = carry_socket_rotation
	add_child(socket)
	return socket


func _lock_model_root_transform() -> void:
	model_root.position = Vector3.ZERO
	model_root.rotation = Vector3.ZERO
	model_root.scale = Vector3.ONE
	if skeleton:
		skeleton.set_bone_pose_position(0, _root_bone_pose_position)


func _prepare_carry_animations() -> void:
	_sanitize_animation_for_controller(ANIM_CARRY_IDLE)
	_create_carry_variant_animation(ANIM_WALK, ANIM_CARRY_WALK)
	_create_carry_variant_animation(ANIM_JUMP, ANIM_CARRY_JUMP)


func _create_carry_variant_animation(base_animation_name: StringName, result_animation_name: StringName) -> void:
	if not anim_player.has_animation(base_animation_name) or not anim_player.has_animation(ANIM_CARRY_IDLE):
		return

	var base_animation: Animation = anim_player.get_animation(base_animation_name)
	var carry_idle_animation: Animation = anim_player.get_animation(ANIM_CARRY_IDLE)
	if not base_animation or not carry_idle_animation:
		return

	var carry_variant: Animation = base_animation.duplicate(true) as Animation
	if not carry_variant:
		return

	_strip_upper_body_transform_tracks(carry_variant)
	_copy_upper_body_pose_tracks(carry_idle_animation, carry_variant)
	_remove_animation_from_all_libraries(result_animation_name)
	_get_or_create_default_animation_library().add_animation(result_animation_name, carry_variant)


func _strip_upper_body_transform_tracks(animation: Animation) -> void:
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		if not _is_transform_track(animation, track_index):
			continue

		var track_path: NodePath = animation.track_get_path(track_index)
		if _is_upper_body_track(track_path):
			animation.remove_track(track_index)


func _copy_upper_body_pose_tracks(source_animation: Animation, target_animation: Animation) -> void:
	for source_track_index in range(source_animation.get_track_count()):
		if source_animation.track_get_type(source_track_index) != Animation.TYPE_ROTATION_3D:
			continue

		var track_path: NodePath = source_animation.track_get_path(source_track_index)
		if not _is_upper_body_track(track_path):
			continue
		if source_animation.track_get_key_count(source_track_index) == 0:
			continue

		var target_track_index: int = target_animation.add_track(Animation.TYPE_ROTATION_3D)
		target_animation.track_set_path(target_track_index, track_path)
		target_animation.track_set_interpolation_type(
			target_track_index,
			source_animation.track_get_interpolation_type(source_track_index)
		)

		var carry_pose_rotation: Variant = source_animation.track_get_key_value(source_track_index, 0)
		target_animation.track_insert_key(target_track_index, 0.0, carry_pose_rotation)
		target_animation.track_insert_key(target_track_index, target_animation.length, carry_pose_rotation)


func _is_transform_track(animation: Animation, track_index: int) -> bool:
	var track_type: int = animation.track_get_type(track_index)
	return (
		track_type == Animation.TYPE_POSITION_3D
		or track_type == Animation.TYPE_ROTATION_3D
		or track_type == Animation.TYPE_SCALE_3D
	)


func _is_upper_body_track(track_path: NodePath) -> bool:
	var lower_path: String = _get_track_bone_name(track_path).to_lower()
	return (
		lower_path.contains("spine")
		or lower_path.contains("chest")
		or lower_path.contains("neck")
		or lower_path.contains("head")
		or lower_path.contains("clavicle")
		or lower_path.contains("shoulder")
		or lower_path.contains("arm")
		or lower_path.contains("forearm")
		or lower_path.contains("hand")
		or lower_path.contains("finger")
	)


func _get_track_bone_name(track_path: NodePath) -> String:
	var path_text: String = String(track_path)
	var bone_separator_index: int = path_text.rfind(":")
	if bone_separator_index == -1:
		return path_text

	return path_text.substr(bone_separator_index + 1)


func _get_or_create_default_animation_library() -> AnimationLibrary:
	if anim_player.has_animation_library(&""):
		return anim_player.get_animation_library(&"")

	var library: AnimationLibrary = AnimationLibrary.new()
	anim_player.add_animation_library(&"", library)
	return library


func _sanitize_animation_for_controller(animation_name: StringName) -> void:
	if not anim_player.has_animation(animation_name):
		return

	var source_animation: Animation = anim_player.get_animation(animation_name)
	if not source_animation:
		return

	var animation_copy: Animation = source_animation.duplicate(true) as Animation
	if not animation_copy:
		return

	_strip_position_and_scale_tracks(animation_copy)
	_remove_animation_from_all_libraries(animation_name)

	_get_or_create_default_animation_library().add_animation(animation_name, animation_copy)


func _strip_position_and_scale_tracks(animation: Animation) -> void:
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		var track_type: int = animation.track_get_type(track_index)
		if track_type == Animation.TYPE_POSITION_3D or track_type == Animation.TYPE_SCALE_3D:
			animation.remove_track(track_index)


func _remove_animation_from_all_libraries(animation_name: StringName) -> void:
	for library_name in anim_player.get_animation_library_list():
		var library: AnimationLibrary = anim_player.get_animation_library(library_name)
		if library and library.has_animation(animation_name):
			library.remove_animation(animation_name)
