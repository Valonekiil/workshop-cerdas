extends CharacterBody2D

@export var tilemap: TileMap
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
const SPEED = 300.0
const INF = 999999.0  # Nilai tak hingga untuk Dijkstra

var target_position: Vector2 = Vector2.ZERO
var distance_to: float = 0.0
@onready var hp_bar: ProgressBar = $ProgressBar
var hp = 5

# Dijkstra algorithm variables
var dijkstra_path: Array[Vector2] = []
var current_path_index: int = 0
var use_dijkstra: bool = true

# Untuk visualisasi
var frontier_nodes: Array[Vector2i] = []
var explored_nodes: Array[Vector2i] = []
var current_algorithm_step: int = 0
var show_algorithm_steps: bool = true

# Struktur data Dijkstra
var distances: Dictionary = {}  # cost terbaik ke setiap node
var previous: Dictionary = {}   # node sebelumnya dalam path terbaik
var visited: Array[Vector2i] = []  # node yang sudah dikunjungi
var unvisited: Array = []      # node yang belum dikunjungi (priority queue)

func _ready() -> void:
	hp_bar.max_value = hp
	hp_bar.value = hp
	set_process(true)

func _physics_process(delta: float) -> void:
	if target_position != Vector2.ZERO and distance_to > 5:
		distance_to = global_position.distance_to(target_position)
		
		if use_dijkstra:
			follow_dijkstra_path()
		else:
			navigation_agent.target_position = target_position
			var next_path_pos = navigation_agent.get_next_path_position()
			var direction = (next_path_pos - global_position).normalized()
			velocity = direction * get_current_tile_speed()
	else:
		velocity = Vector2.ZERO
		if target_position != Vector2.ZERO and distance_to <= 5:
			target_position = Vector2.ZERO
	
	move_and_slide()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_target(get_global_mouse_position())
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				show_algorithm_steps = !show_algorithm_steps
				print("Show algorithm steps: ", show_algorithm_steps)
			KEY_R:
				frontier_nodes.clear()
				explored_nodes.clear()
				current_algorithm_step = 0
				queue_redraw()

func set_target(pos: Vector2):
	var tile_pos = tilemap.local_to_map(pos)
	var tile_data = tilemap.get_cell_tile_data(0, tile_pos)
	
	if tile_data and tile_data.get_collision_polygons_count(0) > 0:
		print("Tile memiliki collision, tidak dapat bergerak ke sini")
		return
	
	target_position = tilemap.map_to_local(tile_pos)
	distance_to = global_position.distance_to(target_position)
	
	if use_dijkstra:
		run_dijkstra_algorithm(global_position, target_position)

func run_dijkstra_algorithm(start_pos: Vector2, end_pos: Vector2):
	dijkstra_path.clear()
	current_path_index = 0
	frontier_nodes.clear()
	explored_nodes.clear()
	current_algorithm_step = 0
	distances.clear()
	previous.clear()
	visited.clear()
	unvisited.clear()
	
	var start_cell = tilemap.local_to_map(start_pos)
	var end_cell = tilemap.local_to_map(end_pos)
	
	print("Start Cell: ", start_cell, " Goal Cell: ", end_cell)
	
	var path_cells = dijkstra_find_path(start_cell, end_cell)
	
	if path_cells.is_empty():
		dijkstra_path = [target_position]
	else:
		for cell in path_cells:
			dijkstra_path.append(tilemap.map_to_local(cell))
		
		print("Path ditemukan! Panjang: ", dijkstra_path.size(), " waypoints")
		print("Total cost: ", distances.get(end_cell, 0))
	
	queue_redraw()

