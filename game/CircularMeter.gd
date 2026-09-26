extends Control
class_name HotNCircularMeter

var progress: float = 0.0
var track_color: Color = Color(0.1, 0.14, 0.12, 0.9)
var fill_color: Color = Color("3ecf7a")
var line_width: float = 10.0

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := mini(size.x, size.y) * 0.42
	draw_arc(center, radius, 0.0, TAU, 64, track_color, line_width, true)
	if progress > 0.001:
		var start := -PI * 0.5
		draw_arc(center, radius, start, start + TAU * progress, 64, fill_color, line_width, true)
		draw_circle(center, radius * 0.12, fill_color)
