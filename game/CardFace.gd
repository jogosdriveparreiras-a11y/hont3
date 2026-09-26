extends Control

var spec: Dictionary = {}

func setup(data: Dictionary) -> void:
	spec = data
	for child in get_children():
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := size.x
	var height := size.y
	var title := Label.new()
	title.text = str(spec.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(width * 0.22, height * 0.03)
	title.size = Vector2(width * 0.74, height * 0.09)
	title.add_theme_font_size_override("font_size", int(clampf(height * 0.055, 18, 42)))
	title.add_theme_color_override("font_color", Color("f4f1ea"))
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var chip := Label.new()
	chip.text = str(spec.get("chip", ""))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.position = Vector2(width * 0.04, height * 0.145)
	chip.size = Vector2(width * 0.28, height * 0.045)
	chip.add_theme_font_size_override("font_size", int(clampf(height * 0.028, 12, 22)))
	chip.add_theme_color_override("font_color", Color("1a1c22"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	if not bool(spec.get("item", false)):
		var stat_name := Label.new()
		stat_name.text = str(spec.get("stat_label", "ATAQUE"))
		stat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_name.position = Vector2(width * 0.04, height * 0.30)
		stat_name.size = Vector2(width * 0.24, height * 0.04)
		stat_name.add_theme_font_size_override("font_size", int(clampf(height * 0.022, 10, 16)))
		stat_name.add_theme_color_override("font_color", Color("f7f4ee"))
		stat_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stat_name)
		var stat_value := Label.new()
		stat_value.text = str(int(spec.get("stat_value", 0)))
		stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_value.position = Vector2(width * 0.04, height * 0.34)
		stat_value.size = Vector2(width * 0.24, height * 0.07)
		stat_value.add_theme_font_size_override("font_size", int(clampf(height * 0.055, 18, 40)))
		stat_value.add_theme_color_override("font_color", spec.get("stat_color", Color.WHITE))
		stat_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stat_value)
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = false
	rules.scroll_active = false
	rules.position = Vector2(width * 0.06, height * 0.62)
	rules.size = Vector2(width * 0.88, height * 0.24)
	rules.add_theme_font_size_override("normal_font_size", int(clampf(height * 0.032, 13, 24)))
	rules.add_theme_color_override("default_color", Color("e7f6f8"))
	rules.text = str(spec.get("rules", ""))
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rules)
	var gain := int(spec.get("gain", 0))
	var cost := int(spec.get("cost", 0))
	if gain > 0 or cost > 0:
		var footer := Label.new()
		footer.text = "INICIATIVA"
		footer.position = Vector2(width * 0.06, height * 0.885)
		footer.size = Vector2(width * 0.4, height * 0.04)
		footer.add_theme_font_size_override("font_size", int(clampf(height * 0.022, 10, 16)))
		footer.add_theme_color_override("font_color", Color("d9d3c6"))
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(footer)
	queue_redraw()

func _draw() -> void:
	var art = spec.get("art", null)
	if art is Texture2D:
		draw_texture_rect(art, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1b1e27"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.28))
	var border: Color = spec.get("border", Color("8a8f98")) as Color
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), border, false, 7.0)
	var icon_center := Vector2(size.x * 0.12, size.y * 0.09)
	var icon_radius := size.y * 0.055
	draw_circle(icon_center, icon_radius, Color("12141c"))
	draw_arc(icon_center, icon_radius, 0, TAU, 48, border, 5.0, true)
	var icon = spec.get("icon", null)
	if icon is Texture2D:
		var side := icon_radius * 1.35
		draw_texture_rect(icon, Rect2(icon_center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	var chip_box := Rect2(size.x * 0.04, size.y * 0.145, size.x * 0.28, size.y * 0.045)
	draw_rect(chip_box, Color("f2efe8"))
	if not bool(spec.get("item", false)):
		_draw_shield(border)
	var gain := int(spec.get("gain", 0))
	var cost := int(spec.get("cost", 0))
	var x := size.x * 0.42
	var y := size.y * 0.90
	for _i in mini(gain, 8):
		_draw_pip(Vector2(x, y), Color("3ecf7a"), "+")
		x += size.x * 0.065
	for _i in mini(cost, 8):
		_draw_pip(Vector2(x, y), Color("d24b4b"), "-")
		x += size.x * 0.065

func _draw_shield(border: Color) -> void:
	var origin := Vector2(size.x * 0.155, size.y * 0.25)
	var width := size.x * 0.11
	var height := size.y * 0.16
	var points := PackedVector2Array([
		origin + Vector2(0, -height * 0.15),
		origin + Vector2(width, height * 0.15),
		origin + Vector2(width * 0.72, height),
		origin + Vector2(0, height * 1.28),
		origin + Vector2(-width * 0.72, height),
		origin + Vector2(-width, height * 0.15)
	])
	draw_colored_polygon(points, Color(0, 0, 0, 0.62))
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, border, 3.0, true)
	var tip := origin + Vector2(0, -height * 0.85)
	var pommel := origin + Vector2(0, height * 1.45)
	draw_line(tip, pommel, Color("ece7dc"), 4.0, true)
	draw_line(origin + Vector2(-width * 0.85, height * 0.05), origin + Vector2(width * 0.85, height * 0.05), Color("ece7dc"), 5.0, true)

func _draw_pip(center: Vector2, tint: Color, glyph: String) -> void:
	var radius := size.y * 0.022
	draw_circle(center, radius, tint)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.35, radius * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(radius * 1.4), Color("111111"))
