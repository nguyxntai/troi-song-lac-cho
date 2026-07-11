@tool
extends Node3D

const CAMEO_RIG_SCRIPT := preload("res://scripts/cameo_rig.gd")

@export var boat_scene: PackedScene
@export var boat_scenes: Array[PackedScene] = []
@export var auto_spawn: bool = true
@export var max_active_boats: int = 4
@export var initial_spawn_count: int = 2
@export var spawn_interval_min: float = 4.0
@export var spawn_interval_max: float = 8.0
@export var spawn_x_extent: float = 30.0
@export var despawn_x_extent: float = 36.0
@export var lane_z_min: float = -18.0
@export var lane_z_max: float = 18.0
@export var water_y: float = 0.08

@export_group("Spawn Point Settings")
## Danh sách các Marker3D/Node3D định vị vị trí spawn. Nếu để trống, script tự động lấy các Node3D con trực tiếp làm spawn point.
@export var spawn_points: Array[Node3D] = []
## Khoảng cách tối thiểu giữa một thuyền đã spawn và spawn point để spawn point đó được coi là trống.
@export var min_spawn_distance: float = 6.0

@export_group("Fixed Position Spawning (Fallback)")
@export var use_fixed_position: bool = false
@export var fixed_spawn_position: Vector3 = Vector3.ZERO
@export var use_spawner_position_as_fixed: bool = true

@export_group("Movement & Despawn Settings")
@export var boats_can_move: bool = true
@export var enable_despawn: bool = true

@export_group("Boat Settings")
@export var boat_scale_min: float = 4.0
@export var boat_scale_max: float = 6.0
@export var speed_min: float = 1.1
@export var speed_max: float = 2.2
@export var bob_speed_min: float = 1.2
@export var bob_speed_max: float = 2.4
@export var bob_amplitude: float = 0.08
@export var rotation_amplitude_degrees: float = 1.5
@export var travel_direction: Vector3 = Vector3.RIGHT
@export var randomize_direction: bool = true

@export_group("Typing Cameo")
## Gắn ông chú gõ laptop lên chính chiếc ghe được BoatSpawner sinh ra.
@export var typing_cameo_enabled: bool = false
## Toạ độ cục bộ theo model ghe02, đặt sát mặt boong; không phụ thuộc scale spawn.
@export var typing_cameo_local_position: Vector3 = Vector3(0.0, 0.08, 0.0):
	set(value):
		typing_cameo_local_position = value
		_request_editor_preview()
@export var typing_cameo_yaw: float = 180.0:
	set(value):
		typing_cameo_yaw = value
		_request_editor_preview()
@export var typing_cameo_char_offset: Vector3 = Vector3(0.0, 0.0, -0.03):
	set(value):
		typing_cameo_char_offset = value
		_request_editor_preview()
@export var typing_cameo_table_offset: Vector3 = Vector3(0.0, 0.23, -0.3):
	set(value):
		typing_cameo_table_offset = value
		_request_editor_preview()
@export var typing_cameo_laptop_offset: Vector3 = Vector3(0.0, 0.32, 0.0):
	set(value):
		typing_cameo_laptop_offset = value
		_request_editor_preview()

@export_group("Editor Preview")
@export var show_typing_cameo_preview: bool = true:
	set(value):
		show_typing_cameo_preview = value
		_request_editor_preview()
@export var preview_local_position: Vector3 = Vector3(0.0, 0.0, 8.0):
	set(value):
		preview_local_position = value
		_request_editor_preview()
@export_range(1.0, 10.0, 0.1) var preview_boat_scale: float = 5.0:
	set(value):
		preview_boat_scale = value
		_request_editor_preview()

var _active_boats: Array[Dictionary] = []
var _spawn_loop_started: bool = false
var _resolved_spawn_points: Array[Node3D] = []
var _editor_preview_queued: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_request_editor_preview()
		return
	randomize()
	_resolve_spawn_points()
	if auto_spawn:
		call_deferred("_start_spawn_loop")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_boats(delta)


func _request_editor_preview() -> void:
	if Engine.is_editor_hint() and is_inside_tree() and not _editor_preview_queued:
		_editor_preview_queued = true
		call_deferred("_rebuild_editor_preview")


func _rebuild_editor_preview() -> void:
	_editor_preview_queued = false
	if not Engine.is_editor_hint():
		return
	var old_preview := get_node_or_null("TypingCameoPreview")
	if old_preview != null:
		old_preview.queue_free()
	if not show_typing_cameo_preview or boat_scenes.is_empty():
		return

	var preview_boat := boat_scenes[0].instantiate() as Node3D
	if preview_boat == null:
		return
	preview_boat.name = "TypingCameoPreview"
	preview_boat.position = preview_local_position
	preview_boat.scale = Vector3.ONE * preview_boat_scale
	add_child(preview_boat)
	_attach_typing_cameo(preview_boat, preview_boat_scale)


func _resolve_spawn_points() -> void:
	_resolved_spawn_points.clear()
	if spawn_points.size() > 0:
		for pt in spawn_points:
			if is_instance_valid(pt):
				_resolved_spawn_points.append(pt)
	else:
		# Tìm các node con trực tiếp làm spawn point
		for child in get_children():
			if child is Node3D:
				_resolved_spawn_points.append(child)


