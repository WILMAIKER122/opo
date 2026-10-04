extends State

func enter() -> void:
	character.playback.travel("run")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("z"):
		state_machine.transition_to("ataque")
	elif event.is_action_pressed("x"):
		state_machine.transition_to("Dash")

func update_physics(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (character.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction == Vector3.ZERO:
		state_machine.transition_to("Idle")
		return

	var target_velocity = direction * character.estadisticas.velocidad_max
	character.velocity.x = move_toward(character.velocity.x, target_velocity.x, character.estadisticas.aceleracion * delta)
	character.velocity.z = move_toward(character.velocity.z, target_velocity.z, character.estadisticas.aceleracion * delta)

	character.handle_rotation(delta, direction)
