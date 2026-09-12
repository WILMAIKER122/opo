extends Camera3D

@export_group("Objetivo y Suavizado")
@export var target: Player                           # Referencia fuertemente tipada a Player
@export var smooth_speed: float = 6.0               # Velocidad de seguimiento normal

@export_group("Perspectiva (Cult of the Lamb)")
@export var base_offset: Vector3 = Vector3(0, 5, 4) # Altura y distancia
@export var pitch_angle: float = -50.0              # Ángulo de inclinación

@export_group("Adelanto Horizontal X (Look-Ahead)")
@export var horizontal_peek_distance: float = 1.0   # Adelanto horizontal en X
@export var peek_smooth_speed: float = 4.0          # Velocidad de lerp del adelanto X

@export_group("Comportamiento de Dash")
@export var dash_lag_speed: float = 10.0            # Velocidad muy baja durante el dash
@export var catch_up_speed: float = 14.0            # Velocidad rápida para alcanzarlo al frenar

# Máquina de estados propia de la cámara
enum State { NORMAL, LAG, CATCH_UP }
var current_state = State.NORMAL

var current_peek_x: float = 0.0
var was_dashing: bool = false

func _ready() -> void:
	rotation_degrees = Vector3(pitch_angle, 0, 0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	# 1. Detección limpia evaluando la StateMachine del Player
	var is_target_dashing: bool = _check_is_target_dashing()

	# 2. Transiciones entre estados de cámara
	_update_state_transitions(is_target_dashing)

	# 3. Calcular el Look-Ahead (Adelanto) SOLO para el eje X
	var target_peek_x = _calculate_peek_x()
	
	# Durante el lag/dash quitamos el adelanto para forzar el retraso de la cámara
	if current_state == State.LAG:
		current_peek_x = lerp(current_peek_x, 0.0, peek_smooth_speed * 2.0 * delta)
	else:
		current_peek_x = lerp(current_peek_x, target_peek_x, peek_smooth_speed * delta)

	# 4. Ejecución del estado actual de la cámara
	match current_state:
		State.NORMAL:
			_state_normal(delta)
		State.LAG:
			_state_lag(delta)
		State.CATCH_UP:
			_state_catch_up(delta)

# --- LÓGICA DE ESTADOS Y DETECCIÓN ---

func _check_is_target_dashing() -> bool:
	if target and target.state_machine and target.state_machine.current_state:
		# Comprueba si el nodo de estado activo se llama "dash" (en minúsculas)
		return target.state_machine.current_state.name.to_lower() == "dash"
	return false

func _state_normal(delta: float) -> void:
	_follow_target(delta, smooth_speed)

func _state_lag(delta: float) -> void:
	_follow_target(delta, dash_lag_speed)

func _state_catch_up(delta: float) -> void:
	_follow_target(delta, catch_up_speed)
	
	var desired_pos = _get_desired_position()
	if global_position.distance_to(desired_pos) < 0.2:
		current_state = State.NORMAL

# --- FUNCIONES AUXILIARES ---

func _update_state_transitions(is_target_dashing: bool) -> void:
	if is_target_dashing and not was_dashing:
		current_state = State.LAG
	elif not is_target_dashing and was_dashing:
		current_state = State.CATCH_UP
		
	was_dashing = is_target_dashing

func _calculate_peek_x() -> float:
	var facing_dir_x: float = 0.0

	# Evalúa primero la velocidad física del Player
	if abs(target.velocity.x) > 0.2:
		facing_dir_x = sign(target.velocity.x)
	else:
		# Si está detenido, consulta la escala horizontal guardada en su modelo
		if target.pj:
			facing_dir_x = 1.0 if target.pj.scale.x > 0 else -1.0

	return facing_dir_x * horizontal_peek_distance

func _get_desired_position() -> Vector3:
	var desired_position = target.global_position + base_offset
	desired_position.x += current_peek_x
	return desired_position

func _follow_target(delta: float, speed: float) -> void:
	var desired_position = _get_desired_position()
	global_position = global_position.lerp(desired_position, speed * delta)
