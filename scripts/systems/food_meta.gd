extends RefCounted
class_name FoodMeta

## Nguồn hằng số metadata dùng chung cho toàn bộ hệ thống đồ ăn.
## Các script cũ vẫn dùng chuỗi thô; file này để code mới tham chiếu thống nhất.

const FOOD_ID := "food_id"
const FOOD_STAGE := "food_stage"
const SERVABLE_FOOD := "is_servable_food"
const CARRY_VISUAL := "carry_visual"
const CARRY_SOCKET_NAME := "CarrySocket"
const HAND_SLOT_NAME := "HandSlot"

const TABLE_POSITION := "table_local_position"
const TABLE_ROTATION := "table_local_rotation"
const TABLE_SCALE := "table_local_scale"

## Chất lượng do ngấm nước: 1.0 = khô/đầy đủ, giảm dần mỗi lần rớt sông.
const WATER_QUALITY := "water_quality"

const STAGE_EMPTY_BOWL := 0
const STAGE_BOWL_WITH_NOODLES := 1
const STAGE_FULL_BOWL := 2


## Lấy HandSlot trên người chơi.
static func find_hand_slot(player: Node) -> Node:
	if player == null:
		return null
	return player.find_child(HAND_SLOT_NAME, true, false)


## Lấy CarrySocket (điểm gắn vật phẩm cầm tay) trên người chơi.
static func find_carry_socket(player: Node) -> Node:
	if player == null:
		return null
	return player.find_child(CARRY_SOCKET_NAME, true, false)


## Đọc chất lượng nước của 1 vật phẩm (mặc định 1.0 nếu chưa từng ngấm nước).
static func get_water_quality(item: Node) -> float:
	if item == null or not item.has_meta(WATER_QUALITY):
		return 1.0
	return clampf(float(item.get_meta(WATER_QUALITY)), 0.0, 1.0)


## Vật phẩm này có phải món ăn giao được không.
static func is_servable(item: Node) -> bool:
	if item == null:
		return false
	if item.has_meta(SERVABLE_FOOD):
		return bool(item.get_meta(SERVABLE_FOOD))
	if item.has_meta(FOOD_STAGE):
		return int(item.get_meta(FOOD_STAGE)) == STAGE_FULL_BOWL
	return false
