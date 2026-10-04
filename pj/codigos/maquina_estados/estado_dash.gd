extends State

@export var dash_cooldown: float = 0.5   # Segundos de espera tras terminar un dash
@export var personaje: Player
@export var rotation_speed: float = 15.0

var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var target_scale_x: float = 1.0

func _puede_dashear() -> bool:
	if character.estadisticas.hambre.esta_en_cero():
		return false
	return Time.get_ticks_msec() >= character.estadisticas.tiempo_dash_disponible
	
func enter() -> void:
	if not _puede_dashear():
		# En cooldown: no hace nada, vuelve al estado apropiado sin ejecutar el dash
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Idle")
		return
	character.estadisticas.hambre.gastar(character.estadisticas.hambre.costo_dash)
	character.playback.travel("dash")
	dash_timer = character.estadisticas.dash_duraccion
	
	personaje.zeta_func(false)
	var dir_x: float = 0.0
	var dir_z: float = 0.0

	if Input.is_action_pressed("ui_right"): dir_x += 1.0
	if Input.is_action_pressed("ui_up"):    dir_z -= 1.0
	if Input.is_action_pressed("ui_left"):  dir_x -= 1.0
	if Input.is_action_pressed("ui_down"):  dir_z += 1.0

	var dash_vector := Vector3(dir_x, 0.0, dir_z)

	if dash_vector != Vector3.ZERO:
		dash_direction = dash_vector.normalized()
	else:
		dash_direction = character.last_movement_direction.normalized()

	if dash_direction.x != 0:
		target_scale_x = 1.0 if dash_direction.x > 0 else -1.0

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("z"):
		state_machine.transition_to("ataque")

func update_physics(delta: float) -> void:
	dash_timer -= delta
	character.velocity.x = dash_direction.x * character.estadisticas.dash_velociadad
	character.velocity.z = dash_direction.z * character.estadisticas.dash_velociadad

	if character.pj:
		character.pj.scale.x = move_toward(character.pj.scale.x, target_scale_x, rotation_speed * delta)

	if dash_timer <= 0.0:
		character.velocity.x = 0.0
		character.velocity.z = 0.0
		
		# El cooldown arranca justo ahora, cuando el dash termina
		character.estadisticas.tiempo_dash_disponible = Time.get_ticks_msec() + int(dash_cooldown * 1000)
		
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Idle")
