extends CharacterBody3D
class_name GuestAI

enum State {
	IDLE,
	WALK_TO_GHEBE,
	JUMP_TO_GUEST_BOAT,
	WALK_TO_AISLE,
	WALK_TO_SEAT,
	SITTING,
}

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_SIT: StringName = &"siteat"

@export var move_speed: float = 1.35
@export var rotation_speed: float = 8.0
@export var stop_distance: float = 0.08
@export var jump_duration: float = 0.8
@export var jump_height: float = 0.85

var _state: int = State.IDLE
var _anim_player: AnimationPlayer
var _current_target: Node3D
var _ghebe_point: Node3D
var _landing_point: Node3D
var _aisle_point: Node3D
var _seat_point: Node3D
var _guest_boat: Node3D
var _table_nodes: Array[Node3D] = []
var _jump_start: Vector3 = Vector3.ZERO
var _jump_end: Vector3 = Vector3.ZERO
var _jump_elapsed: float = 0.0


func setup(model_scene: PackedScene, animations: Dictionary, route: Dictionary) -> void:
	var spawn_point: Node3D = route.get("spawn_point") as Node3D
	_ghebe_point = route.get("ghebe_point") as Node3D
	_landing_point = route.get("landing_point") as Node3D
	_aisle_point = route.get("aisle_point") as Node3D
	_seat_point = route.get("seat_point") as Node3D
	_guest_boat = route.get("guest_boat") as Node3D
	_table_nodes.clear()

	for table_node in route.get("tables", []):
		var table_node_3d: Node3D = table_node as Node3D
		if table_node_3d:
			_table_nodes.append(table_node_3d)

	if spawn_point:
		global_transform = spawn_point.global_transform

	_setup_model(model_scene)
	_apply_animations(animations)
	_start_route()


func _physics_process(delta: float) -> void:
	match _state:
		State.WALK_TO_GHEBE, State.WALK_TO_AISLE, State.WALK_TO_SEAT:
			_process_walk(delta)
		State.JUMP_TO_GUEST_BOAT:
			_process_jump(delta)


func _exit_tree() -> void:
	if _seat_point and is_instance_valid(_seat_point):
		_seat_point.set_meta("occupied", false)


func _setup_model(model_scene: PackedScene) -> void:
	if not model_scene:
		return

	var model: Node = model_scene.instantiate()
	model.name = "Model"
	add_child(model)
	_anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _apply_animations(animations: Dictionary) -> void:
	_ensure_animation(ANIM_IDLE, animations.get("idle") as Animation, true)
	_ensure_animation(ANIM_WALK, animations.get("walk") as Animation, true)
	_ensure_animation(ANIM_SIT, animations.get("siteat") as Animation, false)


func _ensure_animation(animation_name: StringName, animation: Animation, should_loop: bool) -> void:
	if not _anim_player or not animation or _anim_player.has_animation(animation_name):
		return

	if should_loop:
		animation.loop_mode = Animation.LOOP_LINEAR

	var library: AnimationLibrary
	if _anim_player.has_animation_library(&""):
		library = _anim_player.get_animation_library(&"")
	else:
		library = AnimationLibrary.new()
		_anim_player.add_animation_library(&"", library)

	if not library.has_animation(animation_name):
		library.add_animation(animation_name, animation)


func _start_route() -> void:
	if not _seat_point:
		_sit_down()
		return

	if _ghebe_point and _landing_point:
		_state = State.WALK_TO_GHEBE
		_current_target = _ghebe_point
	elif _aisle_point:
		_state = State.WALK_TO_AISLE
		_current_target = _aisle_point
	else:
		_state = State.WALK_TO_SEAT
		_current_target = _seat_point

	_play_animation(ANIM_WALK)


func _process_walk(delta: float) -> void:
	if not _current_target or not is_instance_valid(_current_target):
		return

	var target_position: Vector3 = _current_target.global_position
	if global_position.distance_to(target_position) <= stop_distance:
		global_position = target_position
		_on_walk_target_reached()
		return

	global_position = global_position.move_toward(target_position, move_speed * delta)
	_face_position(target_position, delta)
	_play_animation(ANIM_WALK)


func _on_walk_target_reached() -> void:
	match _state:
		State.WALK_TO_GHEBE:
			_begin_jump()
		State.WALK_TO_AISLE:
			_state = State.WALK_TO_SEAT
			_current_target = _seat_point
		State.WALK_TO_SEAT:
			_sit_down()


func _begin_jump() -> void:
	_state = State.JUMP_TO_GUEST_BOAT
	_jump_start = global_position
	_jump_end = _landing_point.global_position
	_jump_elapsed = 0.0
	_play_animation(ANIM_WALK)


func _process_jump(delta: float) -> void:
	if _landing_point and is_instance_valid(_landing_point):
		_jump_end = _landing_point.global_position

	_jump_elapsed += delta
	var progress: float = clampf(_jump_elapsed / maxf(jump_duration, 0.01), 0.0, 1.0)
	var next_position: Vector3 = _jump_start.lerp(_jump_end, progress)
	next_position.y += sin(progress * PI) * jump_height
	global_position = next_position
	_face_position(_jump_end, delta)

	if progress >= 1.0:
		global_position = _jump_end
		if _guest_boat and get_parent() != _guest_boat:
			reparent(_guest_boat, true)
			global_position = _jump_end

		_state = State.WALK_TO_AISLE
		_current_target = _aisle_point if _aisle_point else _seat_point


func _sit_down() -> void:
	_state = State.SITTING
	_current_target = null

	if _guest_boat and get_parent() != _guest_boat:
		reparent(_guest_boat, true)

	if _seat_point and is_instance_valid(_seat_point):
		global_position = _seat_point.global_position

	_face_nearest_table()

	_play_animation(ANIM_SIT, 0.1)


func _face_nearest_table() -> void:
	if not _seat_point:
		return

	var nearest_table: Node3D
	var best_distance: float = INF
	for table_node in _table_nodes:
		if not is_instance_valid(table_node):
			continue

		var distance: float = _seat_point.global_position.distance_squared_to(table_node.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest_table = table_node

	if nearest_table:
		_face_position(nearest_table.global_position)


func _face_position(target_position: Vector3, delta: float = -1.0) -> void:
	var direction: Vector3 = target_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return

	var target_yaw: float = atan2(direction.x, direction.z)
	var next_rotation: Vector3 = global_rotation
	if delta >= 0.0:
		next_rotation.y = lerp_angle(next_rotation.y, target_yaw, clampf(rotation_speed * delta, 0.0, 1.0))
	else:
		next_rotation.y = target_yaw
	global_rotation = next_rotation


func _play_animation(animation_name: StringName, blend: float = 0.15) -> void:
	if not _anim_player or not _anim_player.has_animation(animation_name):
		return

	if _anim_player.current_animation == animation_name:
		return

	_anim_player.play(animation_name, blend)
