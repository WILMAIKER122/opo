extends EstadoEnemigo
class_name EstadoRecibiendoDanio

var vector_knockback: Vector3 = Vector3.ZERO

var _tiempo_restante: float = 0.0

func aplicar_knockback(origen_impacto: Vector3, fuerza: float, duracion_stun: float) -> void:
	var direccion := enemigo.global_position - origen_impacto
	direccion.y = 0.0
	vector_knockback = direccion.normalized() * fuerza
	_tiempo_restante = maxf(0.2, duracion_stun)

func actualizar_fisicas(delta: float) -> void:
	vector_knockback = vector_knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	enemigo.velocity.x = vector_knockback.x
	enemigo.velocity.z = vector_knockback.z

	_tiempo_restante -= delta
	if _tiempo_restante <= 0.0 and enemigo.vida_actual > 0.0:
		if is_instance_valid(enemigo.jugador):
			enemigo.state_machine.cambiar_estado("persiguiendo")
		else:
			enemigo.state_machine.cambiar_estado("patrullando")
func _recuperarse(duracion_stun: float) -> void:
	await get_tree().create_timer(max(0.2, duracion_stun)).timeout
	if enemigo.vida_actual > 0:
		if is_instance_valid(enemigo.jugador):
			enemigo.state_machine.cambiar_estado("persiguiendo")
		else:
			enemigo.state_machine.cambiar_estado("patrullando")
