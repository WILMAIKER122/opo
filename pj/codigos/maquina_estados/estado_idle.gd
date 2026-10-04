extends State

func enter() -> void:
	character.playback.travel("idle")
	character.velocity.x = 0.0
	character.velocity.z = 0.0

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("z"):
		state_machine.transition_to("ataque")
	elif event.is_action_pressed("x"):
		state_machine.transition_to("Dash")
	if event.is_action_pressed("comer"):
		state_machine.transition_to("comer")

func update_physics(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (character.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		state_machine.transition_to("Run")
	else:
		character.handle_rotation(delta, direction)
