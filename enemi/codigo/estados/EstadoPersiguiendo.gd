extends EstadoEnemigo
class_name EstadoPersiguiendo

var punto_acecho_offset: Vector3 = Vector3.ZERO

func entrar() -> void:
	_actualizar_punto_acecho()

func actualizar_fisicas(_delta: float) -> void:
	if not is_instance_valid(enemigo.jugador):
		enemigo.state_machine.cambiar_estado("patrullando")
		return

	var objetivo_pos = enemigo.jugador.global_position + punto_acecho_offset
	var direccion = (objetivo_pos - enemigo.global_position)
	direccion.y = 0
	
	if direccion.length() > 0.5:
		direccion = direccion.normalized()
		enemigo.velocity.x = direccion.x * enemigo.stats.velocidad_persecucion
		enemigo.velocity.z = direccion.z * enemigo.stats.velocidad_persecucion
		enemigo.look_at(enemigo.jugador.global_position, Vector3.UP)
	else:
		_actualizar_punto_acecho()

func _actualizar_punto_acecho() -> void:
	var angulo = randf_range(0, TAU)
	punto_acecho_offset = Vector3(cos(angulo), 0, sin(angulo)) * enemigo.stats.distancia_mantenida
