extends Node3D

const FOOD_ID_META := "food_id"
const SERVABLE_FOOD_META := "is_servable_food"
const CARRY_VISUAL_META := "carry_visual"
const CARRY_SOCKET_NAME := "CarrySocket"
const DRINK_FOOD_ID := "nuoc_ngot"

@export var xa_xi_scene: PackedScene
@export var xa_xi_local_position: Vector3 = Vector3.ZERO
@export var xa_xi_local_rotation: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var xa_xi_local_scale: Vector3 = Vector3(0.08, 0.08, 0.08)

var player_in_range: Node3D = null
var hold_time: float = 0.0
var required_hold_time: float = 1.5
var is_holding: bool = false


func _process(delta: float) -> void:
	if player_in_range and Input.is_key_pressed(KEY_E):
		is_holding = true
		hold_time += delta
		print("Dang mo tu lanh... ", int((hold_time / required_hold_time) * 100), "%")

		if hold_time >= required_hold_time:
			spawn_xa_xi_to_hand()
			hold_time = 0.0
			is_holding = false
	else:
		if is_holding:
			hold_time = 0.0
			is_holding = false
			print("Da buong phim E, huy mo tu lanh.")


func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.name == "NamChef":
		player_in_range = body
		print("NamChef da den gan tu lanh. Hay giu phim E de lay nuoc!")


func _on_interact_area_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		hold_time = 0.0
		is_holding = false
		print("NamChef da di xa khoi tu lanh.")


func spawn_xa_xi_to_hand() -> void:
	if not xa_xi_scene:
		print("Loi: Chua gan scene lon_xa_xi.tscn cho Tu Lanh.")
		return

	var hand_slot: Node = player_in_range.find_child("HandSlot", true, false)
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
	hand_slot.add_child(holder)

	var lon_moi: Node = xa_xi_scene.instantiate()
	lon_moi.set_meta(FOOD_ID_META, DRINK_FOOD_ID)
	lon_moi.set_meta(SERVABLE_FOOD_META, true)

	if lon_moi is Node3D:
		var lon_3d: Node3D = lon_moi as Node3D
		lon_3d.position = xa_xi_local_position
		lon_3d.rotation_degrees = xa_xi_local_rotation
		lon_3d.scale = xa_xi_local_scale
		_disable_food_visual_physics(lon_3d)

	var carry_parent: Node = _find_carry_visual_parent(hand_slot)
	carry_parent.add_child(lon_moi)
	holder.set_meta(CARRY_VISUAL_META, lon_moi)
	print("Thanh cong! Lon xa xi da xuat hien tren tay NamChef.")


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
