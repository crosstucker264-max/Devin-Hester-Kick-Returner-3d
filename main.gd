extends Node3D

var player
var camera
var speed = 10.0
var label
var big_label  # center screen for TOUCHDOWN / TRY AGAIN
var cam_height = 5.2
var cam_dist = 9.7
var cam_side = 2.5

var ground_y = -10.4

# Game phases: overhead, active, touchdown, tackled
var game_phase = "overhead"
var ball_circle = null
var ball_target = Vector3.ZERO
var football = null
var football_start_y = 0.0
var football_fall_time = 0.0
var football_fall_duration = 3.0

# Field direction vectors
var field_fwd = Vector3.ZERO
var field_right = Vector3.ZERO

# Far goal line position (for touchdown detection)
var far_goal_line = Vector3.ZERO

# Coverage: {body, lane_offset, speed, is_blocked, block_timer, block_duration, broke_free}
var coverage_data = []
var coverage_speed = 7.0

# Blockers: {body, target_index}
var blocker_data = []
var blocker_speed = 6.5

func _ready():
	_setup_field_vectors()
	_load_stadium()
	_create_player()
	_create_other_players()
	_create_ball_circle()
	_create_football()
	_create_end_zone_marker()
	_create_camera()
	_create_lighting()
	_create_label()

func _setup_field_vectors():
	var near_end = Vector3(3, 0, 41)
	var far_end = Vector3(-24, 0, -65)
	field_fwd = (far_end - near_end).normalized()
	field_right = Vector3(-field_fwd.z, 0, field_fwd.x)
	var returner_pos = Vector3(-0.5, ground_y, 28)
	far_goal_line = returner_pos + field_fwd * 86

func _create_end_zone_marker():
	var ez_center = far_goal_line + field_fwd * 4.75
	ez_center.y = ground_y + 0.03
	var ez = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(50.0, 0.05, 9.5)
	ez.mesh = box
	ez.position = ez_center
	ez.rotation.y = atan2(field_fwd.x, field_fwd.z)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.2, 0.9, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.3, 1.0)
	mat.emission_energy_multiplier = 0.5
	ez.material_override = mat
	add_child(ez)

func _create_football():
	football = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.9
	football.mesh = sphere
	football.scale = Vector3(1.0, 1.0, 1.4)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.22, 0.07)
	football.material_override = mat
	football_start_y = ground_y + 30.0
	football.position = Vector3(ball_target.x, football_start_y, ball_target.z)
	add_child(football)

