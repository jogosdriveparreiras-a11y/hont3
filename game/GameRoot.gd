extends Node3D

const Content = preload("res://game/Content.gd")
const Battle = preload("res://game/BattleState.gd")

var battle
var camera: Camera3D
var stage: Node3D
var units: Node3D
var cards_3d: Node3D
var viewport_hosts: Node
var hud: Control
var team: Array[String] = ["guerreiro", "mago", "clerigo"]
var equipped: Dictionary = {}
var improvements: Dictionary = {}
var loadout: Dictionary = {"potion": 1, "bomb": 1, "antidote": 1}
var mission_id := "road"
var selected_card := -1
var selected_action := ""
var chain_targets: Array[int] = []
var feedback := ""
var event_history: Array[String] = []
var card_hit_areas: Array[Button] = []
var card_meshes: Array[MeshInstance3D] = []
var unit_sprites: Array[Sprite3D] = []
var soundtrack: AudioStreamPlayer
var shake_enabled := true
var shake_time := 0.0
var music_volume := -17.0

func _ready() -> void:
	_load_config()
	_make_world()
	_show_menu()

func _make_world() -> void:
	stage = Node3D.new()
	stage.name = "Arena3D"
	add_child(stage)
	units = Node3D.new()
	units.name = "Personagens2D"
	add_child(units)
	cards_3d = Node3D.new()
	cards_3d.name = "Cartas3D"
	add_child(cards_3d)
	viewport_hosts = Node.new()
	viewport_hosts.name = "FacesDasCartas"
	add_child(viewport_hosts)
	camera = Camera3D.new()
	camera.position = Vector3(0, 11.5, 18)
	camera.fov = 51
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101527")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("72769a")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	add_child(world)
	_add_box(Vector3(0, -0.30, 0), Vector3(19, 0.5, 12), Color("353c47"))
	for z in [-3.3, -1.7, 1.7, 3.3]:
		_add_box(Vector3(0, -0.02, z), Vector3(17, 0.04, 0.035), Color("bea674"))
	for x in [-9.1, 9.1]:
		for z in [-5.5, 5.5]:
			_add_box(Vector3(x, 1.75, z), Vector3(0.75, 3.5, 0.75), Color("555169"))
			_add_box(Vector3(x, 3.5, z), Vector3(1.1, 0.3, 1.1), Color("c8ac76"))
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://battle_music.ogg"):
		soundtrack = AudioStreamPlayer.new()
		soundtrack.stream = load("res://battle_music.ogg")
		soundtrack.volume_db = music_volume
		add_child(soundtrack)
		soundtrack.finished.connect(func(): soundtrack.play())
		soundtrack.play()

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _add_box(pos: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = pos
	if parent == null: parent = stage
	parent.add_child(mesh)
	return mesh

func _clear_ui() -> void:
	for child in hud.get_children(): child.queue_free()
	card_hit_areas.clear()

func _clear_combat_visuals() -> void:
	for node in units.get_children(): node.queue_free()
	for node in cards_3d.get_children(): node.queue_free()
	for node in viewport_hosts.get_children(): node.queue_free()
	unit_sprites.clear()
	card_meshes.clear()

func _label(text_value: String, size: int = 23, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, on_click: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(150, 45)
	button.add_theme_font_size_override("font_size", 18)
	button.tooltip_text = hint
	button.pressed.connect(on_click)
	return button

func _center_panel(title: String) -> VBoxContainer:
	_clear_ui()
	_clear_combat_visuals()
	var frame := CenterContainer.new()
	hud.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 0)
	frame.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	panel.add_child(contents)
	contents.add_child(_label(title, 38, Color("dcc28b")))
	return contents

func _show_menu() -> void:
	var menu := _center_panel("HEROES OF THE NIGHTMARE 3")
	menu.add_child(_label("Três heróis. Duas linhas. Um deck compartilhado.", 20))
	menu.add_child(_button("Selecionar missão", _show_missions))
	menu.add_child(_button("Escolher equipe", _show_team))
	menu.add_child(_button("Montar decks", _show_decks))
	menu.add_child(_button("Preparar itens", _show_items))
	menu.add_child(_button("Configurações", _show_settings))
	menu.add_child(_button("Iniciar missão: %s" % Content.MISSIONS[mission_id]["name"], _start_mission))

func _show_settings() -> void:
	var menu := _center_panel("CONFIGURAÇÕES")
	menu.add_child(_button("Tremor da câmera: %s" % ("ligado" if shake_enabled else "desligado"), _toggle_shake))
	menu.add_child(_button("Volume da música: %d%%" % roundi(db_to_linear(music_volume) * 100), _cycle_volume))
	menu.add_child(_button("Voltar", _show_menu))

func _toggle_shake() -> void:
	shake_enabled = not shake_enabled
	_save_config()
	_show_settings()

func _cycle_volume() -> void:
	music_volume = -80.0 if music_volume >= -1.0 else min(-1.0, music_volume + 8.0)
	if soundtrack != null: soundtrack.volume_db = music_volume
	_save_config()
	_show_settings()

func _show_missions() -> void:
	var menu := _center_panel("MISSÕES")
	for id in Content.MISSIONS:
		var entry: Dictionary = Content.MISSIONS[id]
		menu.add_child(_button("%s — %s" % [entry["name"], entry["objective"]], func(): mission_id = id; _show_missions()))
	menu.add_child(_label("Selecionada: %s" % Content.MISSIONS[mission_id]["name"], 19))
	menu.add_child(_button("Voltar", _show_menu))

func _show_team() -> void:
	var menu := _center_panel("EQUIPE · %d/%d" % [team.size(), Content.RULES["team_size"]])
	for id in Content.HEROES:
		var hero: Dictionary = Content.HEROES[id]
		var chosen := team.has(id)
		menu.add_child(_button(("✓ " if chosen else "+ ") + "%s · %s · %d PV" % [hero["name"], hero["type"], hero["hp"]], func(): _toggle_hero(id)))
	menu.add_child(_button("Voltar", _show_menu))

func _toggle_hero(id: String) -> void:
	if team.has(id):
		if team.size() > 1: team.erase(id)
	elif team.size() < int(Content.RULES["team_size"]):
		team.append(id)
	_save_config()
	_show_team()

func _show_decks() -> void:
	var menu := _center_panel("DECKS · 8 CARTAS POR HERÓI")
	for id in team:
		var hero: Dictionary = Content.HEROES[id]
		menu.add_child(_label(hero["name"], 25, Color("d9bd85")))
		var selected_cards: Array = equipped.get(id, hero["cards"])
		var row := HBoxContainer.new()
		menu.add_child(row)
		for position in range(selected_cards.size()):
			var card_id: String = selected_cards[position]
			var definition: Dictionary = Content.CARDS[card_id]
			var button := _button(definition["name"], func(): _cycle_card(id, position))
			button.custom_minimum_size = Vector2(115, 70)
			button.tooltip_text = _card_description(definition) + "\nClique para trocar a carta."
			row.add_child(button)
		var improvements_row := HBoxContainer.new()
		var catalogue := ScrollContainer.new()
		catalogue.custom_minimum_size = Vector2(1160, 66)
		catalogue.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		menu.add_child(catalogue)
		catalogue.add_child(improvements_row)
		for card_id in hero.get("pool", hero["cards"]):
			if improvements_row.get_children().any(func(b): return b.get_meta("card_id", "") == card_id): continue
			var key: String = str(id) + ":" + str(card_id)
			var change: Dictionary = improvements.get(key, {"upgrade": 0, "mod": ""})
			var upgrade_button := _button("%s +%d [%s]" % [Content.CARDS[card_id]["name"], change["upgrade"], change["mod"]], func(): _improve_card(key))
			upgrade_button.set_meta("card_id", card_id)
			improvements_row.add_child(upgrade_button)
	menu.add_child(_button("Voltar", _show_menu))

func _improve_card(key: String) -> void:
	var change: Dictionary = improvements.get(key, {"upgrade": 0, "mod": ""})
	change["upgrade"] = (int(change["upgrade"]) + 1) % 3
	var options := ["", "damage", "impulse", "redraw"]
	change["mod"] = options[(int(change["upgrade"]) + 1) % options.size()]
	improvements[key] = change
	_save_config()
	_show_decks()

func _show_items() -> void:
	var menu := _center_panel("ITENS · %d/%d" % [loadout.values().reduce(func(total, n): return total + n, 0), Content.RULES["items_max"]])
	for id in ["potion", "bomb", "antidote"]:
		menu.add_child(_button("%s ×%d" % [id.capitalize(), loadout.get(id, 0)], func(): _cycle_item(id)))
	menu.add_child(_button("Voltar", _show_menu))

func _cycle_item(id: String) -> void:
	var total := int(loadout.values().reduce(func(sum, n): return sum + n, 0))
	if total < int(Content.RULES["items_max"]): loadout[id] = int(loadout.get(id, 0)) + 1
	else: loadout[id] = 0
	_save_config()
	_show_items()

func _cycle_card(hero_id: String, slot: int) -> void:
	var values: Array = equipped.get(hero_id, Content.HEROES[hero_id]["cards"]).duplicate()
	var options: Array = Content.HEROES[hero_id].get("pool", Content.HEROES[hero_id]["cards"]).duplicate()
	var current_index: int = options.find(values[slot])
	for distance in range(1, options.size() + 1):
		var candidate: String = options[(current_index + distance) % options.size()]
		var count := values.count(candidate)
		if count < int(Content.RULES["copy_limit"]) or candidate == values[slot]:
			values[slot] = candidate
			break
	equipped[hero_id] = values
	_save_config()
	_show_decks()

func _start_mission() -> void:
	if team.size() != int(Content.RULES["team_size"]):
		feedback = "Escolha três heróis para entrar na missão."
		_show_team()
		return
	selected_card = -1
	selected_action = ""
	chain_targets.clear()
	event_history.clear()
	battle = Battle.new()
	battle.event.connect(_on_event)
	battle.changed.connect(_render_battle)
	battle.finished.connect(_on_finished)
	battle.begin(mission_id, team, equipped, 0, improvements, loadout)
	_render_battle()

func _on_event(message: String) -> void:
	event_history.append(message)
	if event_history.size() > 8: event_history.pop_front()
	feedback = message
	if shake_enabled and message.contains("sofreu"):
		shake_time = 0.15

func _on_finished(won: bool) -> void:
	var title := "MISSÃO CONCLUÍDA" if won else "MISSÃO PERDIDA"
	var menu := _center_panel(title)
	menu.add_child(_label("%s · %d rodadas" % [battle.mission["name"], battle.turn], 22))
	for actor in battle.living("ALLY"):
		menu.add_child(_label("%s: %d/%d PV" % [actor["name"], actor["hp"], actor["max_hp"]], 18))
	menu.add_child(_button("Tentar novamente", _start_mission))
	menu.add_child(_button("Selecionar missão", _show_missions))
	menu.add_child(_button("Menu", _show_menu))

func _render_battle() -> void:
	if battle == null or battle.phase == "FINISHED": return
	_clear_ui()
	_clear_combat_visuals()
	var header := HBoxContainer.new()
	hud.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.add_child(_label("%s  ·  RODADA %d" % [battle.mission["name"], battle.turn], 24, Color("e9c891")))
	header.add_child(_label("     AÇÕES %d  ·  ÍMPETO %d/%d  ·  INICIATIVA %d  ·  RECOMPRA %d  ·  MOVER %d" % [battle.card_plays, battle.impulse, battle.rules["impulse_max"], battle.initiative, battle.redraws, battle.moves], 20))
	header.add_child(_label("   DECK %d · DESCARTE %d" % [battle.deck.size(), battle.discard.size()], 18))
	if battle.mission["objective"] == "PROTECT": header.add_child(_label("   SENTINELA %d PV" % battle.protect_hp, 20))
	var next_turn: Array = battle.mission.get("reinforcements", {}).get(battle.turn + 1, [])
	if not next_turn.is_empty(): header.add_child(_label("   REFORÇOS EM 1 TURNO", 19, Color.ORANGE))
	var left := VBoxContainer.new()
	left.position = Vector2(20, 70)
	hud.add_child(left)
	left.add_child(_label("OBJETIVO: %s" % battle.mission["objective"], 20, Color("e9c891")))
	left.add_child(_label("ALIADOS", 22))
	for actor in battle.living("ALLY"):
		_add_actor_button(left, actor)
	left.add_child(_label("INIMIGOS", 22))
	for actor in battle.living("ENEMY"):
		_add_actor_button(left, actor)
	left.add_child(_button("Trocar linha (1x/turno)", func(): selected_action = "move"; _render_battle()))
	left.add_child(_button("Encerrar turno", func(): selected_card = -1; battle.end_player_turn()))
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(get_viewport().get_visible_rect().size.x - 300, 85)
	hud.add_child(right)
	right.add_child(_label("CENÁRIO", 22))
	for index in range(battle.mission.get("environment", []).size()):
		var object: Dictionary = battle.mission["environment"][index]
		right.add_child(_button("%s · %d Ímpeto" % [object["name"], object["cost"]], func(): battle.use_environment(index)))
	right.add_child(_label("ITENS", 22))
	for id in battle.items:
		right.add_child(_button("%s ×%d" % [id.capitalize(), battle.items[id]], func(): selected_action = "item:" + id; selected_card = -1; _render_battle()))
	right.add_child(_label("LOG", 22))
	for entry in event_history.slice(max(0, event_history.size() - 5)):
		var line := _label(entry, 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 260
		right.add_child(line)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(50, get_viewport().get_visible_rect().size.y - 95)
	bottom.add_theme_constant_override("separation", 8)
	hud.add_child(bottom)
	for index in range(battle.hand.size()):
		var card: Dictionary = battle.hand[index]
		var definition: Dictionary = Content.CARDS[card["id"]]
		var owner: Dictionary = battle.actor_by_id(card["owner"])
		var button := _button("%s\n%s" % [definition["name"], owner["name"]], func(): _select_card(index), _card_description(definition, card))
		button.custom_minimum_size = Vector2(132, 68)
		bottom.add_child(button)
		card_hit_areas.append(button)
		_make_3d_card(index, card, definition)
		if selected_card == index: button.modulate = Color("ffd680")
	bottom.add_child(_button("Redesenhar carta", func(): selected_action = "redraw"; _render_battle()))
	var status := _label("%s%s" % [feedback, "  ·  ALVOS %d/%d" % [chain_targets.size(), Content.CARDS[battle.hand[selected_card]["id"]].get("chain", 1)] if selected_card >= 0 and selected_card < battle.hand.size() and not chain_targets.is_empty() else ""], 19, Color("f7d499"))
	status.position = Vector2(30, get_viewport().get_visible_rect().size.y - 145)
	hud.add_child(status)
	_render_actors()

func _add_actor_button(parent: VBoxContainer, actor: Dictionary) -> void:
	var status_names: Array = actor["statuses"].keys()
	var text_value := "%s [%s] %d/%d PV +%d" % [actor["name"], "F" if actor["row"] == "front" else "T", actor["hp"], actor["max_hp"], actor["block"] + actor["shield"]]
	var hint := ", ".join(PackedStringArray(status_names)).replace("_", " ")
	if selected_card >= 0 and selected_card < battle.hand.size():
		var preview_chain: Array = []
		if Content.CARDS[battle.hand[selected_card]["id"]].get("target", "") == "CHAIN":
			preview_chain = chain_targets.duplicate()
			preview_chain.append(actor["id"])
		var estimate: Dictionary = battle.preview(selected_card, actor["id"], preview_chain)
		if not estimate.is_empty():
			var owner: Dictionary = battle.actor_by_id(battle.hand[selected_card]["owner"])
			for id in estimate["targets"]:
				var line: Dictionary = estimate["targets"][id]
				var victim: Dictionary = battle.actor_by_id(id)
				var factor: float = Content.TYPES.get(owner.get("type", ""), {}).get(victim.get("type", ""), 1.0)
				var type_note := " · vantagem" if factor > 1.0 else " · resistência" if factor < 1.0 else ""
				hint += "\n%s: −%d PV, resta %d%s%s" % [victim["name"], line["damage"], line["hp_after"], " · KO" if line["hp_after"] == 0 else "", type_note]
	var button := _button(text_value, func(): _choose_target(actor["id"]), hint)
	button.custom_minimum_size = Vector2(260, 42)
	parent.add_child(button)

func _select_card(index: int) -> void:
	if selected_action == "redraw":
		selected_action = ""
		battle.redraw(index)
		return
	selected_action = ""
	selected_card = index if selected_card != index else -1
	chain_targets.clear()
	if selected_card >= 0:
		var definition: Dictionary = Content.CARDS[battle.hand[index]["id"]]
		if definition["target"] == "SELF":
			_choose_target(battle.hand[index]["owner"])
			return
		feedback = "Escolha o alvo para %s." % definition["name"]
	_render_battle()

func _choose_target(actor_id: int) -> void:
	if selected_action == "move":
		selected_action = ""
		battle.move_actor(actor_id)
		return
	if selected_action.begins_with("item:"):
		var item_id := selected_action.trim_prefix("item:")
		selected_action = ""
		battle.use_item(item_id, actor_id)
		return
	if selected_card < 0 or selected_card >= battle.hand.size():
		feedback = "Selecione uma carta para mostrar a prévia."
		_render_battle()
		return
	var definition: Dictionary = Content.CARDS[battle.hand[selected_card]["id"]]
	if definition.get("target", "") == "CHAIN":
		chain_targets.append(actor_id)
		if chain_targets.size() < int(definition.get("chain", 1)):
			feedback = "Escolha o próximo acerto (%d/%d)." % [chain_targets.size(), definition["chain"]]
			_render_battle()
			return
	var preview: Dictionary = battle.preview(selected_card, actor_id, chain_targets)
	if preview.is_empty():
		feedback = "Alvo indisponível para esta carta."
		chain_targets.clear()
		_render_battle()
		return
	var successful: bool = battle.play(selected_card, actor_id, chain_targets)
	chain_targets.clear()
	if successful:
		selected_card = -1
	else:
		feedback = "Sem ação, Ímpeto, alcance ou alvo válido."
	_render_battle()

func _render_actors() -> void:
	var allies: Array = battle.living("ALLY")
	var enemies: Array = battle.living("ENEMY")
	for group in [allies, enemies]:
		for actor in group:
			var side: String = actor["side"]
			var row: String = actor["row"]
			var row_count := 0
			var row_index := 0
			for other in group:
				if other["row"] == row:
					if other["id"] == actor["id"]: row_index = row_count
					row_count += 1
			var x := (row_index - (row_count - 1) / 2.0) * 2.2
			var z := (3.15 if row == "back" else 1.55) * (1 if side == "ALLY" else -1)
			var location := Vector3(x, 1.1, z)
			var shadow := MeshInstance3D.new()
			var disk := CylinderMesh.new()
			disk.top_radius = 0.53
			disk.bottom_radius = 0.53
			disk.height = 0.02
			shadow.mesh = disk
			shadow.material_override = _material(Color(0.02, 0.02, 0.04, 0.55), true)
			shadow.position = Vector3(x, 0.01, z)
			units.add_child(shadow)
			if ResourceLoader.exists(actor["sprite"]):
				var sheet: Texture2D = load(actor["sprite"])
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(0, 0, sheet.get_width() / 9.0, sheet.get_height() / 6.0)
				var sprite := Sprite3D.new()
				sprite.texture = atlas
				sprite.pixel_size = 2.2 / float(sheet.get_height() / 6.0)
				sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sprite.no_depth_test = false
				sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				sprite.position = location
				units.add_child(sprite)
				unit_sprites.append(sprite)
			var plate := Label3D.new()
			plate.text = "%s · %d/%d" % [actor["name"], actor["hp"], actor["max_hp"]]
			plate.font_size = 36
			plate.pixel_size = 0.006
			plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			plate.position = Vector3(x, 2.55, z)
			units.add_child(plate)

func _make_3d_card(index: int, card: Dictionary, definition: Dictionary) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(320, 480)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_hosts.add_child(view)
	var panel := ColorRect.new()
	panel.color = Color("28314a")
	panel.size = Vector2(320, 480)
	view.add_child(panel)
	var trim := ColorRect.new()
	trim.color = Color("c49f60")
	trim.position = Vector2(12, 12)
	trim.size = Vector2(296, 456)
	panel.add_child(trim)
	var interior := ColorRect.new()
	interior.color = Color("202943")
	interior.position = Vector2(18, 18)
	interior.size = Vector2(284, 444)
	panel.add_child(interior)
	var owner: Dictionary = battle.actor_by_id(card["owner"])
	var title := _label(definition["name"], 26, Color("f2dcad"))
	title.position = Vector2(35, 30)
	title.size = Vector2(250, 75)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(title)
	var owner_label := _label(str(owner.get("name", "")) + " · " + str(definition.get("class", "")), 20)
	owner_label.position = Vector2(35, 105)
	panel.add_child(owner_label)
	var symbol := _label("✦", 90, Color("ad9273"))
	symbol.position = Vector2(122, 170)
	panel.add_child(symbol)
	var description := _label(_card_description(definition, card), 18)
	description.position = Vector2(35, 280)
	description.size = Vector2(250, 160)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)
	var face := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.14, 1.72)
	face.mesh = plane
	var material := _material(Color.WHITE, true)
	material.albedo_texture = view.get_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = material
	face.position = Vector3((index - (battle.hand.size() - 1) / 2.0) * 1.1, 0.92, 6.6)
	face.rotation_degrees.x = -18
	cards_3d.add_child(face)
	card_meshes.append(face)
	var hit_area := Area3D.new()
	hit_area.set_meta("card_index", index)
	face.add_child(hit_area)
	var hit_shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = Vector3(1.14, 1.72, 0.13)
	hit_shape.shape = solid
	hit_area.add_child(hit_shape)
	_add_box(Vector3(0, 0, -0.035), Vector3(1.18, 1.76, 0.055), Color("151b30"), face)

