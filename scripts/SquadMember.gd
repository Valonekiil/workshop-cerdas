extends CharacterBody2D
class_name SquadMember

@export_group("Unit Properties")
@export var unit_name: String = "Swordsman"
@export var unit_type: String = "Melee"
@export var slot_index: int = 0

@export_group("Movement Settings")
@export var max_speed: float = 150.0
@export var max_acceleration: float = 300.0
@export var arrival_radius: float = 25.0

@export_group("Steering Weights")
@export var slot_seek_weight: float = 2.0
@export var obstacle_avoid_weight: float = 3.0
@export var separation_weight: float = 1.5
@export var cohesion_weight: float = 0.5

var leader: LeaderMarker
var current_velocity: Vector2 = Vector2.ZERO
var steering: Vector2 = Vector2.ZERO
var debug_color: Color

# Ability scores (sesuai tabel di dokumen)
var abilities = {
	"HandToHand": 0,
	"LongDistance": 0, 
	"HeavyWeaponry": 0
}

func _ready():
	leader = get_tree().get_first_node_in_group("leader_marker")
	add_to_group("squad_members")
	setup_abilities()
	setup_debug_color()

func _physics_process(delta):
	if leader and is_instance_valid(leader):
		calculate_steering()
		apply_steering(delta)
		move_and_slide()

func setup_abilities():
	# Set abilities berdasarkan unit type (sesuai tabel dokumen)
	match unit_type:
		"Swordsman":
			abilities.HandToHand = 10
			abilities.LongDistance = 0
			abilities.HeavyWeaponry = 0
		"Archer":
			abilities.HandToHand = 4
			abilities.LongDistance = 10
			abilities.HeavyWeaponry = 0
		"Pikeman":
			abilities.HandToHand = 10
			abilities.LongDistance = 3
			abilities.HeavyWeaponry = 0
		"Catapult":
			abilities.HandToHand = 0
			abilities.LongDistance = 0
			abilities.HeavyWeaponry = 20
		"Cannon":
			abilities.HandToHand = 0
			abilities.LongDistance = 0
			abilities.HeavyWeaponry = 20
		"Grenadier":
			abilities.HandToHand = 3
			abilities.LongDistance = 7
			abilities.HeavyWeaponry = 3

func setup_debug_color():
	match unit_type:
		"Swordsman": debug_color = Color.RED
		"Archer": debug_color = Color.GREEN
		"Pikeman": debug_color = Color.BLUE
		"Catapult": debug_color = Color.ORANGE
		"Cannon": debug_color = Color.PURPLE
		"Grenadier": debug_color = Color.YELLOW

func calculate_steering():
	steering = Vector2.ZERO
	
	# 1. Primary behavior: Seek slot position
	var slot_seek = calculate_slot_seek()
	steering += slot_seek * slot_seek_weight
	
	# 2. Obstacle avoidance
	var obstacle_avoid = calculate_obstacle_avoidance()
	steering += obstacle_avoid * obstacle_avoid_weight
	
	# 3. Separation from other squad members
	var separation = calculate_separation()
	steering += separation * separation_weight
	
	# 4. Cohesion with squad
	var cohesion = calculate_cohesion()
	steering += cohesion * cohesion_weight
	
	# Limit steering force
	steering = steering.limit_length(max_acceleration)

func calculate_slot_seek() -> Vector2:
	var target_slot_pos = leader.get_slot_position(slot_index)
	var to_target = target_slot_pos - global_position
	var distance = to_target.length()
	
	var desired_velocity = Vector2.ZERO
	
	if distance > arrival_radius:
		# Regular seek behavior
		desired_velocity = to_target.normalized() * max_speed
	else:
		# Arrival behavior - slow down when close to target
		var speed = max_speed * (distance / arrival_radius)
		desired_velocity = to_target.normalized() * speed
	
	return desired_velocity - current_velocity

func calculate_obstacle_avoidance() -> Vector2:
	var avoidance_force = Vector2.ZERO
	var check_distance = 120.0
	
	var space_state = get_world_2d().direct_space_state
	var directions = 8
	
	for i in range(directions):
		var angle = (float(i) / directions) * 2.0 * PI
		var direction = Vector2.RIGHT.rotated(angle)
		
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + direction * check_distance
		)
		query.exclude = [self]
		query.collision_mask = 2  # Obstacle layer
		
		var result = space_state.intersect_ray(query)
		if result:
			var avoidance_dir = (global_position - result.position).normalized()
			var strength = 1.0 - (global_position.distance_to(result.position) / check_distance)
			avoidance_force += avoidance_dir * strength * max_speed
	
	return avoidance_force

func calculate_separation() -> Vector2:
	var separation_force = Vector2.ZERO
	var separation_distance = 60.0
	var count = 0
	
	for member in get_tree().get_nodes_in_group("squad_members"):
		if member != self and is_instance_valid(member):
			var distance = global_position.distance_to(member.global_position)
			if distance < separation_distance:
				var away_direction = (global_position - member.global_position).normalized()
				var strength = 1.0 - (distance / separation_distance)
				separation_force += away_direction * strength * max_speed
				count += 1
	
	if count > 0:
		separation_force /= count
	
	return separation_force

func calculate_cohesion() -> Vector2:
	var cohesion_force = Vector2.ZERO
	var center_of_mass = Vector2.ZERO
	var count = 0
	
	for member in get_tree().get_nodes_in_group("squad_members"):
		if member != self and is_instance_valid(member):
			center_of_mass += member.global_position
			count += 1
	
	if count > 0:
		center_of_mass /= count
		var to_center = center_of_mass - global_position
		cohesion_force = to_center.normalized() * max_speed * 0.5
	
	return cohesion_force - current_velocity

func apply_steering(delta):
	current_velocity += steering * delta
	current_velocity = current_velocity.limit_length(max_speed)
	velocity = current_velocity

func get_current_speed() -> float:
	return current_velocity.length()

func set_slot_index(new_index: int):
	slot_index = new_index

func get_ability_score(ability_type: String) -> int:
	return abilities.get(ability_type, 0)

func _draw():
	# Debug drawing
	if Engine.is_editor_hint():
		return
	
	# Draw unit circle dengan warna berdasarkan type
	draw_circle(Vector2.ZERO, 10, debug_color)
	
	# Draw line ke target slot
	if leader and is_instance_valid(leader):
		var target_slot = leader.get_slot_position(slot_index)
		var direction = (target_slot - global_position).normalized()
		draw_line(Vector2.ZERO, direction * 20, Color.WHITE, 2)
