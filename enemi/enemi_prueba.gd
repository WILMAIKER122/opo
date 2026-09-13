extends CharacterBody3D


# --- RECURSO DE ESTADÍSTICAS ---
@export var stats: EnemigoStats

# --- ESTADOS DEL ENEMIGO ---
enum Estado {
	PATRULLANDO,
	PERSIGUIENDO,
	ATACANDO,
	RECIBIENDO_DANIO,
	ESPERA
}

var estado_actual: Estado = Estado.PATRULLANDO

# --- VARIABLES DINÁMICAS ---
var vida_actual: float

# --- REFERENCIAS ---
@export var jugador: CharacterBody3D

var direccion_patrulla: Vector3 = Vector3.ZERO
var punto_acecho_offset: Vector3 = Vector3.ZERO
var direccion_embestida: Vector3 = Vector3.ZERO
var vector_knockback: Vector3 = Vector3.ZERO # Fuerza actual de empuje

var puede_atacar: bool = true
var esta_estuneado: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Nodos Hijos
@onready var timer_patrulla: Timer = $TimerPatrulla
@onready var timer_ataque: Timer = $TimerAtaque
@onready var label: Label3D = $Label3D


func _ready() -> void:
	# Si no se ha asignado un recurso desde el inspector, crea uno por defecto para evitar errores
	if not stats:
		stats = EnemigoStats.new()

	vida_actual = stats.vida_maxima
	generar_nueva_direccion_patrulla()
	timer_patrulla.timeout.connect(_on_timer_patrulla_timeout)
	timer_ataque.timeout.connect(_on_timer_ataque_timeout)
	timer_patrulla.start(randf_range(2.0, 4.0))


func _physics_process(delta: float) -> void:
	# Aplica gravedad si está en el aire
	label.text = str(vida_actual)
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Lógica por estado
	match estado_actual:
		Estado.PATRULLANDO:
			_procesar_patrulla(delta)
		Estado.PERSIGUIENDO:
			_procesar_persecucion(delta)
		Estado.ATACANDO:
			_procesar_ataque(delta)
		Estado.RECIBIENDO_DANIO:
			_procesar_recibir_danio(delta)
		Estado.ESPERA:
			velocity.x = move_toward(velocity.x, 0, stats.velocidad_patrulla * delta)
			velocity.z = move_toward(velocity.z, 0, stats.velocidad_patrulla * delta)

	move_and_slide()


# --- LÓGICA DE ESTADOS ---

func _procesar_patrulla(_delta: float) -> void:
	velocity.x = direccion_patrulla.x * stats.velocidad_patrulla
	velocity.z = direccion_patrulla.z * stats.velocidad_patrulla
	
	if direccion_patrulla != Vector3.ZERO:
		look_at(global_position + direccion_patrulla, Vector3.UP)


func _procesar_persecucion(_delta: float) -> void:
	if not is_instance_valid(jugador):
		cambiar_estado(Estado.PATRULLANDO)
		return

	var objetivo_pos = jugador.global_position + punto_acecho_offset
	var direccion = (objetivo_pos - global_position)
	direccion.y = 0
	
	if direccion.length() > 0.5:
		direccion = direccion.normalized()
		velocity.x = direccion.x * stats.velocidad_persecucion
		velocity.z = direccion.z * stats.velocidad_persecucion
		look_at(jugador.global_position, Vector3.UP)
	else:
		_actualizar_punto_acecho()


func _procesar_ataque(_delta: float) -> void:
	velocity.x = direccion_embestida.x * stats.velocidad_embestida
	velocity.z = direccion_embestida.z * stats.velocidad_embestida


func _procesar_recibir_danio(delta: float) -> void:
	# Reducimos progresivamente la velocidad del empuje (fricción)
	vector_knockback = vector_knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.x = vector_knockback.x
	velocity.z = vector_knockback.z


