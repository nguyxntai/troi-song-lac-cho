extends Node

## Điểm khởi động các hệ thống mở rộng cho 1 màn chơi.
## Chỉ cần thả 1 node mang script này vào scene gameplay — nó sẽ tự dựng phần còn lại.
## Giữ scene gọn: mọi hệ thống sinh ra bằng code, không cần kéo thả node thủ công.

const EconomyHudScript := preload("res://scripts/systems/economy_hud.gd")
const ShopPanelScript := preload("res://scripts/systems/shop_panel.gd")
const WeatherManagerScript := preload("res://scripts/systems/weather_manager.gd")
const EventManagerScript := preload("res://scripts/systems/event_manager.gd")
const ResultsScreenScript := preload("res://scripts/systems/results_screen.gd")
const TutorialManagerScript := preload("res://scripts/systems/tutorial_manager.gd")
const Chapter1DirectorScript := preload("res://scripts/chapter1_director.gd")
const IngameMusicButtonScript := preload("res://scripts/systems/ingame_music_button.gd")
const GameplayGuidelinesScript := preload("res://scripts/systems/gameplay_guidelines.gd")

@export var reset_money_on_start: bool = false
@export var spawn_economy_hud: bool = true
@export var spawn_shop: bool = true
@export var spawn_weather: bool = true
@export var spawn_events: bool = true
@export var water_surface_path: NodePath = NodePath("../River")


func _ready() -> void:
	# Nếu đang ở scene tutorial, tắt hệ thống thời tiết và sự kiện ngẫu nhiên.
	var _is_tutorial := _check_is_tutorial()
	if _is_tutorial:
		GameManager.enable_weather = false
		GameManager.enable_random_events = false
	else:
		# Tutorial tắt hai cờ này. Vì GameManager là autoload nên phải bật lại
		# rõ ràng khi chuyển sang chapter, nếu không mưa/sự kiện sẽ bị tắt cả game.
		GameManager.enable_weather = true
		GameManager.enable_random_events = true

	# Khởi tạo phiên chơi (giữ tiền & nâng cấp giữa các ngày).
	GameManager.start_session(reset_money_on_start)
	AudioManager.play_ingame_music_for_level()

	_register_water_surface()
	call_deferred("_spawn_systems")


func _register_water_surface() -> void:
	var surface: Node3D = get_node_or_null(water_surface_path) as Node3D
	if surface == null:
		surface = get_tree().current_scene.find_child("River", true, false) as Node3D
	if surface:
		WaterSystem.register_water_surface(surface)


func _spawn_systems() -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		host = self

	if spawn_economy_hud:
		_add_node(host, CanvasLayer.new(), EconomyHudScript, "EconomyHud")
	if not _check_is_tutorial():
		_add_node(host, CanvasLayer.new(), IngameMusicButtonScript, "IngameMusicButton")
	if spawn_shop:
		_add_node(host, CanvasLayer.new(), ShopPanelScript, "ShopPanel")
	_add_node(host, CanvasLayer.new(), ResultsScreenScript, "ResultsScreen")
	if spawn_weather and GameManager.enable_weather:
		_add_node(host, Node.new(), WeatherManagerScript, "WeatherManager")
	if spawn_events and GameManager.enable_random_events:
		_add_node(host, Node.new(), EventManagerScript, "EventManager")

	# Spawn TutorialManager cho scene tutorial.
	if _check_is_tutorial():
		if GameManager.should_show_new_player_guidelines:
			_add_node(host, CanvasLayer.new(), GameplayGuidelinesScript, "GameplayGuidelines")
		_add_node(host, Node.new(), TutorialManagerScript, "TutorialManager")
	# Chương 1 (không phải tutorial): HUD trả nợ. Ch2/Ch3 dùng director riêng.
	elif GameManager.chapter_index == 1:
		_add_node(host, CanvasLayer.new(), Chapter1DirectorScript, "Chapter1Director")


func _check_is_tutorial() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.get_file() == "tutorial.tscn"


## Gắn script vào 1 node có sẵn đúng base type (CanvasLayer cho UI, Node cho manager).
func _add_node(host: Node, node: Node, script: Script, node_name: String) -> Node:
	if host.find_child(node_name, false, false) != null:
		node.queue_free()
		return null
	node.set_script(script)
	node.name = node_name
	host.add_child(node)
	return node
