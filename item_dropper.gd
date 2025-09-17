extends Node2D

var item_scenes: Array[PackedScene] = [
	preload("res://gmbar/stick.tscn"),
	preload("res://gmbar/stone.tscn"),
	preload("res://gmbar/fruit.tscn")
]

var item_weights: Array = [70.0, 50.0, 20.0]

func random_picker(weights: Array) -> int:
	var total: float = 0.0
	for t in weights:
		total += t

	var v = randf() * total
	var nmbr: float = 0.0
	for i in range(weights.size()):
		nmbr += weights[i]
		if v <= nmbr:
			return i
	
	return weights.size() - 1

func spawn_item(count: int) -> void:
	var spawn_radius = 80.0
	for i in range(count):
		var index = random_picker(item_weights)
		var selected_scene = item_scenes[index]  
		var item_instance = selected_scene.instantiate()
		
		
		get_tree().current_scene.add_child(item_instance)
		
		# Atur posisi dengan sedikit variasi acak
		var random_offset = Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		item_instance.global_position = global_position + random_offset
