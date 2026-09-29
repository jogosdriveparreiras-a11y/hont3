extends Node3D
class_name HotNPresentation

var camera: Camera3D
var overlay: Control
var sound
var sprites: Dictionary = {}
var positions: Dictionary = {}
var camera_origin := Vector3(0, 11.5, 18)
var camera_position := Vector3(0, 11.5, 18)
var orbit := 0.0
var ally_focus := Vector3.ZERO
var punch := Vector3.ZERO
var camera_tween: Tween
var shake_time := 0.0
var shake_strength := 0.0
var shake_enabled := true
var shake_scale := 0.5
var flash_enabled := true
var animation_speed := 1.0
var motion_scale := 1.0
## "normal" (vista atual) | "lateral" (aliados à esquerda).
var view_mode := "normal"
## Zoom da câmera (>1 = mais perto); usado na vista lateral.
var zoom := 1.0
## Ponto de interesse (hover / foco inimigo).
var focus_target := Vector3.ZERO
var fx_player = null
## Se false, não move a câmera (menu/título — evita look_at no boot).
var drive_camera := true

func configure(view: Camera3D, labels: Control, audio, fx = null) -> void:
	camera = view
	overlay = labels
	sound = audio
	fx_player = fx
	if fx_player != null:
		fx_player.configure(self, overlay, sound)

func bind_actor(id: int, sprite: Sprite3D, world_position: Vector3) -> void:
	sprites[id] = sprite
	positions[id] = world_position

func forget_actor(id: int) -> void:
	sprites.erase(id)
	positions.erase(id)

func clear_actors() -> void:
	sprites.clear()
	positions.clear()
	# Abort RM/FX playback before freeing children so tweens cannot touch freed nodes.
	if fx_player != null and fx_player.has_method("stop_active"):
		fx_player.stop_active()
	if camera_tween != null and camera_tween.is_valid():
		camera_tween.kill()
		camera_tween = null
	for child in get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()
	if overlay != null and is_instance_valid(overlay):
		for child in overlay.get_children():
			if str(child.name) in ["PortraitLeft", "PortraitRight"]: continue
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				child.queue_free()
	camera_position = camera_origin
	punch = Vector3.ZERO
	orbit = 0.0
	ally_focus = Vector3.ZERO
	focus_target = Vector3.ZERO
	zoom = 1.0
	shake_time = 0.0

func show_action(kind: String, source_id: int, target_id: int, amount: int) -> void:
	var cues := {"draw": "draw", "redraw": "redraw", "cast": "cast", "counter": "cast", "hit": "hit", "block": "block", "guard": "block", "heal": "heal", "status": "status", "death": "death", "resist": "resist", "immune": "resist", "move": "move", "transform": "cast", "ini_gain": "heal"}
	if cues.has(kind): sound.cue(cues[kind])
	if kind == "draw" or kind == "redraw": return
	if kind == "transform":
		_focus(source_id)
		_animate_sprite(source_id, "cast")
		flash_white(source_id, 0.85 / animation_speed)
		_burst(source_id, Color("e9c891"))
		_burst(source_id, Color("ba9dea"))
		_float_text(source_id, "DESPERTAR", Color("e9c891"))
		_play_preset("summon", source_id)
		_play_preset("buff", source_id)
		# Zoom cinematográfico breve (GameRoot lê estes campos).
		zoom = maxf(zoom, 1.85)
		focus_target = _actor_world_pos(source_id)
		if view_mode != "lateral":
			var point: Vector3 = _actor_world_pos(source_id)
			ally_focus = Vector3(point.x * 0.42, 0.28, 0.0)
	elif kind in ["cast", "counter"]:
		_animate_sprite(source_id, "cast")
		_focus(target_id)
	elif kind == "hit":
		_animate_sprite(target_id, "hit")
		# Flash branco pela duração típica da anim de alvo (~0,45s); play_card_fx pode estender.
		flash_white(target_id, 0.45 / animation_speed)
		if sprites.has(target_id):
			var target_sprite: Sprite3D = sprites[target_id]
			if is_instance_valid(target_sprite) and motion_scale > 0.2:
				target_sprite.set_meta("freeze_until", Time.get_ticks_msec() + int(65.0 / animation_speed))
		if amount > 0:
			_float_damage(target_id, amount)
		_burst(target_id, Color("ec755c"))
		if shake_enabled:
			shake_strength = minf(0.55, 0.10 + float(amount) * 0.014) * shake_scale
			shake_time = 0.36 / animation_speed
	elif kind == "death":
		_float_text(target_id, "CAIU", Color("cfb4ab"))
	elif kind == "heal":
		if amount > 0:
			_float_heal(target_id, amount)
		_burst(target_id, Color("82d9af"))
		_animate_sprite(target_id, "heal")
	elif kind in ["block", "guard", "immune", "resist"]:
		_float_text(target_id, "RESISTIU" if kind in ["resist", "immune"] else "BLOQUEIO", Color("a9d5f4"))
		_animate_sprite(target_id, "guard")
	elif kind == "status":
		_burst(target_id, Color("ba9dea"))
		_animate_sprite(target_id, "status")
		_play_preset("status", target_id)
	elif kind == "ini_gain":
		# Postura: popup verde + foco breve na câmera, depois restaura.
		var msg := "+%d Iniciativa" % maxi(1, amount)
		_spawn_float(target_id, msg, Color("3dff8a"), 34, true)
		_burst(target_id, Color("3dff8a"))
		var prev_focus: Vector3 = focus_target
		var prev_zoom: float = zoom
		var prev_ally: Vector3 = ally_focus
		_focus(target_id)
		focus_target = _actor_world_pos(target_id)
		zoom = maxf(zoom, 1.55)
		if view_mode != "lateral":
			var point: Vector3 = _actor_world_pos(target_id)
			ally_focus = Vector3(point.x * 0.38, 0.22, 0.0)
		var tw := create_tween()
		tw.tween_interval(0.55 / maxf(animation_speed, 0.25))
		tw.tween_callback(func() -> void:
			focus_target = prev_focus
			zoom = prev_zoom
			ally_focus = prev_ally
		)
	if kind == "hit":
		_play_preset("hit", target_id)
	elif kind == "heal":
		_play_preset("heal", target_id)
	elif kind in ["cast", "counter"]:
		_play_preset("cast", source_id)
	elif kind in ["block", "guard"]:
		_play_preset("guard", target_id)

