extends Node3D

const FOOD_ID_META := "food_id"
const SERVABLE_FOOD_META := "is_servable_food"
const CARRY_VISUAL_META := "carry_visual"
const TABLE_POSITION_META := "table_local_position"
const TABLE_ROTATION_META := "table_local_rotation"
const TABLE_SCALE_META := "table_local_scale"
const CARRY_SOCKET_NAME := "CarrySocket"
const DRINK_FOOD_ID := "nuoc_ngot"
const INTERACT_BUTTON_TEXTURE: Texture2D = preload("res://assets/UI/e_button.png")
const EFFECT_SAXI: Texture2D = preload("res://assets/UI/saxi_effect.png")

@export var xa_xi_scene: PackedScene
@export var xa_xi_local_position: Vector3 = Vector3(0.0, 0.1, 0.12)
@export var xa_xi_local_rotation: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var xa_xi_local_scale: Vector3 = Vector3(0.32, 0.32, 0.32)
@export var xa_xi_table_local_position: Vector3 = Vector3.ZERO
@export var xa_xi_table_local_rotation: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var xa_xi_table_local_scale: Vector3 = Vector3(0.32, 0.32, 0.32)
@export var interact_action: StringName = &"interact"
@export var prompt_offset: Vector3 = Vector3(0.0, 0.95, 0.0)
@export_range(0.2, 3.0, 0.05) var interact_distance: float = 1.1

var player_in_range: Node3D = null
var _interact_prompt: Sprite3D


func _ready() -> void:
	_setup_interact_prompt()


func _process(_delta: float) -> void:
	_update_interact_prompt()
	var player: Node3D = _get_player_in_interact_distance()
	if not player or not _can_take_drink(player):
		return

	if not GameManager.is_tutorial_locked and Input.is_action_just_pressed(interact_action):
		spawn_xa_xi_to_hand(player)


func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.name == "NamChef":
		player_in_range = body
		_update_interact_prompt()


func _on_interact_area_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		_update_interact_prompt()


func spawn_xa_xi_to_hand(player: Node3D) -> void:
	if not xa_xi_scene:
		print("Loi: Chua gan scene lon_xa_xi.tscn cho Tu Lanh.")
		return

	var hand_slot: Node = player.find_child("HandSlot", true, false)
	if not hand_slot:
		print("Loi: Khong tim thay HandSlot tren NamChef.")
		return

	if hand_slot.get_child_count() > 0:
		print("NamChef dang cam do, khong lay them nuoc.")
		return

	var holder: Node3D = Node3D.new()
	holder.name = "LonXaXiHolder"
	holder.set_meta(FOOD_ID_META, DRINK_FOOD_ID)
	holder.set_meta(SERVABLE_FOOD_META, true)
	holder.set_meta(TABLE_POSITION_META, xa_xi_table_local_position)
	holder.set_meta(TABLE_ROTATION_META, xa_xi_table_local_rotation)
	holder.set_meta(TABLE_SCALE_META, xa_xi_table_local_scale)
	hand_slot.add_child(holder)

	var lon_moi: Node = xa_xi_scene.instantiate()
	lon_moi.set_meta(FOOD_ID_META, DRINK_FOOD_ID)
	lon_moi.set_meta(SERVABLE_FOOD_META, true)
	lon_moi.set_meta(TABLE_POSITION_META, xa_xi_table_local_position)
	lon_moi.set_meta(TABLE_ROTATION_META, xa_xi_table_local_rotation)
	lon_moi.set_meta(TABLE_SCALE_META, xa_xi_table_local_scale)

	if lon_moi is Node3D:
		var lon_3d: Node3D = lon_moi as Node3D
		_apply_drink_carry_transform(lon_3d)
		_disable_food_visual_physics(lon_3d)
		_force_visual_visible(lon_3d)

	var carry_parent: Node = _find_carry_visual_parent(hand_slot)
	carry_parent.add_child(lon_moi)
	holder.set_meta(CARRY_VISUAL_META, lon_moi)
	EventBus.drink_taken.emit()
	EventBus.food_picked_up.emit(DRINK_FOOD_ID)
	print("Thanh cong! Lon xa xi da xuat hien tren tay NamChef.")
	_spawn_effect(EFFECT_SAXI, player)
	AudioManager.play_fridge()


func _spawn_effect(tex: Texture2D, player: Node3D) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = 0.0015
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	get_tree().current_scene.add_child(sprite)
	sprite.global_position = player.global_position + Vector3(0, 2.2, 0)
	
	var tween := create_tween()
	tween.tween_property(sprite, "global_position:y", sprite.global_position.y + 0.8, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(sprite.queue_free)


func _apply_drink_carry_transform(drink_visual: Node3D) -> void:
	drink_visual.position = xa_xi_local_position
	drink_visual.rotation_degrees = xa_xi_local_rotation
	drink_visual.scale = xa_xi_local_scale
	drink_visual.visible = true


func _force_visual_visible(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true

	for child in node.get_children():
		_force_visual_visible(child)


func _setup_interact_prompt() -> void:
	_interact_prompt = Sprite3D.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.texture = INTERACT_BUTTON_TEXTURE
	_interact_prompt.pixel_size = 0.0006
	_interact_prompt.position = prompt_offset
	_interact_prompt.visible = false
	_interact_prompt.set("billboard", 1)
	_interact_prompt.set("no_depth_test", true)
	add_child(_interact_prompt)


func _update_interact_prompt() -> void:
	if _interact_prompt:
		var player: Node3D = _get_player_in_interact_distance()
		_interact_prompt.visible = player != null and _can_take_drink(player)


func _can_take_drink(player: Node3D) -> bool:
	if not player:
		return false

	var hand_slot: Node = player.find_child("HandSlot", true, false)
	return hand_slot != null and hand_slot.get_child_count() == 0


func _get_player_in_interact_distance() -> Node3D:
	if not player_in_range or not is_instance_valid(player_in_range):
		return null

	var flat_delta: Vector3 = player_in_range.global_position - _get_interact_anchor_position()
	flat_delta.y = 0.0
	if flat_delta.length_squared() > interact_distance * interact_distance:
		return null

	return player_in_range


func _get_interact_anchor_position() -> Vector3:
	var interact_area: Node3D = get_node_or_null("InteractArea") as Node3D
	if interact_area:
		var collision_shape: Node3D = interact_area.get_node_or_null("CollisionShape3D") as Node3D
		if collision_shape:
			return collision_shape.global_position
		return interact_area.global_position

	return global_position


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


func _disable_food_visual_physics(food_visual: Node) -> void:
	if food_visual is CollisionShape3D:
		(food_visual as CollisionShape3D).disabled = true
	elif food_visual is CollisionPolygon3D:
		(food_visual as CollisionPolygon3D).disabled = true
	elif food_visual is Area3D:
		var food_area: Area3D = food_visual as Area3D
		food_area.monitoring = false
		food_area.monitorable = false

	for child in food_visual.get_children():
		_disable_food_visual_physics(child)
