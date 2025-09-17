extends CharacterBody2D

@export var tilemap:TileMap
@onready var navigation_agent:NavigationAgent2D = $NavigationAgent2D
const SPEED = 300.0
var target_position
var distance_to
var input_vector: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if target_position and distance_to > 5 :
		distance_to = global_position.distance_to(target_position)
		navigation_agent.target_position = target_position
		var direction = to_local(navigation_agent.get_next_path_position()).normalized()
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
		target_position = null
	
	move_and_slide()

func handle_movement_input():
	# Reset input vector
	input_vector = Vector2.ZERO
	
	# Check WASD keys
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1
	
	# Normalize vector for diagonal movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
	
	# Apply velocity
	velocity = input_vector * SPEED

func _input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#set_target(get_global_mouse_position())
	if event is InputEventScreenTouch and event.pressed:
		set_target(event.position)

func set_target(pos:Vector2):
	var tile_pos = tilemap.local_to_map(pos)
	# Periksa apakah tile memiliki collision
	var tile_data = tilemap.get_cell_tile_data(0, tile_pos)
	if tile_data and tile_data.get_collision_polygons_count(0) > 0:
		print("Tile memiliki collision, tidak dapat bergerak ke sini")
		return
	target_position = tilemap.map_to_local(tile_pos)
	distance_to = global_position.distance_to(target_position)