func cambiar_estado(nuevo_estado: Estado) -> void:
	# Si está estuneado o recibiendo daño, no permite cambiar de estado por detección de áreas
	if estado_actual == Estado.RECIBIENDO_DANIO and nuevo_estado != Estado.PERSIGUIENDO and nuevo_estado != Estado.PATRULLANDO:
		return

	if estado_actual == nuevo_estado:
		return
		
	estado_actual = nuevo_estado
	
	match estado_actual:
		Estado.PATRULLANDO:
			generar_nueva_direccion_patrulla()
		Estado.PERSIGUIENDO:
			_actualizar_punto_acecho()
		Estado.ATACANDO:
			_iniciar_secuencia_ataque()


# --- SISTEMA DE DAÑO, KNOCKBACK Y STUN ---

func recibir_danio(cantidad_danio: float, origen_impacto: Vector3, fuerza_knockback: float = 10.0, duracion_stun: float = 0.3) -> void:
	vida_actual -= cantidad_danio
	
	if vida_actual <= 0:
		morir()
		return

	# Calculamos la dirección opuesta al punto desde donde fue atacado
	var direccion_empuje = (global_position - origen_impacto)
	direccion_empuje.y = 0 # Mantener el empuje en el plano horizontal
	direccion_empuje = direccion_empuje.normalized()

	# Asignamos la fuerza del knockback
	vector_knockback = direccion_empuje * fuerza_knockback
	
	# Cambiamos al estado de recibir daño
	estado_actual = Estado.RECIBIENDO_DANIO
	
	var tiempo_total_recuperacion = max(0.2, duracion_stun)
	
	await get_tree().create_timer(tiempo_total_recuperacion).timeout
	
	if vida_actual > 0:
		if is_instance_valid(jugador):
			cambiar_estado(Estado.PERSIGUIENDO)
		else:
			cambiar_estado(Estado.PATRULLANDO)


func morir() -> void:
	queue_free()


# --- FUNCIONES AUXILIARES ---

func generar_nueva_direccion_patrulla() -> void:
	var angulo_aleatorio = randf_range(0, TAU)
	direccion_patrulla = Vector3(cos(angulo_aleatorio), 0, sin(angulo_aleatorio)).normalized()


func _actualizar_punto_acecho() -> void:
	var angulo = randf_range(0, TAU)
	punto_acecho_offset = Vector3(cos(angulo), 0, sin(angulo)) * stats.distancia_mantenida


func _iniciar_secuencia_ataque() -> void:
	if not is_instance_valid(jugador):
		cambiar_estado(Estado.PATRULLANDO)
		return

	velocity = Vector3.ZERO
	look_at(jugador.global_position, Vector3.UP)
	
	direccion_embestida = (jugador.global_position - global_position)
	direccion_embestida.y = 0
	direccion_embestida = direccion_embestida.normalized()

	await get_tree().create_timer(0.3).timeout
	
	if estado_actual != Estado.ATACANDO:
		return

	await get_tree().create_timer(0.4).timeout
	
	puede_atacar = false
	timer_ataque.start(stats.tiempo_cooldown_ataque)
	
	if estado_actual == Estado.ATACANDO:
		cambiar_estado(Estado.PERSIGUIENDO)


func _on_area_ataque_body_entered(body: Node3D) -> void:
	if body == jugador and puede_atacar and estado_actual != Estado.RECIBIENDO_DANIO:
		cambiar_estado(Estado.ATACANDO)


# --- TIMERS ---

func _on_timer_patrulla_timeout() -> void:
	if estado_actual == Estado.PATRULLANDO:
		if randf() > 0.5:
			generar_nueva_direccion_patrulla()
		else:
			direccion_patrulla = Vector3.ZERO
		
		timer_patrulla.start(randf_range(2.0, 4.0))


func _on_timer_ataque_timeout() -> void:
	puede_atacar = true


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		jugador = body as CharacterBody3D
		if estado_actual != Estado.RECIBIENDO_DANIO:
			cambiar_estado(Estado.PERSIGUIENDO)


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == jugador:
		jugador = null
		if estado_actual != Estado.RECIBIENDO_DANIO:
			cambiar_estado(Estado.PATRULLANDO)
