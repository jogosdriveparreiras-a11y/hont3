extends Control

var spec: Dictionary = {}
var _shield_tex: Texture2D = null

func setup(data: Dictionary) -> void:
	spec = data
	for child in get_children():
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width := size.x
	var height := size.y
	var dead := bool(spec.get("dead", false))
	_shield_tex = spec.get("shield_icon", null) as Texture2D
	if _shield_tex == null and ResourceLoader.exists("res://assets/ui/impact_shield_sword.png"):
		_shield_tex = load("res://assets/ui/impact_shield_sword.png")

	# Card title in semi-transparent black box (top band under signature)
	var title_bg := ColorRect.new()
	title_bg.color = Color(0, 0, 0, 0.62)
	title_bg.position = Vector2(width * 0.08, height * 0.18)
	title_bg.size = Vector2(width * 0.84, height * 0.075)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_bg)
	var title := Label.new()
	title.text = str(spec.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = title_bg.position
	title.size = title_bg.size
	title.add_theme_font_size_override("font_size", int(clampf(height * 0.048, 16, 36)))
	title.add_theme_color_override("font_color", Color("f4f1ea"))
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Character name centered under circular signature (top center stack)
	var chip := Label.new()
	chip.text = str(spec.get("chip", ""))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.position = Vector2(width * 0.22, height * 0.125)
	chip.size = Vector2(width * 0.56, height * 0.04)
	chip.add_theme_font_size_override("font_size", int(clampf(height * 0.026, 11, 20)))
	chip.add_theme_color_override("font_color", Color("f2efe8"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)

	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage:
		var stat_name := Label.new()
		stat_name.text = str(spec.get("stat_label", "ATAQUE"))
		stat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_name.position = Vector2(width * 0.04, height * 0.30)
		stat_name.size = Vector2(width * 0.28, height * 0.035)
		stat_name.add_theme_font_size_override("font_size", int(clampf(height * 0.022, 10, 16)))
		stat_name.add_theme_color_override("font_color", Color("f7f4ee"))
		stat_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stat_name)
		var stat_value := Label.new()
		stat_value.text = str(int(spec.get("stat_value", 0)))
		stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_value.position = Vector2(width * 0.04, height * 0.335)
		stat_value.size = Vector2(width * 0.28, height * 0.07)
		stat_value.add_theme_font_size_override("font_size", int(clampf(height * 0.055, 18, 40)))
		stat_value.add_theme_color_override("font_color", spec.get("stat_color", Color.WHITE))
		stat_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stat_value)

	# Effects / rules in semi-transparent black box
	var rules_bg := ColorRect.new()
	rules_bg.color = Color(0, 0, 0, 0.68)
	rules_bg.position = Vector2(width * 0.05, height * 0.60)
	rules_bg.size = Vector2(width * 0.90, height * 0.26)
	rules_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rules_bg)
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = false
	rules.scroll_active = false
	rules.position = Vector2(width * 0.07, height * 0.615)
	rules.size = Vector2(width * 0.86, height * 0.23)
	rules.add_theme_font_size_override("normal_font_size", int(clampf(height * 0.030, 12, 22)))
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

	if dead:
		modulate = Color(0.55, 0.55, 0.58, 0.78)
	else:
		modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	var border: Color = spec.get("border", Color("8a8f98")) as Color
	# Opaque background matching border type, slightly darker
	var bg := Color(border.r * 0.28, border.g * 0.28, border.b * 0.32, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	var art = spec.get("art", null)
	if art is Texture2D:
		var art_rect := Rect2(size.x * 0.06, size.y * 0.22, size.x * 0.88, size.y * 0.36)
		draw_texture_rect(art, art_rect, false)
		draw_rect(art_rect, Color(0, 0, 0, 0.18))
	# Character chip area dark plate behind name (MS-like)
	var chip_box := Rect2(size.x * 0.28, size.y * 0.118, size.x * 0.44, size.y * 0.05)
	draw_rect(chip_box, Color(0, 0, 0, 0.55))
	# Signature icon centered at top
	var icon_center := Vector2(size.x * 0.5, size.y * 0.075)
	var icon_radius := size.y * 0.055
	draw_circle(icon_center, icon_radius + 3.0, Color(0, 0, 0, 0.75))
	draw_circle(icon_center, icon_radius, Color("12141c"))
	draw_arc(icon_center, icon_radius, 0, TAU, 48, border, 4.0, true)
	var icon = spec.get("icon", null)
	if icon is Texture2D:
		var side := icon_radius * 1.35
		draw_texture_rect(icon, Rect2(icon_center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), border, false, 6.0)
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage:
		_draw_impact_icon(border)
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

func _draw_impact_icon(_border: Color) -> void:
	var origin := Vector2(size.x * 0.155, size.y * 0.28)
	var icon_size := Vector2(size.x * 0.18, size.y * 0.12)
	if _shield_tex != null:
		draw_texture_rect(_shield_tex, Rect2(origin - icon_size * 0.5, icon_size), false)
	else:
		# Fallback minimal silhouette if texture missing
		draw_circle(origin, icon_size.x * 0.35, Color(0.05, 0.05, 0.07, 0.9))
		draw_arc(origin, icon_size.x * 0.35, 0, TAU, 32, Color("ece7dc"), 2.5, true)

func _draw_pip(center: Vector2, tint: Color, glyph: String) -> void:
	var radius := size.y * 0.022
	draw_circle(center, radius, tint)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.35, radius * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(radius * 1.4), Color("111111"))
