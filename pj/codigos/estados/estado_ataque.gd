extends State

@export var combo_animations: Array[String] = ["ataque", "ataque2", "ataque3"]
@onready var area: Area3D = $"../../Area3D"
@onready var animation_tree: AnimationTree = $"../../AnimationTree"
## "" = golpe normal, "dash" = ataque veloz, "contraataque" = tras esquive perfecto
var _tipo_golpe: StringName = &""
@export_group("Impulsos y Rotación")
@export var attack_forward_impulse: float = 6.0
@export var moving_impulse_multiplier: float = 1.5
@export var recoil_impulse: float = 5.0
@export var attack_friction: float = 12.0
@export var rotation_speed: float = 15.0

@export_group("Velocidad de Ataque")
@export var reduccion_ultimo_ataque: float = 0.9  # diferencia mínima respecto a los demás golpes

@export_group("Recuperación")
@export var tiempo_recuperacion: float = 0.4  # segundos de "vulnerabilidad"/quietud tras el último golpe

var current_combo: int = 0
var combo_queued: bool = false
var can_cancel: bool = false
var hitbox_active: bool = false
var can_dash_cancel: bool = true
var can_change_direction: bool = true

var target_scale_x: float = 1.0
var multiplicador_velocidad_actual: float = 1.0

var en_recuperacion: bool = false
var timer_recuperacion: float = 0.0

var time_scale_base: Dictionary = {}

@export_group("Daño y efectos por golpe")
## Multiplica el daño del jugador. El último golpe pega más fuerte.
@export var multiplicador_danio: Array[float] = [1.0, 1.0, 1.6]
@export var empuje_enemigo: Array[float] = [5.0, 5.0, 12.0]
@export var stun_enemigo: Array[float] = [0.3, 0.3, 0.7]
## Segundos que se congela el juego al impactar
@export var hitstop: Array[float] = [0.05, 0.05, 0.10]
@export var temblor_camara: Array[float] = [0.1, 0.1, 0.2]


@export_group("Ataque tras dash")
## Segundos después de terminar el dash en los que el primer golpe es un "ataque veloz"
@export var ventana_tras_dash: float = 0.3
@export var multiplicador_danio_tras_dash: float = 1.5
## Multiplica la velocidad de la animación del primer golpe
@export var velocidad_tras_dash: float = 1.3
## Multiplica el impulso hacia adelante (se lanza sobre el enemigo)
@export var impulso_tras_dash: float = 1.4

@export_group("Contraataque (tras esquive perfecto)")
@export var multiplicador_danio_contraataque: float = 2.0
@export var velocidad_contraataque: float = 1.4


func _ready() -> void:
	for nombre_anim in combo_animations:
		var ruta = "parameters/%s/TimeScale/scale" % nombre_anim
		time_scale_base[nombre_anim] = animation_tree.get(ruta)
		
func enter() -> void:
	print(current_combo)
	combo_queued = false
	can_cancel = false
	hitbox_active = false
	can_dash_cancel = true
	can_change_direction = true
	en_recuperacion = false
		# Solo el primer golpe del combo puede ser especial
	_tipo_golpe = _detectar_golpe_especial() if current_combo == 0 else &""
	character.estadisticas.hambre.gastar(character.estadisticas.hambre.costo_ataque)
	multiplicador_velocidad_actual = _obtener_multiplicador_velocidad()
	_aplicar_time_scale(multiplicador_velocidad_actual)
	
	var current_anim = combo_animations[current_combo]
	character.playback.start(current_anim)

## ¿Este primer golpe viene de un esquive perfecto, o de un dash reciente?
func _detectar_golpe_especial() -> StringName:
	var ahora := Time.get_ticks_msec()
	if ahora <= character.contraataque_hasta_ms:
		character.contraataque_hasta_ms = -1
		character.ultimo_dash_fin_ms = -100000
		return &"contraataque"
	if ahora - character.ultimo_dash_fin_ms <= int(ventana_tras_dash * 1000.0):
		character.ultimo_dash_fin_ms = -100000
		return &"dash"
	return &""


func handle_input(event: InputEvent) -> void:
	if en_recuperacion:
		return  # Durante la recuperación no se puede cancelar ni encadenar nada
	
	if event.is_action_pressed("x"):
		if can_dash_cancel:
			_reset_combo_state()
			state_machine.transition_to("Dash")
			return

	if event.is_action_pressed("z"):
		combo_queued = true
		if can_cancel:
			_try_advance_combo()

func update_physics(delta: float) -> void:
	if en_recuperacion:
		# Durante la recuperación el personaje queda quieto, sin input, hasta que termine el timer
		character.velocity.x = lerp(character.velocity.x, 0.0, attack_friction * delta)
		character.velocity.z = move_toward(character.velocity.z, 0.0, attack_friction * delta)
		
		timer_recuperacion += delta
		if timer_recuperacion >= tiempo_recuperacion:
			_finalizar_recuperacion()
		return
	
	var friccion_escalada = attack_friction * multiplicador_velocidad_actual
	character.velocity.x = lerp(character.velocity.x, 0.0, friccion_escalada * delta)
	character.velocity.z = move_toward(character.velocity.z, 0.0, friccion_escalada * delta)
	
	if can_cancel:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			_reset_combo_state()
			state_machine.transition_to("Run")
			return

	if can_change_direction and character.pj:
		if Input.is_action_pressed("ui_left"):
			target_scale_x = -1.0
			area.position.x = -0.4
			character.pj.scale.x = target_scale_x
		elif Input.is_action_pressed("ui_right"):
			target_scale_x = 1.0
			area.position.x = 1.6
			character.pj.scale.x = target_scale_x
		else:
			if character.pj.scale.x < 0.5:
				area.position.x = -0.4
			else:
				area.position.x = 1.6

