extends Node3D

## Một món đồ ăn đã rớt xuống sông: rơi → nổi (đếm ngược ngấm nước) → chìm mất,
## hoặc được Nam vớt lại (chất lượng giảm). Tự dựng visual đếm ngược + prompt E.

const INTERACT_BUTTON_TEXTURE: Texture2D = preload("res://assets/UI/e_button.png")
const GRAVITY := 9.8
const DRIFT_SPEED := 0.18           # trôi theo dòng (trục X)
const BOB_AMPLITUDE := 0.04
const BOB_SPEED := 2.2
const RESCUE_DISTANCE := 1.2

enum State { FALLING, FLOATING, SINKING }

var _state: int = State.FALLING
var _velocity: Vector3 = Vector3.ZERO
var _water_y: float = 0.08
var _lifetime: float = 7.0
var _timer: float = 7.0
var _quality_loss: float = 0.4
var _data: Dictionary = {}
var _visual: Node3D
var _bob_phase: float = 0.0
var _player: Node3D

var _patience_root: Node3D
var _patience_fill: MeshInstance3D
var _patience_material: StandardMaterial3D
var _prompt: Sprite3D


func setup(visual: Node3D, data: Dictionary, throw_velocity: Vector3, water_y: float, lifetime: float, quality_loss: float) -> void:
	_visual = visual
	_data = data
	_velocity = throw_velocity
	_water_y = water_y
	_lifetime = maxf(lifetime, 0.5)
	_timer = _lifetime
	_quality_loss = quality_loss
	_bob_phase = randf() * TAU
	_build_decay_bar()
	_build_prompt()


func _process(delta: float) -> void:
	match _state:
		State.FLOATING:
			_process_floating(delta)
		State.SINKING:
			pass


func _physics_process(delta: float) -> void:
	if _state != State.FALLING:
		return

	_velocity.y -= GRAVITY * delta
	global_position += _velocity * delta
	if global_position.y <= _water_y:
		_enter_water()


func _enter_water() -> void:
	global_position.y = _water_y
	_state = State.FLOATING
	_velocity = Vector3.ZERO

	# Ngấm nước: giảm chất lượng.
	var quality: float = float(_data.get("water_quality", 1.0))
	quality = clampf(quality - _quality_loss, 0.0, 1.0)
	_data["water_quality"] = quality

	AudioManager.play_water_splash()
	_spawn_splash()
	Juice.shake_small()
	Juice.popup_text(global_position + Vector3.UP * 0.4, "TÙM!", Color(0.6, 0.85, 1.0), 40, 0.6)
	if _patience_root:
		_patience_root.visible = true


func _process_floating(delta: float) -> void:
	_bob_phase += delta * BOB_SPEED
	global_position.x += DRIFT_SPEED * delta
	if _visual and is_instance_valid(_visual):
		_visual.position.y = sin(_bob_phase) * BOB_AMPLITUDE
		_visual.rotate_y(delta * 0.6)

	_timer = maxf(_timer - delta, 0.0)
	_update_decay_bar()

	_update_rescue(delta)

	if _timer <= 0.0:
		_begin_sink()


func _update_rescue(_delta: float) -> void:
	_player = _get_player()
	var can_rescue: bool = _can_rescue()
	if _prompt:
		_prompt.visible = can_rescue
	if can_rescue and not GameManager.is_tutorial_locked and Input.is_action_just_pressed(&"interact"):
		_rescue()


func _can_rescue() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if global_position.distance_to(_player.global_position) > RESCUE_DISTANCE:
		return false
	var hand: Node = FoodMeta.find_hand_slot(_player)
	return hand != null and hand.get_child_count() == 0


