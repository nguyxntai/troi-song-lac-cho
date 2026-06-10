extends CharacterBody3D
class_name GuestAI

enum State {
	IDLE,
	WAIT_FOR_INTERACT,
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
@export var interact_action: StringName = &"interact"

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
var _model_root: Node3D
var _reserved_table: Node3D
var _player_in_range: Node3D
var _interact_marker: MeshInstance3D
var _interact_prompt: Label3D


func setup(model_scene: PackedScene, animations: Dictionary, route: Dictionary) -> void:
	var spawn_point: Node3D = route.get("spawn_point") as Node3D
	var spawn_position: Vector3 = route.get("spawn_position", spawn_point.global_position if spawn_point else Vector3.ZERO)
	_ghebe_point = route.get("ghebe_point") as Node3D
	_landing_point = route.get("landing_point") as Node3D
	_aisle_point = route.get("aisle_point") as Node3D
	_seat_point = route.get("seat_point") as Node3D
	_guest_boat = route.get("guest_boat") as Node3D
	_reserved_table = route.get("reserved_table") as Node3D
	_table_nodes.clear()

	for table_node in route.get("tables", []):
		var table_node_3d: Node3D = table_node as Node3D
		if table_node_3d:
			_table_nodes.append(table_node_3d)

	if spawn_point:
		_apply_clean_spawn_transform(spawn_point, spawn_position)

	_setup_model(model_scene)
	_setup_interact_visuals()
	_apply_animations(animations)
	_start_route()


func _physics_process(delta: float) -> void:
	match _state:
		State.WALK_TO_GHEBE, State.WALK_TO_AISLE, State.WALK_TO_SEAT:
			_process_walk(delta)
		State.JUMP_TO_GUEST_BOAT:
			_process_jump(delta)


func _process(_delta: float) -> void:
	if _state != State.WAIT_FOR_INTERACT:
		return

	if _player_in_range and Input.is_action_just_pressed(interact_action) and _is_nearest_waiting_guest():
		_begin_route()


func _exit_tree() -> void:
	if _seat_point and is_instance_valid(_seat_point):
		_seat_point.set_meta("occupied", false)
	if _reserved_table and is_instance_valid(_reserved_table):
		_reserved_table.set_meta("occupied", false)


func _setup_model(model_scene: PackedScene) -> void:
	if not model_scene:
		return

	var model: Node = model_scene.instantiate()
	model.name = "Model"
	add_child(model)
	_model_root = model as Node3D
	_anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player:
		_anim_player.set("callback_mode_process", 0)
		_anim_player.set("playback_process_mode", 0)
		_anim_player.set("root_motion_track", NodePath(""))


func _setup_interact_visuals() -> void:
	var marker_mesh: BoxMesh = BoxMesh.new()
	marker_mesh.size = Vector3(0.55, 0.025, 0.55)

	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.0, 0.55, 1.0, 0.55)
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_interact_marker = MeshInstance3D.new()
	_interact_marker.name = "InteractMarker"
	_interact_marker.mesh = marker_mesh
	_interact_marker.material_override = marker_material
	_interact_marker.position = Vector3(0.0, 0.035, 0.75)
	add_child(_interact_marker)

	_interact_prompt = Label3D.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.text = "E"
	_interact_prompt.font_size = 96
	_interact_prompt.pixel_size = 0.008
	_interact_prompt.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_interact_prompt.outline_size = 16
	_interact_prompt.outline_modulate = Color(0.0, 0.25, 0.75, 1.0)
	_interact_prompt.position = Vector3(0.0, 1.9, 0.0)
	_interact_prompt.visible = false
	_interact_prompt.set("billboard", 1)
	_interact_prompt.set("no_depth_test", true)
	add_child(_interact_prompt)


func _apply_animations(animations: Dictionary) -> void:
	_ensure_animation(ANIM_IDLE, animations.get("idle") as Animation, true)
	_ensure_animation(ANIM_WALK, animations.get("walk") as Animation, true)
	_ensure_animation(ANIM_SIT, animations.get("siteat") as Animation, false)


func _ensure_animation(animation_name: StringName, animation: Animation, should_loop: bool) -> void:
	if not _anim_player or not animation:
		return

	var animation_copy: Animation = animation.duplicate(true) as Animation
	if not animation_copy:
		return

	if should_loop:
		animation_copy.loop_mode = Animation.LOOP_LINEAR

	_strip_non_skeleton_transform_tracks(animation_copy)
	_remove_animation_from_all_libraries(animation_name)

	var library: AnimationLibrary
	if _anim_player.has_animation_library(&""):
		library = _anim_player.get_animation_library(&"")
	else:
		library = AnimationLibrary.new()
		_anim_player.add_animation_library(&"", library)

	library.add_animation(animation_name, animation_copy)


func _remove_animation_from_all_libraries(animation_name: StringName) -> void:
	for library_name in _anim_player.get_animation_library_list():
		var library: AnimationLibrary = _anim_player.get_animation_library(library_name)
		if library and library.has_animation(animation_name):
			library.remove_animation(animation_name)


