extends Control
class_name HotNCircularMeter
## Medidor circular épico (recompra / carga). Não é ProgressBar.

var progress: float = 0.0
var track_color: Color = Color(0.08, 0.10, 0.16, 0.92)
var fill_color: Color = Color("3ecf7a")
var accent_color: Color = Color("f0c27a")
var line_width: float = 11.0
var pulse: float = 0.0

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if progress <= 0.001:
		return
	pulse = fmod(pulse + delta * 2.4, TAU)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := mini(size.x, size.y) * 0.40
	# Halo externo suave
	var halo_a := 0.10 + 0.12 * progress
	draw_circle(center, radius * 1.28, Color(fill_color.r, fill_color.g, fill_color.b, halo_a * 0.35))
	draw_arc(center, radius * 1.18, 0.0, TAU, 72, Color(accent_color.r, accent_color.g, accent_color.b, 0.22 + 0.25 * progress), 2.5, true)
	# Trilho interno escuro
	draw_arc(center, radius, 0.0, TAU, 80, track_color, line_width + 4.0, true)
	draw_arc(center, radius, 0.0, TAU, 80, Color(0.18, 0.22, 0.30, 0.85), line_width * 0.45, true)
	# Marcas runicas (12 ticks)
	for i in range(12):
		var ang := -PI * 0.5 + TAU * float(i) / 12.0
		var inner := center + Vector2(cos(ang), sin(ang)) * (radius - line_width * 0.55)
		var outer := center + Vector2(cos(ang), sin(ang)) * (radius + line_width * 0.55)
		var tick_col := Color(accent_color.r, accent_color.g, accent_color.b, 0.35 + 0.45 * progress)
		draw_line(inner, outer, tick_col, 2.0, true)
	if progress > 0.001:
		var start := -PI * 0.5
		var end := start + TAU * progress
		# Glow atrás do arco
		var glow := Color(fill_color.r, fill_color.g, fill_color.b, 0.35 + 0.25 * sin(pulse))
		draw_arc(center, radius, start, end, 96, glow, line_width + 8.0, true)
		# Arco principal
		draw_arc(center, radius, start, end, 96, fill_color, line_width, true)
		# Arco dourado fino por cima
		var tip_mix := fill_color.lerp(accent_color, 0.55)
		draw_arc(center, radius, start, end, 96, Color(tip_mix.r, tip_mix.g, tip_mix.b, 0.9), line_width * 0.35, true)
		# Núcleo pulsante
		var core_r := radius * (0.14 + 0.06 * progress)
		draw_circle(center, core_r * 1.55, Color(fill_color.r, fill_color.g, fill_color.b, 0.18 + 0.12 * sin(pulse)))
		draw_circle(center, core_r, fill_color)
		draw_circle(center, core_r * 0.45, Color(1, 1, 1, 0.75))
		# Ponta brilhante
		var tip := center + Vector2(cos(end), sin(end)) * radius
		draw_circle(tip, line_width * 0.55, Color(1, 1, 0.92, 0.95))
		draw_circle(tip, line_width * 0.95, Color(accent_color.r, accent_color.g, accent_color.b, 0.45))
