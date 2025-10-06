extends CharacterBody2D

@onready var Interaction_Area = $Interaction
@onready var Interact_Btn = $Button
@onready var state_text = $Label
@onready var nav_agent = $NavigationAgent2D
@onready var timer = $Timer
@onready var Dialog_Bubble = $Dialog
@onready var Dialog_Text = $Dialog/Label
@onready var spawn = $Spawner
@onready var resource_manager: ResourceSpawnManager = $"../ResourceSpawner"
@onready var resource_search = $Search
@export var speed: float = 100

var current_resource_point: Node2D = null
var base_position: Vector2
var resources_collected: int = 0
var player_in_area: bool = false
var working_time: float = 0.0
var random_working_time: float = 0.0
var current_action: String = ""
var action_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	Interact_Btn.visible = false
	Dialog_Bubble.visible = false
	base_position = global_position
	
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	
	update_state_text("Ready")



# Condition Functions
func check_player_interaction() -> bool:
	return player_in_area and Interact_Btn.visible

# Action Functions (return "success" when completed, "running" when still working)
# Modifikasi fungsi find_resource_point
func find_resource_point() -> String:
	if resource_search:
		var active_points = resource_search.get_overlapping_areas().is_in_group("ResourcePoint")
		var nearest_point 
		var min_distance = INF
		for point in active_points:
			if is_instance_valid(point) and point.is_available():
				var distance = search_position.distance_to(point.global_position)
				if distance < min_distance and distance <= max_distance:
					min_distance = distance
					nearest_point = point
		if nearest_point:
			current_resource_point = nearest_point
			current_action = "move_to_resource"
			action_target = nearest_point.global_position
			update_state_text("Found Resource")
			return "success"
	
	update_state_text("No Resources")
	return "failure"

func move_to_resource() -> String:
	if current_resource_point == null:
		return "failure"
	
	var distance = global_position.distance_to(current_resource_point.global_position)
	
	if distance < 10.0:
		update_state_text("Reached Resource")
		return "success"
	
	current_action = "move_to_resource"
	action_target = current_resource_point.global_position
	update_state_text("Moving to Resource")
	return "running"

func work_at_resource() -> String:
	if working_time == 0.0:
		random_working_time = randf_range(3.0, 5.0)
		working_time = random_working_time
		
		# Ambil resource dari point
		if current_resource_point and current_resource_point.has_method("take_resource"):
			if current_resource_point.take_resource():
				resources_collected = randi() % 10 + 1
				update_state_text("Working: %.1fs" % working_time)
			else:
				# Resource point sudah tidak tersedia
				update_state_text("Resource Gone")
				return "failure"
	
	working_time -= get_physics_process_delta_time()
	
	if working_time <= 0.0:
		update_state_text("Work Finished")
		working_time = 0.0
		current_resource_point = null
		return "success"
	
	current_action = "work_at_resource"
	update_state_text("Working: %.1fs" % working_time)
	return "running"

func return_to_base() -> String:
	var distance = global_position.distance_to(base_position)
	
	if distance < 10.0:
		update_state_text("Returned to Base")
		return "success"
	
	current_action = "return_to_base"
	action_target = base_position
	update_state_text("Returning to Base")
	return "running"

func report_results() -> String:
	show_dialog()
	update_state_text("Reported Results")
	# Reset untuk siklus berikutnya
	player_in_area = false
	Interact_Btn.visible = false
	return "success"

func patrol_randomly() -> String:
	if current_action != "patrol_randomly" or global_position.distance_to(action_target) < 10.0:
		# Pilih titik patroli baru
		action_target = base_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		current_action = "patrol_randomly"
	
	var distance = global_position.distance_to(action_target)
	if distance < 10.0:
		return "success"
	
	update_state_text("Patrolling")
	return "running"

func wait_at_position() -> String:
	if working_time == 0.0:
		working_time = randf_range(2.0, 4.0)
		current_action = "wait_at_position"
	
	working_time -= get_physics_process_delta_time()
	
	if working_time <= 0.0:
		working_time = 0.0
		update_state_text("Waiting Finished")
		return "success"
	
	update_state_text("Waiting: %.1fs" % working_time)
	return "running"

func handle_movement():
	if current_action in ["move_to_resource", "return_to_base", "patrol_randomly"]:
		nav_agent.target_position = action_target
		
		if nav_agent.is_navigation_finished():
			velocity = Vector2.ZERO
			return
		
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_pos)
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

func update_state_text(state_name: String):
	state_text.text = state_name

func show_dialog():
	Dialog_Text.text = "Kita dapat %d resource boss!" % resources_collected
	Dialog_Bubble.visible = true
	spawn.spawn_item(resources_collected)
	
	var timer_dialog = Timer.new()
	timer_dialog.wait_time = 3.0
	timer_dialog.one_shot = true
	add_child(timer_dialog)
	timer_dialog.start()
	await timer_dialog.timeout
	Dialog_Bubble.visible = false
	timer_dialog.queue_free()

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_area = true
		Interact_Btn.visible = true

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_area = false
		Interact_Btn.visible = false

func _on_button_pressed() -> void:
	# Button press akan terdeteksi oleh check_player_interaction
	pass
