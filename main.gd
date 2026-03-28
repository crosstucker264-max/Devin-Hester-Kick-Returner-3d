extends Node3D

var player
var camera
var speed = 10.0
var label
var cam_height = 5.2
var cam_dist = 9.7
var cam_side = 2.5
var player_facing = Vector3(0, 0, 1)

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
	player.position = Vector3(-0.5, ground_y, 28)  # returner start position

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	player.add_child(col)
	player.add_child(_make_player_mesh(Color(0.8, 0.1, 0.1)))
	add_child(player)

func _create_other_players():
	# Field runs diagonally in world space — compute real field directions
	# Based on measured end zone positions: near (3,41) → far (-24,-65)
	var near_end = Vector3(3, 0, 41)
	var far_end = Vector3(-24, 0, -65)
	var field_fwd = (far_end - near_end).normalized()           # points upfield
	var field_right = Vector3(-field_fwd.z, 0, field_fwd.x)   # points across field to the right

	var returner_pos = Vector3(-0.5, ground_y, 28)

	# Blockers (white) — 10 players at the receiving team's 40-yard line
	var blocker_center = returner_pos + field_fwd * 36
	blocker_center.y = ground_y
	for i in range(10):
		var offset = (i - 4.5) * 4.5
		var pos = blocker_center + field_right * offset
		pos.y = ground_y
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.9, 0.9, 0.9)))
		add_child(p)

	# Coverage (blue) — 10 players at the receiving team's 45-yard line
	var coverage_center = returner_pos + field_fwd * 41
	coverage_center.y = ground_y
	for i in range(10):
		var offset = (i - 4.5) * 4.5
		var pos = coverage_center + field_right * offset
		pos.y = ground_y
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.1, 0.2, 0.8)))
		add_child(p)

	# Kicker (blue) — alone at center, at the kicking team's 35-yard line
	var kicker_pos = returner_pos + field_fwd * 63
	kicker_pos.y = ground_y
	var kicker = StaticBody3D.new()
	kicker.position = kicker_pos
	kicker.add_child(_make_player_mesh(Color(0.1, 0.2, 0.8)))
	add_child(kicker)

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

	# Get camera forward and right directions (ignore Y axis)
	var cam_forward = -camera.global_transform.basis.z
	var cam_right = camera.global_transform.basis.x
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	if Input.is_action_pressed("ui_up"):
		dir += cam_forward
	if Input.is_action_pressed("ui_down"):
		dir -= cam_forward
	if Input.is_action_pressed("ui_left"):
		dir -= cam_right
	if Input.is_action_pressed("ui_right"):
		dir += cam_right

	# Camera sits at fixed offset behind player — no rotation, no feedback loop
	camera.position = player.position + Vector3(cam_side, cam_height, cam_dist)
	camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)

	# Player moves based on camera forward/right
	player.velocity = dir * speed
	player.move_and_slide()

	# Show position and camera info on screen
	var p = player.position
	label.text = "X: %.1f  Y: %.1f  Z: %.1f\nArrow keys = move player" % [p.x, p.y, p.z]
