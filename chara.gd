extends CharacterBody2D

@export var tilemap: TileMap
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
const SPEED = 300.0
var target_position
var distance_to: float
@onready var hp_bar: ProgressBar = $ProgressBar
var hp = 5

# Dijkstra algorithm variables
var dijkstra_path: Array[Vector2] = []
var current_path_index: int = 0
var use_dijkstra: bool = true

# Untuk visualisasi
var frontier_nodes: Array = []  # Node yang sedang di-explore (frontier)
var explored_nodes: Array = []  # Node yang sudah di-explore
var current_algorithm_step: int = 0
var show_algorithm_steps: bool = true

func _ready() -> void:
	hp_bar.max_value = hp
	hp_bar.value = hp
	print("Dijkstra Algorithm Visualization Active")
	
	# Enable continuous redraw
	set_process(true)

func _physics_process(delta: float) -> void:
	if target_position and distance_to > 5:
		distance_to = global_position.distance_to(target_position)
		
		if use_dijkstra:
			follow_dijkstra_path()
		else:
			navigation_agent.target_position = target_position
			var next_path_pos = navigation_agent.get_next_path_position()
			var direction = (next_path_pos - global_position).normalized()
			velocity = direction * get_tile()
	else:
		velocity = Vector2.ZERO
		target_position = null
	
	move_and_slide()
	
	# Redraw setiap frame untuk visualisasi
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_target(get_global_mouse_position())
	
	# Keyboard controls untuk visualisasi
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				show_algorithm_steps = !show_algorithm_steps
				print("Show algorithm steps: ", show_algorithm_steps)
			KEY_R:
				# Reset visualisasi
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
		run_dijkstra_algorithm_with_visualization(global_position, target_position)

func run_dijkstra_algorithm_with_visualization(start_pos: Vector2, end_pos: Vector2):
	print("\n=== DIJKSTRA ALGORITHM START ===")
	
	# Reset untuk visualisasi
	dijkstra_path.clear()
	current_path_index = 0
	frontier_nodes.clear()
	explored_nodes.clear()
	current_algorithm_step = 0
	
	var start_cell = tilemap.local_to_map(start_pos)
	var end_cell = tilemap.local_to_map(end_pos)
	
	print("Start Cell: ", start_cell)
	print("Goal Cell: ", end_cell)
	
	# Jalankan Dijkstra dengan visualisasi step-by-step
	var path_cells = dijkstra_find_path_with_steps(start_cell, end_cell)
	
	if path_cells.is_empty():
		print("❌ Tidak ada path yang ditemukan")
		dijkstra_path = [target_position]
	else:
		# Konversi ke posisi dunia
		for cell in path_cells:
			dijkstra_path.append(tilemap.map_to_local(cell))
		
		print("✅ Path ditemukan! Panjang: ", dijkstra_path.size(), " waypoints")
		print("Path cells: ", path_cells)
	
	queue_redraw()

