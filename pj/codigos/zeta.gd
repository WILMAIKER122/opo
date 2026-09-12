extends Node3D

var delite:bool
func _ready() -> void:
	$AnimationPlayer.play("caida")



func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player and delite:
		body.zeta_func(true)
		$".".queue_free()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name:
		delite = true
		
