extends Control

var spec: Dictionary = {}
var _shield_tex: Texture2D = null
var _title_font: Font = null
const CORNER_RADIUS := 18.0
const BOX_ALPHA := 125.0 / 255.0

func setup(data: Dictionary) -> void:
	spec = data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_tex = spec.get("shield_icon", null) as Texture2D
	if _shield_tex == null and ResourceLoader.exists("res://assets/ui/impact_shield_sword.png"):
		_shield_tex = load("res://assets/ui/impact_shield_sword.png")
	if _title_font == null and ResourceLoader.exists("res://assets/fonts/CardTitle.ttf"):
		_title_font = load("res://assets/fonts/CardTitle.ttf")
	if _has_scene_layout():
		_fill_scene_nodes()
	else:
		_build_dynamic()
	if bool(spec.get("dead", false)):
		modulate = Color(0.55, 0.55, 0.58, 0.78)
	else:
		modulate = Color.WHITE
	queue_redraw()

func _has_scene_layout() -> bool:
	return has_node("Title") and has_node("Chip") and has_node("Rules")

func _apply_title_font(lbl: Label, size_px: int) -> void:
	if _title_font != null:
		lbl.add_theme_font_override("font", _title_font)
	lbl.add_theme_font_size_override("font_size", size_px)
	lbl.add_theme_color_override("font_color", Color("f4f1ea"))

func _fill_scene_nodes() -> void:
	var width := size.x if size.x > 1.0 else custom_minimum_size.x
	var height := size.y if size.y > 1.0 else custom_minimum_size.y
	var title: Label = $Title
	title.text = str(spec.get("title", ""))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.clip_text = true
	_apply_title_font(title, int(clampf(height * 0.048, 16, 36)))
	var chip: Label = $Chip
	chip.text = str(spec.get("chip", ""))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", int(clampf(height * 0.026, 11, 18)))
	chip.add_theme_color_override("font_color", Color("d9d3c6"))
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	var dmg_block: Control = $DamageBlock
	dmg_block.visible = show_damage
	if show_damage:
		var dmg: Label = $DamageBlock/DamageNumber
		dmg.text = str(int(spec.get("stat_value", 0)))
		dmg.add_theme_color_override("font_color", spec.get("stat_color", Color.WHITE))
		dmg.add_theme_font_size_override("font_size", int(clampf(height * 0.08, 22, 64)))
		var stat_lbl: Label = $DamageBlock/StatLabel
		var raw_label := str(spec.get("stat_label", "ATAQUE"))
		stat_lbl.text = "PODER" if raw_label == "PODER" else "IMPACTO"
	var is_desv := bool(spec.get("desvantagem", false))
	var desv: Label = $DesvantagemLabel
	desv.visible = is_desv
	var rules: RichTextLabel = $Rules
	rules.text = str(spec.get("rules", ""))
	rules.add_theme_font_size_override("normal_font_size", int(clampf(height * 0.030, 12, 22)))
	var gain := int(spec.get("gain", 0))
	var cost := int(spec.get("cost", 0))
	var footer: Label = $Footer
	footer.visible = true
	var bits: PackedStringArray = []
	if gain > 0:
		bits.append("+%d INI" % gain)
	if cost > 0:
		bits.append("-%d INI" % cost)
	footer.text = "INICIATIVA" if bits.is_empty() else "INICIATIVA  " + " · ".join(bits)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _build_dynamic() -> void:
	for child in get_children():
		child.queue_free()
	var width := size.x
	var height := size.y
	var icon_r := height * 0.048
	var sig_x := width * 0.06
	var sig_y := height * 0.045
	var icon_diameter := icon_r * 2.0

	# Title — epic/serif, beside signature icon
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

	# Character name — CENTERED in its box under the signature area
	var chip_box := ColorRect.new()
	chip_box.name = "ChipBox"
	chip_box.color = Color(0, 0, 0, BOX_ALPHA)
	chip_box.position = Vector2(width * 0.18, sig_y + icon_diameter + height * 0.012)
	chip_box.size = Vector2(width * 0.64, height * 0.038)
	chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip_box)
	var chip := Label.new()
	chip.name = "Chip"
	chip.text = str(spec.get("chip", ""))
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.position = chip_box.position
	chip.size = chip_box.size
	chip.add_theme_font_size_override("font_size", int(clampf(height * 0.026, 11, 18)))
	chip.add_theme_color_override("font_color", Color("d9d3c6"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)

	var chip_bottom := chip.position.y + chip.size.y
	var rules_top := height * 0.58
	var mid_gap := maxf(1.0, rules_top - chip_bottom)

	# Impact emblem LEFT + IMPACTO/PODER label
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage:
		var block_h := mid_gap * 0.88
		var block_y := chip_bottom + (mid_gap - block_h) * 0.5
		var block_x := width * 0.05
		var icon_side := block_h
		var dmg := Label.new()
		dmg.name = "DamageNumber"
		dmg.text = str(int(spec.get("stat_value", 0)))
		dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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

	# Rules box — bottom semi-transparent
	var rules_box := ColorRect.new()
	rules_box.name = "RulesBox"
	rules_box.color = Color(0, 0, 0, BOX_ALPHA)
	rules_box.position = Vector2(width * 0.05, rules_top)
	rules_box.size = Vector2(width * 0.90, height * 0.28)
	rules_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rules_box)

	var is_desv := bool(spec.get("desvantagem", false))
	if is_desv:
		var desv := Label.new()
		desv.name = "DesvantagemLabel"
		desv.text = "Desvantagem"
		desv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desv.position = Vector2(rules_box.position.x, rules_box.position.y + 4)
		desv.size = Vector2(rules_box.size.x, height * 0.032)
		desv.add_theme_font_size_override("font_size", int(clampf(height * 0.028, 11, 20)))
		desv.add_theme_color_override("font_color", Color("f0c27a"))
		desv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(desv)

	var rules := RichTextLabel.new()
	rules.name = "Rules"
	rules.bbcode_enabled = true
	rules.fit_content = false
	rules.scroll_active = false
	rules.text = str(spec.get("rules", ""))
	var rules_pad_y := height * 0.036 if is_desv else height * 0.012
	rules.position = Vector2(rules_box.position.x + width * 0.02, rules_box.position.y + rules_pad_y)
	rules.size = Vector2(rules_box.size.x - width * 0.04, rules_box.size.y - rules_pad_y - height * 0.01)
	rules.add_theme_font_size_override("normal_font_size", int(clampf(height * 0.030, 12, 22)))
	rules.add_theme_color_override("default_color", Color("e7f6f8"))
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rules)

	# INICIATIVA bottom-left
	var footer := Label.new()
	footer.name = "Footer"
	var gain := int(spec.get("gain", 0))
	var cost := int(spec.get("cost", 0))
	var bits: PackedStringArray = []
	if gain > 0:
		bits.append("+%d" % gain)
	if cost > 0:
		bits.append("−%d" % cost)
	footer.text = "◆ INICIATIVA" if bits.is_empty() else "◆ INICIATIVA  " + " · ".join(bits)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.position = Vector2(width * 0.05, height * 0.90)
	footer.size = Vector2(width * 0.70, height * 0.06)
	footer.add_theme_font_size_override("font_size", int(clampf(height * 0.028, 11, 18)))
	footer.add_theme_color_override("font_color", Color("d9d3c6"))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)

