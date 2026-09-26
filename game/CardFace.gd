extends Control

var spec: Dictionary = {}
var _shield_tex: Texture2D = null
const CORNER_RADIUS := 18.0

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

	# Signature group: top-LEFT — icon above name, left-aligned
	var icon_r := height * 0.048
	var sig_x := width * 0.06
	var sig_y := height * 0.045
	var chip := Label.new()
	chip.text = str(spec.get("chip", ""))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.position = Vector2(sig_x, sig_y + icon_r * 2.15)
	chip.size = Vector2(width * 0.55, height * 0.038)
	chip.add_theme_font_size_override("font_size", int(clampf(height * 0.026, 11, 20)))
	chip.add_theme_color_override("font_color", Color("f2efe8"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)

	# Card title in semi-transparent black box
	var title_bg := ColorRect.new()
	title_bg.color = Color(0, 0, 0, 0.62)
	title_bg.position = Vector2(width * 0.06, height * 0.175)
	title_bg.size = Vector2(width * 0.88, height * 0.075)
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

	# Damage number overlay sits in shield center (drawn in _draw; label on top)
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage:
		var dmg := Label.new()
		dmg.name = "DamageNumber"
		dmg.text = str(int(spec.get("stat_value", 0)))
		dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Shield face sits near center of the impact icon rect (see _draw_impact_icon)
		var icon_origin := Vector2(width * 0.18, height * 0.36)
		var icon_size := Vector2(width * 0.30, height * 0.22)
		# Shield center ≈ 50% x, ~42% y within the sword+shield graphic
		dmg.position = Vector2(icon_origin.x - icon_size.x * 0.22, icon_origin.y - icon_size.y * 0.18)
		dmg.size = Vector2(icon_size.x * 0.44, icon_size.y * 0.42)
		dmg.add_theme_font_size_override("font_size", int(clampf(height * 0.055, 18, 42)))
		dmg.add_theme_color_override("font_color", spec.get("stat_color", Color.WHITE))
		dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dmg)

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
	# Opaque type-tinted background under full-bleed art
	var bg := Color(border.r * 0.28, border.g * 0.28, border.b * 0.32, 1.0)
	_draw_rounded_rect(Rect2(Vector2.ZERO, size), bg, CORNER_RADIUS)
	var art = spec.get("art", null)
	if art is Texture2D:
		# Full-bleed art (slight inset keeps rounded type-tint corners clean)
		var inset := CORNER_RADIUS * 0.35
		_draw_texture_rounded(art, Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2)), CORNER_RADIUS)
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2)), Color(0, 0, 0, 0.12))
	# Signature icon top-LEFT
	var icon_center := Vector2(size.x * 0.06 + size.y * 0.048, size.y * 0.045 + size.y * 0.048)
	var icon_radius := size.y * 0.048
	draw_circle(icon_center, icon_radius + 3.0, Color(0, 0, 0, 0.75))
	draw_circle(icon_center, icon_radius, Color("12141c"))
	draw_arc(icon_center, icon_radius, 0, TAU, 48, border, 4.0, true)
	var icon = spec.get("icon", null)
	if icon is Texture2D:
		var side := icon_radius * 1.35
		draw_texture_rect(icon, Rect2(icon_center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	# Rounded border
	_draw_rounded_border(Rect2(Vector2(3, 3), size - Vector2(6, 6)), border, CORNER_RADIUS - 2.0, 6.0)
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
	var origin := Vector2(size.x * 0.18, size.y * 0.36)
	var icon_size := Vector2(size.x * 0.30, size.y * 0.22)
	if _shield_tex != null:
		draw_texture_rect(_shield_tex, Rect2(origin - icon_size * 0.5, icon_size), false)
	else:
		draw_circle(origin, icon_size.x * 0.28, Color(0.05, 0.05, 0.07, 0.9))
		draw_arc(origin, icon_size.x * 0.28, 0, TAU, 32, Color("ece7dc"), 2.5, true)

func _draw_pip(center: Vector2, tint: Color, glyph: String) -> void:
	var radius := size.y * 0.022
	draw_circle(center, radius, tint)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.35, radius * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, int(radius * 1.4), Color("111111"))

func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.draw(get_canvas_item(), rect)

func _draw_rounded_border(rect: Rect2, color: Color, radius: float, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(int(width))
	style.set_corner_radius_all(int(radius))
	style.draw(get_canvas_item(), rect)

func _draw_texture_rounded(tex: Texture2D, rect: Rect2, _radius: float) -> void:
	draw_texture_rect(tex, rect, false)
