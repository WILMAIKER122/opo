extends EstadoEnemigo
class_name EstadoAtacando

var direccion_embestida: Vector3 = Vector3.ZERO

func entrar() -> void:
	_iniciar_ataque()

func actualizar_fisicas(_delta: float) -> void:
	enemigo.velocity.x = direccion_embestida.x * enemigo.stats.velocidad_embestida
	enemigo.velocity.z = direccion_embestida.z * enemigo.stats.velocidad_embestida

func _iniciar_ataque() -> void:
	if not is_instance_valid(enemigo.jugador):
		enemigo.state_machine.cambiar_estado("patrullando")
		return

	enemigo.velocity = Vector3.ZERO
	enemigo.look_at(enemigo.jugador.global_position, Vector3.UP)
	
	direccion_embestida = (enemigo.jugador.global_position - enemigo.global_position)
	direccion_embestida.y = 0
	direccion_embestida = direccion_embestida.normalized()

	await get_tree().create_timer(0.3).timeout
	if enemigo.state_machine.estado_actual != self: return

	await get_tree().create_timer(0.4).timeout
	
	enemigo.puede_atacar = false
	enemigo.timer_ataque.start(enemigo.stats.tiempo_cooldown_ataque)
	
	if enemigo.state_machine.estado_actual == self:
		enemigo.state_machine.cambiar_estado("persiguiendo")