func _create_ball_circle():
	var returner_pos = Vector3(-0.5, ground_y, 28)
	var dist_upfield = randf_range(6.0, 20.0)
	var side_offset = randf_range(-8.0, 8.0)
	ball_target = returner_pos + field_fwd * dist_upfield + field_right * side_offset
	ball_target.y = ground_y + 0.05
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

	# Big center label for TOUCHDOWN / TRY AGAIN
	big_label = Label.new()
	big_label.visible = false
	big_label.add_theme_font_size_override("font_size", 72)
	big_label.add_theme_color_override("font_color", Color(1, 1, 1))
	big_label.set_anchors_preset(Control.PRESET_CENTER)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	canvas.add_child(big_label)

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

	# --- BLOCKERS (white) ---
	var b35_center = returner_pos + field_fwd * 36
	b35_center.y = ground_y
	for offset in [-20.0, -11.0, -4.0, 4.0, 11.0, 20.0]:
		var pos = b35_center + field_right * offset
		pos.y = ground_y
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.9, 0.9, 0.9)))
		add_child(p)
		blocker_data.append({"body": p, "target_index": blocker_data.size() % 10})

	var setup_center = returner_pos + field_fwd * 32
	setup_center.y = ground_y
	for offset in [-13.0, 0.0, 13.0]:
		var pos = setup_center + field_right * offset
		pos.y = ground_y
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.9, 0.9, 0.9)))
		add_child(p)
		blocker_data.append({"body": p, "target_index": blocker_data.size() % 10})

	# --- COVERAGE (blue) — with lane discipline and random block durations ---
	var coverage_center = returner_pos + field_fwd * 41
	coverage_center.y = ground_y
	var lane_offsets = [-20.0, -14.0, -9.0, -5.0, -1.5, 1.5, 5.0, 9.0, 14.0, 20.0]
	for i in range(10):
		var offset = lane_offsets[i]
		var pos = coverage_center + field_right * offset
		pos.y = ground_y
		var p = StaticBody3D.new()
		p.position = pos
		p.add_child(_make_player_mesh(Color(0.1, 0.2, 0.8)))
		add_child(p)
		var spd = coverage_speed + 1.5 if abs(offset) >= 18.0 else coverage_speed
		coverage_data.append({
			"body": p,
			"lane_offset": offset,
			"speed": spd,
			"is_blocked": false,
			"block_timer": 0.0,
			"block_duration": randf_range(0.5, 4.0),
			"broke_free": false
		})

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
		camera.position = ball_target + Vector3(0, 22, 0)
		camera.look_at(ball_target, Vector3(0, 0, -1))

		var dir = Vector3.ZERO
		if Input.is_action_pressed("ui_up"):    dir += field_fwd
		if Input.is_action_pressed("ui_down"):  dir -= field_fwd
		if Input.is_action_pressed("ui_left"):  dir -= field_right
		if Input.is_action_pressed("ui_right"): dir += field_right
		player.velocity = dir * speed
		player.move_and_slide()

		football_fall_time = min(football_fall_time + delta, football_fall_duration)
		var t_fall = football_fall_time / football_fall_duration
		var current_y = lerp(football_start_y, ball_target.y + 0.5, t_fall)
		football.position = Vector3(ball_target.x, current_y, ball_target.z)
		football.rotation_degrees.x += 180.0 * delta

		var t = Time.get_ticks_msec() * 0.001
		var pulse = sin(t * 5.0) * 0.3 + 1.0
		ball_circle.scale = Vector3(pulse, 1.0, pulse)
		ball_circle.visible = sin(t * 8.0) > 0.0

		var flat_dist = Vector2(player.position.x - ball_target.x, player.position.z - ball_target.z).length()
		if flat_dist < 2.0:
			_catch_ball()

		label.text = "Ball incoming! Run under the yellow circle!\nArrow keys = move"

	elif game_phase == "active":
		camera.position = player.position + Vector3(cam_side, cam_height, cam_dist)
		camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)

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

		# Blockers run toward their assigned coverage player
		for bdata in blocker_data:
			var b = bdata.body
			var cdata = coverage_data[bdata.target_index]
			# Only pursue if coverage hasn't broken free
			if not cdata.broke_free:
				var to_target = cdata.body.position - b.position
				to_target.y = 0
				if to_target.length() > 1.5:
					b.position += to_target.normalized() * blocker_speed * delta
				else:
					# Close enough — trigger the block
					if not cdata.is_blocked:
						cdata.is_blocked = true
						cdata.block_timer = cdata.block_duration

		# Coverage movement — blocked by white, then break free and chase returner
		for cdata in coverage_data:
			var p = cdata.body

			if cdata.is_blocked:
				# Count down the block — stuck in place
				cdata.block_timer -= delta
				if cdata.block_timer <= 0.0:
					cdata.is_blocked = false
					cdata.broke_free = true
				continue  # can't move while blocked

			# Once free (or unblocked gunners), chase returner with lane discipline
			var to_returner = player.position - p.position
			to_returner.y = 0
			var dist = to_returner.length()

			var blend = clamp(1.0 - dist / 20.0, 0.0, 1.0) if not cdata.broke_free else 1.0
			var move_dir = (-field_fwd).lerp(to_returner.normalized(), blend).normalized()

			if dist > 1.0:
				p.position += move_dir * cdata.speed * delta

			# Check tackle — blue touches red
			if dist < 1.5:
				_tackled()
				return

		# Check touchdown — returner crosses far goal line
		var past_goal = (player.position - far_goal_line).dot(field_fwd)
		if past_goal > 0:
			_touchdown()

		label.text = "Run to the BLUE end zone!\nArrow keys = move"

	elif game_phase == "touchdown" or game_phase == "tackled":
		# Freeze everything — just hold the camera
		camera.position = player.position + Vector3(cam_side, cam_height, cam_dist)
		camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)

func _catch_ball():
	game_phase = "active"
	ball_circle.queue_free()
	ball_circle = null
	football.queue_free()
	football = null

func _touchdown():
	game_phase = "touchdown"
	big_label.visible = true
	big_label.text = "TOUCHDOWN!"
	big_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	label.text = ""

func _tackled():
	game_phase = "tackled"
	big_label.visible = true
	big_label.text = "TACKLED!\nTry Again"
	big_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	label.text = ""
