extends CharacterBody2D
class_name LeaderMarker

@export_group("Movement Settings")
@export var max_speed: float = 200.0
@export var acceleration: float = 400.0

@export_group("Formation Settings") 
@export var formation_type: String = "V" # V, Line, Circle
@export var formation_scale: float = 1.0

# Formasi yang berbeda (offset relatif terhadap leader)
var formations = {
	"V": [
		Vector2(0, -80),    # Front
		Vector2(-60, -40),  # Left flank
		Vector2(60, -40),   # Right flank
		Vector2(-30, 40),   # Left rear
		Vector2(30, 40)     # Right rear
	],
	"Line": [
		Vector2(0, -80),
		Vector2(-50, 0),
		Vector2(50, 0),
		Vector2(-25, 80),
		Vector2(25, 80)
	],
	"Circle": [
		Vector2(0, -60),
		Vector2(-60, 0),
		Vector2(60, 0),
		Vector2(-40, 40),
		Vector2(40, 40)
	]
}

var current_formation: Array
var squad_members: Array = []
var current_velocity: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("leader_marker")
	current_formation = formations[formation_type]
	update_squad_members()

func _physics_process(delta):
	handle_input(delta)
	update_leader_velocity()
	move_and_slide()

func handle_input(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	if input_vector.length() > 0:
		var desired_velocity = input_vector.normalized() * max_speed
		current_velocity = current_velocity.move_toward(desired_velocity, acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, acceleration * delta)

func update_leader_velocity():
	# Adjust speed based on squad members (sesuai teori)
	if squad_members.size() > 0:
		var min_speed = max_speed
		var avg_speed = 0.0
		
		for member in squad_members:
			if is_instance_valid(member) and member.has_method("get_current_speed"):
				var speed = member.get_current_speed()
				avg_speed += speed
				min_speed = min(min_speed, speed)
		
		avg_speed /= squad_members.size()
		
		# Gunakan kecepatan minimum agar unit lambat tidak tertinggal
		max_speed = min_speed * 1.2  # Sedikit lebih cepat dari unit paling lambat

func update_squad_members():
	squad_members = get_tree().get_nodes_in_group("squad_members")

func get_slot_position(slot_index: int) -> Vector2:
	if slot_index < current_formation.size():
		var scaled_offset = current_formation[slot_index] * formation_scale
		return global_position + scaled_offset.rotated(rotation)
	return global_position

func get_formation_size() -> int:
	return current_formation.size()

func change_formation(new_formation: String):
	if formations.has(new_formation):
		formation_type = new_formation
		current_formation = formations[new_formation]
		print("Changed formation to: ", new_formation)

func get_squad_members() -> Array:
	return squad_members
