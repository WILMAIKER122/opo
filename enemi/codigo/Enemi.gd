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


func _ready() -> void:
	if not stats:
		stats = EnemigoStats.new()

	vida_actual = stats.vida_maxima
	
	timer_ataque.timeout.connect(_on_timer_ataque_timeout)
	
	# Inicializamos la máquina de estados pasando esta instancia del enemigo
	state_machine.inicializar(self)


func _physics_process(delta: float) -> void:
	label.text = str(vida_actual)
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Delegamos la física al estado activo
	state_machine.actualizar_fisicas(delta)
	
	move_and_slide()


func _process(delta: float) -> void:
	state_machine.actualizar(delta)


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

func _on_area_ataque_body_entered(body: Node3D) -> void:
	if body == jugador and puede_atacar and state_machine.estado_actual.name != "RecibiendoDanio":
		state_machine.cambiar_estado("atacando")


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
