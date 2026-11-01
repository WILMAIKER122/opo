extends EstadoEnemigo
class_name EstadoAtaque
## BASE de todos los ataques del enemigo (embestida, ataque normal, normal + salto atrás...).
##
## Cómo usarlo: en la escena del enemigo, el hijo de StateMachine se llama SIEMPRE "Atacando"
## (así lo llaman AreaAtaque y el resto de estados). Para cambiar el tipo de enemigo solo
## cambiás el script de ese nodo por EstadoAtacando, EstadoAtaqueNormal o EstadoAtaqueSalto.
##
## Los ataques NO usan await: avanzan por fases con una cuenta regresiva en
## actualizar_fisicas(). Si el enemigo recibe daño o muere a mitad de un ataque,
## no queda ninguna corrutina colgada.

@export_group("Daño")
## Multiplica el danio_ataque de EnemigoStats para este ataque
@export var multiplicador_dano: float = 1.0
## Multiplica el knockback_ataque de EnemigoStats para este ataque
@export var multiplicador_knockback: float = 1.0



## true mientras el AreaDanio puede lastimar (Enemi._on_area_danio_body_entered lo consulta)
var haciendo_dano: bool = false
## Evita golpear más de una vez por golpe
var golpeo_realizado: bool = false
## Cuenta regresiva de la fase actual (se descuenta sola en cada frame de física)
var _tiempo_fase: float = 0.0

@export_group("Área de daño")
## Posición X del AreaDanio mientras dura este ataque (mirando a la derecha; el enemigo la espeja solo).
## 0 = alrededor del cuerpo (embestida). Positivo = caja por delante (golpe).
@export var area_danio_x: float = 0.0
# ==============================================================================
# CICLO (no hace falta tocarlo)
# ==============================================================================

func entrar() -> void:
	haciendo_dano = false
	golpeo_realizado = false
	_frenar()
	enemigo.fijar_area_danio_x(area_danio_x)

	if not is_instance_valid(enemigo.jugador):
		enemigo.state_machine.cambiar_estado("patrullando")
		return

	_mirar_jugador()
	_al_iniciar_ataque()


func salir() -> void:
	haciendo_dano = false
	_activar_area_danio(false)
	_frenar()


func actualizar_fisicas(delta: float) -> void:
	_tiempo_fase -= delta
	_procesar_ataque(delta)


# ==============================================================================
# LO QUE REDEFINE CADA ATAQUE
# ==============================================================================

## Se llama una vez al empezar el ataque (acá se arma la primera fase)
func _al_iniciar_ataque() -> void:
	pass


## Se llama en cada frame de física; acá va la lógica de fases del ataque
func _procesar_ataque(_delta: float) -> void:
	pass


# ==============================================================================
# HERRAMIENTAS PARA LOS ATAQUES
# ==============================================================================

func _frenar() -> void:
	enemigo.velocity.x = 0.0
	enemigo.velocity.z = 0.0


func _mirar_jugador() -> void:
	if is_instance_valid(enemigo.jugador):
		enemigo.mirar_hacia(enemigo.jugador.global_position.x - enemigo.global_position.x)


## Dirección horizontal (normalizada) hacia el jugador. Vector3.ZERO si no hay jugador.
func _direccion_al_jugador() -> Vector3:
	if not is_instance_valid(enemigo.jugador):
		return Vector3.ZERO
	var d := enemigo.jugador.global_position - enemigo.global_position
	d.y = 0.0
	return d.normalized()


## Enciende el AreaDanio: desde ahora el golpe puede lastimar
func _empezar_dano() -> void:
	haciendo_dano = true
	golpeo_realizado = false
	_activar_area_danio(true)


func _terminar_dano() -> void:
	haciendo_dano = false
	_activar_area_danio(false)


## Encender el monitoring hace que el Area emita body_entered también para
## cuerpos que ya estaban adentro, así no se pierde un golpe a quemarropa.
func _activar_area_danio(activo: bool) -> void:
	if enemigo and enemigo.area_danio:
		enemigo.area_danio.set_deferred("monitoring", activo)


## Cierra el ataque: arranca el cooldown y vuelve a perseguir
func _terminar_ataque() -> void:
	_terminar_dano()
	_frenar()
	enemigo.puede_atacar = false
	enemigo.timer_ataque.start(enemigo.stats.tiempo_cooldown_ataque)
	enemigo.state_machine.cambiar_estado("persiguiendo")
