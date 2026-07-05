extends Node3D
class_name FoodStation

enum StationMode {
	TAKE_EMPTY_BOWL,
	ADD_NOODLES,
	COMPLETE_BOWL,
	FILL_BOKHO
}

const FOOD_STAGE_META := "food_stage"
const FOOD_ID_META := "food_id"
const SERVABLE_FOOD_META := "is_servable_food"
const CARRY_VISUAL_META := "carry_visual"
const CARRY_SOCKET_NAME := "CarrySocket"
const STAGE_UNKNOWN := -1
const STAGE_EMPTY_BOWL := 0
const STAGE_BOWL_WITH_NOODLES := 1
const STAGE_FULL_BOWL := 2
const INTERACT_BUTTON_TEXTURE: Texture2D = preload("res://assets/UI/e_button.png")
const INTERACT_MARKER_COLOR: Color = Color(0.0, 0.72, 1.0, 0.0)
const EFFECT_EMPTY_BOWL: Texture2D = preload("res://assets/UI/to_rong_effect.png")
const EFFECT_BOKHO: Texture2D = preload("res://assets/UI/bokho_effect.png")

@export var station_mode: StationMode = StationMode.TAKE_EMPTY_BOWL
@export var result_scene: PackedScene
@export var interact_action: StringName = &"interact"
@export var hand_slot_name: String = "HandSlot"
@export var result_local_position: Vector3 = Vector3.ZERO
@export var result_local_rotation: Vector3 = Vector3.ZERO
@export var result_local_scale: Vector3 = Vector3.ONE
@export var result_food_id: String = ""
@export var stock_capacity: int = 7
@export var stock_remaining: int = 7
@export var show_stock_counter: bool = false
@export var marker_offset: Vector3 = Vector3.ZERO
@export var marker_size: Vector2 = Vector2(0.65, 0.65)
@export var prompt_offset: Vector3 = Vector3(0.0, 0.9, 0.0)
@export var stock_label_offset: Vector3 = Vector3(0.0, 1.15, 0.0)
@export var interact_area_offset: Vector3 = Vector3(0.0, 0.7, 0.0)
@export var interact_area_size: Vector3 = Vector3(1.15, 1.4, 1.15)

var _player_in_range: Node3D
var _player: Node3D
var _interact_marker: MeshInstance3D
var _interact_prompt: Sprite3D
var _stock_label: Label3D
var _boiling_sfx_player: AudioStreamPlayer3D


func _ready() -> void:
	if station_mode == StationMode.TAKE_EMPTY_BOWL:
		var capacity_bonus: int = GameManager.get_bowl_capacity_bonus()
		stock_capacity += capacity_bonus
		stock_remaining += capacity_bonus
	stock_capacity = maxi(stock_capacity, 0)
	stock_remaining = clampi(stock_remaining, 0, stock_capacity)
	_player = get_tree().current_scene.find_child("NamChef", true, false) as Node3D
	if station_mode == StationMode.FILL_BOKHO:
		_boiling_sfx_player = AudioManager.play_boiling_loop(self)
	_connect_interact_area()
	_setup_interact_visuals()
	_update_station_visuals()


func _exit_tree() -> void:
	if _boiling_sfx_player != null and is_instance_valid(_boiling_sfx_player):
		_boiling_sfx_player.stop()


func _process(_delta: float) -> void:
	_update_station_visuals()
	if not _player_in_range or not _can_interact(_player_in_range):
		return

	if not GameManager.is_tutorial_locked and Input.is_action_just_pressed(interact_action):
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
		StationMode.FILL_BOKHO:
			return _upgrade_held_food(hand_slot, STAGE_EMPTY_BOWL, STAGE_FULL_BOWL)

	return false