func _unhandled_input(input: InputEvent) -> void:
	if battle == null or battle.phase != "PLAYER" or not input is InputEventMouseButton:
		return
	var click := input as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var origin := camera.project_ray_origin(click.position)
	var end := origin + camera.project_ray_normal(click.position) * 80.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("collider") and hit["collider"].has_meta("card_index"):
		_select_card(int(hit["collider"].get_meta("card_index")))
		get_viewport().set_input_as_handled()

func _card_description(definition: Dictionary, card: Dictionary = {}) -> String:
	var parts: Array[String] = []
	if definition.get("quick", false): parts.append("RÁPIDA: devolve ação no KO")
	if definition.get("free", false): parts.append("LIVRE")
	if definition.get("final", false): parts.append("FINAL: herói encerra ações")
	if definition.get("exhaust", false): parts.append("EXAURE ao jogar")
	if definition.has("roulette"): parts.append("ROULETTE: sorteia efeito ao comprar")
	if definition.has("full_combo"): parts.append("COMBO COMPLETO: todos os acertos no mesmo alvo")
	if definition.get("reach", false): parts.append("ALCANCE")
	if definition.get("chain", 0) > 0: parts.append("CHAIN %d" % definition["chain"])
	if definition.get("cost", 0) > 0: parts.append("−%d Ímpeto" % definition["cost"])
	if definition.get("gain", 0) > 0: parts.append("+%d Ímpeto" % definition["gain"])
	for effect in definition.get("effects", []):
		match effect["kind"]:
			"STATUS": parts.append("%s (%d turno(s), %d carga(s))" % [str(effect["id"]).replace("_", " ").capitalize(), effect.get("duration", 1), effect.get("stacks", 1)])
			"DAMAGE": parts.append("Dano base %d + atributo" % int(effect.get("amount", 0)))
			"HEAL": parts.append("Cura %d" % int(effect.get("amount", 0)))
			"BLOCK": parts.append("Bloqueio %d" % int(effect.get("amount", 0)))
			"SHIELD": parts.append("Escudo %d" % int(effect.get("amount", 0)))
			"DRAW": parts.append("Compra %d" % int(effect.get("amount", 1)))
			"GENERATE": parts.append("Cria %s (temporária)" % Content.CARDS.get(effect.get("id", ""), {}).get("name", "carta"))
			"PUSH": parts.append("Empurra%s" % (" com força" if effect.get("forceful", false) else ""))
			"PULL": parts.append("Puxa")
			"CURE": parts.append("Remove estados negativos")
			"NEXT_TURN": parts.append("Efeito no próximo turno")
			"INFECT": parts.append("Infecta uma carta")
			_: parts.append("%s %s" % [effect["kind"], str(effect.get("amount", effect.get("id", "")))])
	if card.has("roulette_effect"):
		var chosen: Dictionary = card["roulette_effect"]
		parts.append("SORTEADO: %s %s" % [chosen.get("kind", ""), str(chosen.get("amount", chosen.get("id", "")))])
	if card.get("infected", false): parts.append("INFECTADA: recebe 1 Sangramento ao jogar")
	return " · ".join(PackedStringArray(parts))

