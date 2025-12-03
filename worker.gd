extends CharacterBody2D

@onready var Interaction_Area = $Interaction
@onready var Interact_Btn = $Button
@onready var state_text = $Label
@onready var nav_agent = $NavigationAgent2D
@onready var Dialog_Bubble = $Dialog
@onready var Dialog_Text = $Dialog/Label
@onready var spawn = $Spawner
@onready var resource_manager: ResourceSpawnManager = $"../ResourceSpawner"
@onready var search_area: Area2D = $Search

@export var speed: float = 100
@export var max_work_duration: float = 15.0  # Durasi maksimal kerja (60 detik)

var current_resource_point: Node2D = null
var base_position: Vector2
var resources_collected: int = 0
var player_in_area: bool = false
var working_time: float = 0.0
var random_working_time: float = 0.0
var current_action: String = ""
var action_target: Vector2 = Vector2.ZERO

enum BehaviorStatus { SUCCESS, FAILURE, RUNNING }
var current_behavior: String = "idle"
var work_commanded: bool = false

var search_duration: float = 0.0
var max_search_time: float = 15.0
var is_searching: bool = false

# Variabel untuk durasi kerja
var work_duration: float = 0.0  # Sisa durasi kerja
var current_work_session_duration: float = 0.0  # Total durasi sesi kerja saat ini

func _ready() -> void:
	Interact_Btn.visible = false
	Dialog_Bubble.visible = false
	base_position = global_position
	
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	
	call_deferred("setup_navigation")
	update_state_text("Ready")

func setup_navigation():
	nav_agent.target_position = global_position

func _physics_process(delta: float) -> void:
	execute_behavior_tree()
	handle_movement()
	
	# Update durasi kerja jika sedang bekerja
	if work_commanded and work_duration > 0:
		work_duration -= delta
		update_duration_progress()
		
		# Cek jika durasi habis
		if work_duration <= 0:
			on_work_duration_completed()
	
	move_and_slide()

func execute_behavior_tree():
	var report_status = execute_report_behavior()
	if report_status == BehaviorStatus.SUCCESS:
		return
	
	var work_status = execute_work_behavior()
	
	if work_status == BehaviorStatus.RUNNING:
		return
	elif work_status == BehaviorStatus.SUCCESS:
		current_behavior = "idle"
		work_commanded = false
		if player_in_area:
			Interact_Btn.visible = true
		return
	
	execute_idle_behavior()

func execute_report_behavior() -> BehaviorStatus:
	if not (player_in_area and Interact_Btn.visible and resources_collected > 0):
		return BehaviorStatus.FAILURE
	
	show_dialog()
	update_state_text("Reported Results")
	player_in_area = false
	Interact_Btn.visible = false
	resources_collected = 0
	current_behavior = "idle"
	work_commanded = false
	
	return BehaviorStatus.SUCCESS

func execute_work_behavior() -> BehaviorStatus:
	if not work_commanded or work_duration <= 0:
		return BehaviorStatus.FAILURE
	
	Interact_Btn.visible = false
	
	match current_behavior:
		"find_resource":
			return find_resource_behavior()
		"move_to_resource":
			return move_to_resource_behavior()
		"work_at_resource":
			return work_at_resource_behavior()
		"return_to_base":
			return return_to_base_behavior()
		_:
			current_behavior = "find_resource"
			return BehaviorStatus.RUNNING

func find_resource_behavior() -> BehaviorStatus:
	if is_searching:
		search_duration += get_physics_process_delta_time()
	
	print("🔍 Search duration: ", search_duration, "s | Searching: ", is_searching)
	
	if is_searching and search_duration >= max_search_time:
		update_state_text("Search Timeout - No Resources")
		print("⏰ Search timeout after ", search_duration, " seconds")
		
		resources_collected = 1
		current_behavior = "return_to_base"
		current_action = "return_to_base"
		is_searching = false
		
		return BehaviorStatus.RUNNING
	
	if resource_manager:
		var radius = search_area.get_child(0).shape.radius
		var nearest_point = resource_manager.get_nearest_resource_point(global_position, radius)
		if nearest_point:
			current_resource_point = nearest_point
			current_behavior = "move_to_resource"
			current_action = "move_to_resource"
			action_target = nearest_point.global_position
			
			update_state_text("Found Resource!")
			return BehaviorStatus.RUNNING
	
	update_state_text("Searching... %.1fs" % search_duration)
	return BehaviorStatus.RUNNING

