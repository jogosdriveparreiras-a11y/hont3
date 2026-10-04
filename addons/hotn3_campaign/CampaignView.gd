extends CanvasLayer

signal next_line
signal option_selected(option: Dictionary)
signal team_selected(ids: Array)
signal card_selected(option: Dictionary)
signal campaign_selected(campaign_id: String)
signal reward_bundle_continue
signal load_campaign
signal exit_campaign
signal retry_battle

const Content = preload("res://game/Content.gd")

var mode := "line"
var chosen: Array[String] = []
var _roster: Dictionary = {}
var _forbidden: Dictionary = {}
var _full_text := ""
var _typing := 0.0
var _weather_kind := ""

var canvas: Control
var wash: ColorRect
var weather: CPUParticles2D
var heading: Label
var left_frame: PanelContainer
var right_frame: PanelContainer
var left_portrait: TextureRect
var right_portrait: TextureRect
var namebox: Label
var text_panel: PanelContainer
var body: RichTextLabel
var action_area: PanelContainer
var action_list: VBoxContainer

func _ready() -> void:
	layer = 4
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash = ColorRect.new()
	wash.color = Color(0.04, 0.07, 0.14, 0.57)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading = _label("", 25, Color("e4c896"))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.anchor_left = 0.025
	heading.anchor_right = 0.975
	heading.anchor_top = 0.025
	heading.anchor_bottom = 0.10
	canvas.add_child(heading)
	left_frame = _portrait_frame(0.04, 0.38)
	left_portrait = left_frame.get_child(0) as TextureRect
	right_frame = _portrait_frame(0.62, 0.96)
	right_portrait = right_frame.get_child(0) as TextureRect
	namebox = _label("", 23, Color("f7d9a1"))
	namebox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	namebox.anchor_left = 0.055
	namebox.anchor_right = 0.44
	namebox.anchor_top = 0.765
	namebox.anchor_bottom = 0.815
	canvas.add_child(namebox)
	text_panel = PanelContainer.new()
	text_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.13, 0.95), Color("b89a72")))
	text_panel.anchor_left = 0.04
	text_panel.anchor_right = 0.96
	text_panel.anchor_top = 0.815
	text_panel.anchor_bottom = 0.97
	canvas.add_child(text_panel)
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 24)
	padding.add_theme_constant_override("margin_right", 24)
	padding.add_theme_constant_override("margin_top", 13)
	padding.add_theme_constant_override("margin_bottom", 12)
	text_panel.add_child(padding)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.add_theme_font_size_override("normal_font_size", 24)
	body.add_theme_color_override("default_color", Color("f1ece5"))
	body.scroll_active = false
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	padding.add_child(body)
	var hint := _label("ESPAÇO / ENTER / CLIQUE PARA AVANÇAR", 13, Color("aeb0bc"))
	hint.anchor_left = 0.72
	hint.anchor_right = 0.975
	hint.anchor_top = 0.97
	hint.anchor_bottom = 1.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hint)
	canvas.gui_input.connect(_on_canvas_input)
	action_area = PanelContainer.new()
	action_area.anchor_left = 0.26
	action_area.anchor_right = 0.74
	action_area.anchor_top = 0.19
	action_area.anchor_bottom = 0.76
	action_area.add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.16, 0.97), Color("bf9968")))
	canvas.add_child(action_area)
	var action_padding := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		action_padding.add_theme_constant_override(side, 22)
	action_area.add_child(action_padding)
	var action_scroll := ScrollContainer.new()
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Scroll de ações mantém listas longas de campanhas acessíveis.
	action_padding.add_child(action_scroll)
	action_list = VBoxContainer.new()
	action_list.add_theme_constant_override("separation", 12)
	action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(action_list)
	action_area.hide()
	get_viewport().size_changed.connect(_on_screen_resized)

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style

