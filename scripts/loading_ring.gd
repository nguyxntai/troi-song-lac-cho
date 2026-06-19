extends Control
class_name LoadingRing

@export_range(32.0, 120.0, 1.0) var ring_size: float = 54.0
@export_range(3.0, 16.0, 1.0) var ring_width: float = 7.0
@export var back_color: Color = Color(1.0, 1.0, 1.0, 0.92)
@export var fill_color: Color = Color(0.25, 1.0, 0.1, 1.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.35)

var _progress := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * ring_size
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var smallest_side: float = minf(size.x, size.y)
	var radius: float = smallest_side * 0.5 - ring_width * 0.5
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * _progress

	draw_arc(center + Vector2(1.5, 2.0), radius, 0.0, TAU, 80, shadow_color, ring_width + 2.0, true)
	draw_arc(center, radius, 0.0, TAU, 80, back_color, ring_width, true)

	if _progress > 0.001:
		draw_arc(center, radius, start_angle, end_angle, 80, fill_color, ring_width, true)