func move_to_resource_behavior() -> BehaviorStatus:
	if current_resource_point == null or not is_instance_valid(current_resource_point):
		current_behavior = "find_resource"
		is_searching = true
		return BehaviorStatus.FAILURE
	
	var distance = global_position.distance_to(current_resource_point.global_position)
	
	if distance < 10.0:
		current_behavior = "work_at_resource"
		current_action = "work_at_resource"
		update_state_text("Reached Resource")
		return BehaviorStatus.RUNNING
	
	action_target = current_resource_point.global_position
	current_action = "move_to_resource"
	update_state_text("Moving to Resource")
	return BehaviorStatus.RUNNING

func work_at_resource_behavior() -> BehaviorStatus:
	if working_time == 0.0:
		random_working_time = randf_range(3.0, 5.0)
		working_time = random_working_time
		
		if current_resource_point and current_resource_point.has_method("take_resource"):
			if current_resource_point.take_resource():
				resources_collected = randi() % 10 + 1
				update_state_text("Working: %.1fs" % working_time)
			else:
				current_behavior = "find_resource"
				current_action = ""
				is_searching = true
				update_state_text("Resource Gone - Searching Again")
				return BehaviorStatus.FAILURE
	
	working_time -= get_physics_process_delta_time()
	
	if working_time <= 0.0:
		working_time = 0.0
		current_resource_point = null
		current_behavior = "return_to_base"
		current_action = "return_to_base"
		update_state_text("Work Finished")
		return BehaviorStatus.RUNNING
	
	current_action = "work_at_resource"
	update_state_text("Working: %.1fs" % working_time)
	return BehaviorStatus.RUNNING

func return_to_base_behavior() -> BehaviorStatus:
	var distance = global_position.distance_to(base_position)
	
	if distance < 10.0:
		current_behavior = "idle"
		current_action = ""
		is_searching = false
		
		if player_in_area:
			Interact_Btn.visible = true
		
		return BehaviorStatus.SUCCESS
	
	action_target = base_position
	current_action = "return_to_base"
	update_state_text("Returning to Base")
	return BehaviorStatus.RUNNING

func execute_idle_behavior():
	if not work_commanded:
		match current_behavior:
			"patrol":
				patrol_behavior()
			"wait":
				wait_behavior()
			_:
				if randf() > 0.5:
					current_behavior = "patrol"
				else:
					current_behavior = "wait"

func patrol_behavior():
	if current_action != "patrol" or global_position.distance_to(action_target) < 10.0:
		action_target = base_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		current_action = "patrol"
	
	var distance = global_position.distance_to(action_target)
	if distance < 10.0:
		current_behavior = "wait"
	
	update_state_text("Patrolling")

func wait_behavior():
	if working_time == 0.0:
		working_time = randf_range(2.0, 4.0)
		current_action = "wait"
	
	working_time -= get_physics_process_delta_time()
	
	if working_time <= 0.0:
		working_time = 0.0
		current_behavior = "patrol"
		current_action = ""
		update_state_text("Waiting Finished")
	else:
		update_state_text("Waiting: %.1fs" % working_time)

func _on_button_pressed() -> void:
	if player_in_area:
		if current_behavior == "idle" or current_behavior == "patrol" or current_behavior == "wait":
			work_commanded = true
			current_behavior = "find_resource"
			current_action = ""
			Interact_Btn.visible = false
			
			# Set durasi kerja
			work_duration = max_work_duration
			current_work_session_duration = max_work_duration
			
			# Reset search duration
			search_duration = 0.0
			is_searching = true
			
			
			update_state_text("Commanded to Work!")
			print("🎯 Work commanded - Starting search (Duration: %.1fs)" % work_duration)

func on_work_duration_completed():
	print("⏰ Work duration completed!")
	work_commanded = false
	
	if current_behavior == "work_at_resource" or current_behavior == "move_to_resource" or current_behavior == "find_resource":
		current_behavior = "return_to_base"
		current_action = "return_to_base"
		current_resource_point = null
		update_state_text("Time's up! Returning to base")
	

func update_duration_progress():
	
	if current_behavior != "idle" and current_behavior != "patrol" and current_behavior != "wait":
		state_text.text += " (Time left: %.1fs)" % work_duration

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_area = true
		if not work_commanded and resources_collected == 0:
			Interact_Btn.visible = true
		elif resources_collected > 0:
			Interact_Btn.visible = true

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_area = false
		Interact_Btn.visible = false

func handle_movement():
	if current_action in ["patrol", "move_to_resource", "return_to_base"]:
		nav_agent.target_position = action_target
		
		if nav_agent.is_navigation_finished():
			velocity = Vector2.ZERO
			return
		
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = (next_path_pos - global_position).normalized()
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
