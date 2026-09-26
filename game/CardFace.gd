extends Control

var spec: Dictionary = {}
var _shield_tex: Texture2D = null
const CORNER_RADIUS := 18.0
const BOX_ALPHA := 125.0 / 255.0

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

	# Signature group: top-LEFT — icon with CARD NAME beside it in leftover space
	var icon_r := height * 0.048
	var sig_x := width * 0.06
	var sig_y := height * 0.045
	var icon_diameter := icon_r * 2.0
	var title := Label.new()
	title.text = str(spec.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(sig_x + icon_diameter + width * 0.025, sig_y)
	title.size = Vector2(width - (sig_x + icon_diameter + width * 0.06), icon_diameter)
	title.add_theme_font_size_override("font_size", int(clampf(height * 0.042, 14, 32)))
	title.add_theme_color_override("font_color", Color("f4f1ea"))
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Character / owner chip under the signature icon
	var chip := Label.new()
	chip.text = str(spec.get("chip", ""))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.position = Vector2(sig_x, sig_y + icon_diameter + height * 0.008)
	chip.size = Vector2(width * 0.70, height * 0.034)
	chip.add_theme_font_size_override("font_size", int(clampf(height * 0.024, 10, 18)))
	chip.add_theme_color_override("font_color", Color("d9d3c6"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)

	var chip_bottom := chip.position.y + chip.size.y
	var rules_top := height * 0.60
	var mid_gap := maxf(1.0, rules_top - chip_bottom)

	# Sword + IMPACTO/PODER + number — ~90% of space between chip and effects, flush left
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage:
		var block_h := mid_gap * 0.90
		var block_y := chip_bottom + (mid_gap - block_h) * 0.5
		var block_x := width * 0.05
		var icon_side := block_h
		var dmg := Label.new()
		dmg.name = "DamageNumber"
		dmg.text = str(int(spec.get("stat_value", 0)))
		dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Number sits in shield face (~center-left of sword graphic)
		dmg.position = Vector2(block_x + icon_side * 0.18, block_y + icon_side * 0.28)
		dmg.size = Vector2(icon_side * 0.38, icon_side * 0.36)
		dmg.add_theme_font_size_override("font_size", int(clampf(block_h * 0.28, 22, 64)))
		dmg.add_theme_color_override("font_color", spec.get("stat_color", Color.WHITE))
		dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dmg)
		var stat_lbl := Label.new()
		stat_lbl.name = "StatLabel"
		var raw_label := str(spec.get("stat_label", "ATAQUE"))
		stat_lbl.text = "PODER" if raw_label == "PODER" else "IMPACTO"
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_lbl.position = Vector2(block_x + icon_side * 0.92, block_y + block_h * 0.35)
		stat_lbl.size = Vector2(width * 0.40, block_h * 0.30)
		stat_lbl.add_theme_font_size_override("font_size", int(clampf(block_h * 0.16, 14, 36)))
		stat_lbl.add_theme_color_override("font_color", Color("f4f1ea"))
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stat_lbl)

	# Effects / rules in medium-opacity black box
	var rules_bg := ColorRect.new()
	rules_bg.color = Color(0, 0, 0, BOX_ALPHA)
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
		var inset := CORNER_RADIUS * 0.35
		var art_rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2))
		_draw_texture_aspect_cover(art, art_rect)
		draw_rect(art_rect, Color(0, 0, 0, 0.12))
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
	# Match setup(): ~90% of gap between chip bottom and rules top, flush left, vertically centered
	var height := size.y
	var width := size.x
	var icon_r := height * 0.048
	var sig_y := height * 0.045
	var icon_diameter := icon_r * 2.0
	var chip_bottom := sig_y + icon_diameter + height * 0.008 + height * 0.034
	var rules_top := height * 0.60
	var mid_gap := maxf(1.0, rules_top - chip_bottom)
	var block_h := mid_gap * 0.90
	var block_y := chip_bottom + (mid_gap - block_h) * 0.5
	var block_x := width * 0.05
	var origin := Vector2(block_x + block_h * 0.5, block_y + block_h * 0.5)
	var icon_size := Vector2(block_h, block_h)
	if _shield_tex != null:
		draw_texture_rect(_shield_tex, Rect2(origin - icon_size * 0.5, icon_size), false)
	else:
		draw_circle(origin, icon_size.x * 0.28, Color(0.05, 0.05, 0.07, 0.9))
		draw_arc(origin, icon_size.x * 0.28, 0, TAU, 32, Color("ece7dc"), 2.5, true)

func _draw_texture_aspect_cover(tex: Texture2D, rect: Rect2) -> void:
	# Same height as card art rect; keep aspect (crop sides or letterbox — never squash)
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale := rect.size.y / tex_size.y
	var draw_w := tex_size.x * scale
	var draw_h := rect.size.y
	if draw_w >= rect.size.x:
		# Crop left/right: sample center of source
		var src_w := tex_size.x * (rect.size.x / draw_w)
		var src_x := (tex_size.x - src_w) * 0.5
		draw_texture_rect_region(tex, rect, Rect2(src_x, 0.0, src_w, tex_size.y))
	else:
		# Letterbox sides on type-tint background
		var dst := Rect2(
			Vector2(rect.position.x + (rect.size.x - draw_w) * 0.5, rect.position.y),
			Vector2(draw_w, draw_h)
		)
		draw_texture_rect(tex, dst, false)

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
