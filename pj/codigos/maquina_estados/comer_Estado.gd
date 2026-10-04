extends State

@export var eat_duration: float = 1.2
@export var popup_scene: PackedScene   # Asigna PopupComer.tscn en el Inspector

var timer: float = 0.0
var is_eating: bool = false
var en_seleccion: bool = false
var popup: CanvasLayer = null
var seleccion_final: Dictionary = {}

func enter() -> void:
	print("no")
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	
	var comestibles := _obtener_items_comestibles()
	
	if comestibles.is_empty():
		state_machine.transition_to("idle")
		return
	
	popup = popup_scene.instantiate()
	character.get_tree().root.add_child(popup)   # <- CAMBIO: root en vez de current_scene
	popup.construir(comestibles)
	
	en_seleccion = true
	is_eating = false
	timer = 0.0
	seleccion_final.clear()

func exit() -> void:
	is_eating = false
	en_seleccion = false
	if popup and is_instance_valid(popup):
		popup.queue_free()
	popup = null

func _obtener_items_comestibles() -> Dictionary:
	var resultado := {}
	for clave in character.estadisticas.inventario:
		var item: ItemData = character.estadisticas.inventario[clave]
		print(item)
		if item.tipo == ItemData.TipoItem.COMESTIBLE:
			resultado[clave] = item
			print("sisisi")
	return resultado

func handle_input(event: InputEvent) -> void:
	if en_seleccion:
		if event.is_action_pressed("ui_left"):
			popup.mover_seleccion(Vector2i(-1, 0))
		elif event.is_action_pressed("ui_right"):
			popup.mover_seleccion(Vector2i(1, 0))
		elif event.is_action_pressed("ui_up"):
			popup.mover_seleccion(Vector2i(0, -1))
		elif event.is_action_pressed("ui_down"):
			popup.mover_seleccion(Vector2i(0, 1))
		elif event.is_action_pressed("comer_sumar"):
			popup.confirmar_seleccion_actual()
		elif event.is_action_pressed("comer_restar"):
			popup.restar_seleccion_actual()
		elif event.is_action_pressed("comer_confirmar"):
			_confirmar_y_comer()
		return
	
	if is_eating and event.is_action_pressed("x"):
		state_machine.transition_to("Dash")

func _confirmar_y_comer() -> void:
	seleccion_final = popup.obtener_seleccion()
	
	if seleccion_final.is_empty():
		state_machine.transition_to("idle")
		return
	
	if popup and is_instance_valid(popup):
		popup.queue_free()
	popup = null
	
	en_seleccion = false
	is_eating = true
	timer = 0.0
	print("¡Comenzando a comer los items seleccionados...")

func update_physics(delta: float) -> void:
	character.velocity.x = 0.0
	character.velocity.z = 0.0
	
	if en_seleccion:
		return
	
	if not is_eating:
		return
	
	timer += delta
	if timer >= eat_duration:
		_procesar_conversion()
		state_machine.transition_to("idle")

func _procesar_conversion() -> void:
	for clave in seleccion_final:
		var cantidad_a_comer: int = seleccion_final[clave]
		
		if not character.estadisticas.inventario.has(clave):
			continue
		
		var item: ItemData = character.estadisticas.inventario[clave]
		
		character.estadisticas.comer_item(item, cantidad_a_comer)
		character.estadisticas.quitar_item(clave, cantidad_a_comer)
	
	if character.has_method("actualizar_hud"):
		character.actualizar_hud()
	
	print("¡Comida terminada!")
	seleccion_final.clear()
