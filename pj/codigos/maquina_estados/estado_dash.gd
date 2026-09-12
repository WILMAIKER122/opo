extends State

var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
@export var personaje: Player
@export var rotation_speed: float = 15.0

var target_scale_x: float = 1.0

func enter() -> void:
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

	# Establece el objetivo de escala en X según la dirección del dash
	if dash_direction.x != 0:
		target_scale_x = 1.0 if dash_direction.x > 0 else -1.0

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("x"):
		state_machine.transition_to("ataque")

func update_physics(delta: float) -> void:
	dash_timer -= delta
	character.velocity.x = dash_direction.x * character.estadisticas.dash_velociadad
	character.velocity.z = dash_direction.z * character.estadisticas.dash_velociadad

	# Aplica la rotación suave a la variable pj usando move_toward para que complete el giro exacto
	if character.pj:
		character.pj.scale.x = move_toward(character.pj.scale.x, target_scale_x, rotation_speed * delta)

	if dash_timer <= 0.0:
		character.velocity.x = 0.0
		character.velocity.z = 0.0
		
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			state_machine.transition_to("Run")
		else:
			state_machine.transition_to("Idle")