func _take_empty_bowl(hand_slot: Node) -> bool:
	if hand_slot.get_child_count() > 0:
		push_warning("NamChef dang cam do, khong the lay them to.")
		return false
	if stock_remaining <= 0:
		push_warning("%s da het to rong." % name)
		return false

	_spawn_food_item(hand_slot, STAGE_EMPTY_BOWL)
	stock_remaining = maxi(stock_remaining - 1, 0)
	_update_station_visuals()
	_spawn_effect(EFFECT_EMPTY_BOWL)
	AudioManager.play_take_empty_bowl()
	return true


func _spawn_effect(tex: Texture2D) -> void:
	if not _player:
		return
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = 0.0015
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	get_tree().current_scene.add_child(sprite)
	sprite.global_position = _player.global_position + Vector3(0, 2.2, 0)
	
	var tween := create_tween()
	tween.tween_property(sprite, "global_position:y", sprite.global_position.y + 0.8, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(sprite.queue_free)


func _upgrade_held_food(hand_slot: Node, required_stage: int, result_stage: int) -> bool:
	if hand_slot.get_child_count() == 0:
		push_warning("NamChef chua cam to.")
		return false

	var held_item: Node = hand_slot.get_child(0)
	if _get_food_stage(held_item) != required_stage:
		push_warning("%s sai trang thai mon dang cam." % name)
		return false

	_free_carry_visual(held_item)
	hand_slot.remove_child(held_item)
	held_item.queue_free()
	_spawn_food_item(hand_slot, result_stage)
	_update_station_visuals()
	AudioManager.play_take_food_from_pot()
	
	if result_stage == STAGE_FULL_BOWL:
		_spawn_effect(EFFECT_BOKHO)
		
	return true


func _spawn_food_item(hand_slot: Node, result_stage: int) -> Node:
	var holder: Node3D = Node3D.new()
	holder.name = _get_default_item_name(result_stage)
	holder.set_meta(FOOD_STAGE_META, int(result_stage))
	holder.set_meta(SERVABLE_FOOD_META, result_stage == STAGE_FULL_BOWL)
	holder.set_meta(FOOD_ID_META, _get_result_food_id(result_stage))
	hand_slot.add_child(holder)

	var visual_parent: Node = _find_carry_visual_parent(hand_slot)
	var item: Node
	if result_scene:
		item = result_scene.instantiate()
	else:
		item = Node3D.new()
		item.name = "%sVisual" % _get_default_item_name(result_stage)

	if item is Node3D:
		var item_3d: Node3D = item as Node3D
		item_3d.position = result_local_position
		item_3d.rotation_degrees = result_local_rotation
		item_3d.scale = result_local_scale

	visual_parent.add_child(item)
	holder.set_meta(CARRY_VISUAL_META, item)
	return holder


func _get_food_stage(item: Node) -> int:
	if not item.has_meta(FOOD_STAGE_META):
		return STAGE_UNKNOWN

	var raw_stage: int = int(item.get_meta(FOOD_STAGE_META))
	return raw_stage


func _find_hand_slot(player: Node3D) -> Node:
	return player.find_child(hand_slot_name, true, false)


func _find_carry_visual_parent(hand_slot: Node) -> Node:
	var owner_node: Node = hand_slot.owner
	if owner_node:
		var carry_socket: Node = owner_node.find_child(CARRY_SOCKET_NAME, true, false)
		if carry_socket:
			return carry_socket

	var current: Node = hand_slot
	while current:
		var carry_socket_from_parent: Node = current.find_child(CARRY_SOCKET_NAME, true, false)
		if carry_socket_from_parent:
			return carry_socket_from_parent
		current = current.get_parent()

	return hand_slot


func _free_carry_visual(held_item: Node) -> void:
	if not held_item.has_meta(CARRY_VISUAL_META):
		return

	var visual_variant: Variant = held_item.get_meta(CARRY_VISUAL_META)
	if visual_variant is Node:
		var visual_node: Node = visual_variant as Node
		if is_instance_valid(visual_node):
			visual_node.queue_free()


func _connect_interact_area() -> void:
	var area: Area3D = find_child("InteractArea", true, false) as Area3D
	if not area:
		area = Area3D.new()
		area.name = "InteractArea"
		area.position = interact_area_offset
		add_child(area)

		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box: BoxShape3D = BoxShape3D.new()
		box.size = interact_area_size
		shape.shape = box
		area.add_child(shape)

	if not area.body_entered.is_connected(_on_interact_area_body_entered):
		area.body_entered.connect(_on_interact_area_body_entered)
	if not area.body_exited.is_connected(_on_interact_area_body_exited):
		area.body_exited.connect(_on_interact_area_body_exited)


func _setup_interact_visuals() -> void:
	var marker_mesh: BoxMesh = BoxMesh.new()
	marker_mesh.size = Vector3(marker_size.x, 0.025, marker_size.y)

	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = INTERACT_MARKER_COLOR
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_interact_marker = MeshInstance3D.new()
	_interact_marker.name = "InteractMarker"
	_interact_marker.mesh = marker_mesh
	_interact_marker.material_override = marker_material
	_interact_marker.position = marker_offset + Vector3.UP * 0.035
	add_child(_interact_marker)

	_interact_prompt = Sprite3D.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.texture = INTERACT_BUTTON_TEXTURE
	_interact_prompt.pixel_size = 0.0006
	_interact_prompt.position = prompt_offset
	_interact_prompt.set("billboard", 1)
	_interact_prompt.set("no_depth_test", true)
	add_child(_interact_prompt)

	_stock_label = Label3D.new()
	_stock_label.name = "StockLabel"
	_stock_label.position = stock_label_offset
	_stock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stock_label.no_depth_test = true
	_stock_label.font_size = 42
	_stock_label.modulate = Color(1.0, 0.96, 0.78, 1.0)
	_stock_label.outline_modulate = Color(0.14, 0.05, 0.02, 1.0)
	_stock_label.outline_size = 10
	add_child(_stock_label)


func _update_station_visuals() -> void:
	var can_use_station: bool = _can_interact(_player)
	if _interact_marker:
		_interact_marker.visible = can_use_station
	if _interact_prompt:
		_interact_prompt.visible = _player_in_range != null and _can_interact(_player_in_range)
	if _stock_label:
		_stock_label.visible = show_stock_counter
		_stock_label.text = "%d/%d" % [stock_remaining, stock_capacity]


func _can_interact(player: Node3D) -> bool:
	if not player:
		return false

	var hand_slot: Node = _find_hand_slot(player)
	if not hand_slot:
		return false

	match station_mode:
		StationMode.TAKE_EMPTY_BOWL:
			return stock_remaining > 0 and hand_slot.get_child_count() == 0
		StationMode.ADD_NOODLES:
			return _held_food_stage_equals(hand_slot, STAGE_EMPTY_BOWL)
		StationMode.COMPLETE_BOWL:
			return _held_food_stage_equals(hand_slot, STAGE_BOWL_WITH_NOODLES)
		StationMode.FILL_BOKHO:
			return _held_food_stage_equals(hand_slot, STAGE_EMPTY_BOWL)

	return false


func _held_food_stage_equals(hand_slot: Node, required_stage: int) -> bool:
	if hand_slot.get_child_count() == 0:
		return false

	var held_item: Node = hand_slot.get_child(0)
	return _get_food_stage(held_item) == required_stage


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


func _get_result_food_id(stage: int) -> String:
	if not result_food_id.is_empty():
		return result_food_id

	match stage:
		STAGE_EMPTY_BOWL:
			return "empty_bowl"
		STAGE_BOWL_WITH_NOODLES:
			return "bowl_with_noodles"
		STAGE_FULL_BOWL:
			if station_mode == StationMode.FILL_BOKHO:
				return "bo_kho"
			return "full_bowl"

	return "unknown"
