extends Node3D

const FOOD_ID_META := "food_id"
const SERVABLE_FOOD_META := "is_servable_food"
const DRINK_FOOD_ID := "nuoc_ngot"

# Ô để kéo thả file lon_xa_xi.tscn trong bảng Inspector
@export var xa_xi_scene: PackedScene

var player_in_range: Node3D = null # Lưu trữ nhân vật khi đi vào vùng cảm biến
var hold_time: float = 0.0
var required_hold_time: float = 1.5 # Thời gian bắt buộc đè giữ phím E (1.5 giây)
var is_holding: bool = false

func _process(delta: float) -> void:
	# Nếu có nhân vật đứng gần VÀ người chơi đang đè phím E
	if player_in_range and Input.is_key_pressed(KEY_E):
		is_holding = true
		hold_time += delta
		
		# In ra màn hình Output tiến trình mở tủ lạnh để theo dõi
		print("Đang mở tủ lạnh... ", int((hold_time / required_hold_time) * 100), "%")
		
		# Khi đè đủ thời gian 1.5 giây
		if hold_time >= required_hold_time:
			spawn_xa_xi_to_hand()
			hold_time = 0.0 # Reset lại thời gian
			is_holding = false
	else:
		# Nếu người chơi buông phím E giữa chừng hoặc đi ra xa
		if is_holding:
			hold_time = 0.0
			is_holding = false
			print("Đã buông phím E, hủy mở tủ lạnh.")

# Khi NamChef bước vào vùng Area3D của tủ lạnh
func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.name == "NamChef":
		player_in_range = body
		print("NamChef đã đến gần tủ lạnh. Hãy ĐÈ GIỮ phím E để lấy nước!")

# Khi NamChef đi ra khỏi vùng Area3D của tủ lạnh
func _on_interact_area_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		hold_time = 0.0
		is_holding = false
		print("NamChef đã đi xa khỏi tủ lạnh.")

# Hàm xử lý việc tạo lon nước găm vào tay
func spawn_xa_xi_to_hand() -> void:
	if not xa_xi_scene:
		print("LỖI: Bạn chưa kéo file lon_xa_xi.tscn vào ô Xa Xi Scene của Tủ Lạnh!")
		return
		
	# Tự động tìm kiếm Node tên là "HandSlot" trên người NamChef
	var hand_slot: Node = player_in_range.find_child("HandSlot", true, false)
	
	if hand_slot:
		# Kiểm tra nếu trên tay NamChef ĐÃ CÓ lon nước rồi thì không tạo thêm nữa
		if hand_slot.get_child_count() > 0:
			print("NamChef đang cầm sẵn một lon nước rồi, không lấy thêm!")
			return
			
		# Lệnh thần thánh: Tạo ra một bản sao lon xá xị từ file gốc
		var lon_moi: Node = xa_xi_scene.instantiate()
		lon_moi.set_meta(FOOD_ID_META, DRINK_FOOD_ID)
		lon_moi.set_meta(SERVABLE_FOOD_META, true)
		
		# Gắn bản sao này làm con trực tiếp của HandSlot trên bàn tay
		hand_slot.add_child(lon_moi)
		print("Thành công! Lon xá xị đã xuất hiện trên tay NamChef.")
	else:
		print("LỖI: Không tìm thấy Node mang tên 'HandSlot' trong cấu trúc của NamChef!")
