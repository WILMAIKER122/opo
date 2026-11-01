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
var menu_abierto: bool = false

signal dano_recibido(cantidad: float)

@export var duracion_invulnerabilidad: float = 0.6
@export_group("Esquive perfecto")
## Devuelve el hambre gastada en el dash
@export var esquive_devuelve_hambre: bool = true
## Cámara lenta breve (0 = desactivada)
@export var esquive_slowmo_escala: float = 0.35
@export var esquive_slowmo_segundos: float = 0.25
## Segundos (reales) para que el primer golpe sea un contraataque
@export var esquive_ventana_contraataque: float = 1.5
var _ultimo_esquive_ms: int = -1000
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



func _ready() -> void:
	estadisticas.zeta_cambiada.connect(_on_zeta_cambiada)
	
	if CodigoGlobal.vida_inicial_run > 0.0:
		estadisticas.stats.vida_base = CodigoGlobal.vida_inicial_run
		CodigoGlobal.vida_inicial_run = -1.0
		
	state_machine.init(self)
	estadisticas.con_zeta = true
	actualizar_zeta()
	RegistroTomo.asegurar_acciones()	
	
func _unhandled_input(event: InputEvent) -> void:
	if _manejar_atajos_menu(event):
		return

	if _manejar_bolsillo(event):
		return
	
	state_machine.handle_input(event)
	
func _process(delta: float) -> void:
	estadisticas.actualizar(delta, CodigoGlobal.en_run)
	label.text = str("vida:", estadisticas.vida, "   velocidad: ", estadisticas.velocidad_max, "   daño: ", estadisticas.dano, "   hambre: ", estadisticas.hambre.hambre_actual)
	if tiempo_invulnerable > 0.0:
		tiempo_invulnerable -= delta
	_comprobar_muerte()
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
		area.position.x = 1.7
		collision.position.x = 0.55
	# El personaje se sigue moviendo hacia el objetivo aunque ya no presiones la tecla
	pj.scale.x = move_toward(pj.scale.x, target_scale_x, ROTATION_SPEED * delta)

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

func _on_zeta_cambiada(nueva_zeta: Zeta_datos) -> void:
	actualizar_zeta()

func actualizar_zeta():
	var material_actual = mesh_nodo.material_override as StandardMaterial3D
	if material_actual and estadisticas.zeta_actual.textura:
		var material_unico = material_actual.duplicate() as StandardMaterial3D
		material_unico.albedo_texture = estadisticas.zeta_actual.textura
		mesh_nodo.material_override = material_unico

func esta_invulnerable() -> bool:
	return tiempo_invulnerable > 0.0 or _esta_en_dash()

func _esta_en_dash() -> bool:
	var actual = state_machine.current_state
	return actual != null and actual.name.to_lower().contains("dash")

func recibir_dano(cantidad: float, origen: Vector3 = Vector3.ZERO, fuerza_knockback: float = 0.0) -> bool:
	if muerto:
		return false
	if _esta_en_dash():
		_esquive_perfecto()
		return false
	if esta_invulnerable():
		return false
	estadisticas.recibir_dano(cantidad)
	EfectosCombate.numero_flotante(
		get_tree().current_scene,
		global_position + Vector3(0.0, 1.6, 0.0),
		str(roundi(cantidad)),
		Color(1.0, 0.35, 0.35))
	tiempo_invulnerable = duracion_invulnerabilidad
	estadisticas.recibir_dano(cantidad)
	tiempo_invulnerable = duracion_invulnerabilidad
	print("Jugador recibió %.1f de daño (vida: %.1f)" % [cantidad, estadisticas.vida])
	dano_recibido.emit(cantidad)

	_comprobar_muerte()
	if muerto:
		return true

	state_machine.transition_to("RecibiendoDanio")
	var estado := state_machine.current_state as EstadoDanioJugador
	if estado:
		estado.aplicar_knockback(origen, fuerza_knockback)
	return true

func _comprobar_muerte() -> void:
	if muerto or not CodigoGlobal.en_run:
		return
	if estadisticas.vida <= 0.0:
		muerto = true
		print("El jugador murió")
		CodigoGlobal.call_deferred("morir", estadisticas)


func _input(event: InputEvent) -> void:
	RegistroTomo.asegurar_acciones()
	if event.is_action_pressed("abrir_tomo") and not MenuManager.is_menu_open():
		if MenuManager.open_menu("tomo", "res://tomo/tomo.tscn", true, {"estadisticas": estadisticas}):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and MenuManager.is_menu_open():
		MenuManager.close_current_menu()
		return



