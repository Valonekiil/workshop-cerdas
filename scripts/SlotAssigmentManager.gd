extends Node
class_name SlotAssignmentManager

# Slot requirements dengan empty costs (sesuai teori)
var formation_slots = {
	"Vanguard": {"type": "HandToHand", "empty_cost": -15, "priority": 3},
	"FlankerLeft": {"type": "HandToHand", "empty_cost": -10, "priority": 2},
	"FlankerRight": {"type": "HandToHand", "empty_cost": -10, "priority": 2},
	"SupportLeft": {"type": "LongDistance", "empty_cost": -10, "priority": 2},
	"SupportRight": {"type": "LongDistance", "empty_cost": -10, "priority": 2},
	"HeavySupport": {"type": "HeavyWeaponry", "empty_cost": -20, "priority": 4}
}

var current_assignments = {}

func assign_slots(units: Array) -> Dictionary:
	current_assignments.clear()
	var available_units = units.duplicate()
	
	# Sort units by ability variance (hardest to assign first)
	available_units.sort_custom(sort_by_ability_variance)
	
	# Get slots sorted by priority (highest empty cost first)
	var slots_by_priority = get_slots_by_priority()
	
	# Assign units to slots
	for slot_name in slots_by_priority:
		var best_unit = find_best_unit_for_slot(slot_name, available_units)
		if best_unit:
			current_assignments[slot_name] = best_unit
			available_units.erase(best_unit)
		else:
			current_assignments[slot_name] = null  # Empty slot
	
	print_assignment_debug_info()
	return current_assignments

func sort_by_ability_variance(a, b) -> bool:
	return calculate_ability_variance(a) > calculate_ability_variance(b)

func calculate_ability_variance(unit) -> float:
	if not unit or not unit.has_method("get_ability_score"):
		return 0.0
	
	var scores = [
		unit.get_ability_score("HandToHand"),
		unit.get_ability_score("LongDistance"),
		unit.get_ability_score("HeavyWeaponry")
	]
	
	var mean = 0.0
	for score in scores:
		mean += score
	mean /= scores.size()
	
	var variance = 0.0
	for score in scores:
		variance += (score - mean) * (score - mean)
	
	return variance

func get_slots_by_priority() -> Array:
	var slots = formation_slots.keys()
	slots.sort_custom(func(a, b): 
		return formation_slots[a].priority > formation_slots[b].priority
	)
	return slots

func find_best_unit_for_slot(slot_name: String, available_units: Array):
	var slot_type = formation_slots[slot_name].type
	var best_score = -INF
	var best_unit = null
	
	for unit in available_units:
		if unit and unit.has_method("get_ability_score"):
			var score = unit.get_ability_score(slot_type)
			
			# Bonus untuk unit yang sangat cocok
			if score >= 10:
				score += 5
			elif score >= 7:
				score += 2
				
			if score > best_score:
				best_score = score
				best_unit = unit
	
	return best_unit

func calculate_total_score() -> int:
	var total = 0
	for slot_name in current_assignments:
		var unit = current_assignments[slot_name]
		if unit and unit.has_method("get_ability_score"):
			var slot_type = formation_slots[slot_name].type
			total += unit.get_ability_score(slot_type)
		else:
			total += formation_slots[slot_name].empty_cost
	return total

func print_assignment_debug_info():
	print("=== Slot Assignment ===")
	for slot_name in current_assignments:
		var unit = current_assignments[slot_name]
		var slot_type = formation_slots[slot_name].type
		
		if unit:
			var score = unit.get_ability_score(slot_type)
			print("%s: %s (Score: %d)" % [slot_name, unit.unit_name, score])
		else:
			print("%s: EMPTY (Cost: %d)" % [slot_name, formation_slots[slot_name].empty_cost])
	
	print("Total Score: ", calculate_total_score())
