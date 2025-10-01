extends CharacterBody2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@export var player_name: String

var checkpoints: Array = []
var current_checkpoint_index: int = 0
var current_target: Vector2 = Vector2.ZERO
var is_racing: bool = false
var speed: float = 150.0

func setup_race(race_checkpoints: Array):
	checkpoints = race_checkpoints
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	

func start_racing():
	is_racing = true
	move_to_next_checkpoint()

func stop_racing():
	is_racing = false
	velocity = Vector2.ZERO

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
		velocity = direction * speed
		move_and_slide()

func checkpoint_reached():
	current_checkpoint_index += 1
	print(player_name + " telah mencapai cp " + str(current_checkpoint_index))
	if current_checkpoint_index >= checkpoints.size() :
		# Finish reached
		is_racing = false
		var race_manager = get_tree().current_scene
		if race_manager:
			race_manager.check_finish(self)
			print(player_name + " telah finish")
	else:
		move_to_next_checkpoint()

func _on_finish_area_entered(area: Area2D):
	if area.name == "Finish" and is_racing and current_checkpoint_index >= checkpoints.size() - 1:
		var race_manager = get_node("/root/Main/RaceManager") # Sesuaikan path
		if race_manager:
			race_manager.check_finish(self)
