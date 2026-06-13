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
	LEAVING,
}

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_SIT: StringName = &"siteat"
const INTERACT_MARKER_CENTER: Vector3 = Vector3(0.0, 0.0, 0.75)
const INTERACT_MARKER_SIZE: Vector3 = Vector3(0.55, 0.025, 0.55)
const INTERACT_BUTTON_TEXTURE: Texture2D = preload("res://assets/UI/e_button.png")

@export var move_speed: float = 1.35
@export var rotation_speed: float = 8.0
@export var stop_distance: float = 0.08
@export var jump_duration: float = 0.8
@export var jump_height: float = 0.85
@export var food_wait_time: float = 30.0
@export var eat_time: float = 8.0
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
var _interact_prompt: Sprite3D
var _patience_bar_root: Node3D
var _patience_fill: MeshInstance3D
var _patience_material: StandardMaterial3D
var _spawn_position: Vector3 = Vector3.ZERO
var _food_timer: float = 0.0
var _eat_timer: float = 0.0
var _is_pressing_interact: bool = false
var _has_food: bool = false


func setup(model_scene: PackedScene, animations: Dictionary, route: Dictionary) -> void:
	var spawn_point: Node3D = route.get("spawn_point") as Node3D
	var spawn_position: Vector3 = route.get("spawn_position", spawn_point.global_position if spawn_point else Vector3.ZERO)
	_spawn_position = spawn_position
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
	_setup_patience_bar()
	_apply_animations(animations)
	_start_route()


func _physics_process(delta: float) -> void:
	match _state:
		State.WALK_TO_GHEBE, State.WALK_TO_AISLE, State.WALK_TO_SEAT:
			_process_walk(delta)
		State.JUMP_TO_GUEST_BOAT:
			_process_jump(delta)
		State.LEAVING:
			_process_leave(delta)


func _process(_delta: float) -> void:
	if _state == State.SITTING:
		_process_food_wait(_delta)
		return

	if _state != State.WAIT_FOR_INTERACT:
		return

	_update_interact_prompt()
	if _process_press_interaction(_can_start_guest()):
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
	marker_mesh.size = INTERACT_MARKER_SIZE

	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.0, 0.55, 1.0, 0.55)
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_interact_marker = MeshInstance3D.new()
	_interact_marker.name = "InteractMarker"
	_interact_marker.mesh = marker_mesh
	_interact_marker.material_override = marker_material
	_interact_marker.position = INTERACT_MARKER_CENTER + Vector3.UP * 0.035
	add_child(_interact_marker)

	_interact_prompt = Sprite3D.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.texture = INTERACT_BUTTON_TEXTURE
	_interact_prompt.pixel_size = 0.004
	_interact_prompt.position = Vector3(0.0, 1.9, 0.0)
	_interact_prompt.visible = false
	_interact_prompt.set("billboard", 1)
	_interact_prompt.set("no_depth_test", true)
	add_child(_interact_prompt)


func _setup_patience_bar() -> void:
	_patience_bar_root = Node3D.new()
	_patience_bar_root.name = "PatienceBar"
	_patience_bar_root.position = Vector3(0.0, 2.15, 0.0)
	_patience_bar_root.visible = false
	add_child(_patience_bar_root)

	var background_mesh: BoxMesh = BoxMesh.new()
	background_mesh.size = Vector3(0.92, 0.08, 0.035)

	var background_material: StandardMaterial3D = StandardMaterial3D.new()
	background_material.albedo_color = Color(0.04, 0.04, 0.04, 0.75)
	background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var background: MeshInstance3D = MeshInstance3D.new()
	background.name = "Background"
	background.mesh = background_mesh
	background.material_override = background_material
	_patience_bar_root.add_child(background)

	var fill_mesh: BoxMesh = BoxMesh.new()
	fill_mesh.size = Vector3(0.86, 0.05, 0.04)

	_patience_material = StandardMaterial3D.new()
	_patience_material.albedo_color = Color.GREEN
	_patience_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_patience_fill = MeshInstance3D.new()
	_patience_fill.name = "Fill"
	_patience_fill.mesh = fill_mesh
	_patience_fill.material_override = _patience_material
	_patience_bar_root.add_child(_patience_fill)


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
	_face_positive_z()
	_play_animation(ANIM_IDLE, 0.2)


func _begin_route() -> void:
	_set_waiting_visuals(false)
	_set_patience_bar_visible(false)
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
		_reset_press_interaction()
		_update_interact_prompt()


func _apply_clean_spawn_transform(spawn_point: Node3D, spawn_position: Vector3) -> void:
	var next_transform: Transform3D = Transform3D(Basis.IDENTITY, spawn_position)
	global_transform = next_transform
	scale = Vector3.ONE


func _set_waiting_visuals(is_waiting: bool) -> void:
	if _interact_marker:
		_interact_marker.visible = is_waiting
	if not is_waiting and _interact_prompt:
		_interact_prompt.visible = false
		_reset_press_interaction()
		return
	_update_interact_prompt()


