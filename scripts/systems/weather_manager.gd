extends Node

## Thời tiết ngẫu nhiên, nhẹ nhàng: tạo không khí mà không biến thành hình phạt.

enum Weather { MILD, DRY, STORM }

@export var start_delay: float = 8.0
@export var weather_roll_min: float = 20.0
@export var weather_roll_max: float = 35.0
@export_range(0.0, 1.0, 0.01) var storm_chance: float = 0.42
@export_range(0.0, 1.0, 0.01) var dry_chance: float = 0.32
@export var storm_duration: float = 22.0
@export var storm_cooldown: float = 55.0
@export_range(1, 3, 1) var max_storms_per_day: int = 2
## Không để một ngày ngắn kết thúc mà người chơi chưa từng gặp cơ chế mưa.
@export var guaranteed_storm_after: float = 35.0
@export var enable_rain: bool = true

var _weather: int = Weather.MILD
var _timer: float = 0.0
var _storm_cooldown_left: float = 0.0
var _elapsed: float = 0.0
var _storm_count: int = 0
var _weather_slip_budget_configured: bool = false
var _rng := RandomNumberGenerator.new()

var _light: DirectionalLight3D
var _light_base_energy: float = 1.35
var _boats: Array[Node] = []
var _boat_base_params: Array[Dictionary] = []
var _rain: GPUParticles3D
var _player: Node3D


func _ready() -> void:
	_rng.randomize()
	_timer = start_delay
	GameManager.set_weather_slip_budget(0)
	_cache_scene_refs()
	_apply_weather(Weather.MILD, true)


func _process(delta: float) -> void:
	if not GameManager.enable_weather:
		return
	_elapsed += delta
	_storm_cooldown_left = maxf(_storm_cooldown_left - delta, 0.0)
	_timer -= delta
	if _timer <= 0.0:
		var next_weather := _pick_next_weather()
		_apply_weather(next_weather, false)
		_timer = storm_duration if next_weather == Weather.STORM else _rng.randf_range(weather_roll_min, weather_roll_max)
	_update_rain_follow()


func _pick_next_weather() -> int:
	# Không cho bão nối bão; giữa hai cơn luôn có một quãng thời tiết thường.
	if _weather == Weather.STORM:
		return Weather.DRY if _rng.randf() < 0.4 else Weather.MILD
	if _storm_count >= max_storms_per_day:
		return Weather.DRY if _rng.randf() < 0.35 else Weather.MILD
	# Thời điểm vẫn ngẫu nhiên, nhưng ngày ngắn luôn có ít nhất một lần mưa nhẹ.
	if _storm_count == 0 and _elapsed >= guaranteed_storm_after:
		return Weather.STORM
	if _storm_cooldown_left > 0.0:
		return Weather.DRY if _rng.randf() < 0.35 else Weather.MILD

	var roll := _rng.randf()
	if roll < storm_chance:
		return Weather.STORM
	if roll < storm_chance + dry_chance:
		return Weather.DRY
	return Weather.MILD


func _cache_scene_refs() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_light = scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if _light:
		_light_base_energy = _light.light_energy
	_player = scene.find_child("NamChef", true, false) as Node3D
	for boat_name in ["KitchenBoat", "GuestBoat"]:
		var boat: Node = scene.find_child(boat_name, true, false)
		if boat:
			_boats.append(boat)
			_boat_base_params.append({
				"float_speed": boat.get("float_speed"),
				"float_amplitude": boat.get("float_amplitude"),
				"rotation_amplitude": boat.get("rotation_amplitude"),
			})


func _apply_weather(weather: int, _is_initial: bool) -> void:
	_weather = weather
	var slip := 0.0
	var deviation := 0.0
	var drink_bias := 0.0
	var cooling := 1.0
	var boat_mult := 1.0
	var light_mult := 1.0

	match weather:
		Weather.DRY:
			drink_bias = 0.6
			cooling = 1.35
			light_mult = 1.15
		Weather.STORM:
			# Bão đủ vui để trượt/rớt vài lần, nhưng số lần rớt được GameManager giới hạn.
			slip = 0.13
			deviation = 0.14
			drink_bias = -0.15
			cooling = 1.05
			boat_mult = 1.38
			if GameManager.has_anti_slip():
				boat_mult = 1.23
			light_mult = 0.78
			_storm_cooldown_left = maxf(storm_cooldown, storm_duration)
			_storm_count += 1
			if not _weather_slip_budget_configured:
				GameManager.set_weather_slip_budget(1 if GameManager.has_anti_slip() else 3)
				_weather_slip_budget_configured = true
		_:
			pass

	GameManager.set_weather_params(weather, slip, deviation, drink_bias, cooling)
	EventBus.weather_changed.emit(weather)

	_apply_light(light_mult)
	_apply_boat_intensity(boat_mult)
	_apply_rain(weather == Weather.STORM)
	if weather == Weather.STORM and GameManager.has_anti_slip() and _player and is_instance_valid(_player):
		Juice.popup_text(_player.global_position + Vector3.UP * 2.1, "ỦNG CHỐNG TRƯỢT!", Color(0.45, 1.0, 0.76), 34, 0.9)


func _apply_light(mult: float) -> void:
	if _light and is_instance_valid(_light):
		var tween := create_tween()
		tween.tween_property(_light, "light_energy", _light_base_energy * mult, 1.5)


func _apply_boat_intensity(mult: float) -> void:
	for i in range(_boats.size()):
		var boat: Node = _boats[i]
		if not is_instance_valid(boat):
			continue
		var base: Dictionary = _boat_base_params[i]
		if base.get("float_amplitude") != null:
			boat.set("float_amplitude", float(base["float_amplitude"]) * mult)
		if base.get("rotation_amplitude") != null:
			boat.set("rotation_amplitude", float(base["rotation_amplitude"]) * mult)
		if base.get("float_speed") != null:
			boat.set("float_speed", float(base["float_speed"]) * (1.0 + (mult - 1.0) * 0.4))


func _apply_rain(active: bool) -> void:
	if not enable_rain:
		return
	if active:
		if _rain == null:
			_rain = _build_rain()
			get_tree().current_scene.add_child(_rain)
		_rain.emitting = true
	elif _rain and is_instance_valid(_rain):
		_rain.emitting = false


func _update_rain_follow() -> void:
	if _rain and is_instance_valid(_rain) and _player and is_instance_valid(_player):
		_rain.global_position = _player.global_position + Vector3(0, 6, 0)


func _build_rain() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "RainEffect"
	# Mật độ vừa đủ nhìn rõ nhưng nhẹ hơn mức cũ, nhất là trên máy tích hợp GPU.
	particles.amount = 360
	particles.lifetime = 1.2
	particles.local_coords = false
	# Hạt mưa theo Nam nên phải có bounds lớn; bounds mặc định dễ bị camera cull
	# khiến bão đã kích hoạt nhưng người chơi không thấy mưa.
	particles.visibility_aabb = AABB(Vector3(-10.0, -14.0, -10.0), Vector3(20.0, 24.0, 20.0))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(8, 0.2, 8)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 4.0
	mat.gravity = Vector3(0, -22, 0)
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 9.0
	mat.scale_min = 0.4
	mat.scale_max = 0.7
	particles.process_material = mat

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.22, 0.015)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.albedo_color = Color(0.6, 0.75, 0.95, 0.6)
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = draw_mat
	particles.draw_pass_1 = mesh
	return particles


func current_weather() -> int:
	return _weather
