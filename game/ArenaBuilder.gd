extends RefCounted
class_name HotNArenaBuilder

static func build(stage: Node3D, theme: String, view_mode: String) -> void:
	clear(stage)
	if theme == "street_night":
		_build_street(stage, view_mode)
	else:
		_build_default(stage, view_mode)

static func clear(stage: Node3D) -> void:
	if stage == null:
		return
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()

static func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

static func _box(stage: Node3D, pos: Vector3, size: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, unshaded)
	node.position = pos
	stage.add_child(node)
	return node

static func _row_guides(stage: Node3D, view_mode: String) -> void:
	var tint := Color("e9b949")
	if view_mode == "lateral":
		# Divisórias entre as quatro colunas da vista lateral. Elas seguem Z,
		# portanto aparecem como separadores entre as fileiras com a câmera em +Z.
		for x in [-3.0, 0.0, 3.0]:
			_box(stage, Vector3(x, 0.015, 0), Vector3(0.075, 0.05, 12.0), tint, true)
	else:
		for z in [-3.3, -1.7, 1.7, 3.3]:
			_box(stage, Vector3(0, -0.02, z), Vector3(17, 0.04, 0.035), tint, true)

static func _build_default(stage: Node3D, view_mode: String) -> void:
	_box(stage, Vector3(0, -0.30, 0), Vector3(19, 0.5, 12), Color("353c47"))
	_row_guides(stage, view_mode)
	for x in [-9.1, 9.1]:
		for z in [-5.5, 5.5]:
			_box(stage, Vector3(x, 1.75, z), Vector3(0.75, 3.5, 0.75), Color("555169"))
			_box(stage, Vector3(x, 3.5, z), Vector3(1.1, 0.3, 1.1), Color("c8ac76"))

static func _build_street(stage: Node3D, view_mode: String) -> void:
	_box(stage, Vector3(0, -0.32, 0), Vector3(22, 0.45, 14), Color("1a1d28"))
	_row_guides(stage, view_mode)
	_box(stage, Vector3(0, -0.06, 0), Vector3(7.2, 0.08, 13.5), Color("2a2e38"))
	for z in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_box(stage, Vector3(0, -0.01, z), Vector3(0.35, 0.02, 0.9), Color("c9b56a"))
	_box(stage, Vector3(-5.1, -0.04, 0), Vector3(2.6, 0.08, 13.5), Color("3a3f4d"))
	_box(stage, Vector3(5.1, -0.04, 0), Vector3(2.6, 0.08, 13.5), Color("3a3f4d"))
	for i in range(4):
		var z := -5.2 + i * 3.4
		var height := 3.2 + (i % 2) * 1.4
		_box(stage, Vector3(-8.6, height * 0.5, z), Vector3(2.4, height, 3.0), Color("3d3552") if i % 2 == 0 else Color("2f3548"))
		_box(stage, Vector3(8.6, height * 0.5 + 0.2, z), Vector3(2.4, height + 0.4, 3.0), Color("45355a") if i % 2 == 0 else Color("32384a"))
		for window_y in [0.9, 1.9, 2.9]:
			if window_y > height - 0.3:
				continue
			_box(stage, Vector3(-7.35, window_y, z - 0.7), Vector3(0.08, 0.45, 0.55), Color("ffd27a"))
			_box(stage, Vector3(-7.35, window_y, z + 0.7), Vector3(0.08, 0.45, 0.55), Color("ffb86b"))
			_box(stage, Vector3(7.35, window_y, z - 0.7), Vector3(0.08, 0.45, 0.55), Color("9ad7ff"))
			_box(stage, Vector3(7.35, window_y, z + 0.7), Vector3(0.08, 0.45, 0.55), Color("ff9ad0"))
	for x in [-4.0, 4.0]:
		for z in [-4.5, 0.0, 4.5]:
			_box(stage, Vector3(x, 1.1, z), Vector3(0.12, 2.2, 0.12), Color("4a4e5c"))
			_box(stage, Vector3(x, 2.25, z), Vector3(0.55, 0.12, 0.55), Color("c8ac76"))
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 2.15, z)
			lamp.light_color = Color("ffd2a0")
			lamp.light_energy = 1.6
			lamp.omni_range = 6.5
			stage.add_child(lamp)
	_box(stage, Vector3(0, 3.4, -6.4), Vector3(6.5, 0.7, 0.35), Color("6b1f4a"))
	_box(stage, Vector3(0, 3.4, -6.2), Vector3(5.8, 0.45, 0.12), Color("ff4f9a"))