func _strip_non_skeleton_transform_tracks(animation: Animation) -> void:
	if not _anim_player:
		return

	for track_index in range(animation.get_track_count() - 1, -1, -1):
		var track_type: int = animation.track_get_type(track_index)
		var is_transform_track: bool = (
			track_type == Animation.TYPE_POSITION_3D
			or track_type == Animation.TYPE_ROTATION_3D
			or track_type == Animation.TYPE_SCALE_3D
		)
		if not is_transform_track:
			continue

		var track_path: NodePath = animation.track_get_path(track_index)
		var target_node: Node = _resolve_animation_track_node(track_path)
		var is_skeleton_bone_track: bool = (target_node is Skeleton3D) and track_path.get_subname_count() > 0
		if target_node and not is_skeleton_bone_track:
			animation.remove_track(track_index)


func _resolve_animation_track_node(track_path: NodePath) -> Node:
	var animation_root: Node = _anim_player.get_node_or_null(_anim_player.root_node)
	if not animation_root:
		animation_root = _anim_player.get_parent()
	if not animation_root:
		return null

	var node_path: NodePath = _get_track_node_path(track_path)
	if String(node_path).is_empty():
		return animation_root

	return animation_root.get_node_or_null(node_path)


func _get_track_node_path(track_path: NodePath) -> NodePath:
	var node_path_text: String = ""
	for index in range(track_path.get_name_count()):
		if index > 0:
			node_path_text += "/"
		node_path_text += String(track_path.get_name(index))

	return NodePath(node_path_text)


func _start_route() -> void:
	_state = State.WAIT_FOR_INTERACT
	_current_target = null
	_set_waiting_visuals(true)
	_face_nearest_table()
	_play_animation(ANIM_IDLE, 0.2)


func _begin_route() -> void:
	_set_waiting_visuals(false)
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


func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.name == "NamChef":
		_player_in_range = body
		_update_interact_prompt()


func _on_interact_area_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_update_interact_prompt()


func _apply_clean_spawn_transform(spawn_point: Node3D, spawn_position: Vector3) -> void:
	var clean_basis: Basis = spawn_point.global_transform.basis.orthonormalized()
	var next_transform: Transform3D = Transform3D(clean_basis, spawn_position)
	global_transform = next_transform
	scale = Vector3.ONE


func _set_waiting_visuals(is_waiting: bool) -> void:
	if _interact_marker:
		_interact_marker.visible = is_waiting
	if not is_waiting and _interact_prompt:
		_interact_prompt.visible = false
		return
	_update_interact_prompt()


func _update_interact_prompt() -> void:
	if _interact_prompt:
		_interact_prompt.visible = _state == State.WAIT_FOR_INTERACT and _player_in_range != null and _is_nearest_waiting_guest()


func _is_nearest_waiting_guest() -> bool:
	if not _player_in_range:
		return false

	var parent_node: Node = get_parent()
	if not parent_node:
		return true

	var my_distance: float = global_position.distance_squared_to(_player_in_range.global_position)
	for sibling in parent_node.get_children():
		var guest: GuestAI = sibling as GuestAI
		if not guest or guest == self or guest._state != State.WAIT_FOR_INTERACT or not guest._player_in_range:
			continue

		var guest_distance: float = guest.global_position.distance_squared_to(_player_in_range.global_position)
		var distance_difference: float = guest_distance - my_distance
		if distance_difference < -0.0001:
			return false
		if absf(distance_difference) <= 0.0001 and guest.get_instance_id() < get_instance_id():
			return false

	return true


func _process_walk(delta: float) -> void:
	if not _current_target or not is_instance_valid(_current_target):
		return

	var target_position: Vector3 = _get_local_target_position(_current_target)
	if position.distance_to(target_position) <= stop_distance:
		position = target_position
		_on_walk_target_reached()
		return

	position = position.move_toward(target_position, move_speed * delta)
	_face_local_position(target_position, delta)
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
		_state = State.WALK_TO_AISLE
		_current_target = _aisle_point if _aisle_point else _seat_point


func _sit_down() -> void:
	_state = State.SITTING
	_current_target = null

	if _seat_point and is_instance_valid(_seat_point):
		position = _get_local_target_position(_seat_point)

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
		_face_local_position(_get_local_target_position(nearest_table))


func _get_local_target_position(target: Node3D) -> Vector3:
	var parent_node: Node3D = get_parent() as Node3D
	if parent_node:
		return parent_node.to_local(target.global_position)

	return target.global_position


func _face_local_position(target_position: Vector3, delta: float = -1.0) -> void:
	var direction: Vector3 = target_position - position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return

	var target_yaw: float = atan2(direction.x, direction.z)
	if delta >= 0.0:
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(rotation_speed * delta, 0.0, 1.0))
	else:
		rotation.y = target_yaw


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
