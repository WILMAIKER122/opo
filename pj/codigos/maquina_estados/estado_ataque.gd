extends State

@export var combo_animations: Array[String] = ["ataque", "ataque2", "ataque3"]

@export_group("Impulsos y Rotación")
@export var attack_forward_impulse: float = 6  # Fuerza de avance al atacar
@export var recoil_impulse: float = 5.0        # Fuerza de retroceso al golpear a un enemigo
@export var attack_friction: float = 12.0        # Qué tan rápido se frena el impulso (fricción)
@export var rotation_speed: float = 15.0       # Velocidad con la que rota/voltea el personaje

# Variables de control del combo, cancelación y rotación
var current_combo: int = 0         # Índice actual (0 = ataque, 1 = ataque2, 2 = ataque3)
var combo_queued: bool = false
var can_cancel: bool = false
var hitbox_active: bool = false
var can_dash_cancel: bool = true   # Permite cancelar con dash solo antes de la hitbox
var can_change_direction: bool = true # Permite cambiar de dirección solo antes de la hitbox

func enter() -> void:
	print(current_combo)
	# Reiniciamos banderas de control para este golpe
	combo_queued = false
	can_cancel = false
	hitbox_active = false
	can_dash_cancel = true
	can_change_direction = true
	
	# Reproduce la animación correspondiente al paso actual del combo
	var current_anim = combo_animations[current_combo]
	character.playback.start(current_anim)
	
	# Aplica el impulso hacia adelante en la dirección que mira el personaje actual
	_apply_forward_impulse()

func handle_input(event: InputEvent) -> void:
	# Cancelar con dash (tecla Z / acción "dash") antes de que se active la hitbox
	if event.is_action_pressed("z"):
		if can_dash_cancel:
			state_machine.transition_to("Dash")
			return

	if event.is_action_pressed("x"):
		combo_queued = true
		
		# Si ya estamos en la ventana de cancelación, intenta avanzar al siguiente golpe
		if can_cancel:
			_try_advance_combo()
var target_scale_x: float = 1.0

func update_physics(delta: float) -> void:
	# Disminuye gradualmente la velocidad del impulso hasta frenar al personaje
	character.velocity.x = lerp(character.velocity.x, 0.0, attack_friction * delta)
	character.velocity.z = move_toward(character.velocity.z, 0.0, attack_friction * delta)
	
	# Si aún está permitida la rotación (antes de la hitbox), permite girar de forma suave
	if can_change_direction and character.pj:
		
		if Input.is_action_pressed("ui_left"):
			target_scale_x = -1.0
			#character.pj.scale.x = lerp(character.pj.scale.x, -1.0, rotation_speed * delta)
			$"../../Area3D".position.x = -0.4
			character.pj.scale.x = target_scale_x# move_toward(character.pj.scale.x,target_scale_x,7*delta)
		elif Input.is_action_pressed("ui_right"):
			target_scale_x = 1.0
			#character.pj.scale.x = lerp(character.pj.scale.x, 1.0, rotation_speed * delta)
			$"../../Area3D".position.x = 1.6
			character.pj.scale.x = target_scale_x#move_toward(character.pj.scale.x,target_scale_x,10*delta)
		else:
			if character.pj.scale.x < 0.5:
				$"../../Area3D".position.x = -0.4
			else:
				$"../../Area3D".position.x = 1.6

# ==============================================================================
# MOVIMIENTO E IMPULSOS
# ==============================================================================

func _apply_forward_impulse() -> void:
	var facing_dir := _get_facing_direction()
	character.velocity.x = facing_dir.x * attack_forward_impulse
	character.velocity.z = facing_dir.z * attack_forward_impulse

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
	can_dash_cancel = false       # Se bloquea el dash al activar la hitbox
	can_change_direction = false  # Se bloquea el cambio de dirección al activar la hitbox

func disable_hitbox() -> void:
	hitbox_active = false

func open_cancel_window() -> void:
	can_cancel = true
	
	if combo_queued:
		_try_advance_combo()


# ==============================================================================
# LÓGICA DE COMBOS Y SALIDA
# ==============================================================================

func _try_advance_combo() -> void:
	if current_combo < combo_animations.size() - 1:
		current_combo += 1
		enter() 

func _exit_attack() -> void:
	hitbox_active = false
	can_cancel = false
	can_dash_cancel = false
	can_change_direction = false
	current_combo = 0 
	
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		state_machine.transition_to("Run")
	else:
		state_machine.transition_to("Idle")

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if current_combo < combo_animations.size() and anim_name == combo_animations[current_combo]:
		_exit_attack()
