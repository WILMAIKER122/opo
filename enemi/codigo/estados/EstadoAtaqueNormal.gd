extends EstadoAtaque
class_name EstadoAtaqueNormal
## ATAQUE 2 — GOLPE NORMAL (cuerpo a cuerpo).
## Se frena, avisa, golpea con el AreaDanio y queda expuesto un momento (recuperación).
##
## En la escena de este enemigo, el AreaDanio conviene como una caja DELANTE del cuerpo
## (position.x positiva: mirando a la derecha). Se espeja sola al cambiar de lado.

@export_group("Tiempos")
## Segundos de aviso antes del golpe (es la ventana para esquivar)
@export var tiempo_aviso: float = 0.5
## Segundos que el AreaDanio queda activo
@export var duracion_golpe: float = 0.2
## Segundos que queda quieto y vulnerable después del golpe
@export var tiempo_recuperacion: float = 0.6

@export_group("Movimiento")
## Velocidad hacia el jugador durante el golpe (0 = se queda en el lugar)
@export var avance_en_golpe: float = 0.0

enum Fase { AVISO, GOLPE, RECUPERACION }
var _fase: Fase = Fase.AVISO
var _direccion: Vector3 = Vector3.ZERO


func _al_iniciar_ataque() -> void:
	_direccion = _direccion_al_jugador()
	_fase = Fase.AVISO
	_tiempo_fase = tiempo_aviso


func _procesar_ataque(_delta: float) -> void:
	match _fase:
		Fase.AVISO:
			_frenar()
			if _tiempo_fase <= 0.0:
				_fase = Fase.GOLPE
				_tiempo_fase = duracion_golpe
				_empezar_dano()

		Fase.GOLPE:
			enemigo.velocity.x = _direccion.x * avance_en_golpe
			enemigo.velocity.z = _direccion.z * avance_en_golpe
			if _tiempo_fase <= 0.0:
				_terminar_dano()
				_fase = Fase.RECUPERACION
				_tiempo_fase = tiempo_recuperacion

		Fase.RECUPERACION:
			_frenar()
			if _tiempo_fase <= 0.0:
				_terminar_ataque()
