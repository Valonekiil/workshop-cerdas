extends Node
class_name FormationManager

var slot_mapping = {
	"Vanguard": 0,
	"FlankerLeft": 1,
	"FlankerRight": 2, 
	"SupportLeft": 3,
	"SupportRight": 4,
	"HeavySupport": 5
}

func apply_slot_assignments(assignments: Dictionary):
	for slot_name in assignments:
		var unit = assignments[slot_name]
		if unit and unit.has_method("set_slot_index"):
			var slot_index = slot_mapping.get(slot_name, 0)
			unit.set_slot_index(slot_index)

func toggle_formation_type():
	var leader = get_tree().get_first_node_in_group("leader_marker")
	if leader and leader.has_method("change_formation"):
		var current_formation = leader.formation_type
		var new_formation = "Line"
		
		match current_formation:
			"V": new_formation = "Line"
			"Line": new_formation = "Circle" 
			"Circle": new_formation = "V"
		
		leader.change_formation(new_formation)
