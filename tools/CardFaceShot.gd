extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(900, 1200))
	await process_frame
	var out := ProjectSettings.globalize_path("res://playtest_out/ux20260928")
	DirAccess.make_dir_recursive_absolute(out)

	var PackBridge = load("res://game/PackBridge.gd")
	var packs = PackBridge.new()
	packs.merge_into_content()
	var Content = load("res://game/Content.gd")
	var CardFace = load("res://game/CardFace.gd")

	var hero_id := "ent_madelyn"
	var hero: Dictionary = Content.HEROES.get(hero_id, {})
	var card_id := ""
	for cid in Content.CARDS.keys():
		var d: Dictionary = Content.CARDS[cid]
		if str(d.get("name", "")).to_lower().find("disparo") >= 0:
			card_id = str(cid)
			break
	if card_id == "":
		for cid in hero.get("iniciais", []):
			card_id = str(cid)
			break
	var definition: Dictionary = Content.CARDS.get(card_id, {})
	var owner := {
		"name": str(hero.get("name", "Madelyn")),
		"type": str(hero.get("type", "BRUTO")),
		"portrait": str(hero.get("portrait", "")),
		"sprite": str(hero.get("sprite", "")),
		"signature_icon": str(hero.get("signature_icon", "")),
		"hp": 24,
		"attack": 8,
		"power": 0,
		"archetype": hero_id,
	}

	var view := SubViewport.new()
	view.size = Vector2i(420, 640)
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var holder := ColorRect.new()
	holder.color = Color("101527")
	holder.size = Vector2(420, 640)
	view.add_child(holder)

	var art: Texture2D = null
	if ResourceLoader.exists(str(owner["portrait"])):
		art = load(str(owner["portrait"]))
	elif ResourceLoader.exists(str(owner["sprite"])):
		art = load(str(owner["sprite"]))
	var icon: Texture2D = null
	if ResourceLoader.exists(str(owner["signature_icon"])):
		icon = load(str(owner["signature_icon"]))
	var type_colors := {
		"BRUTO": Color("c44536"),
		"TECNICO": Color("3d7ea6"),
		"MYSTIC": Color("8b5cf6"),
		"QUIMICO": Color("2ec4b6"),
	}
	var border: Color = type_colors.get(str(owner["type"]), Color("8d929a"))
	var face = CardFace.new()
	face.size = Vector2(400, 620)
	face.position = Vector2(10, 10)
	face.setup({
		"title": str(definition.get("name", "Disparo inesperado")),
		"chip": str(owner["name"]),
		"item": false,
		"desvantagem": false,
		"art": art,
		"icon": icon,
		"border": border,
		"show_damage": true,
		"stat_label": "IMPACTO",
		"stat_value": 8,
		"stat_color": Color.WHITE,
		"rules": "Alvo: inimigo\n• Adiciona o State [b]Marcado[/b] por 1 turno(s)",
		"gain": 1,
		"cost": 0,
		"dead": false,
		"shield_icon": load("res://assets/ui/impact_shield_sword.png") if ResourceLoader.exists("res://assets/ui/impact_shield_sword.png") else null,
	})
	view.add_child(face)
	for i in range(30):
		await process_frame
	await create_timer(0.35).timeout

	var img: Image = view.get_texture().get_image()
	if img == null:
		img = root.get_viewport().get_texture().get_image()
	if img == null:
		img = DisplayServer.screen_get_image(0)
	if img == null:
		push_error("FAIL no image from SubViewport/screen")
		quit(1)
		return
	img.save_png(out.path_join("cardface_madelyn_proof.png"))
	print("saved cardface_madelyn_proof.png ", img.get_width(), "x", img.get_height())
	print("OK: CardFaceShot card=", card_id, " type=", owner["type"], " border=", border)
	quit(0)
