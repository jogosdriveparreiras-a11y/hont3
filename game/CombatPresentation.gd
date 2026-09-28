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

func configure(view: Camera3D, labels: Control, audio, fx = null) -> void:
	camera = view
	overlay = labels
	sound = audio
	fx_player = fx
	if fx_player != null:
		fx_player.configure(self, overlay)

func bind_actor(id: int, sprite: Sprite3D, world_position: Vector3) -> void:
	sprites[id] = sprite
	positions[id] = world_position

func forget_actor(id: int) -> void:
	sprites.erase(id)
	positions.erase(id)

func clear_actors() -> void:
	sprites.clear()
	positions.clear()
	for child in get_children(): child.queue_free()
	if overlay != null:
		for child in overlay.get_children():
			if str(child.name) in ["PortraitLeft", "PortraitRight"]: continue
			child.queue_free()
	camera_position = camera_origin
	punch = Vector3.ZERO
	orbit = 0.0
	ally_focus = Vector3.ZERO
	focus_target = Vector3.ZERO
	zoom = 1.0
	shake_time = 0.0

func show_action(kind: String, source_id: int, target_id: int, amount: int) -> void:
	var cues := {"draw": "draw", "redraw": "redraw", "cast": "cast", "counter": "cast", "hit": "hit", "block": "block", "guard": "block", "heal": "heal", "status": "status", "death": "death", "resist": "resist", "immune": "resist", "move": "move"}
	if cues.has(kind): sound.cue(cues[kind])
	if kind == "draw" or kind == "redraw": return
	if kind in ["cast", "counter"]:
		_animate_sprite(source_id, "cast")
		_focus(target_id)
	elif kind == "hit":
		_animate_sprite(target_id, "hit")
		if sprites.has(target_id):
			var target_sprite: Sprite3D = sprites[target_id]
			if is_instance_valid(target_sprite) and motion_scale > 0.2:
				target_sprite.set_meta("freeze_until", Time.get_ticks_msec() + int(65.0 / animation_speed))
		_float_text(target_id, "−%d" % amount, Color("ffd49b"))
		_burst(target_id, Color("ec755c"))
		if shake_enabled:
			shake_strength = minf(0.55, 0.10 + float(amount) * 0.014) * shake_scale
			shake_time = 0.36 / animation_speed
	elif kind == "death":
		_float_text(target_id, "CAIU", Color("cfb4ab"))
	elif kind == "heal":
		if amount > 0: _float_text(target_id, "+%d" % amount, Color("a3eec4"))
		_burst(target_id, Color("82d9af"))
		_animate_sprite(target_id, "heal")
	elif kind in ["block", "guard", "immune", "resist"]:
		_float_text(target_id, "RESISTIU" if kind in ["resist", "immune"] else "BLOQUEIO", Color("a9d5f4"))
		_animate_sprite(target_id, "guard")
	elif kind == "status":
		_burst(target_id, Color("ba9dea"))
		_animate_sprite(target_id, "status")
		_play_preset("status", target_id)
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
	sprite.modulate = Color("ffdddd") if kind == "hit" else Color("e1d2ff") if kind == "status" else Color("ffffff")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.22 / animation_speed)
	if kind == "cast":
		var base_s := float(sprite.get_meta("sprite_scale", 1.0))
		var base := Vector3(base_s, base_s, 1.0)
		sprite.scale = base * 1.12
		tween.parallel().tween_property(sprite, "scale", base, 0.22 / animation_speed)

func _float_text(id: int, value: String, tint: Color) -> void:
	if not positions.has(id) or overlay == null or camera == null: return
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 29)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = camera.unproject_position(positions[id] + Vector3(0, 2.35, 0))
	overlay.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -55 * motion_scale), 0.55 / animation_speed)
	tween.tween_property(label, "modulate:a", 0.0, 0.55 / animation_speed)
	tween.chain().tween_callback(label.queue_free)

func _burst(id: int, tint: Color) -> void:
	if not positions.has(id) or not flash_enabled: return
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
	particles.position = positions[id] + Vector3(0, 1.2, 0)
	add_child(particles)
	particles.emitting = true
	var cleanup := create_tween()
	cleanup.tween_interval(0.65 / animation_speed)
	cleanup.finished.connect(particles.queue_free)

func _focus(id: int) -> void:
	if camera == null or not positions.has(id) or motion_scale <= 0.0: return
	if camera_tween != null and camera_tween.is_running(): camera_tween.kill()
	var point: Vector3 = positions[id]
	punch = Vector3(point.x * 0.12, -0.15, 0) * motion_scale
	camera_tween = create_tween()
	camera_tween.tween_property(self, "punch", Vector3.ZERO, 0.34 / animation_speed)

func _process(delta: float) -> void:
	if camera != null:
		shake_time = maxf(0.0, shake_time - delta)
		var offset := Vector3.ZERO
		if shake_enabled and shake_time > 0.0:
			offset = Vector3(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength), 0)
		if view_mode == "lateral":
			# Vista lateral verdadeira (câmera em -X): fileiras em X ficam esquerda→direita;
			# linhas amarelas longas em Z permanecem horizontais na tela.
			var z := clampf(zoom, 1.0, 2.4)
			var dist := 16.0 / z
			var height := 7.6 / sqrt(z)
			var look := Vector3(focus_target.x * 0.35, 1.05, focus_target.z * 0.25)
			var base := Vector3(-dist, height, focus_target.z * 0.2)
			camera.position = base + punch + offset
			camera.look_at(look, Vector3.UP)
			camera.fov = lerpf(camera.fov, 42.0 / (0.55 + 0.45 * z), 1.0 - exp(-delta * 6.0))
		else:
			var radius := 16.8
			var base := Vector3(sin(orbit) * radius, 11.15, cos(orbit) * radius)
			camera.position = base + ally_focus + punch + offset
			camera.look_at(Vector3(ally_focus.x * 2.1, 0.75, 0.0), Vector3.UP)
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
	if fx_player == null or not positions.has(actor_id):
		return
	fx_player.animation_speed = animation_speed
	fx_player.flash_enabled = flash_enabled
	fx_player.play_one(preset, positions[actor_id])

func play_card_fx(definition: Dictionary, source_id: int, target_id: int) -> float:
	if fx_player == null:
		return 0.0
	fx_player.animation_speed = animation_speed
	fx_player.flash_enabled = flash_enabled
	var self_pos: Vector3 = positions.get(source_id, Vector3.ZERO)
	var target_pos: Vector3 = positions.get(target_id, self_pos)
	return float(fx_player.play_card_anims(definition, self_pos, target_pos))
