extends Node3D

var player
var camera
var speed = 10.0
var label
var cam_height = 8.0
var cam_dist = 15.0

# Field center offset — adjust if stadium model is off center
var field_center = Vector3(0, 0, 0)
var ground_y = -10.4  # adjust this until players sit on the field

func _ready():
	_load_stadium()
	_create_player()
	_create_other_players()
	_create_camera()
	_create_lighting()
	_create_label()

func _create_label():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 0))
	canvas.add_child(label)

func _load_stadium():
	var stadium_scene = load("res://arabian_knights_football_stadium_arabal.glb")
	if stadium_scene:
		var stadium = stadium_scene.instantiate()
		add_child(stadium)
		await get_tree().process_frame
		_apply_cartoon(stadium)
	else:
		print("ERROR: Could not load stadium file!")

func _apply_cartoon(node):
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(i)
			if mat is StandardMaterial3D:
				var new_mat = mat.duplicate()
				new_mat.albedo_color = new_mat.albedo_color.lightened(0.15)
				new_mat.roughness = 1.0
				new_mat.metallic = 0.0
				node.set_surface_override_material(i, new_mat)
	for child in node.get_children():
		_apply_cartoon(child)

func _make_player_mesh(color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	mesh.mesh = cap
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	return mesh

func _create_player():
	# Returner — red, at the 10 yard line (back of field)
	player = CharacterBody3D.new()
	player.position = Vector3(-1, ground_y, 30)  # returner at 10 yard line, center field

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	player.add_child(col)
	player.add_child(_make_player_mesh(Color(0.8, 0.1, 0.1)))
	add_child(player)

func _create_other_players():
	# Coverage team (blue) — spread across the 40-50 yard line area
	var coverage_positions = [
		Vector3(-21, ground_y, -35), Vector3(-14, ground_y, -35), Vector3(-7,  ground_y, -35),
		Vector3(-1,  ground_y, -35), Vector3(6,   ground_y, -35), Vector3(13,  ground_y, -35),
		Vector3(20,  ground_y, -35), Vector3(-18, ground_y, -45), Vector3(-1,  ground_y, -45),
		Vector3(16,  ground_y, -45), Vector3(-1,  ground_y, -55)
	]
	for pos in coverage_positions:
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.1, 0.2, 0.8)))
		add_child(p)

	# Blockers (white) — spread between returner and coverage
	var blocker_positions = [
		Vector3(-21, ground_y, 10), Vector3(-14, ground_y, 10), Vector3(-7,  ground_y, 10),
		Vector3(-1,  ground_y, 10), Vector3(6,   ground_y, 10), Vector3(13,  ground_y, 10),
		Vector3(20,  ground_y, 10), Vector3(-14, ground_y, 18), Vector3(6,   ground_y, 18),
		Vector3(-1,  ground_y, 18)
	]
	for pos in blocker_positions:
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.9, 0.9, 0.9)))
		add_child(p)

func _create_camera():
	camera = Camera3D.new()
	add_child(camera)

func _create_lighting():
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	add_child(light)

	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 210, 0)
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	add_child(fill)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.65, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.95, 1.0)
	env.ambient_light_energy = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.1
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _physics_process(delta):
	var dir = Vector3.ZERO

	if Input.is_action_pressed("ui_up"):
		dir.z -= 1
	if Input.is_action_pressed("ui_down"):
		dir.z += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1

	player.velocity = dir * speed
	player.move_and_slide()

	# Camera height and distance controls
	if Input.is_key_pressed(KEY_W): cam_height += 0.1
	if Input.is_key_pressed(KEY_S): cam_height -= 0.1
	if Input.is_key_pressed(KEY_Q): cam_dist -= 0.1
	if Input.is_key_pressed(KEY_E): cam_dist += 0.1

	# Camera locked directly behind and above returner, centered on him
	var cam_offset = Vector3(0, cam_height, cam_dist)
	camera.position = player.position + cam_offset
	camera.look_at(player.position, Vector3.UP)

	# Show position and camera info on screen
	var p = player.position
	label.text = "X: %.1f  Y: %.1f  Z: %.1f\nCam Height: %.1f  Cam Dist: %.1f\nW/S = camera up/down  Q/E = closer/further\nArrow keys = move player" % [p.x, p.y, p.z, cam_height, cam_dist]
