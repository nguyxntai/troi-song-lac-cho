extends Node3D
class_name FoodStation

enum StationMode {
	TAKE_EMPTY_BOWL,
	ADD_NOODLES,
	COMPLETE_BOWL
}

const FOOD_STAGE_META := "food_stage"
const SERVABLE_FOOD_META := "is_servable_food"
const STAGE_EMPTY_BOWL := 0
const STAGE_BOWL_WITH_NOODLES := 1
const STAGE_FULL_BOWL := 2

@export var station_mode: StationMode = StationMode.TAKE_EMPTY_BOWL
@export var result_scene: PackedScene
@export var interact_action: StringName = &"interact"
@export var hand_slot_name: String = "HandSlot"
@export var result_local_position: Vector3 = Vector3.ZERO
@export var result_local_rotation: Vector3 = Vector3.ZERO
@export var result_local_scale: Vector3 = Vector3.ONE

var _player_in_range: Node3D


func _ready() -> void:
	_connect_interact_area()


func _process(_delta: float) -> void:
	if not _player_in_range:
		return

	if Input.is_action_just_pressed(interact_action):
		interact(_player_in_range)


func interact(player: Node3D) -> bool:
	var hand_slot: Node = _find_hand_slot(player)
	if not hand_slot:
		push_warning("%s khong tim thay HandSlot tren player." % name)
		return false

	match station_mode:
		StationMode.TAKE_EMPTY_BOWL:
			return _take_empty_bowl(hand_slot)
		StationMode.ADD_NOODLES:
			return _upgrade_held_food(hand_slot, STAGE_EMPTY_BOWL, STAGE_BOWL_WITH_NOODLES)
		StationMode.COMPLETE_BOWL:
			return _upgrade_held_food(hand_slot, STAGE_BOWL_WITH_NOODLES, STAGE_FULL_BOWL)

	return false


func _take_empty_bowl(hand_slot: Node) -> bool:
	if hand_slot.get_child_count() > 0:
		push_warning("NamChef dang cam do, khong the lay them to.")
		return false

	_spawn_food_item(hand_slot, STAGE_EMPTY_BOWL)
	return true


func _upgrade_held_food(hand_slot: Node, required_stage: int, result_stage: int) -> bool:
	if hand_slot.get_child_count() == 0:
		push_warning("NamChef chua cam to.")
		return false

	var held_item: Node = hand_slot.get_child(0)
	if _get_food_stage(held_item) != required_stage:
		push_warning("%s sai trang thai mon dang cam." % name)
		return false

	hand_slot.remove_child(held_item)
	held_item.queue_free()
	_spawn_food_item(hand_slot, result_stage)
	return true


func _spawn_food_item(hand_slot: Node, result_stage: int) -> Node:
	var item: Node
	if result_scene:
		item = result_scene.instantiate()
	else:
		item = Node3D.new()
		item.name = _get_default_item_name(result_stage)

	if item is Node3D:
		var item_3d: Node3D = item as Node3D
		item_3d.position = result_local_position
		item_3d.rotation_degrees = result_local_rotation
		item_3d.scale = result_local_scale

	item.set_meta(FOOD_STAGE_META, int(result_stage))
	item.set_meta(SERVABLE_FOOD_META, result_stage == STAGE_FULL_BOWL)
	hand_slot.add_child(item)
	return item


func _get_food_stage(item: Node) -> int:
	if not item.has_meta(FOOD_STAGE_META):
		return STAGE_EMPTY_BOWL

	var raw_stage: int = int(item.get_meta(FOOD_STAGE_META))
	return raw_stage


func _find_hand_slot(player: Node3D) -> Node:
	return player.find_child(hand_slot_name, true, false)


func _connect_interact_area() -> void:
	var area: Area3D = find_child("InteractArea", true, false) as Area3D
	if not area:
		return

	if not area.body_entered.is_connected(_on_interact_area_body_entered):
		area.body_entered.connect(_on_interact_area_body_entered)
	if not area.body_exited.is_connected(_on_interact_area_body_exited):
		area.body_exited.connect(_on_interact_area_body_exited)


func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.name == "NamChef":
		_player_in_range = body


func _on_interact_area_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null


func _get_default_item_name(stage: int) -> String:
	match stage:
		STAGE_EMPTY_BOWL:
			return "EmptyBowl"
		STAGE_BOWL_WITH_NOODLES:
			return "BowlWithNoodles"
		STAGE_FULL_BOWL:
			return "FullBowl"

	return "FoodItem"
