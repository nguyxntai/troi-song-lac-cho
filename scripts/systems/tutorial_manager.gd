extends Node
class_name TutorialManager

## Quản lý toàn bộ luồng tutorial. Extend Node (không phải CanvasLayer) để có thể
## quản lý cả node 3D (pointer) lẫn node 2D (dialogue UI) đồng thời.

const DIALOGUE_TEXTURE: Texture2D = preload("res://assets/UI/TutorialDialogue.png")
const POINTING_TEXTURE: Texture2D = preload("res://assets/UI/Pointing.png")

# ── State machine ──────────────────────────────────────────────────────
enum Step {
	WELCOME_1,          # "Chào mừng con trai..."
	WELCOME_2,          # "Chúng ta sẽ làm việc..."
	WELCOME_3,          # "Oh, chúng ta đã có khách..."
	SPAWN_GUEST,        # Spawn 1 khách, hardcode bò kho
	EXPLAIN_MOVE,       # "Di chuyển bằng WASD..."
	WAIT_SEAT,          # Chờ khách ngồi
	EXPLAIN_ORDER_1,    # "Bây giờ thì vị khách đã ngồi..."
	EXPLAIN_ORDER_2,    # "Hãy chú ý vào các điểm này..."
	EXPLAIN_ORDER_3,    # "Con phải giao cho khách càng sớm..."
	EXPLAIN_SERVE,      # "Giờ thì lại lấy cái tô..."
	SERVE_GAMEPLAY,     # Chờ player phục vụ (coroutine)
	OUTRO_1,            # "Giỏi lắm..."
	OUTRO_2,            # "Ngoài bò kho ra..."
	OUTRO_3,            # "Giờ thì con đã hiểu..."
	OUTRO_4,            # "Ta giao lại ghe..."
	OUTRO_5,            # "Cố lên con trai..."
	FREE_PLAY,          # Mở khoá, đợi 5 khách nữa
}

const VOICE_PATHS := {
	Step.WELCOME_1: "res://assets/Voice/tutorial_01.mp3",
	Step.WELCOME_2: "res://assets/Voice/tutorial_02.mp3",
	Step.WELCOME_3: "res://assets/Voice/tutorial_03.mp3",
	Step.EXPLAIN_MOVE: "res://assets/Voice/tutorial_04.mp3",
	Step.EXPLAIN_ORDER_1: "res://assets/Voice/tutorial_05.mp3",
	Step.EXPLAIN_ORDER_2: "res://assets/Voice/tutorial_06.mp3",
	Step.EXPLAIN_SERVE: "res://assets/Voice/tutorial_08.mp3",
	Step.OUTRO_2: "res://assets/Voice/tutorial_10.mp3",
	Step.OUTRO_3: "res://assets/Voice/tutorial_11.mp3",
	Step.OUTRO_5: "res://assets/Voice/tutorial_13.mp3",
}

var _step: int = Step.WELCOME_1

# ── UI nodes ───────────────────────────────────────────────────────────
var _ui_layer: CanvasLayer          # CanvasLayer riêng cho dialogue
var _dialogue_panel: Control        # Panel toàn màn hình (dim + dialogue box)
var _dialogue_label: Label          # Nhãn chữ trong dialogue box

# ── 3D pointer ─────────────────────────────────────────────────────────
var _pointer: Sprite3D
var _pointer_tween: Tween

# ── References ─────────────────────────────────────────────────────────
var _spawner: Node                  # GuestSpawner
var _target_guest: Node             # Khách tutorial đầu tiên
var _is_dialogue_active: bool = false
var _post_tutorial_served: int = 0  # Đếm khách phục vụ sau tutorial
var _is_shutting_down: bool = false
var _serve_callback: Callable


# ══════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Đã vào gameplay ít nhất một lần: lần sau nút "Tiếp tục" sẽ vào thẳng
	# chapter đang lưu, không buộc chạy lại comic hay tutorial.
	SaveManager.set_game_started(true)
	# ── Tìm GuestSpawner và tạm dừng auto-spawn ──
	_spawner = get_tree().current_scene.find_child("GuestSpawner", true, false)
	if _spawner:
		_spawner.set("spawn_paused", true)

	# ── Dựng UI ──
	_build_ui()

	# ── Dựng pointer 3D (con của scene root, KHÔNG phải CanvasLayer) ──
	_pointer = Sprite3D.new()
	_pointer.name = "TutorialPointer"
	_pointer.texture = POINTING_TEXTURE
	_pointer.pixel_size = 0.003
	_pointer.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_pointer.no_depth_test = true
	_pointer.render_priority = 100
	_pointer.rotation_degrees = Vector3(0, 0, -135)
	_pointer.visible = false
	get_tree().current_scene.add_child(_pointer)

	# ── Kết nối signal ──
	EventBus.guest_seated.connect(_on_guest_seated)
	EventBus.guest_served.connect(_on_guest_served)

	# ── Bắt đầu ──
	GameManager.is_tutorial_locked = true
	_play_step()