func dijkstra_find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# 1. Inisialisasi
	distances[start] = 0.0
	previous[start] = Vector2i(-1, -1)  # Tidak ada previous untuk start
	unvisited.append({"cell": start, "distance": 0.0})
	frontier_nodes.append(start)
	
	# 2. Main loop Dijkstra
	var step = 0
	
	while not unvisited.is_empty():
		step += 1
		if step > 500: 
			print("⚠️  Step limit reached (500 steps)")
			break
		
		# Ambil node dengan distance terkecil
		unvisited.sort_custom(func(a, b): return a.distance < b.distance)
		var current_data = unvisited[0]
		var current = current_data.cell
		unvisited.remove_at(0)
		frontier_nodes.erase(current)
		
		# Tambah ke visited dan explored
		visited.append(current)
		explored_nodes.append(current)
		
		print("Step ", step, ": Processing cell ", current, ", distance: ", distances.get(current, INF))
		
		# Jika mencapai goal
		if current == goal:
			print("🎯 Goal reached in ", step, " steps!")
			break
		
		# Explore semua neighbor
		var neighbors = get_neighbors(current)
		for neighbor in neighbors:
			# Hitung cost berdasarkan speed tile
			var move_cost = get_cell_move_cost(neighbor)
			var current_distance = distances.get(current, INF)
			var new_distance = current_distance + move_cost
			
			# Jika distance baru lebih baik
			if new_distance < distances.get(neighbor, INF):
				distances[neighbor] = new_distance
				previous[neighbor] = current
				
				# Update priority queue
				update_unvisited_queue(neighbor, new_distance)
				if not frontier_nodes.has(neighbor):
					frontier_nodes.append(neighbor)
	
	return reconstruct_path(start, goal)

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0),   # Kanan
		Vector2i(-1, 0),  # Kiri
		Vector2i(0, 1),   # Bawah
		Vector2i(0, -1),  # Atas
	]
	
	for direction in directions:
		var neighbor = cell + direction
		if is_valid_cell(neighbor):
			neighbors.append(neighbor)
	
	return neighbors

func is_valid_cell(cell: Vector2i) -> bool:
	var tile_data = tilemap.get_cell_tile_data(0, cell)
	if not tile_data:
		return false
	
	var has_collision = tile_data.get_collision_polygons_count(0) > 0
	return not has_collision

func get_cell_move_cost(cell: Vector2i) -> float:
	var tile_data = tilemap.get_cell_tile_data(0, cell)
	
	if not tile_data:
		return INF
	
	# Dapatkan speed modifier dari custom data "sped"
	var speed_modifier = 1.0
	var custom_speed = tile_data.get_custom_data("sped")
	if custom_speed != null:
		speed_modifier = float(custom_speed)
	
	# Hindari pembagian dengan nol
	if speed_modifier <= 0:
		return INF
	
	# Hitung cost: semakin cepat tile, semakin murah cost-nya
	var cost = 1.0 / speed_modifier
	
	# Clamping untuk nilai yang wajar
	return clamp(cost, 0.1, 10.0)

func update_unvisited_queue(cell: Vector2i, distance: float):
	# Cek apakah sudah ada di queue
	var found = false
	for i in range(unvisited.size()):
		if unvisited[i].cell == cell:
			unvisited[i].distance = distance
			found = true
			break
	
	# Jika belum ada, tambahkan
	if not found:
		unvisited.append({"cell": cell, "distance": distance})

func reconstruct_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = goal
	
	if not previous.has(goal):
		return []
	
	# Telusuri dari goal ke start
	while current != start:
		path.append(current)
		
		if not previous.has(current):
			return []
		
		current = previous[current]
	
	# Tambahkan start dan balik urutannya
	path.append(start)
	path.reverse()
	
	print("Path reconstructed: ", path.size(), " cells")
	print("Total distance: ", distances.get(goal, 0))
	
	return path

func follow_dijkstra_path():
	if dijkstra_path.is_empty() or current_path_index >= dijkstra_path.size():
		velocity = Vector2.ZERO
		return
	
	var current_target = dijkstra_path[current_path_index]
	var distance_to_current = global_position.distance_to(current_target)
	
	if distance_to_current < 10.0:
		current_path_index += 1
		if current_path_index >= dijkstra_path.size():
			velocity = Vector2.ZERO
			return
	
	var direction = (current_target - global_position).normalized()
	velocity = direction * get_current_tile_speed()

func get_current_tile_speed() -> float:
	var cell = tilemap.local_to_map(global_position)
	return get_tile_speed_at_cell(cell)

func get_tile_speed_at_cell(cell: Vector2i) -> float:
	var data = tilemap.get_cell_tile_data(0, cell)
	if data:
		var tile_speed = data.get_custom_data("sped")
		return SPEED * (float(tile_speed) if tile_speed != null else 1.0)
	return SPEED

func _draw():
	if not use_dijkstra:
		return
	
	# Gambar visualisasi algoritma jika diaktifkan
	if show_algorithm_steps:
		draw_algorithm_visualization()
	
	# Gambar path final
	if dijkstra_path.size() > 1:
		draw_final_path()
		
		# Tampilkan total cost di pojok kiri atas
		var start_cell = tilemap.local_to_map(global_position)
		var goal_cell = tilemap.local_to_map(target_position)
		if distances.has(goal_cell):
			var total_cost = distances[goal_cell]
			draw_string(ThemeDB.fallback_font, Vector2(20, 40), 
					   "Total Cost: %.2f" % total_cost, 
					   HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.YELLOW)

