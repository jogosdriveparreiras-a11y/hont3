extends Control

var spec: Dictionary = {}
var _shield_tex: Texture2D = null
var _title_font: Font = null
const CORNER_RADIUS := 18.0
const BOX_ALPHA := 125.0 / 255.0

func setup(data: Dictionary) -> void:
	spec = data
	for child in get_children():
		child.queue_free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_tex = spec.get("shield_icon", null) as Texture2D
	if _shield_tex == null and ResourceLoader.exists("res://assets/ui/impact_shield_sword.png"):
		_shield_tex = load("res://assets/ui/impact_shield_sword.png")
	if _title_font == null and ResourceLoader.exists("res://assets/fonts/CardTitle.ttf"):
		_title_font = load("res://assets/fonts/CardTitle.ttf")
	_build_layout()
	if bool(spec.get("dead", false)):
		modulate = Color(0.55, 0.55, 0.58, 0.78)
	else:
		modulate = Color.WHITE
	queue_redraw()

func _apply_title_font(lbl: Label, size_px: int) -> void:
	if _title_font != null:
		lbl.add_theme_font_override("font", _title_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", Color("f4f1ea"))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)

func _build_layout() -> void:
	var width := size.x if size.x > 1.0 else custom_minimum_size.x
	var height := size.y if size.y > 1.0 else custom_minimum_size.y
	if width < 2.0:
		width = 280.0
	if height < 2.0:
		height = 400.0
	var icon_r := height * 0.048
	var sig_x := width * 0.06
	var sig_y := height * 0.045
	var icon_diameter := icon_r * 2.0

	# Title — epic/serif, top-right of signature icon (leftover width)
	var title := Label.new()
	title.name = "Title"
	title.text = str(spec.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(sig_x + icon_diameter + width * 0.025, sig_y)
	title.size = Vector2(width - (sig_x + icon_diameter + width * 0.08), icon_diameter * 1.35)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_title_font(title, int(clampf(height * 0.048, 16, 36)))
	add_child(title)

	# Character name — WIDTH OF THE ICON, directly below icon, centered
	var chip_box := ColorRect.new()
	chip_box.name = "ChipBox"
	chip_box.color = Color(0, 0, 0, BOX_ALPHA)
	chip_box.position = Vector2(sig_x, sig_y + icon_diameter + height * 0.010)
	chip_box.size = Vector2(icon_diameter, height * 0.038)
	chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip_box)
	var chip := Label.new()
	chip.name = "Chip"
	chip.text = str(spec.get("chip", ""))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.position = chip_box.position
	chip.size = chip_box.size
	chip.clip_text = true
	chip.add_theme_font_size_override("font_size", int(clampf(height * 0.022, 9, 14)))
	chip.add_theme_color_override("font_color", Color("d9d3c6"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)

	var chip_bottom := chip_box.position.y + chip_box.size.y
	var rules_top := height * 0.60
	var mid_gap := maxf(1.0, rules_top - chip_bottom)

	# Impact emblem LEFT — number on shield; IMPACTO/PODER on shield ribbon
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage:
		# Cluster pinned to LEFT card edge (label + shield/sword + value stay grouped).
		var icon_side := minf(mid_gap * 0.62, width * 0.36)
		var block_y := chip_bottom + (mid_gap - icon_side) * 0.5
		var block_x := -width * 0.02
		var stat_lbl := Label.new()
		stat_lbl.name = "StatLabel"
		var raw_label := str(spec.get("stat_label", "ATAQUE"))
		stat_lbl.text = "PODER" if raw_label == "PODER" else "IMPACTO"
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_lbl.position = Vector2(block_x, block_y + icon_side * 0.08)
		stat_lbl.size = Vector2(icon_side, icon_side * 0.16)
		stat_lbl.add_theme_font_size_override("font_size", int(clampf(icon_side * 0.12, 10, 20)))
		stat_lbl.add_theme_color_override("font_color", Color("f4f1ea"))
		stat_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		stat_lbl.add_theme_constant_override("shadow_offset_x", 1)
		stat_lbl.add_theme_constant_override("shadow_offset_y", 1)
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stat_lbl)
		var dmg := Label.new()
		dmg.name = "DamageNumber"
		dmg.text = str(int(spec.get("stat_value", 0)))
		dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dmg.position = Vector2(block_x + icon_side * 0.22, block_y + icon_side * 0.30)
		dmg.size = Vector2(icon_side * 0.56, icon_side * 0.36)
		dmg.add_theme_font_size_override("font_size", int(clampf(icon_side * 0.30, 20, 52)))
		dmg.add_theme_color_override("font_color", spec.get("stat_color", Color.WHITE))
		dmg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		dmg.add_theme_constant_override("shadow_offset_x", 2)
		dmg.add_theme_constant_override("shadow_offset_y", 2)
		dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dmg)
	# Rules box — ONLY intentional semi-transparent element
	var rules_box := ColorRect.new()
	rules_box.name = "RulesBox"
	rules_box.color = Color(0, 0, 0, BOX_ALPHA)
	rules_box.position = Vector2(width * 0.05, rules_top)
	rules_box.size = Vector2(width * 0.90, height * 0.26)
	rules_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rules_box)

	var is_desv := bool(spec.get("desvantagem", false))
	var rules_y := rules_top + height * 0.015
	var rules_h := height * 0.23
	if is_desv:
		var desv := Label.new()
		desv.name = "DesvantagemLabel"
		desv.text = "Desvantagem"
		desv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desv.position = Vector2(rules_box.position.x, rules_top + 4)
		desv.size = Vector2(rules_box.size.x, height * 0.035)
		desv.add_theme_font_size_override("font_size", int(clampf(height * 0.028, 11, 20)))
		desv.add_theme_color_override("font_color", Color("f0c27a"))
		desv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(desv)
		rules_y = rules_top + height * 0.040
		rules_h = height * 0.205

	var rules := RichTextLabel.new()
	rules.name = "Rules"
	rules.bbcode_enabled = true
	rules.fit_content = false
	rules.scroll_active = false
	rules.text = str(spec.get("rules", ""))
	rules.position = Vector2(rules_box.position.x + width * 0.02, rules_y)
	rules.size = Vector2(rules_box.size.x - width * 0.04, rules_h)
	rules.add_theme_font_size_override("normal_font_size", int(clampf(height * 0.030, 12, 22)))
	rules.add_theme_color_override("default_color", Color("e7f6f8"))
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rules)

	# INICIATIVA bottom-left (pips drawn in _draw)
	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "INICIATIVA"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.position = Vector2(width * 0.06, height * 0.885)
	footer.size = Vector2(width * 0.40, height * 0.04)
	footer.add_theme_font_size_override("font_size", int(clampf(height * 0.022, 10, 16)))
	footer.add_theme_color_override("font_color", Color("d9d3c6"))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)