func _process(delta: float) -> void:
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		camera.position = Vector3(0, 11.5, 18) + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), 0)
	else:
		camera.position = Vector3(0, 11.5, 18)
	for i in range(unit_sprites.size()):
		if is_instance_valid(unit_sprites[i]):
			unit_sprites[i].position.y = 1.1 + sin(Time.get_ticks_msec() * 0.002 + i) * 0.045
	for index in range(min(card_meshes.size(), card_hit_areas.size())):
		if not is_instance_valid(card_meshes[index]) or not is_instance_valid(card_hit_areas[index]): continue
		var target_y := 1.18 if selected_card == index else 0.92
		card_meshes[index].position.y = lerpf(card_meshes[index].position.y, target_y, delta * 8)
		card_meshes[index].rotation_degrees.y = lerpf(card_meshes[index].rotation_degrees.y, 0.0 if selected_card == index else (index - (card_meshes.size() - 1) / 2.0) * 2.0, delta * 8)

func _save_config() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "team", team)
	config.set_value("game", "equipped", equipped)
	config.set_value("game", "improvements", improvements)
	config.set_value("game", "loadout", loadout)
	config.set_value("settings", "shake_enabled", shake_enabled)
	config.set_value("settings", "music_volume", music_volume)
	config.save("user://hotn3.cfg")

func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load("user://hotn3.cfg") == OK:
		var saved_team: Array = config.get_value("game", "team", team)
		if saved_team.size() == int(Content.RULES["team_size"]):
			team.clear()
			for id in saved_team:
				if Content.HEROES.has(id): team.append(id)
		equipped = config.get_value("game", "equipped", {})
		improvements = config.get_value("game", "improvements", {})
		loadout = config.get_value("game", "loadout", loadout)
		shake_enabled = bool(config.get_value("settings", "shake_enabled", shake_enabled))
		music_volume = float(config.get_value("settings", "music_volume", music_volume))