func _animate_sprite(id: int, kind: String) -> void:
	if not sprites.has(id): return
	var sprite: Sprite3D = sprites[id]
	if not is_instance_valid(sprite): return
	var action_rows := {"cast": 1, "hit": 4, "heal": 3, "status": 3, "guard": 2}
	sprite.set_meta("action_row", action_rows.get(kind, 0))
	sprite.set_meta("action_until", Time.get_ticks_msec() + int(250.0 / animation_speed))
	if not flash_enabled: return
	if kind == "hit":
		# Flash branco pleno — duração controlada por flash_white / play_card_fx.
		sprite.modulate = Color(1.35, 1.35, 1.35, 1.0)
	elif kind == "status":
		sprite.modulate = Color("e1d2ff")
		var tween := sprite.create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.22 / animation_speed)
	else:
		sprite.modulate = Color.WHITE
	if kind == "cast":
		var base_s := float(sprite.get_meta("sprite_scale", 1.0))
		var base := Vector3(base_s, base_s, 1.0)
		sprite.scale = base * 1.12
		var tween2 := sprite.create_tween()
		tween2.tween_property(sprite, "scale", base, 0.22 / animation_speed)

func _actor_world_pos(id: int) -> Vector3:
	if sprites.has(id) and is_instance_valid(sprites[id]):
		return sprites[id].global_position
	return positions.get(id, Vector3.ZERO)

func _float_text(id: int, value: String, tint: Color) -> void:
	_spawn_float(id, value, tint, 30, false)

func _float_damage(id: int, amount: int) -> void:
	# Número de dano vermelho flutuante (sombra + outline).
	_spawn_float(id, "−%d" % amount, Color("ff3b3b"), 38, true)

func _float_heal(id: int, amount: int) -> void:
	_spawn_float(id, "+%d" % amount, Color("3dff8a"), 36, true)

