extends CharacterBody3D
class_name Enemigo
## Enemigo base. Delegados:
##   OrientacionEnemigo   (giro de la malla y espejado de áreas)
##   AlteracionesEnemigo  (veneno, quemadura, lentitud)
##   EfectosCombate       (números flotantes y destello)

enum TipoAtaque { EMBESTIDA, NORMAL, SALTO }

## Nodo de la StateMachine que ejecuta cada ataque
const ESTADO_POR_ATAQUE := {
	TipoAtaque.EMBESTIDA: "AtaqueEmbestida",
	TipoAtaque.NORMAL: "AtaqueNormal",
	TipoAtaque.SALTO: "AtaqueSalto",
}

@export_group("Combinación")
## Qué enemigo es: de acá salen vida, velocidades, daño, botín y registro del Tomo
@export var tipo_enemigo: EnemigoStats
## Qué ataque usa. Cada enemigo hace UN solo tipo de ataque
@export var tipo_ataque: TipoAtaque = TipoAtaque.NORMAL
## Cuántos enemigos pueden estar atacando a la vez; los demás siguen acechando
@export var max_atacantes_simultaneos: int = 2

## Las estadísticas en uso (el resto del código sigue leyendo enemigo.stats)
var stats: EnemigoStats
@export var jugador: CharacterBody3D

var vida_actual: float
var puede_atacar: bool = true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Nodos Hijos
@onready var state_machine: StateMachine_enemi = $StateMachine
@onready var timer_ataque: Timer = $TimerAtaque
@onready var label: Label3D = $Label3D
@onready var timer_patrulla: Timer = $TimerPatrulla
@onready var area_danio: Area3D = $AreaDanio
@onready var area_ataque: Area3D = get_node_or_null("AreaAtaque")

# --- ORIENTACIÓN (solo izquierda/derecha, igual que el personaje: scale.x = 1 / -1) ---
## Malla que se voltea con scale.x (suave, como el personaje). Vacío = primer MeshInstance3D hijo.
## NUNCA escales el CharacterBody3D ni sus áreas: Jolt no soporta escala no uniforme en formas físicas.
@export var visual: Node3D
## Áreas que se espejan según el lado (se invierte su position.x, sin escalar).
## Vacío = AreaAtaque y AreaDanio. Agregá acá cualquier otra área que esté corrida del centro.
@export var areas_a_voltear: Array[Node3D] = []
## Activalo si en pantalla se ve al revés (depende del ángulo de cámara)
@export var invertir_lado: bool = false
## Velocidad del giro (unidades de scale.x por segundo). Usá el mismo valor que ROTATION_SPEED del personaje.
@export var velocidad_giro: float = 12.0

# --- INICIO DEL ATAQUE ---
## El ataque empieza cuando el jugador está a esta distancia (horizontal) del CENTRO de AreaAtaque.
## 0 = automática (distancia_mantenida + 0.6). Tiene que ser mayor que distancia_mantenida,
## si no el enemigo nunca llega a esa distancia y no ataca.
@export var distancia_inicio_ataque: float = 0.0
## Segundos que el jugador tiene que seguir en posición (dentro del área y cerca del centro) antes de atacar
@export var tiempo_espera_ataque: float = 0.2
@export var escena_parte_drop: PackedScene # Arrastra aquí la escena de tu Node3D

@export_group("Efectos de golpe")
## Opcional: la textura del enemigo, para que el destello respete su silueta
## (necesario si la malla usa alfa recortado como el personaje). Con la cápsula de prueba no hace falta.
@export var textura_destello: Texture2D
@export var segundos_destello: float = 0.08

var _tiempo_en_posicion: float = 0.0
var _muriendo: bool = false
var _orientacion: OrientacionEnemigo
var _alteraciones := AlteracionesEnemigo.new()