func _process(_delta: float) -> void:
	match _step:
		Step.WAIT_SEAT:
			# Cập nhật vị trí pointer theo khách (khách đang di chuyển)
			if is_instance_valid(_target_guest) and _pointer.visible:
				_update_pointer_position(_target_guest.global_position + Vector3.UP * 2.0)


func _exit_tree() -> void:
	_is_shutting_down = true
	if _serve_callback.is_valid() and EventBus.guest_served.is_connected(_serve_callback):
		EventBus.guest_served.disconnect(_serve_callback)
	_serve_callback = Callable()
	# Dọn dẹp pointer nếu còn tồn tại
	if is_instance_valid(_pointer) and _pointer.is_inside_tree():
		_pointer.queue_free()


func _input(event: InputEvent) -> void:
	if not _is_dialogue_active:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_next_step()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_next_step()


# ══════════════════════════════════════════════════════════════════════
#  STATE MACHINE
# ══════════════════════════════════════════════════════════════════════

func _next_step() -> void:
	_step += 1
	_play_step()


func _play_step() -> void:
	_hide_pointer()
	GameManager.is_tutorial_locked = true

	match _step:
		# ── State 0: Welcome ──────────────────────────────────────
		Step.WELCOME_1:
			_show_dialogue("Chào mừng con trai đến với ghe bán hàng!")
		Step.WELCOME_2:
			_show_dialogue("Chúng ta sẽ làm việc ở trên này, bán bò kho và các thực phẩm đặc sản miền Tây sông nước cho các thực khách")
		Step.WELCOME_3:
			_show_dialogue("Oh, chúng ta đã có khách đầu tiên của quán")

		# ── State 1: Spawn guest ──────────────────────────────────
		Step.SPAWN_GUEST:
			_hide_dialogue()
			_spawn_tutorial_guest()
			# Chuyển ngay sang EXPLAIN_MOVE
			_step = Step.EXPLAIN_MOVE
			_play_step()

		# ── State 2: Movement & Seating ───────────────────────────
		Step.EXPLAIN_MOVE:
			_show_dialogue("Di chuyển bằng WASD, Space là nhảy và tương tác nút E hiển thị để đưa vị khách ấy vào bàn ngồi")
		Step.WAIT_SEAT:
			_hide_dialogue()
			GameManager.is_tutorial_locked = false
			if is_instance_valid(_target_guest):
				_show_pointer(_target_guest.global_position + Vector3.UP * 2.0)

		# ── State 3: The Order & Waiting Bar ──────────────────────
		Step.EXPLAIN_ORDER_1:
			_show_dialogue("Bây giờ thì vị khách đã ngồi vào bàn và đang order món bò kho của chúng ta")
		Step.EXPLAIN_ORDER_2:
			_show_dialogue("Hãy chú ý vào các điểm này con trai")
		Step.EXPLAIN_ORDER_3:
			# Show pointer at patience bar WHILE showing dialogue
			if is_instance_valid(_target_guest):
				_show_pointer(_target_guest.global_position + Vector3.UP * 2.5)
			_show_dialogue("Con phải giao cho khách càng sớm càng tốt để khách hài lòng, đánh giá cao quán ta và tips thêm tiền")

		# ── State 4: Serving Gameplay ─────────────────────────────
		Step.EXPLAIN_SERVE:
			_hide_pointer()
			_show_dialogue("Giờ thì lại lấy cái tô và múc bò kho vào. Sau đó giao cho khách đi!")
		Step.SERVE_GAMEPLAY:
			_serve_sequence()

		# ── State 5: Conclusion ───────────────────────────────────
		Step.OUTRO_1:
			_hide_pointer()
			_show_dialogue("Giỏi lắm đúng là con trai của ta")
		Step.OUTRO_2:
			_show_dialogue("Ngoài bò kho ra thì còn cả nước ngọt trong tủ lạnh cho khách")
		Step.OUTRO_3:
			_show_dialogue("Giờ thì con đã hiểu được cách bán hàng")
		Step.OUTRO_4:
			_show_dialogue("Ta giao lại ghe và bí kiếp cho con. Phần còn lại là ở con đó")
		Step.OUTRO_5:
			_show_dialogue("Cố lên con trai của ta!")

		# ── Task 4: Free-Play ─────────────────────────────────────
		Step.FREE_PLAY:
			_hide_dialogue()
			GameManager.is_tutorial_locked = false
			EventBus.tutorial_dialogue_completed.emit()
			# Đánh dấu đã hoàn thành tutorial
			SaveManager.set_tutorial_completed(true)
			# Bật lại spawner
			if _spawner:
				_spawner.set("spawn_paused", false)


