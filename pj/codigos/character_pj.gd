extends CharacterBody3D

@onready var pj: Node3D = $pj/esqueleto/Skeleton3D
@onready var anim_tree: AnimationTree =$AnimationTree 
# Obtenemos el controlador de la máquina de estados del AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# Estados del personaje
enum State { IDLE, RUN, DASH, ATTACK }
var current_state: State = State.IDLE

# Parámetros de movimiento
const MAX_SPEED = 10.0
const ACCELERATION = 22.0
const ROTATION_SPEED = 7.0

# Parámetros del Dash
const DASH_SPEED = 15.0
const DASH_DURATION = 0.30
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

# Parámetros de Ataque / Combo
@export var attack_animations: Array[String] = ["ataque", "attack_2", "attack_3"]
var combo_index: int = 0
var combo_queued: bool = false

# Tiempos (en segundos) para la ventana de cancelación e inicio/fin de cada ataque.
# Ajusta según la duración real en Blender.
const CANCEL_WINDOW_START: Dictionary = {
	"ataque": 0.25,
	"attack_2": 0.30,
	"attack_3": 0.99
}

const ATTACK_DURATION: Dictionary = {
	"ataque": 0.50,
	"attack_2": 0.55,
	"attack_3": 0.80
}

# Registro de la última dirección de movimiento válida
var last_movement_direction: Vector3 = Vector3(-1.0, 0.0, 0.0)

func _physics_process(delta: float) -> void:

	# 1. Gravedad básica
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# 2. Captura de entrada
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		last_movement_direction = direction

	# 3. Máquina de Estados (Evaluación)
	match current_state:
		State.IDLE:
			_state_idle(delta, direction, input_dir)
		State.RUN:
			_state_run(delta, direction, input_dir)
		State.DASH:
			_state_dash(delta, direction)
		State.ATTACK:
			_state_attack(delta)

	# 4. Control de Escala y Rotación (Solo rotar si no está atacando)
	if current_state != State.ATTACK:
		_handle_rotation(delta, direction)

	# 5. Aplicar movimiento
	move_and_slide()

# --- LÓGICA DE ESTADOS ---

func _state_idle(_delta: float, direction: Vector3, input_dir: Vector2) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	playback.travel("idle")

	if Input.is_action_just_pressed("x"):
		_start_attack()
	elif Input.is_action_just_pressed("z"):
		_enter_dash_state(input_dir)
	elif direction != Vector3.ZERO:
		current_state = State.RUN

func _state_run(delta: float, direction: Vector3, input_dir: Vector2) -> void:
	var target_velocity = direction * MAX_SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)
	playback.travel("run")

	if Input.is_action_just_pressed("x"):
		_start_attack()
	elif Input.is_action_just_pressed("z"):
		_enter_dash_state(input_dir)
	elif direction == Vector3.ZERO:
		current_state = State.IDLE

func _state_dash(delta: float, direction: Vector3) -> void:
	dash_timer -= delta
	velocity.x = dash_direction.x * DASH_SPEED
	velocity.z = dash_direction.z * DASH_SPEED

	if Input.is_action_just_pressed("x"):
		_start_attack()
	elif dash_timer <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if direction != Vector3.ZERO:
			current_state = State.RUN
		else:
			current_state = State.IDLE

func _state_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * delta)

	if Input.is_action_just_pressed("x"):
		combo_queued = true

	# Leemos el estado actual directamente desde el AnimationTree
	var current_anim = playback.get_current_node()
	var current_time = playback.get_current_play_position()
	var cancel_time = CANCEL_WINDOW_START.get(current_anim, 99.0)
	var max_duration = ATTACK_DURATION.get(current_anim, 0.0)

	# Opción A: Presionó 'x' y cruzó la ventana -> Cancelar e ir al siguiente golpe
	if combo_queued and current_time >= cancel_time:
		if combo_index + 1 < attack_animations.size():
			combo_index += 1
			combo_queued = false
			_play_current_attack()

	# Opción B: Terminó la animación completa sin presionar 'x' -> Volver a IDLE o RUN
	elif current_time >= max_duration:
		_exit_attack_state()

# --- FUNCIONES AUXILIARES DE ATAQUE ---

func _start_attack() -> void:
	current_state = State.ATTACK
	combo_index = 0
	combo_queued = false
	_play_current_attack()

func _play_current_attack() -> void:
	if combo_index < attack_animations.size():
		playback.travel(attack_animations[combo_index])

func _exit_attack_state() -> void:
	combo_index = 0
	combo_queued = false
	
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		current_state = State.RUN
	else:
		current_state = State.IDLE

# --- FUNCIONES AUXILIARES EXISTENTES ---

func _enter_dash_state(_input_dir: Vector2) -> void:
	current_state = State.DASH
	dash_timer = DASH_DURATION
	playback.travel("dash")
	
	var dir_x: float = 0.0
	var dir_z: float = 0.0

	if Input.is_action_pressed("ui_right"):
		dir_x += 1.0
	if Input.is_action_pressed("ui_up"):
		dir_z -= 1.0
	if Input.is_action_pressed("ui_left"):
		dir_x -= 1.0
	if Input.is_action_pressed("ui_down"):
		dir_z += 1.0

	var dash_vector := Vector3(dir_x, 0.0, dir_z)

	if dash_vector != Vector3.ZERO:
		dash_direction = dash_vector.normalized()
	else:
		dash_direction = last_movement_direction.normalized()

func _handle_rotation(delta: float, direction: Vector3) -> void:
	if direction != Vector3.ZERO:
		if Input.is_action_pressed("ui_left"):
			pj.scale.x = lerp(pj.scale.x, -1.0, ROTATION_SPEED * delta)
		if Input.is_action_pressed("ui_right"):
			pj.scale.x = lerp(pj.scale.x, 1.0, ROTATION_SPEED * delta)
