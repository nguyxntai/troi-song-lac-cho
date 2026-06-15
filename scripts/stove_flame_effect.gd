@tool
extends Node3D

@export var flame_radius: float = 0.018
@export var flame_height: float = 0.085
@export var light_energy: float = 0.45

var _light: OmniLight3D
var _time := 0.0

func _ready() -> void:
	_build_flame()
	set_process(true)

func _process(delta: float) -> void:
	if _light == null:
		return

	_time += delta
	var flicker := 0.85 + 0.15 * sin(_time * 18.0) + 0.07 * sin(_time * 43.0)
	_light.light_energy = light_energy * flicker

func _build_flame() -> void:
	for child in get_children():
		child.queue_free()

	_create_particles("BlueCore", Color(0.25, 0.55, 1.0, 0.65), Color(0.5, 0.9, 1.0, 1.0), flame_radius * 0.65, flame_height * 0.4, 0.025, 0.06, 28)
	_create_particles("OrangeFlame", Color(1.0, 0.38, 0.05, 0.7), Color(1.0, 0.82, 0.22, 1.0), flame_radius, flame_height, 0.04, 0.12, 42)

	_light = OmniLight3D.new()
	_light.name = "FlameLight"
	_light.light_color = Color(1.0, 0.48, 0.16)
	_light.light_energy = light_energy
	_light.omni_range = 0.65
	_light.omni_attenuation = 1.7
	_light.shadow_enabled = false
	add_child(_light)

func _create_particles(particle_name: String, albedo: Color, emission: Color, radius: float, height: float, velocity_min: float, velocity_max: float, amount: int) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = 2.2

	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 1.45, height)
	quad.material = material

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = radius
	process_material.direction = Vector3.UP
	process_material.spread = 10.0
	process_material.gravity = Vector3(0.0, 0.055, 0.0)
	process_material.initial_velocity_min = velocity_min
	process_material.initial_velocity_max = velocity_max
	process_material.angular_velocity_min = -35.0
	process_material.angular_velocity_max = 35.0
	process_material.scale_min = 0.45
	process_material.scale_max = 0.85

	var particles := GPUParticles3D.new()
	particles.name = particle_name
	particles.amount = amount
	particles.lifetime = 0.42
	particles.preprocess = 0.42
	particles.local_coords = true
	particles.position.y = height * 0.62
	particles.visibility_aabb = AABB(Vector3(-0.08, 0.0, -0.08), Vector3(0.16, 0.18, 0.16))
	particles.process_material = process_material
	particles.draw_pass_1 = quad
	particles.emitting = true
	add_child(particles)