func _label(value: String, size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	return label

func _button(value: String, action: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = value
	button.tooltip_text = hint
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _style(Color("272638"), Color("615769")))
	button.add_theme_stylebox_override("hover", _style(Color("413649"), Color("d1aa70")))
	button.pressed.connect(action)
	return button

func _portrait_frame(start: float, stop: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = start
	panel.anchor_right = stop
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.76
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.14, 0.48), Color(0.4, 0.4, 0.5, 0.35)))
	canvas.add_child(panel)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(picture)
	return panel

func _portrait(hero_id: String) -> Texture2D:
	if hero_id.begins_with("res://") and ResourceLoader.exists(hero_id):
		return load(hero_id) as Texture2D
	var hero: Dictionary = Content.HEROES.get(hero_id, {})
	var path := str(hero.get("portrait", ""))
	if path == "" or not ResourceLoader.exists(path):
		path = str(hero.get("sprite", ""))
	if path == "" or not ResourceLoader.exists(path): return null
	return load(path) as Texture2D

func _set_right(hero_id: String) -> void:
	right_portrait.texture = _portrait(hero_id) if hero_id != "" else null
	right_frame.visible = right_portrait.texture != null

func show_line(title: String, entry: Dictionary, text_value: String, right_id: String, weather_name: String, left_id: String = "ent_alyssa_wine") -> void:
	show()
	mode = "line"
	_set_weather(weather_name)
	heading.text = title
	left_portrait.texture = _portrait(left_id)
	_set_right(right_id)
	var speaker := str(entry.get("speaker", "NARRADOR"))
	namebox.text = str(entry.get("display_name", speaker))
	var active := str(entry.get("active_portrait", ""))
	if active == "": active = "right" if _right_is_speaking(speaker, right_id) else "left"
	left_frame.modulate = Color.WHITE if active == "left" else Color(0.38, 0.42, 0.52, 0.80)
	right_frame.modulate = Color.WHITE if active == "right" and right_id != "" else Color(0.38, 0.42, 0.52, 0.80)
	text_panel.show()
	_full_text = text_value
	body.text = text_value
	body.visible_characters = 0
	_typing = 0.0
	action_area.hide()

func _right_is_speaking(speaker: String, hero_id: String) -> bool:
	if hero_id == "" or not Content.HEROES.has(hero_id): return false
	return str(Content.HEROES[hero_id].get("name", "")).to_upper().begins_with(speaker)

func _clear_actions(title: String, subtitle: String = "") -> void:
	show()
	mode = "action"
	action_area.show()
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	action_list.add_child(_label(title, 26, Color("f1d398")))
	if subtitle != "": action_list.add_child(_label(subtitle, 17, Color("dad5d3")))

func show_choices(options: Array) -> void:
	_clear_actions("Decisão de Alyssa", "A escolha altera o desfecho da história.")
	for raw in options:
		var option: Dictionary = raw
		action_list.add_child(_button(str(option.get("label", "Escolher")), _select_option.bind(option)))
	text_panel.hide()

func _select_option(option: Dictionary) -> void:
	option_selected.emit(option)

func show_campaign_list(campaigns: Array) -> void:
	_clear_actions("Campanhas", "Escolha uma campanha para começar ou continuar.")
	for raw in campaigns:
		if typeof(raw) != TYPE_DICTIONARY: continue
		var campaign: Dictionary = raw
		var id := str(campaign.get("id", ""))
		var title := str(campaign.get("title", id))
		var source := str(campaign.get("source_file", ""))
		var caption := title if source == "" else "%s · %s" % [title, source]
		action_list.add_child(_button(caption, _select_campaign.bind(id)))
	action_list.add_child(_button("Voltar ao menu", _exit))
	text_panel.hide()

func _select_campaign(id: String) -> void:
	campaign_selected.emit(id)

func show_team(roster: Dictionary, selection: Array[String], forbidden: Dictionary, battle_name: String, required_party: Array = ["ent_alyssa_wine"], party_size: int = 3) -> void:
	_roster = roster
	_forbidden = forbidden
	set_meta("required_party", required_party)
	set_meta("party_size", party_size)
	chosen = selection.duplicate()
	for raw in required_party:
		var id := str(raw)
		if not chosen.has(id): chosen.push_front(id)
	_draw_team(battle_name)

