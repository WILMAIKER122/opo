extends EstadoAtaque
class_name EstadoAtaqueSalto
## ATAQUE 3 — GOLPE NORMAL + SALTO HACIA ATRÁS.
## Avisa, golpea con el AreaDanio y después salta alejándose del jugador (sigue mirándolo).
## Aterriza y recién ahí empieza el cooldown, así que el jugador puede castigarlo
## o perseguirlo mientras está en el aire.

@export_group("Tiempos")
@export var tiempo_aviso: float = 0.45
@export var duracion_golpe: float = 0.2
## Pausa corta entre el golpe y el salto
@export var pausa_antes_del_salto: float = 0.15

@export_group("Salto hacia atrás")
## Impulso vertical (altura del salto)
@export var fuerza_salto: float = 4.0
## Velocidad horizontal alejándose del jugador (distancia del salto)
@export var velocidad_salto: float = 4.0
## Seguro: si por algún motivo no aterriza, el salto termina a este tiempo
@export var tiempo_maximo_salto: float = 1.2

enum Fase { AVISO, GOLPE, PAUSA, SALTO }
var _fase: Fase = Fase.AVISO
var _direccion_inicial: Vector3 = Vector3.ZERO
var _direccion_salto: Vector3 = Vector3.ZERO
var _despego: bool = false


func _al_iniciar_ataque() -> void:
	_direccion_inicial = _direccion_al_jugador()
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
			_frenar()
			if _tiempo_fase <= 0.0:
				_terminar_dano()
				_fase = Fase.PAUSA
				_tiempo_fase = pausa_antes_del_salto

		Fase.PAUSA:
			_frenar()
			if _tiempo_fase <= 0.0:
				_empezar_salto()

		Fase.SALTO:
			enemigo.velocity.x = _direccion_salto.x * velocidad_salto
			enemigo.velocity.z = _direccion_salto.z * velocidad_salto
			if not enemigo.is_on_floor():
				_despego = true
			if (_despego and enemigo.is_on_floor()) or _tiempo_fase <= 0.0:
				_terminar_ataque()


func _empezar_salto() -> void:
	# Se aleja de donde está el jugador AHORA; si lo perdió, usa la dirección del inicio
	var hacia_jugador := _direccion_al_jugador()
	if hacia_jugador == Vector3.ZERO:
		hacia_jugador = _direccion_inicial
	_direccion_salto = -hacia_jugador
	_despego = false
	enemigo.velocity.y = fuerza_salto
	_fase = Fase.SALTO
	_tiempo_fase = tiempo_maximo_salto
