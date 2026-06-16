extends Node3D

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

var _active_boats: Array[Dictionary] = []
var _spawn_loop_started: bool = false
var _resolved_spawn_points: Array[Node3D] = []


func _ready() -> void:
	randomize()
	_resolve_spawn_points()
	if auto_spawn:
		call_deferred("_start_spawn_loop")


func _process(delta: float) -> void:
	_update_boats(delta)


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

	_active_boats.append({
		"node": boat,
		"direction": direction,
		"speed": randf_range(speed_min, speed_max),
		"base_y": spawn_pos.y,
		"time": randf() * TAU,
		"bob_speed": randf_range(bob_speed_min, bob_speed_max),
	})
	return boat


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
