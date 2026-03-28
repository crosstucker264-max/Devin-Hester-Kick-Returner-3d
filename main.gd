extends Node3D

var player
var camera
var speed = 10.0

func _ready():
	_create_field()
	_create_player()
	_create_camera()
	_create_lighting()

func _create_field():
	# Green grass surface
	var field = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(53.3, 120.0)
	field.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.45, 0.13)
	field.material_override = mat
	add_child(field)

	# White yard lines every 5 yards
	for i in range(-10, 11):
		var line = MeshInstance3D.new()
		var lmesh = PlaneMesh.new()
		lmesh.size = Vector2(53.3, 0.2)
		line.mesh = lmesh
		var lmat = StandardMaterial3D.new()
		lmat.albedo_color = Color(1, 1, 1)
		line.material_override = lmat
		line.position = Vector3(0, 0.01, i * 5.0)
		add_child(line)

func _create_player():
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1, 40)

	# Player body (capsule shape)
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	player.add_child(col)

	# Player visual (red jersey)
	var mesh = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	mesh.mesh = cap
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.8, 0.1, 0.1)
	mesh.material_override = pmat
	player.add_child(mesh)

	add_child(player)

func _create_camera():
	camera = Camera3D.new()
	camera.position = Vector3(0, 5, 55)
	camera.rotation_degrees = Vector3(-15, 0, 0)
	add_child(camera)

func _create_lighting():
	# Sun light
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.2
	add_child(light)

	# Ambient sky
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	env.sky = sky
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

	# Camera follows player
	camera.position = player.position + Vector3(0, 5, 15)
	camera.look_at(player.position, Vector3.UP)