func _get_available_spawn_points() -> Array[Node3D]:
	var available: Array[Node3D] = []
	for pt in _resolved_spawn_points:
		if not is_instance_valid(pt):
			continue
		
		var occupied: bool = false
		for boat_data in _active_boats:
			var boat: Node3D = boat_data.get("node") as Node3D
			if is_instance_valid(boat):
				if boat.global_position.distance_to(pt.global_position) < min_spawn_distance:
					occupied = true
					break
		
		if not occupied:
			available.append(pt)
	return available


func spawn_boat() -> Node3D:
	var chosen_scene: PackedScene = boat_scene
	if boat_scenes.size() > 0:
		chosen_scene = boat_scenes.pick_random()

	if not chosen_scene:
		push_warning("AmbientBoatSpawner chua gan boat_scene hoac boat_scenes.")
		return null

	if _active_boats.size() >= max_active_boats:
		return null

	# Tính toán vị trí, góc xoay và hướng đi
	var spawn_pos: Vector3
	var spawn_rot: Vector3
	var direction: Vector3

	if _resolved_spawn_points.size() > 0:
		var available_points: Array[Node3D] = _get_available_spawn_points()
		if available_points.is_empty():
			# Không có điểm spawn nào trống, bỏ qua lần spawn này
			return null
		
		var pt: Node3D = available_points.pick_random()
		spawn_pos = pt.global_position
		spawn_rot = pt.global_rotation_degrees
		# Hướng di chuyển lấy theo trục Z của spawn point (hướng Forward của node)
		direction = pt.global_transform.basis.z.normalized()
	else:
		# Fallback nếu không có spawn points nào được thiết lập
		direction = travel_direction.normalized()
		if direction.length_squared() < 0.0001:
			direction = Vector3.RIGHT
		if randomize_direction and randf() < 0.5:
			direction *= -1.0

		if use_fixed_position:
			if use_spawner_position_as_fixed:
				spawn_pos = global_position
			else:
				spawn_pos = fixed_spawn_position
		else:
			var spawn_x: float = -spawn_x_extent if direction.x > 0.0 else spawn_x_extent
			var z_position: float = randf_range(lane_z_min, lane_z_max)
			spawn_pos = Vector3(spawn_x, water_y, z_position)
		
		spawn_rot = Vector3(0.0, 90.0 if direction.x > 0.0 else -90.0, 0.0)

	var boat: Node3D = chosen_scene.instantiate() as Node3D
	if not boat:
		return null

	var scale_value: float = randf_range(boat_scale_min, boat_scale_max)

	add_child(boat)
	boat.global_position = spawn_pos
	boat.rotation_degrees = spawn_rot
	boat.scale = Vector3.ONE * scale_value
	_attach_typing_cameo(boat, scale_value)

	_active_boats.append({
		"node": boat,
		"direction": direction,
		"speed": randf_range(speed_min, speed_max),
		"base_y": spawn_pos.y,
		"time": randf() * TAU,
		"bob_speed": randf_range(bob_speed_min, bob_speed_max),
	})
	return boat


func _attach_typing_cameo(boat: Node3D, scale_value: float) -> void:
	if not typing_cameo_enabled:
		return

	var cameo := CAMEO_RIG_SCRIPT.new() as Node3D
	if cameo == null:
		return

	# Ghe decor được phóng to ngẫu nhiên; bù scale để ông chú, bàn và laptop
	# luôn giữ đúng kích thước trong thế giới nhưng vẫn đi/lắc cùng ghe.
	var safe_scale := maxf(absf(scale_value), 0.01)
	cameo.name = "TypingCameo"
	cameo.position = typing_cameo_local_position
	cameo.scale = Vector3.ONE / safe_scale
	cameo.rotation.y = deg_to_rad(typing_cameo_yaw)
	cameo.set("include_boat", false)
	cameo.set("char_offset", typing_cameo_char_offset)
	cameo.set("table_offset", typing_cameo_table_offset)
	cameo.set("laptop_offset", typing_cameo_laptop_offset)
	boat.add_child(cameo)


func _start_spawn_loop() -> void:
	if _spawn_loop_started:
		return

	_spawn_loop_started = true
	for i in range(initial_spawn_count):
		spawn_boat()

	while auto_spawn and is_inside_tree():
		await get_tree().create_timer(randf_range(spawn_interval_min, spawn_interval_max)).timeout
		spawn_boat()


func _update_boats(delta: float) -> void:
	for i in range(_active_boats.size() - 1, -1, -1):
		var boat_data: Dictionary = _active_boats[i]
		var boat: Node3D = boat_data.get("node") as Node3D
		if not is_instance_valid(boat):
			_active_boats.remove_at(i)
			continue

		var direction: Vector3 = boat_data.get("direction", Vector3.RIGHT)
		var speed: float = 0.0
		if boats_can_move:
			speed = float(boat_data.get("speed", speed_min))
			
		var time: float = float(boat_data.get("time", 0.0)) + delta * float(boat_data.get("bob_speed", 1.0))
		var base_y: float = float(boat_data.get("base_y", water_y))

		if boats_can_move:
			boat.global_position += direction * speed * delta
		
		boat.global_position.y = base_y + sin(time) * bob_amplitude
		boat.rotation_degrees.z = cos(time) * rotation_amplitude_degrees
		boat_data["time"] = time

		if enable_despawn and boats_can_move and absf(boat.global_position.x) > despawn_x_extent:
			boat.queue_free()
			_active_boats.remove_at(i)
