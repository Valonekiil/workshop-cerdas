extends CharacterBody2D

@export var target:CharacterBody2D
var SPEED = 100
var target_found:bool
@onready var raycast = $RayCast2D

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	if target:
		# Update raycast ke arah target
		raycast.target_position = to_local(target.global_position)
		raycast.force_raycast_update()
		
		# Cek jika raycast mengenai target
		if raycast.is_colliding() and raycast.get_collider() == target:
			target_found = true
			direction = (target.position - position).normalized()
		else:
			target_found = false
	
	velocity = direction * SPEED

	move_and_slide()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if target == null and body.is_in_group("Player"):
		target = body
		print("test")


func _on_area_2d_body_exited(body: Node2D) -> void:
	if target == body:
		target = null
		target_found = false
