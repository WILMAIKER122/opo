class_name Player
extends CharacterBody3D
@export var estadisticas:estadisticas_player
@onready var pj: Node3D = $pj/esqueleto/Skeleton3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var state_machine: StateMachine = $estados
@export var zeta_dejar:PackedScene
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var area: Area3D = $Area3D
@onready var label: Label3D = $Label3D
@onready var mesh_nodo: MeshInstance3D = $pj/esqueleto/Skeleton3D/zeta

const ROTATION_SPEED = 7.0

# Registro de última dirección
var last_movement_direction: Vector3 = Vector3(-1.0, 0.0, 0.0)

func _ready() -> void:
	estadisticas.zeta_cambiada.connect(_on_zeta_cambiada)
	
	if CodigoGlobal.vida_inicial_run > 0.0:
		estadisticas.stats.vida_base = CodigoGlobal.vida_inicial_run
		CodigoGlobal.vida_inicial_run = -1.0
		
	state_machine.init(self)
	estadisticas.poner_quitar_zeta()
	actualizar_zeta()
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):   # Enter
		if CodigoGlobal.en_run:
			CodigoGlobal.finalizar_run(estadisticas)
		else:
			CodigoGlobal.iniciar_run(estadisticas)
		return
	
	if event.is_action_pressed("c"):   # Tecla C, de prueba
		CodigoGlobal.morir(estadisticas)
		return
	
	state_machine.handle_input(event)	
	
func _process(delta: float) -> void:
	estadisticas.actualizar(delta, CodigoGlobal.en_run)
	label.text = str("vida:", estadisticas.vida, "   velocidad: ", estadisticas.velocidad_max, "   daño: ", estadisticas.dano, "   hambre: ", estadisticas.hambre.hambre_actual)

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
		area.position.x = -0.4
		collision.position.x = 0.05

	elif Input.is_action_pressed("ui_right"):
		target_scale_x = 1.0
		area.position.x = 1.6
		collision.position.x = 0.55
	# El personaje se sigue moviendo hacia el objetivo aunque ya no presiones la tecla
	pj.scale.x = move_toward(pj.scale.x, target_scale_x, ROTATION_SPEED * delta)

func zeta_func(valor:bool):
	
	var var_zeta =$pj/esqueleto/Skeleton3D/zeta
	if not var_zeta.visible:
		
		var_zeta.visible = valor
	else:
		var_zeta.visible = valor
		var instanciar_zeta = zeta_dejar.instantiate()
		get_tree().current_scene.add_child(instanciar_zeta)
		instanciar_zeta.global_position = global_position
		instanciar_zeta.position.y -=0.8
		#estadisticas.con_zeta=false
		estadisticas.poner_quitar_zeta()
		return
	

func _on_zeta_cambiada(nueva_zeta: Zeta_datos) -> void:
	actualizar_zeta()

func actualizar_zeta():
	var material_actual = mesh_nodo.material_override as StandardMaterial3D
	if material_actual and estadisticas.zeta_actual.textura:
		var material_unico = material_actual.duplicate() as StandardMaterial3D
		material_unico.albedo_texture = estadisticas.zeta_actual.textura
		mesh_nodo.material_override = material_unico