func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 2.0 or height < 2.0:
		return
	var border: Color = spec.get("border", Color("8a8f98")) as Color
	# Opaque type-tinted background under full-bleed art (NOT transparent card)
	var bg := Color(border.r * 0.28, border.g * 0.28, border.b * 0.32, 1.0)
	_draw_rounded_rect(Rect2(Vector2.ZERO, size), bg, CORNER_RADIUS)
	var art = spec.get("art", null)
	if art is Texture2D:
		var inset := CORNER_RADIUS * 0.35
		var art_rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2))
		_draw_texture_aspect_cover(art, art_rect)
		draw_rect(art_rect, Color(0, 0, 0, 0.12))
	# Signature icon top-LEFT (chrome opaque)
	var icon_center := Vector2(width * 0.06 + height * 0.048, height * 0.045 + height * 0.048)
	var icon_radius := height * 0.048
	draw_circle(icon_center, icon_radius + 3.0, Color(0, 0, 0, 0.85))
	draw_circle(icon_center, icon_radius, Color("12141c"))
	draw_arc(icon_center, icon_radius, 0, TAU, 48, border, 4.0, true)
	var icon = spec.get("icon", null)
	if icon is Texture2D:
		var side := icon_radius * 1.35
		draw_texture_rect(icon, Rect2(icon_center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	# Type-colored rounded border (existing _type_color via spec.border)
	_draw_rounded_border(Rect2(Vector2(3, 3), size - Vector2(6, 6)), border, CORNER_RADIUS - 2.0, 6.0)
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage:
		_draw_impact_icon()
	# Green helmet-style pips for INICIATIVA gain; red for cost
	var gain := int(spec.get("gain", 0))
	var cost := int(spec.get("cost", 0))
	var x := width * 0.42
	var y := height * 0.905
	for _i in mini(gain, 8):
		_draw_pip(Vector2(x, y), Color("3ecf7a"))
		x += width * 0.065
	for _i in mini(cost, 8):
		_draw_pip(Vector2(x, y), Color("d24b4b"))
		x += width * 0.065

func _draw_impact_icon() -> void:
	var height := size.y
	var width := size.x
	var icon_r := height * 0.048
	var sig_y := height * 0.045
	var icon_diameter := icon_r * 2.0
	var chip_bottom := sig_y + icon_diameter + height * 0.010 + height * 0.038
	var rules_top := height * 0.60
	var mid_gap := maxf(1.0, rules_top - chip_bottom)
	var icon_side := minf(mid_gap * 0.62, width * 0.36)
	var block_y := chip_bottom + (mid_gap - icon_side) * 0.5
	var block_x := -width * 0.02
	var origin := Vector2(block_x + icon_side * 0.5, block_y + icon_side * 0.5)
	var icon_size := Vector2(icon_side, icon_side)
	if _shield_tex != null:
		draw_texture_rect(_shield_tex, Rect2(origin - icon_size * 0.5, icon_size), false)
	else:
		draw_circle(origin, icon_size.x * 0.28, Color(0.05, 0.05, 0.07, 0.9))
		draw_arc(origin, icon_size.x * 0.28, 0, TAU, 32, Color("ece7dc"), 2.5, true)

func _draw_texture_aspect_cover(tex: Texture2D, rect: Rect2) -> void:
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var cover := rect.size.y / tex_size.y
	var draw_w := tex_size.x * cover
	if draw_w >= rect.size.x:
		var src_w := tex_size.x * (rect.size.x / draw_w)
		var src_x := (tex_size.x - src_w) * 0.5
		draw_texture_rect_region(tex, rect, Rect2(src_x, 0.0, src_w, tex_size.y))
	else:
		var dst := Rect2(
			Vector2(rect.position.x + (rect.size.x - draw_w) * 0.5, rect.position.y),
			Vector2(draw_w, rect.size.y)
		)
		draw_texture_rect(tex, dst, false)

func _draw_pip(center: Vector2, tint: Color) -> void:
	# Green/red circular "helmet" initiative pip
	var radius := size.y * 0.022
	draw_circle(center, radius + 1.5, Color(0, 0, 0, 0.55))
	draw_circle(center, radius, tint)
	# Simple helmet silhouette (dome + cheek)
	var ink := Color(0.08, 0.08, 0.10, 0.92)
	draw_circle(center + Vector2(0, -radius * 0.12), radius * 0.42, ink)
	draw_rect(Rect2(center + Vector2(-radius * 0.28, radius * 0.05), Vector2(radius * 0.56, radius * 0.28)), ink)

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
