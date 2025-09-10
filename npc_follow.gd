extends CharacterBody2D

@export var target: CharacterBody2D
var SPEED = 100
var target_found: bool
@onready var raycast = $RayCast2D
@onready var Attack_Range: Area2D = $Attack
@onready var Current_State: Label = $Label
@onready var NavAgent: NavigationAgent2D = $NavigationAgent2D

enum Mode {PASIF, AGRESIF}
enum State {PATROL, MENGAWASI, MENGEJAR, INVESTIGASI, MENYERANG, MUNDUR}

var current_mode: Mode = Mode.PASIF
var current_state: State = State.PATROL

var last_known_position: Vector2
var investigation_timer: float = 0.0
var max_investigation_time: float = 6.0
var mengawasi_timer: float = 0.0
var max_mengawasi_time: float = 3.0
var patrol_timer:float = 0
var max_patrol_timer:float = 5.0

@export var idle_path: Path2D
@export var idle_speed: float = 50.0
@export var path_follow: PathFollow2D
var path_progress: float = 0.0
var patrol_direction: int = 1

func _ready():
	update_state_label()
	
	NavAgent.path_desired_distance = 4.0
	NavAgent.target_desired_distance = 4.0

func _physics_process(delta: float) -> void:
	if target:
		raycast.target_position = to_local(target.global_position)
		raycast.force_raycast_update()
		if raycast.is_colliding() and raycast.get_collider() == target:
			target_found = true
			last_known_position = target.global_position
		else:
			target_found = false
	
	match current_mode:
		Mode.PASIF:
			match current_state:
				State.PATROL:
					if idle_path and path_follow:
						if path_follow.progress_ratio >= 0.99:
							patrol_direction = -1
						elif path_follow.progress_ratio <= 0.01:
							patrol_direction = 1
						path_progress += idle_speed * delta * patrol_direction
						path_follow.progress = path_progress
						patrol_timer += delta
						global_position = path_follow.global_position
						velocity = Vector2.ZERO
						if patrol_timer > max_patrol_timer:
							mengawasi_timer = 0
							change_state(State.MENGAWASI)
					else:
						velocity = Vector2.ZERO
					
					if target and target_found:
						change_mode(Mode.AGRESIF)
						change_state(State.MENGEJAR)
				
				State.MENGAWASI:
					velocity = Vector2.ZERO
					mengawasi_timer += delta
					
					if mengawasi_timer >= max_mengawasi_time:
						patrol_timer = 0
						change_state(State.PATROL)
					
					if target and target_found:
						change_mode(Mode.AGRESIF)
						change_state(State.MENGEJAR)
				State.MUNDUR:
					NavAgent.target_position = idle_path.global_position
					var next_path_pos = NavAgent.get_next_path_position()
					var direction = global_position.direction_to(next_path_pos)
					velocity = direction * SPEED
					if target and target_found:
						change_mode(Mode.AGRESIF)
						change_state(State.MENGEJAR)
					if global_position.distance_to(idle_path.global_position) < 0.5:
						change_state(State.PATROL)
		
		Mode.AGRESIF:
			match current_state:
				State.MENGEJAR:
					# State MENGEJAR: Mengejar target
					if target and target_found:
						NavAgent.target_position = target.global_position
						var next_path_pos = NavAgent.get_next_path_position()
						var direction = global_position.direction_to(next_path_pos)
						velocity = direction * SPEED
						
					else:
						velocity = Vector2.ZERO
						
						if target and not target_found:
							change_state(State.INVESTIGASI)
					if not target_found:
						change_state(State.INVESTIGASI)
				
				State.INVESTIGASI:
					investigation_timer += delta
					NavAgent.target_position = last_known_position
					
					var next_path_pos = NavAgent.get_next_path_position()
					var direction = global_position.direction_to(next_path_pos)
					velocity = direction * SPEED * 0.7
					
					if global_position.distance_to(last_known_position) < 1.0:
						velocity = Vector2.ZERO
						
						if investigation_timer >= max_investigation_time:
							change_mode(Mode.PASIF)
							change_state(State.MUNDUR)
					
					if target and target_found:
						change_state(State.MENGEJAR)
				
				State.MENYERANG:
					# State MENYERANG: Menyerang target
					velocity = Vector2.ZERO
					
					if not target_found:
						change_state(State.INVESTIGASI)
	
	move_and_slide()

func change_mode(new_mode: Mode):
	if current_mode != new_mode:
		current_mode = new_mode
		print("Mode berubah ke: ", Mode.keys()[current_mode])
		update_state_label()

func change_state(new_state: State):
	if current_state != new_state:
		current_state = new_state
		print("State berubah ke: ", State.keys()[current_state])
		update_state_label()
		
		if new_state == State.INVESTIGASI:
			investigation_timer = 0.0
		elif new_state == State.MENGAWASI:
			mengawasi_timer = 0.0

func update_state_label():
	if Current_State:
		Current_State.text = Mode.keys()[current_mode] + " - " + State.keys()[current_state]

func _on_area_2d_body_entered(body: Node2D) -> void:
	if target == null and body.is_in_group("Player"):
		target = body
		print("Target ditemukan")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if target == body:
		target = null
		target_found = false
		print("Target hilang")

func _on_attack_body_entered(body: Node2D) -> void:
	if body == target and current_mode == Mode.AGRESIF:
		change_state(State.MENYERANG)

func _on_attack_body_exited(body: Node2D) -> void:
	if body == target and current_state == State.MENYERANG:
		change_state(State.MENGEJAR)
