class_name CombateJugador
extends RefCounted
## Daño, invulnerabilidad, muerte y esquive perfecto del jugador.
## Los datos y los @export siguen en Player (_p) para no perder lo configurado en el inspector.
## Destino: res://pj/codigos/estados/jugador_combate.gd

var _p: Player
var _ultimo_esquive_ms: int = -1000


func _init(jugador: Player) -> void:
	_p = jugador


## Llamar cada frame desde Player._process
func actualizar(delta: float) -> void:
	if _p.tiempo_invulnerable > 0.0:
		_p.tiempo_invulnerable -= delta
	comprobar_muerte()


func esta_invulnerable() -> bool:
	return _p.tiempo_invulnerable > 0.0 or _esta_en_dash()


func _esta_en_dash() -> bool:
	var actual = _p.state_machine.current_state
	return actual != null and actual.name.to_lower().contains("dash")


## true si el golpe entró (el dash lo esquiva y devuelve false)
func recibir_dano(cantidad: float, origen: Vector3 = Vector3.ZERO, fuerza_knockback: float = 0.0) -> bool:
	if _p.muerto:
		return false
	if _esta_en_dash():
		_esquive_perfecto()
		return false
	if esta_invulnerable():
		return false

	_p.estadisticas.recibir_dano(cantidad)
	EfectosCombate.numero_flotante(
		_p.get_tree().current_scene,
		_p.global_position + Vector3(0.0, 1.6, 0.0),
		str(roundi(cantidad)),
		Color(1.0, 0.35, 0.35))
	_p.tiempo_invulnerable = _p.duracion_invulnerabilidad
	print("Jugador recibió %.1f de daño (vida: %.1f)" % [cantidad, _p.estadisticas.vida])
	_p.dano_recibido.emit(cantidad)

	comprobar_muerte()
	if _p.muerto:
		return true

	_p.state_machine.transition_to("RecibiendoDanio")
	var estado := _p.state_machine.current_state as EstadoDanioJugador
	if estado:
		estado.aplicar_knockback(origen, fuerza_knockback)
	return true


func comprobar_muerte() -> void:
	if _p.muerto or not CodigoGlobal.en_run:
		return
	if _p.estadisticas.vida <= 0.0:
		_p.muerto = true
		print("El jugador murió")
		CodigoGlobal.call_deferred("morir", _p.estadisticas)


## Un golpe te alcanzó justo durante el dash
func _esquive_perfecto() -> void:
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_esquive_ms < 400:
		return
	_ultimo_esquive_ms = ahora
	_p.contraataque_hasta_ms = ahora + int(_p.esquive_ventana_contraataque * 1000.0)
	_p.dash_sin_cooldown = true
	EfectosCombate.numero_flotante(
		_p.get_tree().current_scene,
		_p.global_position + Vector3(0.0, 2.0, 0.0),
		"!esquive!",
		Color(0.5, 0.9, 1.0), 1.2)

	_p.get_tree().call_group("zeta_suelta", "volver_ya")
	if _p.esquive_devuelve_hambre:
		_p.estadisticas.hambre.comer(_p.estadisticas.hambre.costo_dash)

	# Efecto único de la Zeta: chispas al esquivar (si tiene la escena asignada)
	var efectos: ZetaPasivaEfectosUnicos = null
	if _p.estadisticas.zeta_actual:
		efectos = _p.estadisticas.zeta_actual.EfectosUnicos
	if efectos and efectos.lanzar_chispas_al_esquivar and efectos.escena_chispas:
		var chispas := efectos.escena_chispas.instantiate()
		_p.get_tree().current_scene.add_child(chispas)
		chispas.global_position = _p.global_position

	if _p.esquive_slowmo_segundos > 0.0:
		CodigoGlobal.slowmo(_p.esquive_slowmo_escala, _p.esquive_slowmo_segundos)