func _update_interact_prompt() -> void:
	if _interact_prompt:
		var can_start_guest: bool = _can_start_guest()
		var can_serve_food: bool = _can_serve_food()
		_interact_prompt.visible = can_start_guest or can_serve_food
		if not _interact_prompt.visible:
			_reset_press_interaction()


func _can_start_guest() -> bool:
	return _state == State.WAIT_FOR_INTERACT and _player_in_range != null and _is_player_on_interact_marker()


func _can_serve_food() -> bool:
	return _state == State.SITTING and not _has_food and _player_in_range != null and _player_has_food() and _is_player_on_interact_marker()


func _process_press_interaction(can_interact: bool) -> bool:
	if not can_interact:
		_reset_press_interaction()
		return false

	if Input.is_action_just_pressed(interact_action):
		_is_pressing_interact = true
		_update_press_effect(true)

	if _is_pressing_interact and Input.is_action_just_released(interact_action):
		_reset_press_interaction()
		return true

	return false


func _reset_press_interaction() -> void:
	if not _is_pressing_interact:
		return

	_is_pressing_interact = false
	_update_press_effect(false)


func _update_press_effect(is_pressed: bool) -> void:
	if _interact_prompt:
		_interact_prompt.scale = Vector3.ONE * (0.86 if is_pressed else 1.0)
		_interact_prompt.position = Vector3(0.0, 1.82 if is_pressed else 1.9, 0.0)


func _face_positive_z() -> void:
	rotation.y = 0.0


func _is_player_on_interact_marker() -> bool:
	if not _player_in_range:
		return false

	var local_player_position: Vector3 = to_local(_player_in_range.global_position)
	var delta_from_marker: Vector3 = local_player_position - INTERACT_MARKER_CENTER
	return (
		absf(delta_from_marker.x) <= INTERACT_MARKER_SIZE.x * 0.5
		and absf(delta_from_marker.z) <= INTERACT_MARKER_SIZE.z * 0.5
	)


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
	_start_food_wait()

	_play_animation(ANIM_SIT, 0.1)


func serve_food() -> void:
	if _state != State.SITTING or _has_food:
		return

	_has_food = true
	_eat_timer = maxf(eat_time, 0.1)
	_set_patience_bar_visible(false)
	_update_interact_prompt()


func _start_food_wait() -> void:
	_has_food = false
	_food_timer = maxf(food_wait_time, 0.1)
	_update_patience_bar()
	_set_patience_bar_visible(true)


func _process_food_wait(delta: float) -> void:
	if _has_food:
		_eat_timer = maxf(_eat_timer - delta, 0.0)
		if _eat_timer <= 0.0:
			_leave_after_eating()
		return

	_update_interact_prompt()
	if _process_press_interaction(_can_serve_food()):
		_consume_player_food()
		serve_food()
		return

	_food_timer = maxf(_food_timer - delta, 0.0)
	_update_patience_bar()
	if _food_timer <= 0.0:
		_leave_without_food()


func _leave_after_eating() -> void:
	_begin_leave()


func _leave_without_food() -> void:
	_begin_leave()


func _begin_leave() -> void:
	_state = State.LEAVING
	_current_target = null
	_set_waiting_visuals(false)
	_set_patience_bar_visible(false)
	_play_animation(ANIM_WALK)


func _process_leave(delta: float) -> void:
	var target_position: Vector3 = _get_local_position_from_global(_spawn_position)
	if position.distance_to(target_position) <= stop_distance:
		queue_free()
		return

	position = position.move_toward(target_position, move_speed * delta)
	_face_local_position(target_position, delta)
	_play_animation(ANIM_WALK)


func _set_patience_bar_visible(is_visible: bool) -> void:
	if _patience_bar_root:
		_patience_bar_root.visible = is_visible


func _update_patience_bar() -> void:
	if not _patience_fill or not _patience_material:
		return

	var ratio: float = clampf(_food_timer / maxf(food_wait_time, 0.1), 0.0, 1.0)
	_patience_fill.scale.x = ratio
	_patience_fill.position.x = -0.43 * (1.0 - ratio)
	_patience_material.albedo_color = Color.RED.lerp(Color.GREEN, ratio)


func _player_has_food() -> bool:
	var hand_slot: Node = _get_player_hand_slot()
	if hand_slot == null or hand_slot.get_child_count() == 0:
		return false

	var held_item: Node = hand_slot.get_child(0)
	if held_item.has_meta("is_servable_food"):
		return bool(held_item.get_meta("is_servable_food"))
	if held_item.has_meta("food_stage"):
		return int(held_item.get_meta("food_stage")) == 2

	return true


func _consume_player_food() -> void:
	var hand_slot: Node = _get_player_hand_slot()
	if not hand_slot or hand_slot.get_child_count() == 0:
		return

	hand_slot.get_child(0).queue_free()


func _get_player_hand_slot() -> Node:
	if not _player_in_range:
		return null

	return _player_in_range.find_child("HandSlot", true, false)


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
	return _get_local_position_from_global(target.global_position)


func _get_local_position_from_global(global_target_position: Vector3) -> Vector3:
	var parent_node: Node3D = get_parent() as Node3D
	if parent_node:
		return parent_node.to_local(global_target_position)

	return global_target_position


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
