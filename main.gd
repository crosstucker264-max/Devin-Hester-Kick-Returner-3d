extends Node3D

var player
var camera
var label
var big_label
var stamina_bar_bg
var stamina_bar_fill
var try_again_btn

var cam_height = 5.2
var cam_dist = 9.7
var cam_side = 2.5

var base_speed = 6.0
var sprint_speed = 10.0
var stamina = 100.0
var max_stamina = 100.0
var stamina_drain = 42.0        # drains fast — sprint is precious
var stamina_regen = 16.0
var exhausted = false

# Juke and spin moves — cost stamina instead of cooldowns
var spin_invincible_timer = 0.0
var move_recovery_timer = 0.0
var JUKE_DIST = 1.83            # ~2 yards
var SPIN_DIST = 1.5
var JUKE_COST = 22.0            # stamina cost per juke
var SPIN_COST = 30.0            # stamina cost per spin

# Defense stamina — invisible, lasts 20% longer, empty = 30% speed penalty
var def_drain_rate = 35.0 / 1.2
var def_regen_rate = 15.0
var kicker_stamina = 100.0

var ground_y = -10.4

# Game phases: overhead, active, touchdown, tackled
var game_phase = "overhead"
var ball_circle = null
var ball_target = Vector3.ZERO
var football = null
var football_kick_pos = Vector3.ZERO  # where the ball starts (kicker's feet)
var football_fall_time = 0.0
var football_fall_duration = 3.5
var kicker_body = null
var kicker_speed = 0.0

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
	print("GAME: Starting _ready")
	_setup_field_vectors()
	print("GAME: field vectors done")
	_load_stadium()
	print("GAME: stadium loaded")
	_create_player()
	print("GAME: player created")
	_create_other_players()
	print("GAME: other players created")
	_create_ball_circle()
	print("GAME: ball circle created")
	_create_football()
	print("GAME: football created")
	_create_end_zone_marker()
	print("GAME: end zone created")
	_create_camera()
	print("GAME: camera created")
	_create_lighting()
	print("GAME: lighting created")
	_create_label()
	print("GAME: ALL DONE - ready complete")

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
	# Ball starts at the kicker's position
	football_kick_pos = Vector3(-0.5, ground_y, 28) + field_fwd * 63
	football_kick_pos.y = ground_y + 1.0
	football.position = football_kick_pos
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

	# Stamina label
	var stam_label = Label.new()
	stam_label.position = Vector2(10, 10)
	stam_label.add_theme_font_size_override("font_size", 20)
	stam_label.add_theme_color_override("font_color", Color(1, 1, 1))
	stam_label.text = "STAMINA"
	canvas.add_child(stam_label)

	# Stamina bar background
	stamina_bar_bg = ColorRect.new()
	stamina_bar_bg.position = Vector2(10, 36)
	stamina_bar_bg.size = Vector2(220, 22)
	stamina_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	canvas.add_child(stamina_bar_bg)

	# Stamina bar fill
	stamina_bar_fill = ColorRect.new()
	stamina_bar_fill.position = Vector2(12, 38)
	stamina_bar_fill.size = Vector2(216, 18)
	stamina_bar_fill.color = Color(0.1, 0.9, 0.1)
	canvas.add_child(stamina_bar_fill)

	# Instruction label below the bar
	label = Label.new()
	label.position = Vector2(10, 64)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 0))
	canvas.add_child(label)

	# Big center label for TOUCHDOWN / TACKLED
	big_label = Label.new()
	big_label.visible = false
	big_label.add_theme_font_size_override("font_size", 72)
	big_label.add_theme_color_override("font_color", Color(1, 1, 1))
	big_label.set_anchors_preset(Control.PRESET_CENTER)
	big_label.position.y -= 60
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	canvas.add_child(big_label)

	# Try Again button — shown after touchdown or tackle
	try_again_btn = Button.new()
	try_again_btn.text = "Try Again"
	try_again_btn.visible = false
	try_again_btn.name = "TryAgainBtn"
	try_again_btn.add_theme_font_size_override("font_size", 36)
	try_again_btn.set_anchors_preset(Control.PRESET_CENTER)
	try_again_btn.position.y += 40
	try_again_btn.size = Vector2(200, 60)
	try_again_btn.position.x -= 100
	try_again_btn.pressed.connect(_on_try_again)
	canvas.add_child(try_again_btn)

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
		# Gunners (outer) fastest; inner players slightly faster to cut off gaps
		var spd = coverage_speed
		if abs(offset) >= 18.0:
			spd = coverage_speed + 1.5
		elif abs(offset) <= 3.0:
			spd = coverage_speed + 0.5
		coverage_data.append({
			"body": p,
			"lane_offset": offset,
			"speed": spd,
			"is_blocked": false,
			"block_timer": 0.0,
			"block_duration": randf_range(0.5, 4.0),
			"broke_free": false,
			"stamina": 100.0
		})

	# Kicker at A35 — stored so he can chase after kick
	var kicker_pos = returner_pos + field_fwd * 63
	kicker_pos.y = ground_y
	kicker_body = StaticBody3D.new()
	kicker_body.position = kicker_pos
	kicker_body.add_child(_make_player_mesh(Color(0.1, 0.2, 0.8)))
	add_child(kicker_body)
	kicker_speed = coverage_speed * 0.7  # 70% of coverage speed

