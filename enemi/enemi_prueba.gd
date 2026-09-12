extends CharacterBody3D
class_name Enemi
@onready var phantom_camera_3d: PhantomCamera3D = $PhantomCamera3D


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		phantom_camera_3d.set_priority(2)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is Player:
		phantom_camera_3d.set_priority(0)
