extends Node3D
class_name FoodBufferSlot

const CARRY_VISUAL_META := "carry_visual"
const CARRY_SOCKET_NAME := "CarrySocket"
const INTERACT_BUTTON_TEXTURE: Texture2D = preload("res://assets/UI/e_button.png")
const STORED_POSITION_META := "buffer_stored_position"
const STORED_ROTATION_META := "buffer_stored_rotation"
const STORED_SCALE_META := "buffer_stored_scale"

@export var interact_action: StringName = &"interact"
@export var hand_slot_name: String = "HandSlot"
@export var slot_visual_position: Vector3 = Vector3(0.0, 0.15, 0.0)
@export var slot_visual_rotation: Vector3 = Vector3.ZERO
@export var slot_visual_scale: Vector3 = Vector3(0.22, 0.22, 0.22)
@export var interact_area_offset: Vector3 = Vector3(0.0, 0.7, 0.0)
@export var interact_area_size: Vector3 = Vector3(1.05, 1.4, 1.05)
@export var prompt_offset: Vector3 = Vector3(0.0, 0.95, 0.0)
@export var label_offset: Vector3 = Vector3(0.0, 0.5, 0.0)
@export var show_slot_surface: bool = false

var _player_in_range: Node3D
var _stored_item: Node
var _interact_prompt: Sprite3D
var _status_label: Label3D


func _ready() -> void:
	_setup_interact_area()
	_setup_visuals()
	_update_visuals()


func _process(_delta: float) -> void:
	if not _player_in_range or not _can_interact(_player_in_range):
		return

	if not GameManager.is_tutorial_locked and Input.is_action_just_pressed(interact_action):
		_interact(_player_in_range)


func _interact(player: Node3D) -> void:
	var hand_slot: Node = _find_hand_slot(player)
	if not hand_slot:
		return

	if hand_slot.get_child_count() > 0 and _stored_item == null:
		_store_from_hand(hand_slot)
	elif hand_slot.get_child_count() == 0 and _stored_item != null:
		_take_to_hand(player, hand_slot)

	_update_visuals()


func _store_from_hand(hand_slot: Node) -> void:
	var held_item: Node = hand_slot.get_child(0)
	_store_carry_transform(held_item)
	hand_slot.remove_child(held_item)
	add_child(held_item)
	_stored_item = held_item

	var visual_node: Node3D = _get_carry_visual(held_item)
	if visual_node:
		_move_visual_to_slot(visual_node)


func _take_to_hand(player: Node3D, hand_slot: Node) -> void:
	if not _stored_item:
		return

	var stored_item: Node = _stored_item
	_stored_item = null
	remove_child(stored_item)
	hand_slot.add_child(stored_item)

	var visual_node: Node3D = _get_carry_visual(stored_item)
	if visual_node:
		_move_visual_to_hand(player, hand_slot, stored_item, visual_node)


func _store_carry_transform(item: Node) -> void:
	var visual_node: Node3D = _get_carry_visual(item)
	if not visual_node:
		return

	item.set_meta(STORED_POSITION_META, visual_node.position)
	item.set_meta(STORED_ROTATION_META, visual_node.rotation_degrees)
	item.set_meta(STORED_SCALE_META, visual_node.scale)


func _move_visual_to_slot(visual_node: Node3D) -> void:
	var old_parent: Node = visual_node.get_parent()
	if old_parent:
		old_parent.remove_child(visual_node)

	add_child(visual_node)
	visual_node.position = slot_visual_position
	visual_node.rotation_degrees = slot_visual_rotation
	visual_node.scale = slot_visual_scale


func _move_visual_to_hand(player: Node3D, hand_slot: Node, item: Node, visual_node: Node3D) -> void:
	var old_parent: Node = visual_node.get_parent()
	if old_parent:
		old_parent.remove_child(visual_node)

	var carry_parent: Node = _find_carry_visual_parent(player, hand_slot)
	carry_parent.add_child(visual_node)
	var stored_position: Variant = item.get_meta(STORED_POSITION_META, visual_node.position)
	var stored_rotation: Variant = item.get_meta(STORED_ROTATION_META, visual_node.rotation_degrees)
	var stored_scale: Variant = item.get_meta(STORED_SCALE_META, visual_node.scale)
	if stored_position is Vector3:
		visual_node.position = stored_position
	if stored_rotation is Vector3:
		visual_node.rotation_degrees = stored_rotation
	if stored_scale is Vector3:
		visual_node.scale = stored_scale


func _get_carry_visual(item: Node) -> Node3D:
	if not item or not item.has_meta(CARRY_VISUAL_META):
		return null

	var visual_variant: Variant = item.get_meta(CARRY_VISUAL_META)
	if visual_variant is Node3D and is_instance_valid(visual_variant):
		return visual_variant as Node3D

	return null


func _can_interact(player: Node3D) -> bool:
	var hand_slot: Node = _find_hand_slot(player)
	if not hand_slot:
		return false

	return (hand_slot.get_child_count() > 0 and _stored_item == null) or (hand_slot.get_child_count() == 0 and _stored_item != null)


func _find_hand_slot(player: Node3D) -> Node:
	return player.find_child(hand_slot_name, true, false)


func _find_carry_visual_parent(player: Node3D, hand_slot: Node) -> Node:
	var carry_socket: Node = player.find_child(CARRY_SOCKET_NAME, true, false)
	if carry_socket:
		return carry_socket

	return hand_slot


func _setup_interact_area() -> void:
	var area: Area3D = Area3D.new()
	area.name = "InteractArea"
	area.position = interact_area_offset
	add_child(area)

	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = interact_area_size
	shape.shape = box
	area.add_child(shape)

	area.body_entered.connect(_on_interact_area_body_entered)
	area.body_exited.connect(_on_interact_area_body_exited)


func _setup_visuals() -> void:
	if show_slot_surface:
		var slot_mesh: BoxMesh = BoxMesh.new()
		slot_mesh.size = Vector3(0.7, 0.045, 0.7)

		var slot_material: StandardMaterial3D = StandardMaterial3D.new()
		slot_material.albedo_color = Color(0.2, 0.85, 1.0, 0.18)
		slot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		slot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var slot_surface: MeshInstance3D = MeshInstance3D.new()
		slot_surface.name = "SlotSurface"
		slot_surface.mesh = slot_mesh
		slot_surface.material_override = slot_material
		slot_surface.position = Vector3.UP * 0.035
		add_child(slot_surface)

	_interact_prompt = Sprite3D.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.texture = INTERACT_BUTTON_TEXTURE
	_interact_prompt.pixel_size = 0.0006
	_interact_prompt.position = prompt_offset
	_interact_prompt.set("billboard", 1)
	_interact_prompt.set("no_depth_test", true)
	add_child(_interact_prompt)

	_status_label = Label3D.new()
	_status_label.name = "StatusLabel"
	_status_label.position = label_offset
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.font_size = 28
	_status_label.modulate = Color(1.0, 0.96, 0.78, 1.0)
	_status_label.outline_modulate = Color(0.14, 0.05, 0.02, 1.0)
	_status_label.outline_size = 8
	add_child(_status_label)


func _update_visuals() -> void:
	if _interact_prompt:
		_interact_prompt.visible = _player_in_range != null and _can_interact(_player_in_range)
	if _status_label:
		_status_label.text = "1/1" if _stored_item != null else "0/1"


func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.name == "NamChef":
		_player_in_range = body
		_update_visuals()


func _on_interact_area_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_update_visuals()