func _create_camera():
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	# Set initial position so first frame isn't blank
	camera.position = Vector3(-0.5, ground_y + 22, 28)
	camera.look_at(Vector3(-0.5, ground_y, 28), Vector3(0, 0, -1))

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
		player.velocity = dir * base_speed
		player.move_and_slide()

		# Football arcs from kicker to landing target
		football_fall_time = min(football_fall_time + delta, football_fall_duration)
		var t_fall = football_fall_time / football_fall_duration
		var flat_x = lerp(football_kick_pos.x, ball_target.x, t_fall)
		var flat_z = lerp(football_kick_pos.z, ball_target.z, t_fall)
		var arc_y = ground_y + 1.0 + 22.0 * sin(t_fall * PI)
		football.position = Vector3(flat_x, arc_y, flat_z)
		football.rotation_degrees.x += 360.0 * delta

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

		# Tick effect timers
		spin_invincible_timer = max(spin_invincible_timer - delta, 0.0)
		move_recovery_timer = max(move_recovery_timer - delta, 0.0)

		var dir = Vector3.ZERO
		if Input.is_action_pressed("ui_up"):    dir += cam_forward
		if Input.is_action_pressed("ui_down"):  dir -= cam_forward
		if Input.is_action_pressed("ui_left"):  dir -= cam_right_vec
		if Input.is_action_pressed("ui_right"): dir += cam_right_vec

		# Sprint logic
		var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and stamina > 0 and not exhausted
		if is_sprinting and dir != Vector3.ZERO:
			stamina = max(stamina - stamina_drain * delta, 0.0)
			if stamina == 0.0:
				exhausted = true
		else:
			stamina = min(stamina + stamina_regen * delta, max_stamina)
			if exhausted and stamina >= 25.0:
				exhausted = false

		# Recovery after juke/spin reduces speed briefly
		var recovery_mult = 0.75 if move_recovery_timer > 0.0 else 1.0
		var current_speed = sprint_speed if is_sprinting else base_speed
		player.velocity = dir * current_speed * recovery_mult
		player.move_and_slide()

		# Update stamina bar
		var pct = stamina / max_stamina
		stamina_bar_fill.size.x = 216.0 * pct
		if pct > 0.5:
			stamina_bar_fill.color = Color(0.1, 0.9, 0.1)
		elif pct > 0.25:
			stamina_bar_fill.color = Color(0.95, 0.75, 0.1)
		else:
			stamina_bar_fill.color = Color(0.9, 0.1, 0.1)

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
				cdata.block_timer -= delta
				# Regen stamina while blocked (resting)
				cdata.stamina = min(cdata.stamina + def_regen_rate * delta, 100.0)
				if cdata.block_timer <= 0.0:
					cdata.is_blocked = false
					cdata.broke_free = true
				continue

			# Drain stamina while running
			cdata.stamina = max(cdata.stamina - def_drain_rate * delta, 0.0)
			# 30% speed penalty when stamina is empty
			var effective_speed = cdata.speed if cdata.stamina > 0.0 else cdata.speed * 0.7

			var to_returner = player.position - p.position
			to_returner.y = 0
			var dist = to_returner.length()

			# Inner players (small lane offset) cut off angles — aim ahead of returner
			var target_pos = player.position
			if abs(cdata.lane_offset) <= 3.0 and not cdata.broke_free:
				# Predict where returner will be and cut off the lane
				target_pos = player.position + (player.velocity.normalized() * 3.0)
				target_pos.y = p.position.y

			var to_target = target_pos - p.position
			to_target.y = 0

			var blend = clamp(1.0 - dist / 20.0, 0.0, 1.0) if not cdata.broke_free else 1.0
			var move_dir = (-field_fwd).lerp(to_target.normalized(), blend).normalized()

			if dist > 1.0:
				p.position += move_dir * effective_speed * delta

			if dist < 1.5 and spin_invincible_timer <= 0.0:
				_tackled()
				return

		# Kicker chases at 70% speed, also has invisible stamina
		kicker_stamina = max(kicker_stamina - def_drain_rate * delta, 0.0)
		var effective_kicker_speed = kicker_speed if kicker_stamina > 0.0 else kicker_speed * 0.7
		var to_player_k = player.position - kicker_body.position
		to_player_k.y = 0
		if to_player_k.length() > 1.0:
			kicker_body.position += to_player_k.normalized() * effective_kicker_speed * delta
		elif to_player_k.length() < 1.5 and spin_invincible_timer <= 0.0:
			_tackled()
			return

		# Check touchdown — returner crosses far goal line
		var past_goal = (player.position - far_goal_line).dot(field_fwd)
		if past_goal > 0:
			_touchdown()

		label.text = "Run to the BLUE end zone!\nShift=Sprint  Z=Juke Left  X=Juke Right  C=Spin"

	elif game_phase == "touchdown" or game_phase == "tackled":
		# Freeze everything — just hold the camera
		camera.position = player.position + Vector3(cam_side, cam_height, cam_dist)
		camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)

func _unhandled_key_input(event):
	if game_phase != "active":
		return
	if not event.pressed:
		return
	if event.is_echo():
		return
	var key = event.keycode
	if key == KEY_Z and stamina >= JUKE_COST:
		player.position -= field_right * JUKE_DIST
		stamina -= JUKE_COST
		move_recovery_timer = 0.35
	elif key == KEY_X and stamina >= JUKE_COST:
		player.position += field_right * JUKE_DIST
		stamina -= JUKE_COST
		move_recovery_timer = 0.35
	elif key == KEY_C and stamina >= SPIN_COST:
		player.position -= field_fwd * SPIN_DIST
		stamina -= SPIN_COST
		spin_invincible_timer = 0.45
		move_recovery_timer = 0.2

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
	try_again_btn.visible = true
	label.text = ""

func _tackled():
	game_phase = "tackled"
	big_label.visible = true
	big_label.text = "TACKLED!"
	big_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	try_again_btn.visible = true
	label.text = ""

func _on_try_again():
	get_tree().reload_current_scene()