func _ready() -> void:
	add_to_group("enemigos")
	stats = tipo_enemigo if tipo_enemigo else EnemigoStats.new()
	if CodigoGlobal.nivel_sala > 0:
		stats = stats.duplicate()
		var f := 1.0 + 0.25 * CodigoGlobal.nivel_sala
		stats.vida_maxima *= f
		stats.danio_ataque *= f
	vida_actual = stats.vida_maxima

	if visual == null:
		for hijo in get_children():
			if hijo is MeshInstance3D:
				visual = hijo
				break
	if areas_a_voltear.is_empty():
		for area in [area_ataque, area_danio]:
			if area:
				areas_a_voltear.append(area)
	_orientacion = OrientacionEnemigo.new(visual, areas_a_voltear, invertir_lado, velocidad_giro)

	timer_ataque.timeout.connect(_on_timer_ataque_timeout)

	# Inicializamos la máquina de estados pasando esta instancia del enemigo
	state_machine.inicializar(self)

	# El área de daño solo se enciende durante el ataque (lo hace EstadoAtaque)
	if area_danio:
		area_danio.monitoring = false


func _physics_process(delta: float) -> void:
	label.text = str(vida_actual)

	var dano_dot := _alteraciones.actualizar(delta)
	if dano_dot > 0.0:
		_aplicar_dano_dot(dano_dot)
	if _muriendo:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Delegamos la física al estado activo
	state_machine.actualizar_fisicas(delta)
	# Lentitud: los estados reasignan la velocidad en cada frame, así que no se acumula
	if _alteraciones.factor_velocidad < 1.0:
		velocity.x *= _alteraciones.factor_velocidad
		velocity.z *= _alteraciones.factor_velocidad
	_evaluar_inicio_ataque(delta)

	move_and_slide()


func _process(delta: float) -> void:
	state_machine.actualizar(delta)
	_orientacion.actualizar_giro(delta)


# ==============================================================================
# ORIENTACIÓN (delegada en OrientacionEnemigo)
# ==============================================================================

## Define hacia qué lado mira el enemigo según el signo de direccion_x
func mirar_hacia(direccion_x: float) -> void:
	_orientacion.mirar_hacia(direccion_x)


## Lo llama el ataque al empezar: dónde va el AreaDanio (X mirando a la derecha)
func fijar_area_danio_x(x: float) -> void:
	_orientacion.fijar_x(area_danio, x)


# ==============================================================================
# DAÑO Y MUERTE
# ==============================================================================

func recibir_danio(cantidad_danio: float, origen_impacto: Vector3, fuerza_knockback: float = 10.0, duracion_stun: float = 0.3) -> void:
	if _muriendo:
		return
	vida_actual -= cantidad_danio

	var murio := vida_actual <= 0.0
	EfectosCombate.numero_flotante(
		get_tree().current_scene,
		global_position + Vector3(0.0, 1.4, 0.0),
		str(roundi(cantidad_danio)),
		Color(1.0, 0.85, 0.2) if murio else Color.WHITE,
		1.4 if murio else 1.0)

	if murio:
		morir()
		return

	EfectosCombate.destello(visual as GeometryInstance3D, textura_destello, segundos_destello)

	# Cambiamos al estado de recibir daño y ejecutamos su empuje
	state_machine.cambiar_estado("recibiendodanio")

	var estado_danio = state_machine.estado_actual as EstadoRecibiendoDanio
	if estado_danio:
		estado_danio.aplicar_knockback(origen_impacto, fuerza_knockback, duracion_stun)


func morir() -> void:
	if _muriendo:
		return
	_muriendo = true
	CodigoGlobal.registrar_derrota(stats.id_registro())

	if escena_parte_drop:
		var cantidad := randi_range(stats.cantidad_drop_min, maxi(stats.cantidad_drop_min, stats.cantidad_drop_max))
		for i in cantidad:
			var pieza = escena_parte_drop.instantiate()
			pieza.configurar(stats.elegir_parte())   # null = usa la lista de la escena
			get_tree().current_scene.add_child(pieza)
			pieza.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
	queue_free()


