class_name Player
extends CharacterBody3D
## Jugador. Delegados:
##   CombateJugador      (daño, invulnerabilidad, muerte, esquive perfecto)
##   ControlMenusJugador (atajos de menús, bolsillo, partir a la run)

signal dano_recibido(cantidad: float)

@export var estadisticas: estadisticas_player
@export var zeta_dejar: PackedScene
@export var duracion_invulnerabilidad: float = 0.6
@export_group("Esquive perfecto")
## Devuelve el hambre gastada en el dash
@export var esquive_devuelve_hambre: bool = true
## Cámara lenta breve (0 = desactivada)
@export var esquive_slowmo_escala: float = 0.35
@export var esquive_slowmo_segundos: float = 0.25
## Segundos (reales) para que el primer golpe sea un contraataque
@export var esquive_ventana_contraataque: float = 1.5

@onready var pj: Node3D = $pj/esqueleto/Skeleton3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var state_machine: StateMachine = $estados
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var area: Area3D = $Area3D
@onready var label: Label3D = $Label3D
@onready var mesh_nodo: MeshInstance3D = $pj/esqueleto/Skeleton3D/zeta

## Cuándo terminó el último dash (lo escribe estado_dash) y hasta cuándo dura el contraataque
var ultimo_dash_fin_ms: int = -100000
var contraataque_hasta_ms: int = -1
## true tras un esquive perfecto: el dash en curso no deja cooldown
var dash_sin_cooldown: bool = false
var muerto: bool = false
var tiempo_invulnerable: float = 0.0

const ROTATION_SPEED = 7.0

# Registro de última dirección
var last_movement_direction: Vector3 = Vector3(-1.0, 0.0, 0.0)
var target_scale_x: float = 1.0

var _combate: CombateJugador
var _menus: ControlMenusJugador


func _ready() -> void:
	_combate = CombateJugador.new(self)
	_menus = ControlMenusJugador.new(self)
	estadisticas.zeta_cambiada.connect(_on_zeta_cambiada)

	if CodigoGlobal.vida_inicial_run > 0.0:
		estadisticas.stats.vida_base = CodigoGlobal.vida_inicial_run
		CodigoGlobal.vida_inicial_run = -1.0

	state_machine.init(self)
	estadisticas.con_zeta = true
	actualizar_zeta()
	RegistroTomo.asegurar_acciones()

	estadisticas.sincronizar_mejoras()
func _unhandled_input(event: InputEvent) -> void:
	if _menus.manejar_input(event):
		return
	state_machine.handle_input(event)


func _process(delta: float) -> void:
	estadisticas.actualizar(delta, CodigoGlobal.en_run)
	label.text = str("vida:", estadisticas.vida, "   velocidad: ", estadisticas.velocidad_max, "   daño: ", estadisticas.dano, "   hambre: ", estadisticas.hambre.hambre_actual)
	_combate.actualizar(delta)


func _physics_process(delta: float) -> void:
	# Gravedad básica
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Delegar la lógica de físicas al estado activo
	state_machine.update_physics(delta)

	# Aplicar movimiento global
	move_and_slide()


# ==============================================================================
# MOVIMIENTO
# ==============================================================================

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
		area.position.x = 1.7
		collision.position.x = 0.55
	# El personaje se sigue moviendo hacia el objetivo aunque ya no presiones la tecla
	pj.scale.x = move_toward(pj.scale.x, target_scale_x, ROTATION_SPEED * delta)


# ==============================================================================
# ZETA
# ==============================================================================

## Dash: según la Zeta actual se suelta, se lanza o se queda puesta (FIJA)
func soltar_zeta(direccion_dash: Vector3) -> void:
	var zeta := estadisticas.zeta_actual
	if zeta == null or not estadisticas.con_zeta:
		return
	if zeta.comportamiento_suelta == Zeta_datos.ComportamientoSuelta.FIJA:
		return

	mesh_nodo.visible = false
	estadisticas.poner_quitar_zeta()    # con_zeta = false

	var suelta := zeta_dejar.instantiate() as ZetaSuelta
	suelta.datos_zeta = zeta
	suelta.jugador = self
	suelta.direccion = direccion_dash
	get_tree().current_scene.add_child(suelta)
	suelta.global_position = global_position
	suelta.position.y -= 0.8


## La llama la Zeta suelta al llegar al jugador (o al pisarla)
func recoger_zeta() -> void:
	if estadisticas.con_zeta:
		return
	estadisticas.poner_quitar_zeta()    # con_zeta = true
	mesh_nodo.visible = true


func _on_zeta_cambiada(_nueva_zeta: Zeta_datos) -> void:
	actualizar_zeta()


func actualizar_zeta() -> void:
	var material_actual = mesh_nodo.material_override as StandardMaterial3D
	if material_actual and estadisticas.zeta_actual.textura:
		var material_unico = material_actual.duplicate() as StandardMaterial3D
		material_unico.albedo_texture = estadisticas.zeta_actual.textura
		mesh_nodo.material_override = material_unico


# ==============================================================================
# FACHADA (los demás scripts siguen llamando a player.xxx igual que antes)
# ==============================================================================

func recibir_dano(cantidad: float, origen: Vector3 = Vector3.ZERO, fuerza_knockback: float = 0.0) -> bool:
	return _combate.recibir_dano(cantidad, origen, fuerza_knockback)

func esta_invulnerable() -> bool:
	return _combate.esta_invulnerable()

## La llama PortalRun al apretar E
func _partir_a_la_run() -> void:
	_menus.partir_a_la_run()
