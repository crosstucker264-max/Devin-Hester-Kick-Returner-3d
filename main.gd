extends Node3D

func _ready():
	print("TEST: script is running")
	var camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.position = Vector3(0, 5, 10)
	camera.look_at(Vector3.ZERO)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 0, 0)
	add_child(light)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.4, 1.0)
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(2, 2, 2)
	mesh.mesh = box
	add_child(mesh)
	print("TEST: everything added")
