extends Node3D
class_name HotNPresentation

var camera: Camera3D
var overlay: Control
var sound
var sprites: Dictionary = {}
var positions: Dictionary = {}
var camera_origin := Vector3(0, 11.5, 18)
var camera_position := Vector3(0, 11.5, 18)
var camera_tween: Tween
var shake_time := 0.0
var shake_strength := 0.0
var shake_enabled := true
var shake_scale := 0.5
var flash_enabled := true
var animation_speed := 1.0
var motion_scale := 1.0

func configure(view: Camera3D, labels: Control, audio) -> void:
	camera = view
	overlay = labels
	sound = audio

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
			shake_strength = minf(0.18, 0.035 + float(amount) * 0.004) * shake_scale
			shake_time = 0.18 / animation_speed
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
		sprite.scale = Vector3(1.12, 1.12, 1.12)
		tween.parallel().tween_property(sprite, "scale", Vector3.ONE, 0.22 / animation_speed)

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
	camera_tween = create_tween()
	camera_tween.tween_property(self, "camera_position", camera_origin + Vector3(point.x * 0.16, -0.6, -2.0) * motion_scale, 0.16 / animation_speed)
	camera_tween.tween_interval(0.08 / animation_speed)
	camera_tween.tween_property(self, "camera_position", camera_origin, 0.28 / animation_speed)

func _process(delta: float) -> void:
	if camera != null:
		shake_time = maxf(0.0, shake_time - delta)
		var offset := Vector3.ZERO
		if shake_enabled and shake_time > 0.0:
			offset = Vector3(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength), 0)
		camera.position = camera_position + offset
		camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
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
