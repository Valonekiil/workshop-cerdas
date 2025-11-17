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

var current_resource_point: Node2D = null
var base_position: Vector2
var resources_collected: int = 0
var player_in_area: bool = false
var working_time: float = 0.0
var random_working_time: float = 0.0
var current_action: String = ""
var action_target: Vector2 = Vector2.ZERO

# 🎯 BEHAVIOR TREE STATES
enum BehaviorStatus { SUCCESS, FAILURE, RUNNING }
var current_behavior: String = "idle"

func _ready() -> void:
	Interact_Btn.visible = false
	Dialog_Bubble.visible = false
	base_position = global_position
	
	# 🎯 FIX NAVIGATION SETUP
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	
	# 🎯 TUNGGU SEHINGGA NAVIGATION READY
	call_deferred("setup_navigation")
	
	update_state_text("Ready")

func setup_navigation():
	# 🎯 SET TARGET POSITION AWAL BIAR NAV_AGENT READY
	nav_agent.target_position = global_position

func _physics_process(delta: float) -> void:
	# 🎯 EXECUTE BEHAVIOR TREE
	execute_behavior_tree()
	
	handle_movement()
	move_and_slide()

# 🎯 SIMPLE BEHAVIOR TREE SYSTEM
func execute_behavior_tree():
	# 🎯 SELECTOR: Coba behavior berurutan sampai ada yang success
	if execute_report_behavior() == BehaviorStatus.SUCCESS:
		return
	elif execute_work_behavior() == BehaviorStatus.RUNNING:
		return
	elif execute_work_behavior() == BehaviorStatus.SUCCESS:
		current_behavior = "idle"  # Reset ke idle setelah work selesai
		return
	else:
		execute_idle_behavior()

# 🎯 BEHAVIOR 1: REPORT KE PLAYER (Priority Tertinggi)
func execute_report_behavior() -> BehaviorStatus:
	# Condition: Ada player dan ada resources untuk di-report
	if not (player_in_area and Interact_Btn.visible and resources_collected > 0):
		return BehaviorStatus.FAILURE
	
	# Action: Report results
	show_dialog()
	update_state_text("Reported Results")
	player_in_area = false
	Interact_Btn.visible = false
	resources_collected = 0
	current_behavior = "idle"  # Kembali ke idle setelah report
	
	return BehaviorStatus.SUCCESS

# 🎯 BEHAVIOR 2: WORK CYCLE (Priority Menengah)
func execute_work_behavior() -> BehaviorStatus:
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
			# Start work cycle
			current_behavior = "find_resource"
			return BehaviorStatus.RUNNING

# 🎯 SUB-BEHAVIORS UNTUK WORK CYCLE
func find_resource_behavior() -> BehaviorStatus:
	if resource_manager:
		var radius = search_area.get_child(0).shape.radius
		var nearest_point = resource_manager.get_nearest_resource_point(global_position, radius)
		if nearest_point:
			current_resource_point = nearest_point
			current_behavior = "move_to_resource"
			current_action = "move_to_resource"  # 🎯 PASTIKAN CURRENT_ACTION DI-SET!
			action_target = nearest_point.global_position
			update_state_text("Found Resource")
			return BehaviorStatus.RUNNING
	
	update_state_text("No Resources")
	return BehaviorStatus.FAILURE