# ══════════════════════════════════════════════════════════════════════
#  SIGNAL HANDLERS
# ══════════════════════════════════════════════════════════════════════

func _on_guest_seated(guest: Node, _table: Node) -> void:
	if _step == Step.WAIT_SEAT and guest == _target_guest:
		_hide_pointer()
		_step = Step.EXPLAIN_ORDER_1
		_play_step()


func _on_guest_served(_stars: int, _tip: int, _food_id: String) -> void:
	if _step == Step.FREE_PLAY:
		_post_tutorial_served += 1
		# Win condition: 5 khách nữa sau tutorial
		# DayManager sẽ tự xử lý win khi đếm đủ required_customers


# ══════════════════════════════════════════════════════════════════════
#  SERVING SEQUENCE (COROUTINE)
# ══════════════════════════════════════════════════════════════════════

func _serve_sequence() -> void:
	if _is_shutting_down or not is_inside_tree():
		return
	_hide_dialogue()
	GameManager.is_tutorial_locked = false
	var bowl_stack := _find_scene_child("ToRongStation")
	var pot := _find_scene_child("NoiBoKhoStation")
	var current_target_node: Node = null

	var served := [false]
	_serve_callback = func(_stars: int, _tip: int, _food_id: String):
		if not _is_shutting_down:
			served[0] = true
	EventBus.guest_served.connect(_serve_callback)

	# Lặp chờ cho đến khi khách được phục vụ (Fail-safe: tự động back về bước trước nếu player vứt đồ)
	while not served[0] and not _is_shutting_down and is_inside_tree():
		var new_target: Node = null
		if _player_has_food_id("bo_kho"):
			# Đã múc bò kho -> Trỏ vào khách
			if is_instance_valid(_target_guest):
				new_target = _target_guest
		elif _player_has_food_id("") or _player_has_food_id("empty_bowl"):
			# Đang cầm tô không -> Trỏ vào nồi bò kho
			if is_instance_valid(pot):
				new_target = pot
		else:
			# Tay không (có thể đã vứt đồ) -> Trỏ vào lấy tô
			if is_instance_valid(bowl_stack):
				new_target = bowl_stack
		
		# Explicit pointer state management to avoid flickering
		if new_target != current_target_node:
			current_target_node = new_target
			_hide_pointer()
			var tree := get_tree()
			if tree == null:
				break
			await tree.create_timer(0.2).timeout
			if _is_shutting_down or not is_inside_tree():
				break
			if is_instance_valid(current_target_node) and not served[0]:
				_show_pointer(current_target_node.global_position + Vector3.UP * 2.0)
		else:
			# Cập nhật vị trí liên tục (cho khách di chuyển)
			if is_instance_valid(current_target_node) and _pointer.visible:
				_update_pointer_position(current_target_node.global_position + Vector3.UP * 2.0)
		
		var frame_tree := get_tree()
		if frame_tree == null:
			break
		await frame_tree.process_frame

	if _serve_callback.is_valid() and EventBus.guest_served.is_connected(_serve_callback):
		EventBus.guest_served.disconnect(_serve_callback)
	_serve_callback = Callable()
	if _is_shutting_down or not is_inside_tree():
		return
	_hide_pointer()

	# Đợi khách ăn xong và rời đi hoàn toàn (tree_exited)
	if is_instance_valid(_target_guest):
		await _target_guest.tree_exited
		if _is_shutting_down or not is_inside_tree():
			return

	_step = Step.OUTRO_1
	_play_step()


# ══════════════════════════════════════════════════════════════════════
#  SPAWNER CONTROL
# ══════════════════════════════════════════════════════════════════════

func _spawn_tutorial_guest() -> void:
	if not _spawner or not _spawner.has_method("spawn_random_guest"):
		push_warning("TutorialManager: Không tìm thấy GuestSpawner!")
		return

	_target_guest = _spawner.call("spawn_random_guest")
	if _target_guest and _target_guest.has_method("setup"):
		# Force bò kho cho khách đầu tiên
		_target_guest.set("forced_order_id", "bo_kho")
		_target_guest.set("is_tutorial_first_guest", true)


