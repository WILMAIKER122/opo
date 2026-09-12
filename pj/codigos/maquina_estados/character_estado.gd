class_name Player
extends CharacterBody3D
@export var estadisticas:estadisticas_player
@onready var pj: Node3D = $pj/esqueleto/Skeleton3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var state_machine: StateMachine = $estados
@export var zeta_dejar:PackedScene


const ROTATION_SPEED = 7.0

# Registro de última dirección
var last_movement_direction: Vector3 = Vector3(-1.0, 0.0, 0.0)

func _ready() -> void:
	# Inicializar la máquina de estados pasándole la referencia del personaje
	state_machine.init(self)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.handle_input(event)

func _physics_process(delta: float) -> void:
	# Gravedad básica
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Delegar la lógica de físicas al estado activo
	state_machine.update_physics(delta)

	# Aplicar movimiento global
	move_and_slide()

var target_scale_x: float = 1.0

func handle_rotation(delta: float, direction: Vector3) -> void:
	if direction != Vector3.ZERO:
		last_movement_direction = direction
		
	# Actualizamos el objetivo según la tecla que se presione
	if Input.is_action_pressed("ui_left"):
		target_scale_x = -1.0
		$Area3D.position.x = -0.4
	elif Input.is_action_pressed("ui_right"):
		target_scale_x = 1.0
		$Area3D.position.x = 1.6
	# El personaje se sigue moviendo hacia el objetivo aunque ya no presiones la tecla
	pj.scale.x = move_toward(pj.scale.x, target_scale_x, ROTATION_SPEED * delta)
func zeta_func(valor:bool):
	var var_zeta =$pj/esqueleto/Skeleton3D/zeta
	if not var_zeta.visible:
		$pj/esqueleto/Skeleton3D/zeta.visible = valor
	else:
		$pj/esqueleto/Skeleton3D/zeta.visible = valor
		var instanciar_zeta = zeta_dejar.instantiate()
		get_tree().current_scene.add_child(instanciar_zeta)
		instanciar_zeta.global_position = global_position
