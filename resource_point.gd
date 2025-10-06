extends Area2D

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

var is_active: bool = true
@export var lifetime: float = 10.0
var lifetime_timer: float = 0.0

func _ready():
	add_to_group("ResourcePoint")
	start_lifetime_timer()

func _process(delta):
	if is_active:
		lifetime_timer += delta
		if lifetime_timer >= lifetime:
			despawn()

func start_lifetime_timer():
	lifetime_timer = 0.0

func despawn():
	if is_active:
		is_active = false
		queue_free()

func take_resource():
	if is_active:
		is_active = false
		queue_free()
		return true
	return false

func is_available() -> bool:
	return is_active