# ══════════════════════════════════════════════════════════════════════
#  UI - DIALOGUE
# ══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# CanvasLayer riêng, z-index cao để luôn trên cùng
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "TutorialUI"
	_ui_layer.layer = 100
	add_child(_ui_layer)

	# Panel toàn màn hình (chứa dim background + dialogue box)
	_dialogue_panel = Control.new()
	_dialogue_panel.name = "DialoguePanel"
	_dialogue_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_layer.add_child(_dialogue_panel)

	# Dim background
	var dim_bg := ColorRect.new()
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = Color(0, 0, 0, 0.35)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_panel.add_child(dim_bg)

	# Dialogue box (anchored bottom-right)
	var tex_rect := TextureRect.new()
	tex_rect.name = "DialogueBox"
	tex_rect.texture = DIALOGUE_TEXTURE
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor bottom-right
	tex_rect.anchor_left = 1.0
	tex_rect.anchor_top = 1.0
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0

	# Size and offset (box grows left and up from bottom-right corner)
	var box_size := Vector2(750, 320)
	var margin := Vector2(20, -40)
	tex_rect.offset_left = -box_size.x - margin.x
	tex_rect.offset_top = -box_size.y - margin.y
	tex_rect.offset_right = -margin.x
	tex_rect.offset_bottom = -margin.y
	_dialogue_panel.add_child(tex_rect)

	# Label cho text dialogue
	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueText"
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.clip_text = true
	_dialogue_label.add_theme_font_size_override("font_size", 16)
	_dialogue_label.add_theme_color_override("font_color", Color(0.35, 0.18, 0.05, 1.0))
	_dialogue_label.add_theme_color_override("font_outline_color", Color(0.95, 0.85, 0.65, 1.0))
	_dialogue_label.add_theme_constant_override("outline_size", 3)
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Fill the dialogue box with padding (adjusted for massive transparent borders in the texture)
	_dialogue_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialogue_label.offset_left = 85
	_dialogue_label.offset_right = -170
	_dialogue_label.offset_top = 150
	_dialogue_label.offset_bottom = -90
	tex_rect.add_child(_dialogue_label)

	# Nhãn hướng dẫn nhỏ
	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Nhấn chuột trái hoặc Space để tiếp tục..."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.55, 0.38, 0.18, 0.9))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.offset_left = -400
	hint_label.offset_right = -170
	hint_label.offset_top = -120
	hint_label.offset_bottom = -90
	tex_rect.add_child(hint_label)

	_dialogue_panel.visible = false


func _show_dialogue(text: String) -> void:
	_is_dialogue_active = true
	_dialogue_label.text = text
	_dialogue_panel.visible = true
	AudioManager.play_voice_file(String(VOICE_PATHS.get(_step, "")), -1.5)


func _hide_dialogue() -> void:
	_is_dialogue_active = false
	_dialogue_panel.visible = false
	AudioManager.stop_voice()


# ══════════════════════════════════════════════════════════════════════
#  3D POINTER
# ══════════════════════════════════════════════════════════════════════

func _show_pointer(pos: Vector3) -> void:
	if not is_instance_valid(_pointer):
		return
	_pointer.global_position = pos
	_pointer.visible = true

	if _pointer_tween and _pointer_tween.is_valid():
		_pointer_tween.kill()
	_pointer_tween = create_tween().set_loops()
	_pointer_tween.tween_property(_pointer, "global_position:y", pos.y + 0.35, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pointer_tween.tween_property(_pointer, "global_position:y", pos.y, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_pointer_position(pos: Vector3) -> void:
	if not is_instance_valid(_pointer) or not _pointer.visible:
		return
	# Chỉ cập nhật X/Z, Y giữ nguyên do tween
	_pointer.global_position.x = pos.x
	_pointer.global_position.z = pos.z


func _hide_pointer() -> void:
	if not is_instance_valid(_pointer):
		return
	_pointer.visible = false
	if _pointer_tween and _pointer_tween.is_valid():
		_pointer_tween.kill()


# ══════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════

func _player_has_food_id(id: String) -> bool:
	var scene := _get_current_scene()
	if scene == null:
		return false
	var player := scene.find_child("NamChef", true, false)
	if not player:
		return false
	var hand_slot := player.find_child("HandSlot", true, false)
	if not hand_slot or hand_slot.get_child_count() == 0:
		return false
	var item := hand_slot.get_child(0)
	var item_id: String = item.get_meta("food_id") if item.has_meta("food_id") else ""
	return item_id == id


func _find_scene_child(pattern: String) -> Node:
	var scene := _get_current_scene()
	return scene.find_child(pattern, true, false) if scene != null else null


func _get_current_scene() -> Node:
	if _is_shutting_down or not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene
