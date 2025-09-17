extends CharacterBody2D

@onready var Interaction_Area = $Interaction
@onready var Interact_Btn = $Button
@onready var state_text = $Label
@onready var nav_agent = $NavigationAgent2D
@onready var timer = $Timer
@onready var Dialog_Bubble = $Dialog
@onready var Dialog_Text = $Dialog/Label
@export var path:Path2D
@export var path_follow:PathFollow2D
@export var speed: float = 100
@onready var spawn = $Spawner

enum State {IDLE, BEKERJA, LAPORAN_HASIL}
var current_state = State.IDLE

var working_time: float = 0.0
var random_working_time: float = 0.0
var resources_collected: int = 0
var player_in_area: bool = false
var progress_target: float = 0.0

func _ready() -> void:
	#position = path_follow.global_position
	Interact_Btn.visible = false
	Dialog_Bubble.visible = false
	if path_follow:
		path_follow.progress = 0.0
		global_position = path_follow.global_position
	
	update_state_text()

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			progress_target = 0.0
			Interact_Btn.visible = player_in_area
		
		State.BEKERJA:
			progress_target = 1.0
			Interact_Btn.visible = false
			
			if path_follow.progress_ratio >= 0.99:
				if working_time == 0.0:
					random_working_time = randf_range(3.0, 5.0)
					timer.start(random_working_time)
					working_time = random_working_time
					resources_collected = randi() % 10 + 1 
				working_time -= delta
		
		State.LAPORAN_HASIL:
			progress_target = 0.0
			Interact_Btn.visible = false
			if path_follow.progress_ratio <= 0.01:
				show_dialog()
				change_state(State.IDLE)
	
	if path_follow:
		var lerp_speed = speed * delta 
		var current_progress = path_follow.progress_ratio
		var new_progress = lerp(current_progress, progress_target, lerp_speed)
		path_follow.progress_ratio = new_progress
		global_position = path_follow.global_position
	
	move_and_slide()

func change_state(new_state):
	if current_state != new_state:
		current_state = new_state
		update_state_text()
		
		if new_state == State.IDLE:
			working_time = 0.0
		elif new_state == State.BEKERJA:
			working_time = 0.0

func update_state_text():
	match current_state:
		State.IDLE:
			state_text.text = "Idle"
		State.BEKERJA:
			state_text.text = "Bekerja"
		State.LAPORAN_HASIL:
			state_text.text = "Laporan"

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

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_area = false
		Interact_Btn.visible = false

func _on_button_pressed() -> void:
	if current_state == State.IDLE:
		change_state(State.BEKERJA)

func _on_timer_timeout() -> void:
	if current_state == State.BEKERJA:
		change_state(State.LAPORAN_HASIL)
