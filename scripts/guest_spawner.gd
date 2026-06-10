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
	var seat: Node3D = _reserve_random_seat()
	if not seat:
		return null

	var route: Dictionary = _build_route(seat)
	if route.is_empty():
		_release_seat(seat)
		return null

	var guest: Node = GUEST_AGENT_SCENE.instantiate() as Node
	if not guest or not guest.has_method("setup"):
		_release_seat(seat)
		return null

	var definition: Dictionary = GUEST_DEFINITIONS[_rng.randi_range(0, GUEST_DEFINITIONS.size() - 1)]
	_spawned_count += 1
	guest.name = "%s_%02d" % [definition["name"], _spawned_count]

	var spawn_parent: Node = route.get("guest_boat") as Node
	if not spawn_parent:
		spawn_parent = get_parent()

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
	guest.tree_exited.connect(_on_guest_tree_exited.bind(guest, seat), CONNECT_ONE_SHOT)
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
			if not guest and _get_free_seats().is_empty():
				return

		if not repeat_until_full:
			return

		await get_tree().create_timer(spawn_interval).timeout


func _build_route(seat: Node3D) -> Dictionary:
	var spawn_point: Node3D = _get_node3d(spawn_point_path)
	var guest_boat: Node3D = _get_node3d(guest_boat_path)
	if not spawn_point or not guest_boat:
		push_warning("GuestSpawner thieu marker duong di cho khach.")
		return {}

	return {
		"spawn_point": spawn_point,
		"aisle_point": _get_node3d(aisle_point_path),
		"guest_boat": guest_boat,
		"seat_point": seat,
		"tables": _get_table_nodes(),
	}


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


func _reserve_random_seat() -> Node3D:
	var free_seats: Array[Node3D] = _get_free_seats()
	if free_seats.is_empty():
		return null

	var seat: Node3D = free_seats[_rng.randi_range(0, free_seats.size() - 1)]
	seat.set_meta("occupied", true)
	return seat


func _get_free_seats() -> Array[Node3D]:
	var free_seats: Array[Node3D] = []
	for seat_path in seat_paths:
		var seat: Node3D = _get_node3d(seat_path)
		if seat and _is_seat_free(seat):
			free_seats.append(seat)

	return free_seats


func _is_seat_free(seat: Node3D) -> bool:
	return not (seat.has_meta("occupied") and bool(seat.get_meta("occupied")))


func _release_seat(seat: Node3D) -> void:
	if seat and is_instance_valid(seat):
		seat.set_meta("occupied", false)


func _cleanup_active_guests() -> void:
	for index in range(_active_guests.size() - 1, -1, -1):
		if not is_instance_valid(_active_guests[index]):
			_active_guests.remove_at(index)


func _on_guest_tree_exited(guest: Node, seat: Node3D) -> void:
	_active_guests.erase(guest)
	_release_seat(seat)
