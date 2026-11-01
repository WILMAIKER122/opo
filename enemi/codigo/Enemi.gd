extends CharacterBody3D
class_name Enemigo

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
@export var escena_parte_drop: PackedScene # Arrastra aquí la escena de tu Node3D

@export_group("Efectos de golpe")
## Opcional: la textura del enemigo, para que el destello respete su silueta
## (necesario si la malla usa alfa recortado como el personaje). Con la cápsula de prueba no hace falta.
@export var textura_destello: Texture2D
@export var segundos_destello: float = 0.08

var _material_destello: StandardMaterial3D


# --- ESTADOS (veneno, quemadura, lentitud...) ---
var _estados: Dictionary = {}   # id -> {"dps", "restante", "lentitud", "color"}
var _factor_velocidad: float = 1.0
var _acum_dot: float = 0.0
var _tiempo_tick_dot: float = 0.0
var _color_dot: Color = Color.WHITE
var _muriendo: bool = false



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

	_actualizar_estados(delta)
	if _muriendo:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Delegamos la física al estado activo
	state_machine.actualizar_fisicas(delta)
	# Lentitud: los estados reasignan la velocidad en cada frame, así que no se acumula
	if _factor_velocidad < 1.0:
		velocity.x *= _factor_velocidad
		velocity.z *= _factor_velocidad
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

	_destello()

	# Cambiamos al estado de recibir daño y ejecutamos su empuje
	state_machine.cambiar_estado("recibiendodanio")

	var estado_danio = state_machine.estado_actual as EstadoRecibiendoDanio
	if estado_danio:
		estado_danio.aplicar_knockback(origen_impacto, fuerza_knockback, duracion_stun)


## Destello blanco: un material encima de la malla durante unos milisegundos
func _destello() -> void:
	var malla := visual as GeometryInstance3D
	if malla == null:
		return
	if _material_destello == null:
		_material_destello = StandardMaterial3D.new()
		_material_destello.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_destello.albedo_color = Color.WHITE
		if textura_destello:
			_material_destello.albedo_texture = textura_destello
			_material_destello.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	malla.material_overlay = _material_destello
	# El timer ignora el time_scale: el destello se ve completo después del hitstop
	await get_tree().create_timer(segundos_destello, true, false, true).timeout
	if is_instance_valid(malla):
		malla.material_overlay = null

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
			CodigoGlobal.marcar_visto("bestia:" + stats.id_registro())


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == jugador:
		jugador = null
		if state_machine.estado_actual.name != "RecibiendoDanio":
			state_machine.cambiar_estado("patrullando")


func _on_timer_ataque_timeout() -> void:
	puede_atacar = true

## Aplica (o renueva) un estado: daño por segundo y/o lentitud durante `segundos`
func aplicar_estado(id: StringName, dps: float, segundos: float, lentitud: float = 0.0, color: Color = Color.WHITE) -> void:
	if _muriendo:
		return
	_estados[id] = {"dps": dps, "restante": segundos, "lentitud": lentitud, "color": color}


func _actualizar_estados(delta: float) -> void:
	if _estados.is_empty():
		_factor_velocidad = 1.0
		return

	var dps_total := 0.0
	var lentitud := 0.0
	for id in _estados.keys():
		var e: Dictionary = _estados[id]
		e["restante"] -= delta
		if e["restante"] <= 0.0:
			_estados.erase(id)
			continue
		dps_total += e["dps"]
		lentitud = maxf(lentitud, e["lentitud"])
		if e["dps"] > 0.0:
			_color_dot = e["color"]
	_factor_velocidad = 1.0 - lentitud

	if dps_total <= 0.0:
		return
	# El daño se acumula y se aplica cada 0.5 s (un número por tick, sin spamear)
	_acum_dot += dps_total * delta
	_tiempo_tick_dot += delta
	if _tiempo_tick_dot >= 0.5:
		_tiempo_tick_dot = 0.0
		var danio := _acum_dot
		_acum_dot = 0.0
		vida_actual -= danio
		EfectosCombate.numero_flotante(get_tree().current_scene,
				global_position + Vector3(0.0, 1.4, 0.0),
				str(maxi(1, roundi(danio))), _color_dot, 0.7)
		if vida_actual <= 0.0:
			morir()


## ¿Hay lugar para que este enemigo ataque ahora?
func _hay_cupo_de_ataque() -> bool:
	var atacando := 0
	for otro in get_tree().get_nodes_in_group("enemigos"):
		if otro != self and otro is Enemigo and otro.state_machine.estado_actual is EstadoAtaque:
			atacando += 1
	return atacando < max_atacantes_simultaneos

## Lo llama el ataque al empezar: dónde va el AreaDanio (X mirando a la derecha)
func fijar_area_danio_x(x: float) -> void:
	if area_danio == null:
		return
	_pos_base_x[area_danio] = x   # así el espejado de _aplicar_lado_a_areas respeta el valor
	area_danio.position.x = x * (1.0 if mirando_derecha else -1.0)