func move_to_resource_behavior() -> BehaviorStatus:
	if current_resource_point == null:
		current_behavior = "find_resource"
		return BehaviorStatus.FAILURE
	
	var distance = global_position.distance_to(current_resource_point.global_position)
	
	if distance < 10.0:
		current_behavior = "work_at_resource"
		current_action = "work_at_resource"  # 🎯 UPDATE CURRENT_ACTION
		update_state_text("Reached Resource")
		return BehaviorStatus.RUNNING
	
	action_target = current_resource_point.global_position
	current_action = "move_to_resource"  # 🎯 PASTIKAN SELALU DI-SET!
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
				current_action = ""  # 🎯 RESET ACTION
				update_state_text("Resource Gone")
				return BehaviorStatus.FAILURE
	
	working_time -= get_physics_process_delta_time()
	
	if working_time <= 0.0:
		working_time = 0.0
		current_resource_point = null
		current_behavior = "return_to_base"
		current_action = "return_to_base"  # 🎯 UPDATE ACTION
		update_state_text("Work Finished")
		return BehaviorStatus.RUNNING
	
	current_action = "work_at_resource"
	update_state_text("Working: %.1fs" % working_time)
	return BehaviorStatus.RUNNING

func return_to_base_behavior() -> BehaviorStatus:
	var distance = global_position.distance_to(base_position)
	
	if distance < 10.0:
		current_behavior = "idle"  # Work cycle selesai
		current_action = ""  # 🎯 RESET ACTION
		update_state_text("Returned to Base")
		return BehaviorStatus.SUCCESS
	
	action_target = base_position
	current_action = "return_to_base"  # 🎯 PASTIKAN DI-SET!
	update_state_text("Returning to Base")
	return BehaviorStatus.RUNNING

# 🎯 BEHAVIOR 3: IDLE BEHAVIORS (Priority Terendah)
func execute_idle_behavior():
	match current_behavior:
		"patrol":
			patrol_behavior()
		"wait":
			wait_behavior()
		_:
			# Pilih random idle behavior
			if randf() > 0.5:
				current_behavior = "patrol"
			else:
				current_behavior = "wait"

func patrol_behavior():
	if current_action != "patrol" or global_position.distance_to(action_target) < 10.0:
		action_target = base_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		current_action = "patrol"  # 🎯 PASTIKAN DI-SET!
	
	var distance = global_position.distance_to(action_target)
	if distance < 10.0:
		current_behavior = "wait"  # Switch ke wait setelah patroli
	
	update_state_text("Patrolling")

func wait_behavior():
	if working_time == 0.0:
		working_time = randf_range(2.0, 4.0)
		current_action = "wait"  # 🎯 PASTIKAN DI-SET!
	
	working_time -= get_physics_process_delta_time()
	
	if working_time <= 0.0:
		working_time = 0.0
		current_behavior = "patrol"  # Switch ke patrol setelah wait
		current_action = ""  # 🎯 RESET ACTION
		update_state_text("Waiting Finished")
	else:
		update_state_text("Waiting: %.1fs" % working_time)

# 🎯 FIXED MOVEMENT HANDLER
func handle_movement():
	# 🎯 DEBUG: Print state untuk troubleshooting
	print("Current Action: ", current_action, " | Target: ", action_target)
	
	if current_action in ["patrol", "move_to_resource", "return_to_base"]:
		# 🎯 UPDATE NAV_AGENT TARGET SETIAP FRAME
		nav_agent.target_position = action_target
		
		# 🎯 CEK JIKA SUDAH SAMPAI
		if nav_agent.is_navigation_finished():
			velocity = Vector2.ZERO
			update_state_text("Destination Reached")
			return
		
		# 🎯 DAPATKAN POSISI BERIKUTNYA DARI PATH
		var next_path_pos = nav_agent.get_next_path_position()
		
		# 🎯 HITUNG DIRECTION DAN VELOCITY
		var direction = (next_path_pos - global_position).normalized()
		velocity = direction * speed
		
		# 🎯 DEBUG: Print movement info
		print("Moving to: ", next_path_pos, " | Direction: ", direction, " | Velocity: ", velocity)
	else:
		velocity = Vector2.ZERO
		print("No movement action")

# 🎯 EXISTING FUNCTIONS (TETAP SAMA)
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
	if current_behavior == "idle" or current_action == "patrol" or current_behavior == "wait":
		current_behavior = "find_resource"  # 🎯 LANGSUNG SET BEHAVIOR
