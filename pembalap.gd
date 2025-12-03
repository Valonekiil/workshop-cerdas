extends CharacterBody2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var avoidance_area: Area2D = $AvoidanceArea  # Area2D untuk menghindari collision

@export var player_name: String
@export var speed: float = 150.0
@export var avoidance_speed: float = 180.0  # Kecepatan saat menghindar

var checkpoints: Array = []
var current_checkpoint_index: int = 0
var current_target: Vector2 = Vector2.ZERO
var is_racing: bool = false

# Untuk collision avoidance
var obstacles_nearby: Array = []

func setup_race(race_checkpoints: Array):
	checkpoints = race_checkpoints
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	
	# Setup avoidance area jika ada
	if avoidance_area:
		avoidance_area.connect("body_entered", _on_thing_nearby)
		avoidance_area.connect("body_exited", _on_thing_gone)
		avoidance_area.connect("area_entered", _on_thing_nearby)
		avoidance_area.connect("area_exited", _on_thing_gone)

func start_racing():
	is_racing = true
	move_to_next_checkpoint()

func stop_racing():
	is_racing = false
	velocity = Vector2.ZERO
	obstacles_nearby.clear()

func move_to_next_checkpoint():
	if not is_racing or current_checkpoint_index >= checkpoints.size():
		return
	
	var checkpoint = checkpoints[current_checkpoint_index]
	current_target = select_random_position_in_area(checkpoint)
	navigation_agent.target_position = current_target

func select_random_position_in_area(area: Area2D) -> Vector2:
	var collision = area.get_node("CollisionShape2D")
	var collision_shape = collision.shape
	var extents = collision_shape.size / 2
	var random_x = randf_range(-extents.x, extents.x)
	var random_y = randf_range(-extents.y, extents.y)
	return area.global_position + Vector2(random_x, random_y)

func _physics_process(delta):
	if not is_racing:
		return
	
	# Update movement
	if navigation_agent.is_navigation_finished():
		checkpoint_reached()
	else:
		var next_path_pos = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_pos)
		
		# Jika ada obstacle di dekat, adjust direction
		if obstacles_nearby.size() > 0:
			direction = adjust_direction_for_avoidance(direction)
			velocity = direction * avoidance_speed
		else:
			velocity = direction * speed
		
		move_and_slide()

func adjust_direction_for_avoidance(original_direction: Vector2) -> Vector2:
	var adjusted_direction = original_direction
	
	for obstacle in obstacles_nearby:
		if is_instance_valid(obstacle):
			# Hindari obstacle dengan group "players" (pemain lain)
			if obstacle.is_in_group("players") and obstacle != self:
				var obstacle_pos = obstacle.global_position
				var to_obstacle = (obstacle_pos - global_position).normalized()
				
				# Cek jika obstacle di depan kita
				var dot_product = original_direction.dot(to_obstacle)
				
				if dot_product > 0.3:  # Obstacle di depan (angle < ~72 derajat)
					# Hitung vektor untuk menghindar
					var perpendicular = Vector2(-original_direction.y, original_direction.x)
					
					# Pilih sisi yang lebih jauh dari obstacle
					var cross_product = (obstacle_pos - global_position).cross(original_direction)
					var avoid_direction = perpendicular * sign(cross_product)
					
					# Gabungkan: 60% arah asli, 40% avoidance
					adjusted_direction = (original_direction * 0.6 + avoid_direction * 0.4).normalized()
					break  # Prioritaskan obstacle pertama
	
	return adjusted_direction.normalized()

func checkpoint_reached():
	current_checkpoint_index += 1
	print(player_name + " telah mencapai cp " + str(current_checkpoint_index))
	
	if current_checkpoint_index >= checkpoints.size():
		# Finish reached
		is_racing = false
		var race_manager = get_tree().current_scene
		if race_manager:
			race_manager.check_finish(self)
			print(player_name + " telah finish")
	else:
		move_to_next_checkpoint()

# Signal handlers untuk avoidance
func _on_thing_nearby(thing):
	if thing != self and thing not in obstacles_nearby:
		# Prioritaskan obstacle dengan group "players"
		if thing.is_in_group("players"):
			obstacles_nearby.insert(0, thing)  # Masukkan di awal
		else:
			obstacles_nearby.append(thing)

func _on_thing_gone(thing):
	if thing in obstacles_nearby:
		obstacles_nearby.erase(thing)

func _on_finish_area_entered(area: Area2D):
	if area.name == "Finish" and is_racing and current_checkpoint_index >= checkpoints.size() - 1:
		var race_manager = get_node("/root/Main/RaceManager") # Sesuaikan path
		if race_manager:
			race_manager.check_finish(self)