func dijkstra_find_path_with_steps(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	print("\n--- Step 1: Initialize ---")
	print("Frontier dimulai dengan start node: ", start)
	
	var frontier: Array = []
	frontier.append({"cost": 0, "pos": start, "step": 0})
	
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {}
	
	came_from[start] = null
	cost_so_far[start] = 0
	
	frontier_nodes = [start]  # Untuk visualisasi
	
	# Simpan step pertama untuk visualisasi
	save_algorithm_step(frontier, came_from, cost_so_far)
	
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),   # Kanan
		Vector2i(-1, 0),  # Kiri
		Vector2i(0, 1),   # Bawah
		Vector2i(0, -1),   # Atas
	]
	
	print("\n--- Step 2: Main Loop ---")
	var step_counter = 1
	
	while not frontier.is_empty():
		# Urutkan frontier berdasarkan cost terendah
		frontier.sort_custom(func(a, b): return a.cost < b.cost)
		
		var current = frontier[0]
		frontier.remove_at(0)
		frontier_nodes.erase(current.pos)
		explored_nodes.append(current.pos)
		
		print("\nStep ", step_counter, ": Explore node ", current.pos, 
			  " (cost: ", cost_so_far[current.pos], ")")
		
		# Jika sudah mencapai goal
		if current.pos == goal:
			print("🎯 GOAL DICAPAI di step ", step_counter)
			print("Total cost: ", cost_so_far[current.pos])
			break
		
		print("  Neighbors: ", get_neighbors_list(current.pos, directions))
		
		# Explore neighbors
		var neighbor_count = 0
		for direction in directions:
			var next_pos: Vector2i = current.pos + direction
			
			# Cek apakah cell valid
			if not is_valid_cell(next_pos):
				print("    ", next_pos, ": ❌ Invalid (collision/out of bounds)")
				continue
			
			# Hitung cost baru
			var move_cost = get_cell_cost(next_pos)
			var new_cost = cost_so_far[current.pos] + move_cost
			
			print("    ", next_pos, ": cost=", move_cost, 
				  ", total_cost=", new_cost, 
				  ", best_so_far=", cost_so_far.get(next_pos, "INF"))
			
			# Jika ini adalah path yang lebih baik ke next_pos
			if not cost_so_far.has(next_pos) or new_cost < cost_so_far[next_pos]:
				cost_so_far[next_pos] = new_cost
				var priority = new_cost
				frontier.append({"cost": priority, "pos": next_pos, "step": step_counter})
				came_from[next_pos] = current.pos
				
				# Update visualisasi
				if not frontier_nodes.has(next_pos):
					frontier_nodes.append(next_pos)
				
				neighbor_count += 1
				print("      ✓ Added to frontier")
			else:
				print("      ✗ Not better, skip")
		
		print("  Added ", neighbor_count, " neighbors to frontier")
		
		# Simpan state untuk visualisasi
		save_algorithm_step(frontier, came_from, cost_so_far)
		step_counter += 1
		
		# Optional: limit steps untuk demo
		if step_counter > 50:
			print("⚠️  Step limit reached (50)")
			break
	
	print("\n--- Step 3: Reconstruct Path ---")
	return reconstruct_path_with_steps(came_from, start, goal, cost_so_far)

func save_algorithm_step(frontier: Array, came_from: Dictionary, cost_so_far: Dictionary):
	# Simpan state saat ini untuk visualisasi
	current_algorithm_step += 1
	
	# Update frontier nodes untuk visualisasi
	var current_frontier = []
	for item in frontier:
		current_frontier.append(item.pos)
	frontier_nodes = current_frontier

func get_neighbors_list(pos: Vector2i, directions: Array[Vector2i]) -> String:
	var neighbors = []
	for dir in directions:
		neighbors.append(str(pos + dir))
	return "[" + ", ".join(neighbors) + "]"

