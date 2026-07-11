extends SceneTree

func _init() -> void:
	var packed := load("res://assets/OngChu/OngChu_Typing.fbx") as PackedScene
	if packed == null:
		printerr("Unable to load OngChu_Typing.fbx")
		quit(1)
		return
	var root := packed.instantiate()
	for node in _walk(root):
		if node is Skeleton3D:
			var skeleton := node as Skeleton3D
			print("SKELETON=", skeleton.name, " bones=", skeleton.get_bone_count())
		if node is AnimationPlayer:
			var player := node as AnimationPlayer
			print("ANIMATION_PLAYER=", player.name)
			for animation_name in player.get_animation_list():
				var animation := player.get_animation(animation_name)
				print("ANIMATION=", animation_name, " length=", animation.length, " loop=", animation.loop_mode)
	root.queue_free()
	var ambient_boat_packed := load("res://assets/TauDeco/ghe02.glb") as PackedScene
	var ambient_boat := ambient_boat_packed.instantiate() as Node3D
	get_root().add_child.call_deferred(ambient_boat)
	await process_frame
	var bounds := AABB()
	var has_bounds := false
	for node in _walk(ambient_boat):
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh == null:
				continue
			var local_bounds: AABB = mesh_node.get_aabb()
			for x in [local_bounds.position.x, local_bounds.end.x]:
				for y in [local_bounds.position.y, local_bounds.end.y]:
					for z in [local_bounds.position.z, local_bounds.end.z]:
						var point := mesh_node.global_transform * Vector3(x, y, z)
						var point_bounds := AABB(point, Vector3.ZERO)
						bounds = point_bounds if not has_bounds else bounds.merge(point_bounds)
						has_bounds = true
	print("AMBIENT_BOAT_BOUNDS=", bounds)
	ambient_boat.queue_free()
	var cameo_script := load("res://scripts/cameo_rig.gd") as Script
	var cameo := cameo_script.new() as Node3D
	get_root().add_child.call_deferred(cameo)
	await process_frame
	var cameo_player := cameo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if cameo_player == null:
		printerr("CameoRig did not create an AnimationPlayer")
		quit(1)
		return
	print("CAMEO_PLAYING=", cameo_player.current_animation, " is_playing=", cameo_player.is_playing())
	if cameo_player.current_animation != &"mixamo_com" or not cameo_player.is_playing():
		printerr("CameoRig did not start the Mixamo typing animation")
		quit(1)
		return
	cameo.queue_free()
	var spawner_script := load("res://scripts/ambient_boat_spawner.gd") as Script
	var spawner := spawner_script.new() as Node3D
	var test_boat_scenes: Array[PackedScene] = [ambient_boat_packed]
	spawner.set("auto_spawn", false)
	spawner.set("boat_scenes", test_boat_scenes)
	spawner.set("typing_cameo_enabled", true)
	get_root().add_child.call_deferred(spawner)
	await process_frame
	var spawned_boat := spawner.call("spawn_boat") as Node3D
	await process_frame
	var passenger := spawned_boat.get_node_or_null("TypingCameo") as Node3D if spawned_boat != null else null
	var passenger_player := passenger.find_child("AnimationPlayer", true, false) as AnimationPlayer if passenger != null else null
	if passenger_player == null or passenger_player.current_animation != &"mixamo_com":
		printerr("Ambient boat did not load the typing cameo animation")
		quit(1)
		return
	if passenger.get_node_or_null("Boat") != null:
		printerr("Typing cameo incorrectly created its own boat")
		quit(1)
		return
	print("AMBIENT_CAMEO_PLAYING=", passenger_player.current_animation, " parent=", passenger.get_parent().name)
	spawner.queue_free()
	quit()

func _walk(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_walk(child))
	return result
