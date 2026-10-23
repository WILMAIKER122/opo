extends CharacterBody3D
class_name Enemigo

@export var stats: EnemigoStats
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
var mirando_derecha: bool = true

# --- INICIO DEL ATAQUE ---
## El ataque empieza cuando el jugador está a esta distancia (horizontal) del CENTRO de AreaAtaque.
## 0 = automática (distancia_mantenida + 0.6). Tiene que ser mayor que distancia_mantenida,
## si no el enemigo nunca llega a esa distancia y no ataca.
@export var distancia_inicio_ataque: float = 0.0
## Segundos que el jugador tiene que seguir en posición (dentro del área y cerca del centro) antes de atacar
@export var tiempo_espera_ataque: float = 0.2
var _tiempo_en_posicion: float = 0.0
var _escala_base_x: float = 1.0
var _escala_objetivo_x: float = 1.0
var _pos_base_x: Dictionary = {}


func _ready() -> void:
	if not stats:
		stats = EnemigoStats.new()

	vida_actual = stats.vida_maxima

	if visual == null:
		for hijo in get_children():
			if hijo is MeshInstance3D:
				visual = hijo
				break
	if visual:
		_escala_base_x = absf(visual.scale.x)
		_escala_objetivo_x = visual.scale.x

	# Posición X de cada área tal como la dejaste en el editor (mirando a la derecha)
	if areas_a_voltear.is_empty():
		for area in [area_ataque, area_danio]:
			if area:
				areas_a_voltear.append(area)
	for area in areas_a_voltear:
		if area:
			_pos_base_x[area] = area.position.x

	timer_ataque.timeout.connect(_on_timer_ataque_timeout)

	# Inicializamos la máquina de estados pasando esta instancia del enemigo
	state_machine.inicializar(self)

	# El área de daño solo se enciende durante la embestida (lo hace EstadoAtacando)
	if area_danio:
		area_danio.monitoring = false


func _physics_process(delta: float) -> void:
	label.text = str(vida_actual)

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Delegamos la física al estado activo
	state_machine.actualizar_fisicas(delta)
	_evaluar_inicio_ataque(delta)

	move_and_slide()


func _process(delta: float) -> void:
	state_machine.actualizar(delta)
	_actualizar_giro(delta)


# --- ORIENTACIÓN ---

## Define hacia qué lado mira el enemigo según el signo de direccion_x
## (eje X del mundo). Si el valor es casi 0 mantiene el lado actual.
func mirar_hacia(direccion_x: float) -> void:
	if absf(direccion_x) < 0.05:
		return
	var lado_anterior := mirando_derecha
	mirando_derecha = direccion_x > 0.0
	if invertir_lado:
		mirando_derecha = not mirando_derecha
	if mirando_derecha != lado_anterior:
		_aplicar_lado_a_areas()
	_escala_objetivo_x = _escala_base_x if mirando_derecha else -_escala_base_x


## Gira suave la malla hacia el lado objetivo (se llama cada frame desde _process)
func _actualizar_giro(delta: float) -> void:
	if visual == null:
		return
	var nueva := move_toward(visual.scale.x, _escala_objetivo_x, velocidad_giro * delta)
	# Evita quedar en escala 0 exacta
	if absf(nueva) < 0.02:
		nueva = 0.02 * signf(_escala_objetivo_x)
	visual.scale.x = nueva


## Espeja las áreas de golpe (sin escalar): AreaDanio / AreaAtaque pasan al lado al que mira
func _aplicar_lado_a_areas() -> void:
	var signo := 1.0 if mirando_derecha else -1.0
	for area in areas_a_voltear:
		if area and _pos_base_x.has(area):
			area.position.x = _pos_base_x[area] * signo


# --- SISTEMA DE DAÑO Y KNOCKBACK ---

func recibir_danio(cantidad_danio: float, origen_impacto: Vector3, fuerza_knockback: float = 10.0, duracion_stun: float = 0.3) -> void:
	vida_actual -= cantidad_danio

	if vida_actual <= 0:
		morir()
		return

	# Cambiamos al estado de recibir daño y ejecutamos su empuje
	state_machine.cambiar_estado("recibiendodanio")

	var estado_danio = state_machine.estado_actual as EstadoRecibiendoDanio
	if estado_danio:
		estado_danio.aplicar_knockback(origen_impacto, fuerza_knockback, duracion_stun)


@export var escena_parte_drop: PackedScene # Arrastra aquí la escena de tu Node3D
func morir() -> void:
	var cantidad = randi_range(1, 5)
	for i in range(cantidad):
		var nueva_pieza = escena_parte_drop.instantiate()
		get_tree().current_scene.add_child(nueva_pieza)
		nueva_pieza.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
	queue_free()


# --- SEÑALES ---

# AreaAtaque.body_entered: YA NO dispara el ataque. Lo decide _evaluar_inicio_ataque(),
# que espera a que el jugador esté bien dentro del área. Se deja la función para no romper
# la conexión de la señal en el editor.
func _on_area_ataque_body_entered(_body: Node3D) -> void:
	pass


## Decide cuándo empieza el ataque: el jugador debe estar dentro de AreaAtaque,
## cerca del centro del área y mantenerse así tiempo_espera_ataque segundos.
func _evaluar_inicio_ataque(delta: float) -> void:
	var puede := state_machine.estado_actual is EstadoPersiguiendo \
		and puede_atacar \
		and area_ataque != null \
		and is_instance_valid(jugador) \
		and area_ataque.overlaps_body(jugador)

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
		state_machine.cambiar_estado("atacando")


# AreaDanio.body_entered -> HACE DAÑO al jugador (solo mientras el ataque actual esté "haciendo_dano").
# Sirve para cualquier ataque: EstadoAtacando, EstadoAtaqueNormal, EstadoAtaqueSalto...
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


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == jugador:
		jugador = null
		if state_machine.estado_actual.name != "RecibiendoDanio":
			state_machine.cambiar_estado("patrullando")


func _on_timer_ataque_timeout() -> void:
	puede_atacar = true