func draw_algorithm_visualization():
	# Gambar frontier nodes (node yang sedang dieksplorasi)
	for cell in frontier_nodes:
		var world_pos = tilemap.map_to_local(cell)
		var local_pos = to_local(world_pos)
		
		# Gambar kotak kuning untuk frontier
		draw_rect(Rect2(local_pos - Vector2(6, 6), Vector2(12, 12)), 
				 Color(1, 1, 0, 0.5), false, 2.0)
		
		# Tampilkan cost di atas tile
		if distances.has(cell):
			var cost = distances[cell]
			if cost < INF:
				draw_string(ThemeDB.fallback_font, local_pos + Vector2(-10, -15), 
						   "%.1f" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.YELLOW)
	
	# Gambar explored nodes (node yang sudah dikunjungi)
	for cell in explored_nodes:
		var world_pos = tilemap.map_to_local(cell)
		var local_pos = to_local(world_pos)
		
		# Gambar lingkaran biru untuk explored
		draw_circle(local_pos, 5.0, Color(0, 0.5, 1, 0.3))
		
		# Tampilkan cost di atas tile
		if distances.has(cell):
			var cost = distances[cell]
			if cost < INF:
				draw_string(ThemeDB.fallback_font, local_pos + Vector2(-10, -15), 
						   "%.1f" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.BLUE)
	
	# Gambar start dan goal
	if target_position != Vector2.ZERO:
		var start_cell = tilemap.local_to_map(global_position)
		var goal_cell = tilemap.local_to_map(target_position)
		
		var start_world = tilemap.map_to_local(start_cell)
		var goal_world = tilemap.map_to_local(goal_cell)
		
		# Start point (hijau besar)
		draw_circle(to_local(start_world), 8.0, Color(0, 1, 0, 0.8))
		draw_string(ThemeDB.fallback_font, to_local(start_world) + Vector2(15, 15), 
				   "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.GREEN)
		
		# Goal point (merah besar)
		draw_circle(to_local(goal_world), 8.0, Color(1, 0, 0, 0.8))
		draw_string(ThemeDB.fallback_font, to_local(goal_world) + Vector2(15, 15), 
				   "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.RED)
		
		# Tampilkan cost di goal
		if distances.has(goal_cell):
			var goal_cost = distances[goal_cell]
			if goal_cost < INF:
				draw_string(ThemeDB.fallback_font, to_local(goal_world) + Vector2(15, -20), 
						   "Cost: %.1f" % goal_cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.RED)

func draw_final_path():
	# Gambar garis path hijau tebal
	for i in range(dijkstra_path.size() - 1):
		var start = to_local(dijkstra_path[i])
		var end = to_local(dijkstra_path[i + 1])
		
		draw_line(start, end, Color(0, 1, 0, 0.9), 4.0)
		
		# Gambar titik kuning di setiap waypoint
		draw_circle(start, 4.0, Color(1, 1, 0, 0.9))
		
		# Tampilkan cost di tengah segmen
		if i < dijkstra_path.size():
			var cell = tilemap.local_to_map(dijkstra_path[i])
			if distances.has(cell):
				var cost_value = distances[cell]
				var mid_point = (start + end) / 2
				draw_string(ThemeDB.fallback_font, mid_point - Vector2(15, 10), 
						   "%.1f" % cost_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# Titik terakhir
	if dijkstra_path.size() > 0:
		var last = to_local(dijkstra_path[dijkstra_path.size() - 1])
		draw_circle(last, 4.0, Color(1, 1, 0, 0.9))
	
	# Waypoint saat ini (merah besar)
	if current_path_index < dijkstra_path.size():
		var current = to_local(dijkstra_path[current_path_index])
		draw_circle(current, 6.0, Color(1, 0, 0, 1.0))
		
		# Tampilkan speed saat ini
		var speed = get_current_tile_speed()
		draw_string(ThemeDB.fallback_font, Vector2(20, 70), 
				   "Speed: %.0f" % speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.CYAN)

@onready var frezer: Sprite2D = $Frezer
func take_damage():
	hp -= 1
	hp_bar.value = hp
	frezer.self_modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	frezer.self_modulate = Color.WHITE
	if hp <= 0:
		get_tree().reload_current_scene()
