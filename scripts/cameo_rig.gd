@tool
extends Node3D
class_name CameoRig

const ONG_CHU_SCENE := preload("res://assets/OngChu/OngChu_Typing.fbx")

## Dựng cụm cameo: bàn, laptop và nhân vật ông chú ngồi gõ máy. Khi gắn vào
## ghe đang di chuyển, tắt include_boat để cụm trở thành con trực tiếp của ghe đó.

@export_file("*.glb") var boat_path: String = "res://assets/GheNhua/Ghe.glb"
@export var include_boat: bool = true
@export var boat_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var boat_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var boat_yaw: float = 0.0

@export_file("*.glb") var table_path: String = "res://assets/Ban/Ban.glb"
@export var table_scale: Vector3 = Vector3(0.7, 0.7, 0.7)
@export var table_offset: Vector3 = Vector3(0.0, 0.35, 0.55)
@export var table_yaw: float = 0.0

# Model "Ông Chú Miền Tây" đã được Mixamo rig và có animation gõ máy.
@export_file("*.glb", "*.fbx") var char_path: String = "res://assets/OngChu/OngChu_Typing.fbx"
@export var char_offset: Vector3 = Vector3(0.0, 0.3, -0.1)
@export var char_yaw: float = 180.0
@export var typing_animation: StringName = &"mixamo_com"

@export_file("*.res") var idle_anim_path: String = "res://assets/Nam/animations/idle.res"
## Bỏ file anim NGỒI (Mixamo) vào đúng path này rồi mình phát tự động.
@export_file("*.res") var sit_anim_path: String = "res://assets/Nam/animations/sit.res"

## Vị trí laptop tính từ mặt bàn (đặt lên trên mặt bàn, trước mặt Nam).
@export var laptop_offset: Vector3 = Vector3(0.0, 0.42, 0.0)


func _ready() -> void:
	if include_boat:
		_spawn(boat_path, boat_offset, boat_scale, boat_yaw, "Boat")
	_spawn(table_path, table_offset, table_scale, table_yaw, "Table")
	_build_laptop()
	_build_character()


func _spawn(path: String, offset: Vector3, scl: Vector3, yaw: float, node_name: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = ONG_CHU_SCENE if path == char_path else load(path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	inst.name = node_name
	add_child(inst)
	inst.position = offset
	inst.scale = scl
	inst.rotation.y = deg_to_rad(yaw)
	return inst


func _build_character() -> void:
	var nam := _spawn(char_path, char_offset, Vector3.ONE, char_yaw, "Nam")
	if nam == null:
		return

	var anim := nam.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		anim = AnimationPlayer.new()
		nam.add_child(anim)

	var lib := AnimationLibrary.new()
	if ResourceLoader.exists(idle_anim_path):
		var a: Animation = load(idle_anim_path)
		if a != null:
			lib.add_animation("idle", a)
	# File Mixamo đang dùng có clip gõ là "mixamo_com". Ưu tiên tên export để
	# đổi animation sau này chỉ cần chọn lại trong Inspector.
	if anim.has_animation(typing_animation):
		var typing_clip := anim.get_animation(typing_animation)
		typing_clip.loop_mode = Animation.LOOP_LINEAR
		anim.play(typing_animation)
		return

	var play_name := "idle"
	# Fallback cho các file GLB khác có tên animation theo kiểu importer.
	for candidate in anim.get_animation_list():
		var candidate_text := String(candidate).to_lower()
		if candidate_text.contains("typing") or candidate_text.contains("sitting"):
			var candidate_clip := anim.get_animation(candidate)
			candidate_clip.loop_mode = Animation.LOOP_LINEAR
			anim.play(candidate)
			return
	if ResourceLoader.exists(sit_anim_path):
		var s: Animation = load(sit_anim_path)
		if s != null:
			lib.add_animation("sit", s)
			play_name = "sit"

	if anim.has_animation_library(""):
		anim.remove_animation_library("")
	anim.add_animation_library("", lib)
	if lib.has_animation(play_name):
		anim.play(play_name)
		anim.get_animation(play_name).loop_mode = Animation.LOOP_LINEAR


func _build_laptop() -> void:
	var root := Node3D.new()
	root.name = "Laptop"
	add_child(root)
	root.position = table_offset + laptop_offset

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.34, 0.02, 0.24)
	base.mesh = base_mesh
	base.material_override = _mat(Color(0.14, 0.14, 0.17))
	root.add_child(base)

	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.34, 0.22, 0.02)
	screen.mesh = screen_mesh
	screen.material_override = _mat(Color(0.1, 0.1, 0.12))
	screen.position = Vector3(0.0, 0.12, -0.11)
	screen.rotation.x = deg_to_rad(-15.0)
	root.add_child(screen)

	var glow := MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.3, 0.18, 0.008)
	glow.mesh = glow_mesh
	var gmat := _mat(Color(0.55, 0.8, 1.0))
	gmat.emission_enabled = true
	gmat.emission = Color(0.4, 0.7, 1.0)
	gmat.emission_energy_multiplier = 1.6
	glow.material_override = gmat
	glow.position = Vector3(0.0, 0.12, -0.098)
	glow.rotation.x = deg_to_rad(-15.0)
	root.add_child(glow)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