func _draw_team(battle_name: String) -> void:
	var required: Array = get_meta("required_party", [])
	var party_size := int(get_meta("party_size", 3))
	var names := PackedStringArray()
	for id in required: names.append(str(_roster.get(str(id), {}).get("name", id)))
	_clear_actions("Equipe · %s" % battle_name, "%s é obrigatório. Complete %d vaga(s) com personagens da sua coleção." % [", ".join(names), party_size - required.size()])
	var selected_names := PackedStringArray()
	for id in chosen: selected_names.append(str(_roster.get(id, {}).get("name", id)))
	action_list.add_child(_label("Na equipe: " + ", ".join(selected_names), 18, Color("d4c7e4")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 225
	action_list.add_child(scroll)
	var all := VBoxContainer.new()
	scroll.add_child(all)
	var ids: Array[String] = []
	for id in _roster:
		if bool(_roster[id].get("playable", true)) and not _forbidden.has(str(id)):
			ids.append(str(id))
	ids.sort()
	for id in ids:
		var hero: Dictionary = _roster[id]
		var entry := _button(("✓ " if chosen.has(id) else "+ ") + str(hero.get("name", id)) + " · %d Vida" % int(hero.get("hp", 0)), _toggle_team_member.bind(id))
		entry.disabled = required.has(id)
		all.add_child(entry)
	action_list.add_child(_label("Adversários dos três capítulos não podem entrar na equipe.", 15, Color("d9a29b")))
	var confirm := _button("Entrar na batalha · %d/%d" % [chosen.size(), party_size], _confirm_team)
	confirm.disabled = chosen.size() != party_size
	action_list.add_child(confirm)
	action_list.add_child(_button("Voltar ao menu", _exit))
	text_panel.hide()

func _toggle_team_member(id: String) -> void:
	var required: Array = get_meta("required_party", [])
	var party_size := int(get_meta("party_size", 3))
	if required.has(id) or _forbidden.has(id): return
	if chosen.has(id):
		chosen.erase(id)
	elif chosen.size() < party_size:
		chosen.append(id)
	_draw_team(str(get_meta("battle_name", "Missão")))

func _confirm_team() -> void:
	if chosen.size() == int(get_meta("party_size", 3)): team_selected.emit(chosen.duplicate())

func show_reward(options: Array) -> void:
	_clear_actions("Escolha uma carta", "Vitória. Uma carta nova entra na coleção; as outras duas continuam disponíveis em missões futuras.")
	for raw in options:
		var option: Dictionary = raw
		var cid := str(option.get("card", ""))
		var owner_id := str(option.get("owner", ""))
		var hero_name := str(Content.HEROES.get(owner_id, {}).get("name", owner_id))
		var definition: Dictionary = Content.CARDS.get(cid, {})
		var label_text := "%s · %s" % [hero_name, str(definition.get("name", cid))]
		var hint := "%s · Iniciativa: %s" % [str(definition.get("class", "")), str(definition.get("cost", 0))]
		action_list.add_child(_button(label_text, _select_card.bind(option), hint))
	text_panel.hide()

func show_reward_bundle(title: String, rewards: Array) -> void:
	_clear_actions(title, "Recompensas recebidas")
	for raw in rewards:
		if typeof(raw) != TYPE_DICTIONARY: continue
		var reward: Dictionary = raw
		var kind := str(reward.get("type", "item"))
		var id := str(reward.get("id", ""))
		var label := str(reward.get("label", id if id != "" else "Sorteio"))
		action_list.add_child(_label("%s · %s ×%d" % [kind.capitalize(), label, maxi(1, int(reward.get("amount", 1)))], 18, Color("dad5d3")))
	action_list.add_child(_button("Receber e continuar", func(): reward_bundle_continue.emit()))
	text_panel.hide()

func _select_card(option: Dictionary) -> void:
	card_selected.emit(option)

func show_defeat(battle_name: String, game_over: String = "none") -> void:
	_clear_actions("Retirada · " + battle_name, "A história retorna à preparação desta luta. Nenhuma carta é concedida pela derrota.")
	if game_over != "title": action_list.add_child(_button("Editar equipe e tentar novamente", _retry))
	if game_over == "load": action_list.add_child(_button("Carregar campanha salva", func(): load_campaign.emit()))
	action_list.add_child(_button("Ir para a tela inicial", _exit))
	text_panel.hide()

func show_ending() -> void:
	_clear_actions("Fim · A Fenda das Três Vigílias", "As escolhas e cartas conquistadas foram salvas.")
	action_list.add_child(_button("Voltar ao menu", _exit))
	text_panel.hide()

func _exit() -> void:
	exit_campaign.emit()

func _retry() -> void:
	retry_battle.emit()

func _set_weather(kind: String) -> void:
	if kind == _weather_kind: return
	_weather_kind = kind
	if is_instance_valid(weather):
		canvas.remove_child(weather)
		weather.queue_free()
	wash.color = Color(0.08, 0.12, 0.21, 0.53) if kind == "rain" else (Color(0.17, 0.10, 0.12, 0.54) if kind == "ash" else Color(0.10, 0.04, 0.11, 0.53))
	weather = CPUParticles2D.new()
	weather.amount = 145 if kind == "rain" else 64
	weather.lifetime = 1.4 if kind == "rain" else 4.0
	weather.direction = Vector2(0.15, 1.0) if kind == "rain" else Vector2(-0.25, 0.2)
	weather.gravity = Vector2(0, 620) if kind == "rain" else Vector2(0, -8)
	weather.initial_velocity_min = 90 if kind == "rain" else 13
	weather.initial_velocity_max = 170 if kind == "rain" else 28
	weather.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	weather.color = Color("a6c8e5") if kind == "rain" else (Color("f3ad9c") if kind == "ash" else Color("d6a5bb"))
	weather.texture = _flake_texture(kind == "rain")
	canvas.add_child(weather)
	canvas.move_child(weather, 1)
	_on_screen_resized()
	weather.emitting = true

func _flake_texture(long_shape: bool) -> ImageTexture:
	var height := 14 if long_shape else 4
	var image := Image.create(3, height, false, Image.FORMAT_RGBA8)
	for x in range(3):
		for y in range(height):
			image.set_pixel(x, y, Color(1, 1, 1, 0.22 if x != 1 else 0.66))
	return ImageTexture.create_from_image(image)

func _on_screen_resized() -> void:
	if not is_instance_valid(weather): return
	var area := get_viewport().get_visible_rect().size
	weather.position = Vector2(area.x * 0.5, -18 if _weather_kind == "rain" else area.y * 0.25)
	weather.emission_rect_extents = Vector2(area.x * 0.5, 30 if _weather_kind == "rain" else area.y * 0.30)

func _on_canvas_input(event: InputEvent) -> void:
	if mode != "line":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		var _vp := get_viewport()
		if _vp != null:
			_vp.set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or mode != "line":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		advance()
		var _vp := get_viewport()
		if _vp != null:
			_vp.set_input_as_handled()

func _line_revealed() -> bool:
	# RichTextLabel uses -1 to mean "show all"; that must count as finished
	# or the first skip-click traps advance forever (visible_characters < length).
	if body.visible_characters < 0:
		return true
	return body.visible_characters >= _full_text.length()

func advance() -> void:
	if mode != "line":
		return
	if not _line_revealed():
		body.visible_characters = -1
	else:
		next_line.emit()

func _process(delta: float) -> void:
	if not visible or mode != "line" or body.visible_characters < 0:
		return
	_typing += delta * 44.0
	if _typing >= 1.0:
		body.visible_characters = mini(_full_text.length(), body.visible_characters + int(_typing))
		_typing -= floor(_typing)
