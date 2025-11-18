extends Node2D
class_name ResourceSpawnManager
@export var resource_point_scene: PackedScene
@export var max_active_points: int = 5
@export var spawn_interval: float = 3
@export var spawn_zone: Array[Area2D]

var active_points: Array = []
var spawn_timer: float = 0.0

func _ready():
	# Spawn beberapa point awal
	for i in range(2):
		spawn_resource_point()

func _process(delta):
	spawn_timer += delta
	
	if spawn_timer >= spawn_interval:
		var available_count = 0
		for point in active_points:
			if is_instance_valid(point) and point.has_method("is_available") and point.is_available():
				available_count += 1
		
		# 🎯 SPAWN JIKA MASIH KURANG DARI MAX
		if available_count < max_active_points:
			spawn_resource_point()
		spawn_timer = 0.0
	cleanup_points()

func cleanup_points():
	# 🎯 HAPUS POINT YANG SUDAH TIDAK VALID
	for i in range(active_points.size() - 1, -1, -1):
		if not is_instance_valid(active_points[i]):
			active_points.remove_at(i)

func spawn_resource_point():
	if not resource_point_scene:
		return
	
	var new_point = resource_point_scene.instantiate()
	var col = spawn_zone.pick_random()
	var collision = col.get_node("CollisionShape2D")
	var collision_shape = collision.shape
	var extents = collision_shape.size / 2
	var random_x = randf_range(-extents.x, extents.x)
	var random_y = randf_range(-extents.y, extents.y)
	
	new_point.global_position = col.global_position + Vector2(random_x, random_y)
	
	add_child(new_point)
	active_points.append(new_point)
	print("🎯 Spawned point. Total: ", active_points.size())

func get_nearest_resource_point(search_position: Vector2, max_distance: float) -> Node2D:
	var nearest_point = null
	var min_distance = INF
	
	for point in active_points:
		if is_instance_valid(point) and point.is_available():
			var distance = search_position.distance_to(point.global_position)
			if distance < min_distance and distance <= max_distance:
				min_distance = distance
				nearest_point = point
	
	return nearest_point

func get_available_resource_points() -> Array:
	return active_points.filter(func(point): 
		return is_instance_valid(point) and point.is_available()
	)

# Debug function untuk melihat jumlah resource point aktif
func get_debug_info() -> String:
	return "Active Points: %d/%d" % [get_available_resource_points().size(), max_active_points]
