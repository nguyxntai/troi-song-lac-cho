@tool
extends MainLoop

const ANIMATIONS := [
	"res://animations/sit&eat.res",
	"res://animations/walk_with_bowl.res",
]

func _initialize() -> void:
	var log := FileAccess.open("res://_codex_fix_animation_paths.log", FileAccess.WRITE)
	if log != null:
		log.store_line("started")
	var failed := false
	for animation_path in ANIMATIONS:
		var animation: Animation = load(animation_path)
		if animation == null:
			push_error("Cannot load %s" % animation_path)
			if log != null:
				log.store_line("cannot load " + animation_path)
			failed = true
			continue

		var changed := false
		for track_index in animation.get_track_count():
			var track_path := str(animation.track_get_path(track_index))
			if track_path.begins_with("Skeleton3D:"):
				animation.track_set_path(track_index, NodePath("Armature/" + track_path))
				changed = true

		if changed:
			var err := ResourceSaver.save(animation, animation_path)
			if err != OK:
				push_error("Cannot save %s: %s" % [animation_path, error_string(err)])
				if log != null:
					log.store_line("cannot save " + animation_path)
				failed = true
			else:
				print("Updated ", animation_path)
				if log != null:
					log.store_line("updated " + animation_path)
		else:
			print("No path changes needed for ", animation_path)
			if log != null:
				log.store_line("unchanged " + animation_path)

	return