func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 2.0 or height < 2.0:
		return
	# Soft rounded frame
	var frame := Color(0.05, 0.06, 0.10, 0.35)
	draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), frame, false, 2.0)
	# Signature icon disc (top-left)
	var icon_r := height * 0.048
	var sig_x := width * 0.06 + icon_r
	var sig_y := height * 0.045 + icon_r
	draw_circle(Vector2(sig_x, sig_y), icon_r, Color(0.12, 0.14, 0.2, 0.85))
	var sig_tex: Texture2D = spec.get("signature", null) as Texture2D
	if sig_tex != null:
		var side := icon_r * 1.6
		draw_texture_rect(sig_tex, Rect2(sig_x - side * 0.5, sig_y - side * 0.5, side, side), false)
	# Impact emblem art
	var show_damage := bool(spec.get("show_damage", false)) and not bool(spec.get("item", false))
	if show_damage and _shield_tex != null:
		var chip_bottom := height * 0.045 + icon_r * 2.0 + height * 0.012 + height * 0.038
		var rules_top := height * 0.58
		var mid_gap := maxf(1.0, rules_top - chip_bottom)
		var block_h := mid_gap * 0.88
		var block_y := chip_bottom + (mid_gap - block_h) * 0.5
		var block_x := width * 0.05
		draw_texture_rect(_shield_tex, Rect2(block_x, block_y, block_h, block_h), false)
