extends Node

## Đổi mùa theo chu kỳ và áp tham số môi trường vào GameManager.
## Mùa khô: khách thèm nước, đồ nguội nhanh. Mùa bão: ghe lắc mạnh, Nam dễ trượt.

enum Weather { MILD, DRY, STORM }

@export var phase_duration: float = 45.0   # giây mỗi mùa
@export var start_delay: float = 12.0
@export var enable_rain: bool = true

var _weather: int = Weather.MILD
var _timer: float = 0.0
var _phase_index: int = 0
const ORDER := [Weather.MILD, Weather.DRY, Weather.STORM]

var _light: DirectionalLight3D
var _light_base_energy: float = 1.35
var _boats: Array[Node] = []
var _boat_base_params: Array[Dictionary] = []
var _rain: GPUParticles3D
var _player: Node3D


func _ready() -> void:
	_timer = start_delay
	_cache_scene_refs()
	_apply_weather(Weather.MILD, true)


func _process(delta: float) -> void:
	if not GameManager.enable_weather:
		return
	_timer -= delta
	if _timer <= 0.0:
		_phase_index = (_phase_index + 1) % ORDER.size()
		_apply_weather(ORDER[_phase_index], false)
		_timer = phase_duration
	_update_rain_follow()


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
			slip = 0.3
			deviation = 0.35
			drink_bias = -0.15
			cooling = 1.1
			boat_mult = 2.2
			light_mult = 0.6
		_:
			pass

	GameManager.set_weather_params(weather, slip, deviation, drink_bias, cooling)
	EventBus.weather_changed.emit(weather)

	_apply_light(light_mult)
	_apply_boat_intensity(boat_mult)
	_apply_rain(weather == Weather.STORM)


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
	particles.amount = 600
	particles.lifetime = 1.2
	particles.local_coords = false

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
