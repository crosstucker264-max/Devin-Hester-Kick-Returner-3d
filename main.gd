extends Node3D

var player
var camera
var speed = 10.0
var label
var cam_height = 5.2
var cam_dist = 9.7
var cam_side = 2.5

var ground_y = -10.4

# Game phases: "overhead" = waiting to catch, "active" = running with ball
var game_phase = "overhead"
var coverage_players = []
var coverage_speed = 7.0
var ball_circle = null
var ball_target = Vector3.ZERO

# Field direction vectors
var field_fwd = Vector3.ZERO
var field_right = Vector3.ZERO

func _ready():
	_setup_field_vectors()
	_load_stadium()
	_create_player()
	_create_other_players()
	_create_ball_circle()
	_create_camera()
	_create_lighting()
	_create_label()

func _setup_field_vectors():
	var near_end = Vector3(3, 0, 41)
	var far_end = Vector3(-24, 0, -65)
	field_fwd = (far_end - near_end).normalized()
	field_right = Vector3(-field_fwd.z, 0, field_fwd.x)

func _create_ball_circle():
	# Place the ball landing target randomly within the landing zone (goal line to B20)
	# In world units: roughly 4 to 22 units upfield from returner
	var returner_pos = Vector3(-0.5, ground_y, 28)
	var dist_upfield = randf_range(6.0, 20.0)
	var side_offset = randf_range(-8.0, 8.0)
	ball_target = returner_pos + field_fwd * dist_upfield + field_right * side_offset
	ball_target.y = ground_y + 0.05  # just above ground

	# Create a flat glowing ring on the ground
	ball_circle = MeshInstance3D.new()
	var ring = CylinderMesh.new()
	ring.top_radius = 1.8
	ring.bottom_radius = 1.8
	ring.height = 0.1
	ring.rings = 1
	ball_circle.mesh = ring
	ball_circle.position = ball_target

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball_circle.material_override = mat
	add_child(ball_circle)

func _create_label():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 26)
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
	player = CharacterBody3D.new()
	player.position = Vector3(-0.5, ground_y, 28)
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	player.add_child(col)
	player.add_child(_make_player_mesh(Color(0.8, 0.1, 0.1)))
	add_child(player)

func _create_other_players():
	var returner_pos = Vector3(-0.5, ground_y, 28)

	# 6 blockers on B35 restraining line
	var b35_center = returner_pos + field_fwd * 36
	b35_center.y = ground_y
	var b35_offsets = [-20.0, -11.0, -4.0, 4.0, 11.0, 20.0]
	for offset in b35_offsets:
		var pos = b35_center + field_right * offset
		pos.y = ground_y
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.9, 0.9, 0.9)))
		add_child(p)

	# 3 blockers in setup zone
	var setup_center = returner_pos + field_fwd * 32
	setup_center.y = ground_y
	for offset in [-13.0, 0.0, 13.0]:
		var pos = setup_center + field_right * offset
		pos.y = ground_y
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.9, 0.9, 0.9)))
		add_child(p)

	# 10 coverage players at B40 — stored so they move after catch
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
		coverage_players.append(p)

	# Kicker at A35
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
	if game_phase == "overhead":
		# Overhead camera — directly above the landing zone, looking straight down
		var look_center = ball_target + Vector3(0, 0, 6)
		camera.position = look_center + Vector3(0, 45, 0)
		camera.look_at(look_center, Vector3(0, 0, -1))

		# Player can move to get under the circle
		var dir = Vector3.ZERO
		if Input.is_action_pressed("ui_up"):    dir += field_fwd
		if Input.is_action_pressed("ui_down"):  dir -= field_fwd
		if Input.is_action_pressed("ui_left"):  dir -= field_right
		if Input.is_action_pressed("ui_right"): dir += field_right
		player.velocity = dir * speed
		player.move_and_slide()

		# Pulse size and blink visibility
		var t = Time.get_ticks_msec() * 0.001
		var pulse = sin(t * 5.0) * 0.3 + 1.0
		ball_circle.scale = Vector3(pulse, 1.0, pulse)
		ball_circle.visible = sin(t * 8.0) > 0.0

		# Check if player is under the circle — catch the ball!
		var flat_dist = Vector2(player.position.x - ball_target.x, player.position.z - ball_target.z).length()
		if flat_dist < 2.0:
			_catch_ball()

		label.text = "Ball incoming! Run under the yellow circle to catch it!\nArrow keys = move"

	elif game_phase == "active":
		# Third-person camera behind the player
		camera.position = player.position + Vector3(cam_side, cam_height, cam_dist)
		camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)

		# Player moves based on camera direction
		var cam_forward = -camera.global_transform.basis.z
		var cam_right_vec = camera.global_transform.basis.x
		cam_forward.y = 0
		cam_right_vec.y = 0
		cam_forward = cam_forward.normalized()
		cam_right_vec = cam_right_vec.normalized()

		var dir = Vector3.ZERO
		if Input.is_action_pressed("ui_up"):    dir += cam_forward
		if Input.is_action_pressed("ui_down"):  dir -= cam_forward
		if Input.is_action_pressed("ui_left"):  dir -= cam_right_vec
		if Input.is_action_pressed("ui_right"): dir += cam_right_vec
		player.velocity = dir * speed
		player.move_and_slide()

		# Coverage runs straight at the returner
		for p in coverage_players:
			var to_player = player.position - p.position
			to_player.y = 0
			if to_player.length() > 1.0:
				p.position += to_player.normalized() * coverage_speed * delta

		label.text = "Arrow keys = run!  Get past the coverage!"

func _catch_ball():
	game_phase = "active"
	# Remove the circle
	ball_circle.queue_free()
	ball_circle = null
