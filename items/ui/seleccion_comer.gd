extends CanvasLayer
## Popup de selección de comestibles. Lo abre MenuManager y recibe sus datos en configurar():
##   modo      : "comer" (por defecto) o "equipar" (selector de provisiones antes de la run)
##   items     : Dictionary clave -> ItemData con lo que se puede elegir
##   capacidad : tope de unidades en total (solo modo "equipar"; 0 = sin tope)
##
## Maneja sus PROPIOS controles (así funciona con el juego en pausa) y al cerrarse devuelve:
##   {"accion": "confirmar", "seleccion": {clave: unidades}}   o   {"accion": "cancelar"}
##
## En modo "equipar", si la escena tiene un Label con nombre único %LabelCapacidad,
## muestra ahí "Provisiones: 3 / 5".

@onready var grid: GridContainer = $Control/PanelPrincipal/MarginContainer/VBoxContainer/ContenedorGrid/GridContainer
@onready var cursor: TextureRect = $Control/PanelPrincipal/MarginContainer/VBoxContainer/ContenedorGrid/Cursor
@onready var vista_previa: HBoxContainer =$Control/PanelPrincipal/MarginContainer/VBoxContainer/VistaPrevia

const ITEM_SLOT_SCENE := preload("res://items/ui/ItemSlot.tscn")

var modo: String = "comer"
var capacidad: int = 0

var slots: Array = []
var indice_actual: int = 0
var tween: Tween


## Lo llama MenuManager apenas se abre el menú
func configurar(datos: Dictionary) -> void:
	modo = datos.get("modo", "comer")
	capacidad = int(datos.get("capacidad", 0))
	construir(datos.get("items", {}))
	_actualizar_capacidad()


# ==============================================================================
# CONTROLES
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		mover_seleccion(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		mover_seleccion(Vector2i(1, 0))
	elif event.is_action_pressed("ui_up"):
		mover_seleccion(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		mover_seleccion(Vector2i(0, 1))
	elif event.is_action_pressed("comer_sumar"):
		_sumar()
	elif event.is_action_pressed("comer_restar"):
		restar_seleccion_actual()
		_actualizar_capacidad()
	elif event.is_action_pressed("comer_confirmar"):
		_confirmar()
	elif event.is_action_pressed("ui_cancel"):
		MenuManager.close_current_menu({"accion": "cancelar"})
	else:
		return
	# Que ninguna otra cosa del juego reaccione a estas teclas
	get_viewport().set_input_as_handled()


func _sumar() -> void:
	if capacidad > 0 and _total_seleccionado() >= capacidad:
		_avisar_lleno()
		return
	confirmar_seleccion_actual()
	_actualizar_capacidad()


func _confirmar() -> void:
	var seleccion := obtener_seleccion()
	# Comer sin haber elegido nada = cancelar. Equipar sin nada = partir sin provisiones.
	if modo == "comer" and seleccion.is_empty():
		MenuManager.close_current_menu({"accion": "cancelar"})
		return
	MenuManager.close_current_menu({"accion": "confirmar", "seleccion": seleccion})


func _total_seleccionado() -> int:
	var total := 0
	for slot in slots:
		total += slot.veces_seleccionado
	return total


func _actualizar_capacidad() -> void:
	if capacidad <= 0:
		return
	var etiqueta := get_node_or_null("%LabelCapacidad") as Label
	if etiqueta:
		etiqueta.text = "Provisiones: %d / %d" % [_total_seleccionado(), capacidad]


## Destello rojo en el contador cuando se intenta pasar de la capacidad
func _avisar_lleno() -> void:
	var etiqueta := get_node_or_null("%LabelCapacidad") as Label
	if etiqueta:
		etiqueta.modulate = Color(1.0, 0.35, 0.35)
		var destello := etiqueta.create_tween()
		destello.tween_property(etiqueta, "modulate", Color.WHITE, 0.4)


# ==============================================================================
# GRILLA Y SELECCIÓN
# ==============================================================================

func construir(items_comestibles: Dictionary) -> void:
	for child in grid.get_children():
		child.queue_free()
	for child in vista_previa.get_children():
		child.queue_free()
	slots.clear()

	for clave in items_comestibles:
		var item: ItemData = items_comestibles[clave]
		var slot = ITEM_SLOT_SCENE.instantiate()
		grid.add_child(slot)
		slot.configurar(clave, item)
		slots.append(slot)

	indice_actual = 0

	# Esperamos un frame para que el GridContainer calcule tamaños/posiciones reales
	await get_tree().process_frame
	_mover_cursor_instantaneo()

func _mover_cursor_instantaneo() -> void:
	if slots.is_empty():
		return
	var slot = slots[indice_actual]
	cursor.global_position = slot.global_position
	cursor.size = slot.size

func _mover_cursor_animado() -> void:
	if slots.is_empty():
		return
	var slot = slots[indice_actual]

	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cursor, "global_position", slot.global_position, 0.15)
	tween.parallel().tween_property(cursor, "size", slot.size, 0.15)

func mover_seleccion(direccion: Vector2i) -> void:
	if slots.is_empty():
		return

	var columnas: int = grid.columns
	var total: int = slots.size()
	var filas: int = ceili(float(total) / columnas)

	var col := (indice_actual % columnas) + direccion.x
	var fila := int(indice_actual / columnas) + direccion.y

	col = clampi(col, 0, columnas - 1)
	fila = clampi(fila, 0, filas - 1)

	var nuevo_indice := fila * columnas + col
	if nuevo_indice >= total:
		nuevo_indice = total - 1

	if nuevo_indice == indice_actual:
		return

	indice_actual = nuevo_indice
	_mover_cursor_animado()

func confirmar_seleccion_actual() -> void:
	if slots.is_empty():
		return

	var slot = slots[indice_actual]
	if slot.incrementar_seleccion():
		_actualizar_vista_previa()

func _actualizar_vista_previa() -> void:
	for child in vista_previa.get_children():
		child.queue_free()

	for slot in slots:
		if slot.veces_seleccionado <= 0:
			continue

		var contenedor := VBoxContainer.new()
		contenedor.alignment = BoxContainer.ALIGNMENT_CENTER

		var mini_icono := TextureRect.new()
		mini_icono.texture = slot.item_data.icono
		mini_icono.custom_minimum_size = Vector2(32, 32)
		mini_icono.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		mini_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var mini_label := Label.new()
		mini_label.text = "x%d" % slot.veces_seleccionado
		mini_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		contenedor.add_child(mini_icono)
		contenedor.add_child(mini_label)
		vista_previa.add_child(contenedor)

func obtener_seleccion() -> Dictionary:
	var resultado := {}
	for slot in slots:
		if slot.veces_seleccionado > 0:
			resultado[slot.clave_item] = slot.veces_seleccionado
	return resultado

func restar_seleccion_actual() -> void:
	if slots.is_empty():
		return
	slots[indice_actual].decrementar_seleccion()
	_actualizar_vista_previa()
