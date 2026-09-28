extends Node3D

# Cenários feitos com geometria do Godot. A área central fica livre para as
# quatro fileiras de atores que GameRoot posiciona em X/Z.
var _random := RandomNumberGenerator.new()
var _weather: Array[Node3D] = []
var _weather_speed := 4.0

func build(theme: String) -> void:
	_random.seed = 2049 + theme.hash()
	match theme:
		"campaign_road": _road()
		"campaign_ritual": _ritual()
		"campaign_eclipse": _eclipse()
		_: _road()

func _process(delta: float) -> void:
	for mote in _weather:
		if not is_instance_valid(mote): continue
		mote.position.y -= delta * _weather_speed
		if mote.position.y < 0.1:
			mote.position.y = _random.randf_range(6.5, 9.0)

func _mat(tint: Color, emissive: bool = false, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.85
	if emissive:
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.9
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _box(at: Vector3, size: Vector3, color: Color, turn: Vector3 = Vector3.ZERO, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _mat(color, glow)
	node.position = at
	node.rotation_degrees = turn
	add_child(node)
	return node

func _cylinder(at: Vector3, radius: float, height: float, color: Color, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = at
	node.rotation_degrees = turn
	add_child(node)
	return node

func _sphere(at: Vector3, radius: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = _mat(color, glow)
	node.position = at
	add_child(node)
	return node

func _ring(at: Vector3, radius: float, color: Color, vertical: bool = false) -> void:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.045
	mesh.outer_radius = radius + 0.045
	node.mesh = mesh
	node.material_override = _mat(color, true)
	node.position = at
	if vertical: node.rotation_degrees.x = 90.0
	add_child(node)

func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)

func _scatter(count: int, color: Color, x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	for i in range(count):
		var x := _random.randf_range(x_min, x_max)
		var z := _random.randf_range(z_min, z_max)
		var w := _random.randf_range(0.18, 0.72)
		_box(Vector3(x, w * 0.13, z), Vector3(w, w * 0.26, w * 0.7), color.darkened(_random.randf_range(0.0, 0.25)), Vector3(0, _random.randf_range(0.0, 180.0), 0))

func _particles(color: Color, count: int, speed: float, rain: bool) -> void:
	_weather_speed = speed
	for i in range(count):
		var x := _random.randf_range(-10.0, 10.0)
		var y := _random.randf_range(0.5, 8.0)
		var z := _random.randf_range(-8.0, 7.0)
		var mote := _box(Vector3(x, y, z), Vector3(0.018, 0.34, 0.018) if rain else Vector3(0.045, 0.045, 0.045), color)
		_weather.append(mote)

func _foundation(color: Color) -> void:
	_box(Vector3(0, -0.42, 0), Vector3(23, 0.8, 16), color)
	for x in [-11.4, 11.4]:
		_box(Vector3(x, 0.25, 0), Vector3(0.55, 1.0, 16), color.lightened(0.08))

func _road() -> void:
	_foundation(Color("242d36"))
	# Estrada de placas desiguais, sarjetas e barrancos laterais.
	for i in range(11):
		var z := -7.2 + i * 1.44
		for lane in [-1, 1]:
			var x := float(lane) * 2.4
			_box(Vector3(x, -0.06 + float(i % 3) * 0.008, z), Vector3(4.6, 0.09, 1.35), Color("545965").darkened(float((i + lane + 3) % 3) * 0.04))
		_box(Vector3(0, -0.012, z), Vector3(0.07, 0.025, 1.25), Color("77766a"))
	for side in [-1, 1]:
		var x := float(side) * 7.4
		_box(Vector3(x, -0.05, 0), Vector3(3.4, 0.22, 16), Color("3c3d3a"))
		_scatter(24, Color("6b6559"), x - 1.3, x + 1.3, -7.0, 7.0)
		for z in [-6.3, -1.8, 2.8, 6.3]:
			# Pilares de guarda com argolas e lanternas.
			_box(Vector3(x, 1.45, z), Vector3(0.65, 2.9, 0.65), Color("626478"))
			_box(Vector3(x, 3.05, z), Vector3(0.95, 0.32, 0.95), Color("9d8870"))
			_ring(Vector3(x, 2.7, z), 0.35, Color("c99a60"), true)
			_sphere(Vector3(x, 3.42, z), 0.24, Color("ffbb66"), true)
			_light(Vector3(x, 3.3, z), Color("ffc687"), 0.65, 4.3)
		# Troncos, raízes e uma cerca partida ao fundo.
		for z in [-5.4, 0.7, 5.2]:
			_cylinder(Vector3(x + side * 2.5, 1.0, z), 0.24, 2.2, Color("2a332b"))
			_sphere(Vector3(x + side * 2.5, 2.6, z), 1.0, Color("293b33"))
			_sphere(Vector3(x + side * 2.9, 2.2, z + 0.4), 0.65, Color("334539"))
	_box(Vector3(-8.6, 0.55, -4.1), Vector3(2.7, 0.18, 1.4), Color("57473c"), Vector3(0, 18, 0))
	for x in [-9.65, -7.55]:
		_cylinder(Vector3(x, 0.30, -4.1), 0.36, 0.25, Color("252628"), Vector3(90, 0, 0))
	_box(Vector3(0, 0.22, -7.65), Vector3(4.0, 0.35, 0.38), Color("5d4851"))
	for x in [-1.65, 1.65]:
		_box(Vector3(x, 1.45, -7.65), Vector3(0.48, 2.5, 0.48), Color("77717c"))
	_particles(Color("a4c4d0"), 65, 6.5, true)
	_light(Vector3(0, 5.0, -7.0), Color("7893ca"), 1.5, 15.0)

func _ritual() -> void:
	_foundation(Color("211d29"))
	_box(Vector3(0, -0.09, 0), Vector3(19, 0.16, 13.8), Color("39313c"))
	for radius in [2.8, 4.4, 6.1]:
		_ring(Vector3(0, 0.065, 0), radius, Color("ad5b52"))
	for i in range(12):
		var angle := float(i) * TAU / 12.0
		var center := Vector3(cos(angle) * 5.2, 0.08, sin(angle) * 5.2)
		var outer := Vector3(cos(angle) * 6.2, 0.08, sin(angle) * 6.2)
		_box((center + outer) * 0.5, Vector3(0.14, 0.04, 0.75), Color("bb6a50"), Vector3(0, -rad_to_deg(angle) - 90.0, 0), true)
	for side in [-1, 1]:
		var x := float(side) * 8.35
		for z in [-5.8, -1.9, 1.9, 5.8]:
			_cylinder(Vector3(x, 2.2, z), 0.53, 4.4, Color("514650"))
			_box(Vector3(x, 4.4, z), Vector3(1.25, 0.45, 1.25), Color("6d5860"))
			_box(Vector3(x, 4.68, z), Vector3(0.55, 0.06, 0.55), Color("de7970"), Vector3.ZERO, true)
			for rune in range(3):
				_ring(Vector3(x, 1.0 + rune * 1.1, z), 0.5, Color("8f81b0"))
			_sphere(Vector3(x, 5.0, z), 0.35, Color("e9a47b"), true)
			_light(Vector3(x, 4.75, z), Color("d87a66"), 1.3, 5.0)
	_scatter(32, Color("5b4e50"), -10.2, -6.5, -6.9, 6.9)
	_scatter(32, Color("5b4e50"), 6.5, 10.2, -6.9, 6.9)
	# Capela destruída ao fundo: traves, degraus e vitral fragmentado.
	for step in range(4):
		_box(Vector3(0, step * 0.22 - 0.08, -6.75 - step * 0.36), Vector3(8.5 - step * 0.6, 0.34, 0.65), Color("6a5961"))
	for x in [-4.0, 4.0]:
		_box(Vector3(x, 2.1, -8.1), Vector3(0.65, 4.2, 0.65), Color("4d3c50"))
	_box(Vector3(0, 4.2, -8.1), Vector3(8.7, 0.56, 0.62), Color("574157"))
	_box(Vector3(0, 2.6, -8.28), Vector3(3.1, 2.5, 0.14), Color("703f60"), Vector3.ZERO, true)
	_particles(Color("e5b99a"), 40, 0.85, false)
	_light(Vector3(0, 6, -3), Color("9c78bb"), 1.5, 15.0)

func _eclipse() -> void:
	_foundation(Color("171929"))
	_cylinder(Vector3(0, -0.285, 0), 8.5, 0.55, Color("4a4757"))
	_cylinder(Vector3(0, -0.08, 0), 7.3, 0.16, Color("777186"))
	for radius in [3.4, 5.1, 7.0]:
		_ring(Vector3(0, 0.018, 0), radius, Color("b28c72"))
	for i in range(14):
		var angle := float(i) * TAU / 14.0
		var x := cos(angle) * 9.65
		var z := sin(angle) * 7.3
		_cylinder(Vector3(x, 2.25, z), 0.43, 4.3, Color("99909b"))
		_box(Vector3(x, 4.46, z), Vector3(1.12, 0.35, 1.12), Color("6c616d"))
		_sphere(Vector3(x, 4.78, z), 0.25, Color("a996c1"), true)
	for z in [-5.9, 5.9]:
		for x in [-6.0, 6.0]:
			_box(Vector3(x, 0.65, z), Vector3(1.9, 0.26, 1.5), Color("554f66"), Vector3(0, 20, 0))
			_cylinder(Vector3(x, 1.65, z), 0.6, 1.8, Color("8f8190"), Vector3(0, 0, 18))
	# Mecanismo astronômico e eclipse à distância da área jogável.
	_cylinder(Vector3(8.7, 2.4, -4.8), 0.43, 4.3, Color("54444d"), Vector3(0, 0, 22))
	_cylinder(Vector3(8.9, 4.5, -5.0), 0.55, 4.0, Color("a77b66"), Vector3(0, 0, 68))
	for radius in [1.2, 1.7, 2.15]:
		_ring(Vector3(0, 6.2, -14.0), radius, Color("d47a62"), true)
	_sphere(Vector3(0, 6.2, -14.0), 1.45, Color("090b18"))
	_light(Vector3(0, 6.0, -11.0), Color("ec9574"), 2.7, 23.0)
	for x in [-9.0, 9.0]:
		for z in [-4.2, 0.0, 4.2]:
			_sphere(Vector3(x, 0.42, z), 0.43, Color("b07993"), true)
			_light(Vector3(x, 1.4, z), Color("a58bc7"), 0.65, 4.0)
	_scatter(26, Color("80747b"), -10.4, -7.6, -7.0, 7.0)
	_scatter(26, Color("80747b"), 7.6, 10.4, -7.0, 7.0)
	_particles(Color("cf98ad"), 38, 0.65, false)