func _spawn_float(id: int, value: String, tint: Color, font_size: int, pretty: bool) -> void:
	if (not positions.has(id) and not sprites.has(id)) or overlay == null or camera == null: return
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	if pretty:
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02, 0.95))
		label.add_theme_constant_override("outline_size", 8)
		if ResourceLoader.exists("res://assets/fonts/CardTitle.ttf"):
			label.add_theme_font_override("font", load("res://assets/fonts/CardTitle.ttf"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_pos := camera.unproject_position(_actor_world_pos(id) + Vector3(0, 2.35, 0))
	# leve jitter horizontal para empilhar hits
	base_pos += Vector2(randf_range(-18.0, 18.0), randf_range(-6.0, 6.0))
	label.position = base_pos
	label.pivot_offset = Vector2(40, 16)
	label.scale = Vector2(0.55, 0.55) if pretty else Vector2.ONE
	overlay.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	if pretty:
		tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.12 / animation_speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", label.position + Vector2(0, -72 * motion_scale), 0.85 / animation_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.85 / animation_speed).set_delay(0.25 / animation_speed)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

## Flash branco no sprite do alvo pela duração da anim de hit/alvo.
func flash_white(id: int, duration: float) -> void:
	if not flash_enabled or not sprites.has(id):
		return
	var sprite: Sprite3D = sprites[id]
	if not is_instance_valid(sprite):
		return
	var dur := maxf(0.12, duration)
	sprite.set_meta("flash_until", Time.get_ticks_msec() + int(dur * 1000.0))
	sprite.modulate = Color(1.4, 1.4, 1.4, 1.0)
	var tween := sprite.create_tween()
	# Mantém branco ~80% do tempo, depois volta.
	tween.tween_interval(dur * 0.72)
	tween.tween_property(sprite, "modulate", Color.WHITE, dur * 0.28)

func _burst(id: int, tint: Color) -> void:
	if (not positions.has(id) and not sprites.has(id)) or not flash_enabled: return
	var particles := CPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 0.36 / animation_speed
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 170.0
	particles.gravity = Vector3(0, -2.0, 0)
	particles.initial_velocity_min = 1.6 * motion_scale
	particles.initial_velocity_max = 3.4 * motion_scale
	particles.color = tint
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	particles.mesh = mesh
	particles.position = _actor_world_pos(id) + Vector3(0, 1.2, 0)
	add_child(particles)
	particles.emitting = true
	var cleanup := particles.create_tween()
	cleanup.tween_interval(0.65 / animation_speed)
	cleanup.finished.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _focus(id: int) -> void:
	if camera == null or (not positions.has(id) and not sprites.has(id)) or motion_scale <= 0.0: return
	if camera_tween != null and camera_tween.is_running(): camera_tween.kill()
	var point: Vector3 = _actor_world_pos(id)
	punch = Vector3(point.x * 0.12, -0.15, 0) * motion_scale
	camera_tween = create_tween()
	camera_tween.tween_property(self, "punch", Vector3.ZERO, 0.34 / animation_speed)

func _safe_look_at(target: Vector3, up: Vector3 = Vector3.UP) -> void:
	if camera == null:
		return
	var origin := camera.global_position if camera.is_inside_tree() else camera.position
	var dir := target - origin
	if dir.length_squared() < 1e-6:
		return
	if absf(dir.normalized().dot(up.normalized())) > 0.998:
		target += Vector3(0.05, 0.0, 0.05)
	camera.look_at(target, up)

func _process(delta: float) -> void:
	if camera != null and drive_camera:
		shake_time = maxf(0.0, shake_time - delta)
		var offset := Vector3.ZERO
		if shake_enabled and shake_time > 0.0:
			offset = Vector3(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength), 0)
		if view_mode == "lateral":
			# Vista lateral: câmera FIXA em +Z (FOV/posição estáveis).
			# Zoom/foco movem o mundo (stage+units) em GameRoot — a mão 3D filha
			# da câmera permanece do mesmo tamanho/posição na tela.
			var base := Vector3(0.0, 8.4, 15.2)
			camera.position = base + punch + offset
			_safe_look_at(Vector3(0.0, 1.05, 0.0))
			camera.fov = lerpf(camera.fov, 42.0, 1.0 - exp(-delta * 6.0))
		else:
			var radius := 16.8
			var base := Vector3(sin(orbit) * radius, 11.15, cos(orbit) * radius)
			camera.position = base + ally_focus + punch + offset
			_safe_look_at(Vector3(ally_focus.x * 2.1, 0.75, 0.0))
			camera.fov = lerpf(camera.fov, 51.0, 1.0 - exp(-delta * 6.0))
	for id in sprites:
		var sprite: Sprite3D = sprites[id]
		if not is_instance_valid(sprite): continue
		if Time.get_ticks_msec() < int(sprite.get_meta("freeze_until", 0)): continue
		var columns := int(sprite.get_meta("columns", 1))
		if columns <= 1: continue
		var rows := int(sprite.get_meta("rows", 1))
		var active := Time.get_ticks_msec() < int(sprite.get_meta("action_until", 0))
		var row := mini(rows - 1, int(sprite.get_meta("action_row", 0))) if active else 0
		var col := int(Time.get_ticks_msec() / 85) % 3 + (3 if active else 0)
		col = mini(columns - 1, col)
		var atlas := sprite.texture as AtlasTexture
		if atlas != null:
			var width := atlas.atlas.get_width() / float(columns)
			var height := atlas.atlas.get_height() / float(rows)
			atlas.region = Rect2(col * width, row * height, width, height)

func _play_preset(preset: String, actor_id: int) -> void:
	if fx_player == null or (not positions.has(actor_id) and not sprites.has(actor_id)):
		return
	fx_player.animation_speed = animation_speed
	fx_player.flash_enabled = flash_enabled
	fx_player.play_one(preset, _actor_world_pos(actor_id))

func play_card_fx(definition: Dictionary, source_id: int, target_id: int) -> float:
	if fx_player == null:
		return 0.0
	fx_player.animation_speed = animation_speed
	fx_player.flash_enabled = flash_enabled
	var self_pos: Vector3 = _actor_world_pos(source_id)
	var target_pos: Vector3 = _actor_world_pos(target_id)
	var dur := float(fx_player.play_card_anims(definition, self_pos, target_pos))
	# Flash branco no alvo pela duração da anim_target / hit.
	if target_id != source_id or str(definition.get("target", "")) in ["SELF", "ALLY", "ALL_ALLIES"]:
		flash_white(target_id, maxf(dur, 0.35 / animation_speed))
	return dur