func reconstruct_path_with_steps(came_from: Dictionary, start: Vector2i, goal: Vector2i, cost_so_far: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = goal
	
	print("Rekonstruksi path dari goal ke start:")
	
	while current != start:
		path.append(current)
		
		if not came_from.has(current):
			print("❌ ERROR: Tidak bisa merekonstruksi path")
			return []
		
		var prev = came_from[current]
		print("  ", current, " ← ", prev, " (cost: ", cost_so_far.get(current, "?"), ")")
		current = prev
	
	path.append(start)
	path.reverse()
	
	print("Path final: ", path)
	print("Total cells: ", path.size())
	
	return path

func is_valid_cell(cell_pos: Vector2i) -> bool:
	var tile_data = tilemap.get_cell_tile_data(0, cell_pos)
	if not tile_data:
		return false
	var has_collision = tile_data.get_collision_polygons_count(0) > 0
	return not has_collision

func get_cell_cost(cell_pos: Vector2i) -> float:
	var tile_data = tilemap.get_cell_tile_data(0, cell_pos)
	if tile_data:
		var terrain_cost = tile_data.get_custom_data("cost")
		return float(terrain_cost) if terrain_cost != null else 1.0
	return 1.0

func _draw():
	# Gambar background grid (debug)
	draw_grid()
	
	if not use_dijkstra or not show_algorithm_steps:
		return
	
	# Visualisasi Dijkstra algorithm
	draw_algorithm_visualization()
	
	# Gambar path final (jika ada)
	if dijkstra_path.size() > 1:
		draw_final_path()

func draw_grid():
	# Gambar grid tilemap (debug)
	var grid_color = Color(0.3, 0.3, 0.3, 0.2)
	var grid_size = Vector2(16, 16)  # Sesuaikan dengan tilemap
	
	# Gambar vertical lines
	for x in range(-10, 11):
		var start = Vector2(x * grid_size.x, -10 * grid_size.y)
		var end = Vector2(x * grid_size.x, 10 * grid_size.y)
		draw_line(start, end, grid_color, 1.0)
	
	# Gambar horizontal lines
	for y in range(-10, 11):
		var start = Vector2(-10 * grid_size.x, y * grid_size.y)
		var end = Vector2(10 * grid_size.x, y * grid_size.y)
		draw_line(start, end, grid_color, 1.0)

func draw_algorithm_visualization():
	# Gambar frontier nodes (yang sedang di-explore)
	for cell in frontier_nodes:
		var world_pos = tilemap.map_to_local(cell)
		var local_pos = to_local(world_pos)
		
		# Gambar kotak kuning untuk frontier nodes
		draw_rect(Rect2(local_pos - Vector2(4, 4), Vector2(8, 8)), 
				 Color(1, 1, 0, 0.6))  # Kuning transparan
		
		# Tulis cost (jika ada)
		draw_string(ThemeDB.fallback_font, local_pos + Vector2(10, 0), 
				   str(cell))
	
	# Gambar explored nodes (yang sudah di-explore)
	for cell in explored_nodes:
		var world_pos = tilemap.map_to_local(cell)
		var local_pos = to_local(world_pos)
		
		# Gambar kotak biru untuk explored nodes
		draw_circle(local_pos, 3.0, Color(0, 0.5, 1, 0.4))  # Biru transparan
	
	# Gambar start dan goal
	if target_position:
		var start_cell = tilemap.local_to_map(global_position)
		var goal_cell = tilemap.local_to_map(target_position)
		
		# Start (hijau)
		var start_world = tilemap.map_to_local(start_cell)
		draw_circle(to_local(start_world), 5.0, Color(0, 1, 0, 0.8))
		draw_string(ThemeDB.fallback_font, to_local(start_world) + Vector2(10, 10), 
				   "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 1, 0, 1))
		
		# Goal (merah)
		var goal_world = tilemap.map_to_local(goal_cell)
		draw_circle(to_local(goal_world), 5.0, Color(1, 0, 0, 0.8))
		draw_string(ThemeDB.fallback_font, to_local(goal_world) + Vector2(10, 10), 
				   "GOAL",HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.RED)

func draw_final_path():
	# Gambar path final dengan warna berbeda
	for i in range(dijkstra_path.size() - 1):
		var start = to_local(dijkstra_path[i])
		var end = to_local(dijkstra_path[i + 1])
		
		# Garis tebal hijau untuk path
		draw_line(start, end, Color.MEDIUM_VIOLET_RED, 4.0)
		
		# Titik di setiap waypoint
		draw_circle(start, 4.0, Color(1, 1, 0, 0.9))
	
	# Titik di waypoint terakhir
	if dijkstra_path.size() > 0:
		var last = to_local(dijkstra_path[dijkstra_path.size() - 1])
		draw_circle(last, 4.0, Color(1, 1, 0, 0.9))
	
	# Gambar waypoint saat ini (jika sedang bergerak)
	if current_path_index < dijkstra_path.size():
		var current = to_local(dijkstra_path[current_path_index])
		draw_circle(current, 6.0, Color(1, 0, 0, 1.0))  # Merah solid

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
	velocity = direction * get_tile()

func get_tile() -> float:
	var cell = tilemap.local_to_map(position)
	var data = tilemap.get_cell_tile_data(0, cell)
	
	if data:
		var tile_speed = data.get_custom_data("sped")
		return SPEED * (float(tile_speed) if tile_speed != null else 1.0)
	return SPEED

@onready var frezer: Sprite2D = $Frezer
func take_damage():
	hp -= 1
	hp_bar.value = hp
	frezer.self_modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	frezer.self_modulate = Color.WHITE
	if hp <= 0:
		get_tree().reload_current_scene()
