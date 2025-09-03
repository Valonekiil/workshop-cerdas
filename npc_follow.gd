extends CharacterBody2D

@export var target: CharacterBody2D
var SPEED = 100
var target_found: bool
@onready var raycast = $RayCast2D
@onready var Attack_Range: Area2D = $Attack
@onready var Current_State: Label = $Label
<<<<<<< Updated upstream
=======
@onready var NavAgent: NavigationAgent2D = $NavigationAgent2D
>>>>>>> Stashed changes

# State machine variables
enum State {IDLE, MENGEJAR, MENYERANG}
var current_state = State.IDLE
var attack_cooldown = 1.0  # Waktu antara serangan

func _ready():
	update_state_label()

func _physics_process(delta: float) -> void:
	if target:
		raycast.target_position = to_local(target.global_position)
		raycast.force_raycast_update()
		if raycast.is_colliding() and raycast.get_collider() == target:
			target_found = true
		else:
			target_found = false
	
	match current_state:
		State.IDLE:
			# State Idle: NPC diam
			velocity = Vector2.ZERO
			# Cek jika ada target dalam detection range
			if target and target_found:
				change_state(State.MENGEJAR)
		
		State.MENGEJAR:
			# State Mengejar: NPC mengejar target
			if target_found:
				makepath()
				var direction = to_local(NavAgent.get_next_path_position()).normalized()
				velocity = direction * SPEED
			elif target == null:
				target_found = false
				change_state(State.IDLE)
			else:
				change_state(State.IDLE)
		
		State.MENYERANG:
			# State Menyerang: NPC berhenti dan menyerang
			velocity = Vector2.ZERO
			
			
			# Jika target keluar dari attack range, kembali mengejar
			if not is_target_in_attack_range():
				change_state(State.MENGEJAR)
			if !target_found:
				change_state(State.IDLE)
	
	move_and_slide()

func makepath():
	NavAgent.target_position = target.global_position

func change_state(new_state):
	if current_state != new_state:
		current_state = new_state
		update_state_label()
		print("State berubah ke: ", State.keys()[current_state])

func update_state_label():
	if Current_State:
		Current_State.text = State.keys()[current_state]

func is_target_in_attack_range():
	if target:
		var bodies = Attack_Range.get_overlapping_bodies()
		return bodies.has(target)
	return false

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
	if body == target:
		change_state(State.MENYERANG)

func _on_attack_body_exited(body: Node2D) -> void:
	if body == target:
		change_state(State.MENGEJAR)
