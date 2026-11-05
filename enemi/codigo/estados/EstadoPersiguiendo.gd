extends EstadoEnemigo
class_name EstadoPersiguiendo

var punto_acecho_offset: Vector3 = Vector3.ZERO
@export_group("Posición de acecho")
## Cuánto se puede desviar en Z del jugador (0 = justo a su izquierda/derecha).
## Mantenelo menor que la mitad de la profundidad de AreaAtaque del enemigo y del área de ataque del jugador.
@export var desfase_z_maximo: float = 0.5
## Probabilidad de acechar en los lados "ciegos" (arriba/abajo del jugador). 0 = nunca
@export_range(0.0, 1.0) var probabilidad_lado_ciego: float = 0.05
## Probabilidad de quedarse del mismo lado en que ya está (evita cruzar por encima del jugador)
@export_range(0.0, 1.0) var probabilidad_mismo_lado: float = 0.8

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
		enemigo.mirar_hacia(enemigo.jugador.global_position.x - enemigo.global_position.x)
	else:
		_actualizar_punto_acecho()

func _actualizar_punto_acecho() -> void:
	var radio := enemigo.stats.distancia_mantenida
	# Casi nunca: un punto cualquiera alrededor del jugador (puede caer en un lado ciego)
	if randf() < probabilidad_lado_ciego:
		var angulo := randf_range(0.0, TAU)
		punto_acecho_offset = Vector3(cos(angulo), 0.0, sin(angulo)) * radio
		return
	# Normal: a la izquierda o derecha del jugador, casi alineado en Z
	var lado := _lado_actual()
	if randf() >= probabilidad_mismo_lado:
		lado = -lado
	punto_acecho_offset = Vector3(lado * radio, 0.0, randf_range(-desfase_z_maximo, desfase_z_maximo))


## Lado (-1 izquierda / 1 derecha) del jugador en el que está el enemigo ahora
func _lado_actual() -> float:
	if is_instance_valid(enemigo.jugador):
		var dx := enemigo.global_position.x - enemigo.jugador.global_position.x
		if absf(dx) > 0.1:
			return signf(dx)
	return 1.0 if randf() < 0.5 else -1.0
