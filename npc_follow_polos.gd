extends CharacterBody2D

@export var target:CharacterBody2D
var SPEED = 100
@onready var raycast = $RayCast2D

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	if target:
		direction = (target.position - position).normalized()
	velocity = direction * SPEED
	move_and_slide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if target == null and body.is_in_group("Player"):
		target = body
		print("test")


func _on_area_2d_body_exited(body: Node2D) -> void:
	if target == body:
		target = null
