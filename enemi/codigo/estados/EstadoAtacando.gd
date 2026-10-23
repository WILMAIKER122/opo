extends EstadoAtaque
class_name EstadoAtacando
## ATAQUE 1 — EMBESTIDA.
## Se frena y te mira (aviso), fija la dirección y embiste en línea recta.
## El AreaDanio solo lastima durante la embestida.
##
## En la escena de este enemigo, el AreaDanio conviene como una forma alrededor del cuerpo.

@export_group("Tiempos")
## Segundos que se frena antes de embestir (el "aviso"). 0 = embestida inmediata.
@export var tiempo_aviso: float = 0.3
## Segundos que dura la embestida
@export var tiempo_embestida: float = 0.4

enum Fase { AVISO, EMBESTIDA }
var _fase: Fase = Fase.AVISO
var _direccion_embestida: Vector3 = Vector3.ZERO


func _al_iniciar_ataque() -> void:
	# La dirección se fija ahora: si el jugador se mueve durante el aviso, la esquiva
	_direccion_embestida = _direccion_al_jugador()
	_fase = Fase.AVISO
	_tiempo_fase = tiempo_aviso


func _procesar_ataque(_delta: float) -> void:
	match _fase:
		Fase.AVISO:
			_frenar()
			if _tiempo_fase <= 0.0:
				_fase = Fase.EMBESTIDA
				_tiempo_fase = tiempo_embestida
				_empezar_dano()

		Fase.EMBESTIDA:
			enemigo.velocity.x = _direccion_embestida.x * enemigo.stats.velocidad_embestida
			enemigo.velocity.z = _direccion_embestida.z * enemigo.stats.velocidad_embestida
			if _tiempo_fase <= 0.0:
				_terminar_ataque()