# ==============================================================================
# VELOCIDAD DE ATAQUE
# ==============================================================================

func _obtener_multiplicador_velocidad() -> float:
	var vel_stat: float = character.estadisticas.velocidad_ataque
	var es_ultimo_golpe: bool = current_combo == combo_animations.size() - 1
	var mult := vel_stat
	if es_ultimo_golpe:
		mult = 1.0 + (vel_stat - 1.0) * reduccion_ultimo_ataque
	match _tipo_golpe:
		&"dash":
			mult *= velocidad_tras_dash
		&"contraataque":
			mult *= velocidad_contraataque
	return mult

func _aplicar_time_scale(multiplicador: float) -> void:
	var nombre_anim = combo_animations[current_combo]
	var ruta_parametro = "parameters/%s/TimeScale/scale" % nombre_anim
	var base = time_scale_base.get(nombre_anim, 1.0)
	animation_tree.set(ruta_parametro, base * multiplicador)

# ==============================================================================
# MOVIMIENTO E IMPULSOS
# ==============================================================================

func _apply_forward_impulse() -> void:
	var facing_dir := _get_facing_direction()
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var final_impulse = attack_forward_impulse * multiplicador_velocidad_actual
	if _tipo_golpe != &"":
		final_impulse *= impulso_tras_dash
	
	if input_dir != Vector2.ZERO:
		final_impulse *= moving_impulse_multiplier
		
	character.velocity.x = facing_dir.x * final_impulse
	character.velocity.z = facing_dir.z * final_impulse

func apply_recoil() -> void:
	var facing_dir := _get_facing_direction()
	character.velocity.x = -facing_dir.x * recoil_impulse
	character.velocity.z = -facing_dir.z * recoil_impulse

func _get_facing_direction() -> Vector3:
	if character.pj:
		var dir_x = 1.0 if character.pj.scale.x > 0 else -1.0
		return Vector3(dir_x, 0, 0)
	return -character.transform.basis.z.normalized()

# ==============================================================================
# FUNCIONES LLAMADAS DESDE LA PISTA (CALL METHOD TRACK) EN GODOT
# ==============================================================================

func enable_hitbox() -> void:
	hitbox_active = true
	area.activar_desactivar_area(true)
	can_dash_cancel = false
	can_change_direction = false
	_apply_forward_impulse()

func disable_hitbox() -> void:
	hitbox_active = false
	area.activar_desactivar_area(false)
	
func open_cancel_window() -> void:
	can_cancel = true
	can_dash_cancel = true
	
	if combo_queued:
		_try_advance_combo()

# ==============================================================================
# LÓGICA DE COMBOS Y SALIDA
# ==============================================================================

func _try_advance_combo() -> void:
	if current_combo < combo_animations.size() - 1:
		current_combo += 1
		enter()

func _reset_combo_state() -> void:
	_tipo_golpe = &""
	hitbox_active = false
	area.activar_desactivar_area(false)
	can_cancel = false
	can_dash_cancel = false
	can_change_direction = false
	current_combo = 0
	en_recuperacion = false
	timer_recuperacion = 0.0
	
	for nombre_anim in combo_animations:
		var ruta = "parameters/%s/TimeScale/scale" % nombre_anim
		animation_tree.set(ruta, time_scale_base.get(nombre_anim, 1.0))

func _exit_attack() -> void:
	var es_ultimo_golpe: bool = current_combo == combo_animations.size() - 1
	
	if es_ultimo_golpe and not en_recuperacion:
		# En vez de transicionar de inmediato, entra en fase de recuperación
		en_recuperacion = true
		timer_recuperacion = 0.0
		can_cancel = false
		can_dash_cancel = false
		return
	
	_reset_combo_state()
	
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		state_machine.transition_to("Run")
	else:
		state_machine.transition_to("Idle")

func _finalizar_recuperacion() -> void:
	_reset_combo_state()
	
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		state_machine.transition_to("Run")
	else:
		state_machine.transition_to("Idle")

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if current_combo < combo_animations.size() and anim_name == combo_animations[current_combo]:
		_exit_attack()


func _dato_golpe(lista: Array[float], por_defecto: float) -> float:
	if lista.is_empty():
		return por_defecto
	return lista[mini(current_combo, lista.size() - 1)]


func efectos_golpe() -> Dictionary:
	var danio := _dato_golpe(multiplicador_danio, 1.0)
	var etiqueta := ""
	var color := Color.WHITE
	match _tipo_golpe:
		&"dash":
			danio *= multiplicador_danio_tras_dash
			etiqueta = "¡Ataque veloz!"
			color = Color(1.0, 0.75, 0.3)
		&"contraataque":
			danio *= multiplicador_danio_contraataque
			etiqueta = "¡Contraataque!"
			color = Color(0.5, 0.9, 1.0)
	return {
		"danio": danio,
		"empuje": _dato_golpe(empuje_enemigo, 5.0),
		"stun": _dato_golpe(stun_enemigo, 0.5),
		# Los golpes especiales congelan un poco más
		"hitstop": _dato_golpe(hitstop, 0.05) + (0.03 if _tipo_golpe != &"" else 0.0),
		"temblor": _dato_golpe(temblor_camara, 0.1),
		"etiqueta": etiqueta,
		"color": color,
	}