# ==============================================================================
# ESTADOS ALTERADOS (delegados en AlteracionesEnemigo)
# ==============================================================================

## Aplica (o renueva) un estado: daño por segundo y/o lentitud durante `segundos`
func aplicar_estado(id: StringName, dps: float, segundos: float, lentitud: float = 0.0, color: Color = Color.WHITE) -> void:
	if _muriendo:
		return
	_alteraciones.aplicar(id, dps, segundos, lentitud, color)


func _aplicar_dano_dot(danio: float) -> void:
	vida_actual -= danio
	EfectosCombate.numero_flotante(get_tree().current_scene,
			global_position + Vector3(0.0, 1.4, 0.0),
			str(maxi(1, roundi(danio))), _alteraciones.color_dot, 0.7)
	if vida_actual <= 0.0:
		morir()


# ==============================================================================
# INICIO DEL ATAQUE
# ==============================================================================

## Decide cuándo empieza el ataque: el jugador debe estar dentro de AreaAtaque,
## cerca del centro del área y mantenerse así tiempo_espera_ataque segundos.
func _evaluar_inicio_ataque(delta: float) -> void:
	var puede := state_machine.estado_actual is EstadoPersiguiendo \
		and puede_atacar \
		and area_ataque != null \
		and is_instance_valid(jugador) \
		and area_ataque.overlaps_body(jugador) \
		and _hay_cupo_de_ataque()

	if puede:
		var limite := distancia_inicio_ataque
		if limite <= 0.0:
			limite = stats.distancia_mantenida + 0.6
		var d := jugador.global_position - area_ataque.global_position
		d.y = 0.0
		puede = d.length() <= limite

	if not puede:
		_tiempo_en_posicion = 0.0
		return

	_tiempo_en_posicion += delta
	if _tiempo_en_posicion >= tiempo_espera_ataque:
		_tiempo_en_posicion = 0.0
		state_machine.cambiar_estado(ESTADO_POR_ATAQUE[tipo_ataque])


## ¿Hay lugar para que este enemigo ataque ahora?
func _hay_cupo_de_ataque() -> bool:
	var atacando := 0
	for otro in get_tree().get_nodes_in_group("enemigos"):
		if otro != self and otro is Enemigo and otro.state_machine.estado_actual is EstadoAtaque:
			atacando += 1
	return atacando < max_atacantes_simultaneos


# ==============================================================================
# SEÑALES (conectadas desde la escena)
# ==============================================================================

# AreaAtaque.body_entered: YA NO dispara el ataque (lo decide _evaluar_inicio_ataque).
# Se deja la función para no romper la conexión de la señal en el editor.
func _on_area_ataque_body_entered(_body: Node3D) -> void:
	pass


# AreaDanio.body_entered -> HACE DAÑO al jugador (solo mientras el ataque actual esté "haciendo_dano").
func _on_area_danio_body_entered(body: Node3D) -> void:
	var estado := state_machine.estado_actual as EstadoAtaque
	if estado == null or not estado.haciendo_dano or estado.golpeo_realizado:
		return
	if body is Player:
		var danio := stats.danio_ataque * estado.multiplicador_dano
		var empuje := stats.knockback_ataque * estado.multiplicador_knockback
		if (body as Player).recibir_dano(danio, global_position, empuje):
			estado.golpeo_realizado = true


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		jugador = body as CharacterBody3D
		if state_machine.estado_actual.name != "RecibiendoDanio":
			state_machine.cambiar_estado("persiguiendo")
			CodigoGlobal.marcar_visto("bestia:" + stats.id_registro())


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == jugador:
		jugador = null
		if state_machine.estado_actual.name != "RecibiendoDanio":
			state_machine.cambiar_estado("patrullando")


func _on_timer_ataque_timeout() -> void:
	puede_atacar = true
