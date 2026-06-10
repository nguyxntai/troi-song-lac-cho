extends Node

const GUEST_AGENT_SCENE: PackedScene = preload("res://scenes/guest_ai.tscn")
const GUEST_DEFINITIONS: Array[Dictionary] = [
	{
		"name": "Khach1",
		"scene": preload("res://assets/Khach1/Bacubantraicay.glb"),
		"idle": preload("res://assets/Khach1/animations/idle.res"),
		"walk": preload("res://assets/Khach1/animations/walk.res"),
		"siteat": preload("res://assets/Khach1/animations/siteat.res"),
	},
	{
		"name": "Khach4",
		"scene": preload("res://assets/Khach4/Khachdulich.glb"),
		"idle": preload("res://assets/Khach4/animations/idle.res"),
		"walk": preload("res://assets/Khach4/animations/walk.res"),
		"siteat": preload("res://assets/Khach4/animations/siteat.res"),
	},
]

@export var auto_spawn: bool = true
@export var initial_spawn_delay: float = 10.0
@export var spawn_interval: float = 10.0
@export var max_guests: int = 4
@export var repeat_until_full: bool = true
@export var spawn_slot_spacing: float = 0.7
@export var spawn_point_path: NodePath = NodePath("../GuestBoat/GuestSpawnPoint")
@export var aisle_point_path: NodePath = NodePath("../GuestBoat/GuestAislePoint")
@export var guest_boat_path: NodePath = NodePath("../GuestBoat")
@export var seat_paths: Array[NodePath] = [
	NodePath("../GuestBoat/GuestSeatSlots/Seat1"),
	NodePath("../GuestBoat/GuestSeatSlots/Seat2"),
	NodePath("../GuestBoat/GuestSeatSlots/Seat3"),
	NodePath("../GuestBoat/GuestSeatSlots/Seat4"),
]
@export var table_paths: Array[NodePath] = [
	NodePath("../GuestBoat/Ban1"),
	NodePath("../GuestBoat/Ban2"),
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawned_count: int = 0
var _active_guests: Array[Node] = []
var _spawn_loop_started: bool = false


func _ready() -> void:
	_rng.randomize()
	call_deferred("_start_spawn_loop")


func spawn_random_guest() -> Node:
	var reservation: Dictionary = _reserve_random_table()
	if reservation.is_empty():
		return null
	var seat: Node3D = reservation["seat"] as Node3D
	var table: Node3D = reservation["table"] as Node3D

	var route: Dictionary = _build_route(seat, table)
	if route.is_empty():
		_release_reservation(seat, table)
		return null

	var guest: Node = GUEST_AGENT_SCENE.instantiate() as Node
	if not guest or not guest.has_method("setup"):
		_release_reservation(seat, table)
		return null

	var definition: Dictionary = GUEST_DEFINITIONS[_rng.randi_range(0, GUEST_DEFINITIONS.size() - 1)]
	_spawned_count += 1
	guest.name = "%s_%02d" % [definition["name"], _spawned_count]
	guest.set_meta("spawn_slot_index", int(route.get("spawn_slot_index", 0)))

	var spawn_parent: Node = get_parent()
	if spawn_parent:
		spawn_parent.add_child(guest)
	else:
		add_child(guest)

	guest.call(
		"setup",
		definition["scene"],
		{
			"idle": definition["idle"],
			"walk": definition["walk"],
			"siteat": definition["siteat"],
		},
		route
	)

	_active_guests.append(guest)
	guest.tree_exited.connect(_on_guest_tree_exited.bind(guest, seat, table), CONNECT_ONE_SHOT)
	return guest


func _start_spawn_loop() -> void:
	if not auto_spawn or _spawn_loop_started:
		return

	_spawn_loop_started = true
	if initial_spawn_delay > 0.0:
		await get_tree().create_timer(initial_spawn_delay).timeout

	while is_inside_tree():
		_cleanup_active_guests()
		if _active_guests.size() < max_guests:
			var guest: Node = spawn_random_guest()
			if not guest and _get_free_table_spots().is_empty():
				return

		if not repeat_until_full:
			return

		await get_tree().create_timer(spawn_interval).timeout


func _build_route(seat: Node3D, table: Node3D) -> Dictionary:
	var spawn_point: Node3D = _get_node3d(spawn_point_path)
	var guest_boat: Node3D = _get_node3d(guest_boat_path)
	if not spawn_point or not guest_boat or not table:
		push_warning("GuestSpawner thieu marker duong di cho khach.")
		return {}

	var spawn_slot_index: int = _get_next_spawn_slot_index()
	return {
		"spawn_point": spawn_point,
		"spawn_slot_index": spawn_slot_index,
		"spawn_position": _get_spawn_position(spawn_point, spawn_slot_index),
		"aisle_point": _get_node3d(aisle_point_path),
		"guest_boat": guest_boat,
		"seat_point": seat,
		"reserved_table": table,
		"tables": _get_table_nodes(),
	}


func _get_spawn_position(spawn_point: Node3D, slot_index: int) -> Vector3:
	var start_offset: float = -float(max_guests - 1) * spawn_slot_spacing * 0.5
	var x_offset: float = start_offset + float(slot_index) * spawn_slot_spacing
	return spawn_point.global_position + Vector3.RIGHT * x_offset


func _get_next_spawn_slot_index() -> int:
	var used_slots: Dictionary = {}
	for guest in _active_guests:
		if is_instance_valid(guest) and guest.has_meta("spawn_slot_index"):
			used_slots[int(guest.get_meta("spawn_slot_index"))] = true

	for slot_index in range(max_guests):
		if not used_slots.has(slot_index):
			return slot_index

	return _active_guests.size() % max(1, max_guests)


func _get_node3d(path: NodePath) -> Node3D:
	if String(path).is_empty():
		return null

	return get_node_or_null(path) as Node3D


func _get_table_nodes() -> Array[Node3D]:
	var tables: Array[Node3D] = []
	for table_path in table_paths:
		var table_node: Node3D = _get_node3d(table_path)
		if table_node:
			tables.append(table_node)

	return tables


func _reserve_random_table() -> Dictionary:
	var free_spots: Array[Dictionary] = _get_free_table_spots()
	if free_spots.is_empty():
		return {}

	var spot: Dictionary = free_spots[_rng.randi_range(0, free_spots.size() - 1)]
	var seat: Node3D = spot["seat"] as Node3D
	var table: Node3D = spot["table"] as Node3D
	seat.set_meta("occupied", true)
	table.set_meta("occupied", true)
	return spot


func _get_free_table_spots() -> Array[Dictionary]:
	var free_spots: Array[Dictionary] = []
	for seat_path in seat_paths:
		var seat: Node3D = _get_node3d(seat_path)
		if not seat or not _is_node_free(seat):
			continue

		var table: Node3D = _find_nearest_free_table(seat)
		if table:
			free_spots.append({"seat": seat, "table": table})

	return free_spots


func _find_nearest_free_table(seat: Node3D) -> Node3D:
	var nearest_table: Node3D = _find_nearest_table(seat)
	if nearest_table and _is_node_free(nearest_table):
		return nearest_table

	return null


func _find_nearest_table(seat: Node3D) -> Node3D:
	var nearest_table: Node3D
	var nearest_distance: float = INF
	for table_node in _get_table_nodes():
		var table: Node3D = table_node as Node3D
		if not table:
			continue

		var distance: float = seat.global_position.distance_squared_to(table.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_table = table

	return nearest_table


func _is_node_free(node: Node3D) -> bool:
	return not (node.has_meta("occupied") and bool(node.get_meta("occupied")))


func _release_seat(seat: Node3D) -> void:
	if seat and is_instance_valid(seat):
		seat.set_meta("occupied", false)


func _release_table(table: Node3D) -> void:
	if table and is_instance_valid(table):
		table.set_meta("occupied", false)


func _release_reservation(seat: Node3D, table: Node3D) -> void:
	_release_seat(seat)
	_release_table(table)


func _cleanup_active_guests() -> void:
	for index in range(_active_guests.size() - 1, -1, -1):
		if not is_instance_valid(_active_guests[index]):
			_active_guests.remove_at(index)


func _on_guest_tree_exited(guest: Node, seat: Node3D, table: Node3D) -> void:
	_active_guests.erase(guest)
	_release_reservation(seat, table)
