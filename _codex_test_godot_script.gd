@tool
extends MainLoop

func _initialize() -> void:
	var file := FileAccess.open("res://_codex_test_godot_script.log", FileAccess.WRITE)
	file.store_line("ok")
