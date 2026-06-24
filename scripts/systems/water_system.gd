extends Node

## Autoload: quản lý cơ chế "Thủy Kích Đồ Ăn".
## nam_chef gọi WaterSystem.drop_food(...) khi làm rớt đồ; hệ thống tạo 1 DroppedFood
## rơi xuống sông, nổi lềnh bềnh, đếm ngược ngấm nước, cho phép vớt lại.

const DroppedFoodScript := preload("res://scripts/systems/dropped_food.gd")

## Cao độ mặt nước (mặc định gần với node River ~0.03). Bootstrap sẽ cập nhật lại.
var water_y: float = 0.08

## Số giây nổi trước khi chìm mất. Mái che (canopy) sẽ kéo dài thời gian này.
@export var float_lifetime: float = 7.0
@export var canopy_lifetime_bonus: float = 3.5

## Mức chất lượng mất đi mỗi lần ngấm nước (1.0 = mất hết).
@export var quality_loss_per_dip: float = 0.4

var _active_items: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Bootstrap gọi để khớp cao độ mặt nước với node River trong scene.
func register_water_surface(surface: Node3D) -> void:
	if surface and is_instance_valid(surface):
		water_y = surface.global_position.y + 0.05


## Thả 1 món đồ xuống sông.
## data: { food_id, food_stage, is_servable, water_quality, table_pos/rot/scale,
##         carry_pos/rot/scale } — mô tả để có thể tái tạo khi vớt.
func drop_food(visual: Node3D, data: Dictionary, spawn_global_pos: Vector3, throw_velocity: Vector3) -> Node:
	if not GameManager.enable_water_risk:
		# Nếu tắt cơ chế, huỷ visual để tránh rác.
		if visual and is_instance_valid(visual):
			visual.queue_free()
		return null

	var host: Node = get_tree().current_scene
	if host == null:
		if visual and is_instance_valid(visual):
			visual.queue_free()
		return null

	var lifetime: float = float_lifetime
	if GameManager.has_canopy():
		lifetime += canopy_lifetime_bonus

	var dropped: Node3D = Node3D.new()
	dropped.set_script(DroppedFoodScript)
	dropped.name = "DroppedFood_%s" % String(data.get("food_id", "item"))
	host.add_child(dropped)
	dropped.global_position = spawn_global_pos

	# Đưa visual vào trong DroppedFood.
	if visual and is_instance_valid(visual):
		var old_parent: Node = visual.get_parent()
		if old_parent:
			old_parent.remove_child(visual)
		dropped.add_child(visual)
		visual.position = Vector3.ZERO

	dropped.call("setup", visual, data, throw_velocity, water_y, lifetime, quality_loss_per_dip)
	_active_items.append(dropped)
	dropped.tree_exited.connect(_on_item_exited.bind(dropped), CONNECT_ONE_SHOT)

	EventBus.food_dropped_in_water.emit(String(data.get("food_id", "")))
	return dropped


func active_count() -> int:
	_active_items = _active_items.filter(func(n): return is_instance_valid(n))
	return _active_items.size()


func _on_item_exited(item: Node) -> void:
	_active_items.erase(item)
