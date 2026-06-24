extends Node

## Autoload: "game feel". Cung cấp rung màn hình (trauma-based), hit-stop,
## chữ bay 3D, và hạt bắn ăn mừng. Camera đọc get_shake_offset() mỗi khung hình.

const MAX_SHAKE_OFFSET := 0.35
const TRAUMA_DECAY := 1.8

var _trauma: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _hitstop_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
		var amount: float = _trauma * _trauma * MAX_SHAKE_OFFSET
		_shake_offset = Vector3(
			_rng.randf_range(-amount, amount),
			_rng.randf_range(-amount, amount),
			_rng.randf_range(-amount, amount) * 0.4
		)
	else:
		_shake_offset = Vector3.ZERO


# ---------- Rung màn hình ----------
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func shake_small() -> void:
	add_trauma(0.25)


func shake_big() -> void:
	add_trauma(0.55)


func get_shake_offset() -> Vector3:
	return _shake_offset


# ---------- Hit-stop (đóng băng cực ngắn cho cảm giác "chắc tay") ----------
func hitstop(duration: float = 0.06, scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = scale
	# Đếm theo thời gian thực, bỏ qua time_scale.
	var timer := get_tree().create_timer(duration, true, false, true)
	await timer.timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


# ---------- Chữ bay 3D ----------
func popup_text(world_pos: Vector3, text: String, color: Color = Color.WHITE, size: int = 48, rise: float = 1.0) -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.05, 0.0, 1.0)
	label.outline_size = maxi(int(size / 6), 4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0016
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(label)
	label.global_position = world_pos

	label.scale = Vector3.ZERO
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.parallel().tween_property(label, "global_position:y", world_pos.y + rise, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


# ---------- Hạt bắn ăn mừng ----------
func burst(world_pos: Vector3, color: Color = Color(1.0, 0.85, 0.3), count: int = 18, speed: float = 3.0) -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var particles := GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.gravity = Vector3(0, -6.0, 0)
	mat.initial_velocity_min = speed * 0.6
	mat.initial_velocity_max = speed
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	mat.color = color
	particles.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = color
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = draw_mat
	particles.draw_pass_1 = mesh
	particles.process_mode = Node.PROCESS_MODE_ALWAYS

	host.add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true
	# Tự dọn sau khi bắn xong.
	var timer := get_tree().create_timer(1.5, true, false, true)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free())


## Pháo giấy ăn mừng trên đầu người chơi / cả màn (dùng cho thắng / kỷ lục).
func confetti(world_pos: Vector3, count: int = 80) -> void:
	burst(world_pos, Color(1.0, 0.3, 0.4), int(count / 3), 4.5)
	burst(world_pos, Color(0.3, 0.7, 1.0), int(count / 3), 4.5)
	burst(world_pos, Color(1.0, 0.85, 0.3), int(count / 3), 4.5)