func _libre_para_actuar() -> bool:
	var actual := state_machine.current_state
	return actual != null and actual.name.to_lower() in ["idle", "run"]

## Crea las acciones si no existen (si las definís en el Mapa de entrada, esas tienen prioridad)
func _asegurar_acciones_bolsillo() -> void:
	var teclas := {"bolsillo_usar": KEY_C, "bolsillo_cambiar": KEY_V, "bolsillo_equipar": KEY_B}
	for nombre in teclas:
		if InputMap.has_action(nombre):
			continue
		InputMap.add_action(nombre)
		var evento := InputEventKey.new()
		evento.physical_keycode = teclas[nombre]
		InputMap.action_add_event(nombre, evento)

## A = Inventario, B = Bolsillo, T = Tomo. Todos abren el mismo hub en su pestaña.
func _manejar_atajos_menu(event: InputEvent) -> bool:
	if muerto or MenuManager.is_menu_open():
		return false
	var pestana := &""
	if event.is_action_pressed("abrir_tomo"):
		pestana = &"tomo"
	elif event.is_action_pressed("comer"):
		pestana = &"inventario"
	elif event.is_action_pressed("bolsillo_equipar"):
		pestana = &"bolsillo"
	else:
		return false
	if not _libre_para_actuar():
		return false
	return _abrir_hub(pestana)


func _abrir_hub(pestana: StringName, partir: bool = false) -> bool:
	MenuManager.menu_closed.connect(_al_cerrar_hub, CONNECT_ONE_SHOT)
	var datos := {"estadisticas": estadisticas, "pestana": pestana, "partir": partir}
	if MenuManager.open_menu("hub", "res://menu/hub/menu_hub.tscn", true, datos):
		get_viewport().set_input_as_handled()
		return true
	MenuManager.menu_closed.disconnect(_al_cerrar_hub)
	return false


func _al_cerrar_hub(_nombre: String, resultado: Dictionary) -> void:
	match resultado.get("accion", "cancelar"):
		"comer":
			var comer := state_machine.states["comer"] as EstadoComer
			comer.seleccion_pendiente = resultado.get("seleccion", {})
			state_machine.transition_to("Comer")
		"partir":
			CodigoGlobal.iniciar_run(estadisticas)


func _partir_a_la_run() -> void:
	# Con el bolsillo vacío (y algo para llevar) se abre el hub en el Bolsillo para equiparse antes de salir
	if estadisticas.bolsillo.is_empty() and CodigoGlobal.hay_comestibles_en_base():
		_abrir_hub(&"bolsillo", true)
	else:
		CodigoGlobal.iniciar_run(estadisticas)


## C come la provisión seleccionada y V cambia de provisión (en la run y en la base)
func _manejar_bolsillo(event: InputEvent) -> bool:
	if muerto or MenuManager.is_menu_open():
		return false
	if event.is_action_pressed("bolsillo_cambiar"):
		estadisticas.ciclar_bolsillo(1)
	elif event.is_action_pressed("bolsillo_usar"):
		if not _libre_para_actuar():
			return false
		state_machine.transition_to("ComerRapido")
	else:
		return false
	get_viewport().set_input_as_handled()
	return true

## Un golpe te alcanzó justo durante el dash
func _esquive_perfecto() -> void:
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_esquive_ms < 400:
		return
	_ultimo_esquive_ms = ahora
	contraataque_hasta_ms = ahora + int(esquive_ventana_contraataque*1000.0)
	dash_sin_cooldown = true
	EfectosCombate.numero_flotante(
		get_tree().current_scene,
		global_position + Vector3(0.0,2.0,0.0),
		"!esquive!",
		Color(0.5,0.9,1.0), 1.2)

	get_tree().call_group("zeta_suelta", "volver_ya")
	if esquive_devuelve_hambre:
		estadisticas.hambre.comer(estadisticas.hambre.costo_dash)

	# Efecto único de la Zeta: chispas al esquivar (si tiene la escena asignada)
	var efectos: ZetaPasivaEfectosUnicos = null
	if estadisticas.zeta_actual:
		efectos = estadisticas.zeta_actual.EfectosUnicos
	if efectos and efectos.lanzar_chispas_al_esquivar and efectos.escena_chispas:
		var chispas := efectos.escena_chispas.instantiate()
		get_tree().current_scene.add_child(chispas)
		chispas.global_position = global_position

	if esquive_slowmo_segundos > 0.0:
		CodigoGlobal.slowmo(esquive_slowmo_escala, esquive_slowmo_segundos)
