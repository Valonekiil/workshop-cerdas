extends Node2D

@onready var leader_marker = $LeaderMarker
@onready var formation_manager = $FormationManager
@onready var slot_assignment_manager = $SlotAssignmentManager

var squad_members = []

func _ready():
	# Setup squad members
	squad_members = get_tree().get_nodes_in_group("squad_members")
	
	# Initial slot assignment
	var assignments = slot_assignment_manager.assign_slots(squad_members)
	formation_manager.apply_slot_assignments(assignments)
	
	# Debug info
	print("Squad initialized with ", squad_members.size(), " members")
	print("Total formation score: ", slot_assignment_manager.calculate_total_score())

func _input(event):
	if event.is_action_pressed("ui_accept"):
		# Simulate squad member being removed
		if squad_members.size() > 0:
			var removed_member = squad_members.pop_back()
			removed_member.queue_free()
			print("Member removed! Reassigning slots...")
			
			# Reassign slots dynamically
			var new_assignments = slot_assignment_manager.assign_slots(squad_members)
			formation_manager.apply_slot_assignments(new_assignments)
			print("New total score: ", slot_assignment_manager.calculate_total_score())

func _process(delta):
	# Update debug info
	if Input.is_key_pressed(KEY_SPACE):
		formation_manager.toggle_formation_type()