func _rescue() -> void:
	var hand: Node = FoodMeta.find_hand_slot(_player)
	if hand == null:
		return

	# Tái tạo holder trong tay người chơi.
	var holder: Node3D = Node3D.new()
	holder.name = "RescuedFoodHolder"
	holder.set_meta(FoodMeta.FOOD_ID, String(_data.get("food_id", "")))
	holder.set_meta(FoodMeta.SERVABLE_FOOD, bool(_data.get("is_servable", true)))
	holder.set_meta(FoodMeta.FOOD_STAGE, int(_data.get("food_stage", FoodMeta.STAGE_FULL_BOWL)))
	holder.set_meta(FoodMeta.WATER_QUALITY, float(_data.get("water_quality", 0.6)))
	if _data.has("table_pos"):
		holder.set_meta(FoodMeta.TABLE_POSITION, _data["table_pos"])
	if _data.has("table_rot"):
		holder.set_meta(FoodMeta.TABLE_ROTATION, _data["table_rot"])
	if _data.has("table_scale"):
		holder.set_meta(FoodMeta.TABLE_SCALE, _data["table_scale"])
	hand.add_child(holder)

	# Đưa visual về CarrySocket với transform cầm tay ban đầu.
	if _visual and is_instance_valid(_visual):
		var socket: Node = FoodMeta.find_carry_socket(_player)
		var parent: Node = socket if socket else hand
		remove_child(_visual)
		parent.add_child(_visual)
		_visual.position = _data.get("carry_pos", Vector3.ZERO)
		_visual.rotation_degrees = _data.get("carry_rot", Vector3.ZERO)
		_visual.scale = _data.get("carry_scale", Vector3.ONE)
		holder.set_meta(FoodMeta.CARRY_VISUAL, _visual)
		_visual = null

	Juice.popup_text(global_position + Vector3.UP * 0.6, "VỚT ĐƯỢC!", Color(0.5, 1.0, 0.7), 42, 0.9)
	Juice.burst(global_position, Color(0.6, 0.9, 1.0), 12, 2.5)
	EventBus.food_rescued.emit(String(_data.get("food_id", "")), float(_data.get("water_quality", 0.6)))
	queue_free()


func _begin_sink() -> void:
	_state = State.SINKING
	if _prompt:
		_prompt.visible = false
	if _patience_root:
		_patience_root.visible = false
	Juice.popup_text(global_position + Vector3.UP * 0.4, "Trôi mất...", Color(0.9, 0.4, 0.4), 38, 0.7)
	EventBus.food_lost_in_water.emit(String(_data.get("food_id", "")))

	var tween := create_tween()
	tween.tween_property(self, "global_position:y", _water_y - 0.6, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _visual and is_instance_valid(_visual):
		tween.parallel().tween_property(_visual, "scale", Vector3.ZERO, 1.1)
	tween.tween_callback(queue_free)


func _get_player() -> Node3D:
	if _player and is_instance_valid(_player):
		return _player
	return get_tree().current_scene.find_child("NamChef", true, false) as Node3D


func _spawn_splash() -> void:
	# Vòng tròn tóe nước phẳng, phóng to & mờ dần.
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.05
	mesh.outer_radius = 0.12
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.rotation_degrees.x = 90.0
	get_tree().current_scene.add_child(ring)
	ring.global_position = Vector3(global_position.x, _water_y + 0.02, global_position.z)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(ring.queue_free)


func _build_decay_bar() -> void:
	_patience_root = Node3D.new()
	_patience_root.name = "DecayBar"
	_patience_root.position = Vector3(0.0, 0.5, 0.0)
	_patience_root.visible = false
	add_child(_patience_root)

	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(0.62, 0.07, 0.03)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.04, 0.04, 0.04, 0.8)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.material_override = bg_mat
	_patience_root.add_child(bg)

	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.58, 0.045, 0.035)
	_patience_material = StandardMaterial3D.new()
	_patience_material.albedo_color = Color.CYAN
	_patience_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_patience_fill = MeshInstance3D.new()
	_patience_fill.mesh = fill_mesh
	_patience_fill.material_override = _patience_material
	_patience_root.add_child(_patience_fill)


func _update_decay_bar() -> void:
	if not _patience_fill or not _patience_material:
		return
	var ratio: float = clampf(_timer / maxf(_lifetime, 0.01), 0.0, 1.0)
	_patience_fill.scale.x = ratio
	_patience_fill.position.x = -0.29 * (1.0 - ratio)
	_patience_material.albedo_color = Color.RED.lerp(Color.CYAN, ratio)


func _build_prompt() -> void:
	_prompt = Sprite3D.new()
	_prompt.name = "RescuePrompt"
	_prompt.texture = INTERACT_BUTTON_TEXTURE
	_prompt.pixel_size = 0.0007
	_prompt.position = Vector3(0.0, 0.75, 0.0)
	_prompt.visible = false
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	add_child(_prompt)
