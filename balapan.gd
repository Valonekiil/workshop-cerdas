extends Node2D

@export var Available_Players: Array[PackedScene]
@onready var Spawn_Area: Area2D = $Track/Spawn
@onready var CP_1: Area2D = $Track/CP1
@onready var CP_2: Area2D = $Track/CP2
@onready var Finish: Area2D = $Track/Finish
@onready var Countdown_Label: Label = $CountdownLabel
@onready var Winning_Label: Label = $Winner
@onready var race_btn = $Button

var players_in_race: Array = []
var current_players: Array = []
var race_started: bool = false
var countdown_time: float = 3.0
var winner: Node2D = null

func _ready():
	Countdown_Label.visible = false

func battle(players: Array[PackedScene]):
	players_in_race.clear()
	current_players = players
	start_countdown()

func start_countdown():
	Countdown_Label.text = "3"
	Countdown_Label.visible = true
	countdown_time = 3.0
	race_started = false
	
	# Spawn semua player terlebih dahulu
	for player_scene in current_players:
		var player = player_scene.instantiate()
		var pos = select_random_pos(Spawn_Area)
		player.global_position = pos
		get_tree().current_scene.add_child(player)
		player.setup_race([CP_1, CP_2, Finish])
		players_in_race.append(player)
	
	# Mulai countdown
	await get_tree().create_timer(1.0).timeout
	countdown_time = 2.0
	Countdown_Label.text = "2"
	
	await get_tree().create_timer(1.0).timeout
	countdown_time = 1.0
	Countdown_Label.text = "1"
	
	await get_tree().create_timer(1.0).timeout
	Countdown_Label.text = "GO!"
	race_started = true
	
	for player in players_in_race:
		player.start_racing()
	
	await get_tree().create_timer(0.5).timeout
	Countdown_Label.visible = false

func select_random_pos(area: Area2D) -> Vector2:
	var collision = area.get_node("CollisionShape2D")
	var collision_shape = collision.shape
	var extents = collision_shape.size / 2
	var random_x = randf_range(-extents.x, extents.x)
	var random_y = randf_range(-extents.y, extents.y)
	return area.global_position + Vector2(random_x, random_y)

func check_finish(player: Node2D):
	if winner == null and race_started:
		winner = player
		end_race(player)

func end_race(winning_player: Node2D):
	race_started = false
	print("Pemenang: ", winning_player.player_name)
	
	Winning_Label.visible = true
	Winning_Label.text = winning_player.player_name + " MENANG!"
	
	for player in players_in_race:
		player.stop_racing()
		player.queue_free()
	await get_tree().create_timer(5.0).timeout
	race_btn.disabled = false
	Winning_Label.visible = false

func _on_button_pressed() -> void:
	battle(Available_Players)
	race_btn.disabled = true
