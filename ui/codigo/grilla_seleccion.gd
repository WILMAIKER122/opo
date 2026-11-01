extends ScrollContainer
class_name GrillaSeleccion
## Grilla de ItemSlot con cursor animado y scroll automático. Reutilizable en Bolsillo,
## Comer, Cocina, Botín... El menú que la contiene decide qué hacer con las señales.
##
## Estructura de la escena (nombres únicos %): Contenido (Control) > Grid (GridContainer) + Cursor.
## El Cursor NO es top_level: vive dentro de Contenido para scrollear junto con la grilla.

## El cursor se movió. slot = null si la grilla quedó vacía.
signal cursor_movido(slot)
## Cambió alguna cantidad seleccionada (sumar / restar)
signal seleccion_cambiada
## Se intentó sumar pasando el tope_total

@export var escena_slot: PackedScene = preload("res://items/ui/ItemSlot.tscn")
@export var segundos_cursor: float = 0.15
## Unidades que suma/resta Z/X al mantener Shift
@export var cantidad_rapida: int = 5
@export var accion_sumar: StringName = &"comer_sumar"
@export var accion_restar: StringName = &"comer_restar"

@onready var contenido: Control = %Contenido
@onready var grid: GridContainer = %Grid
@onready var cursor: TextureRect = %Cursor

var slots: Array = []
var indice_actual: int = 0
## Máximo de unidades seleccionadas en total (0 = sin tope)
var tope_total: int = 0

var _tween: Tween

signal tope_alcanzado(motivo: String)   # "total", "por_item" o "ranuras"

## Máximo de unidades por ítem (0 = sin tope)
var tope_por_slot: int = 0
## Máximo de ítems distintos con algo seleccionado (0 = sin tope)
var tope_slots: int = 0

func _ready() -> void:
	cursor.visible = false
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.minimum_size_changed.connect(_ajustar_contenido)


# ==============================================================================
# API
# ==============================================================================

## Arma la grilla. filtro (opcional): Callable(item: ItemData) -> bool.
## Si se vuelve a llamar, intenta conservar la posición del cursor.
func cargar(items: Dictionary, filtro: Callable = Callable()) -> void:
	var indice_previo := indice_actual
	var previo = slot_actual()
	var clave_previa: String = previo.clave_item if previo else ""

	for hijo in grid.get_children():
		grid.remove_child(hijo)
		hijo.queue_free()
	slots.clear()

	for clave in items:
		var item: ItemData = items[clave]
		if item == null or item.cantidad <= 0:
			continue
		if filtro.is_valid() and not filtro.call(item):
			continue
		var slot = escena_slot.instantiate()
		grid.add_child(slot)
		slot.configurar(clave, item)
		slots.append(slot)

	indice_actual = clampi(indice_previo, 0, maxi(slots.size() - 1, 0))
	for i in slots.size():
		if slots[i].clave_item == clave_previa:
			indice_actual = i
			break

	cursor.visible = not slots.is_empty()

	# Un frame para que el GridContainer calcule tamaños y posiciones reales
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_ajustar_contenido()
	_ir_a_slot(false)
	cursor_movido.emit(slot_actual())


func slot_actual():
	if slots.is_empty():
		return null
	return slots[clampi(indice_actual, 0, slots.size() - 1)]


func item_actual() -> ItemData:
	var slot = slot_actual()
	return slot.item_data if slot else null


func mover(direccion: Vector2i) -> void:
	if slots.is_empty():
		return
	var columnas: int = grid.columns
	var total: int = slots.size()
	var filas: int = ceili(float(total) / columnas)

	var col := clampi((indice_actual % columnas) + direccion.x, 0, columnas - 1)
	var fila := clampi(floori(float(indice_actual) / columnas) + direccion.y, 0, filas - 1)
	var nuevo := mini(fila * columnas + col, total - 1)

	if nuevo == indice_actual:
		return
	indice_actual = nuevo
	_ir_a_slot(true)
	cursor_movido.emit(slot_actual())


func slots_usados() -> int:
	var usados := 0
	for slot in slots:
		if slot.veces_seleccionado > 0:
			usados += 1
	return usados


## Marca cantidades iniciales { clave: unidades } (ej. lo que ya está equipado)
func preseleccionar(seleccion: Dictionary) -> void:
	for slot in slots:
		slot.fijar_seleccion(int(seleccion.get(slot.clave_item, 0)))
	seleccion_cambiada.emit()


func sumar(cantidad: int = 1) -> void:
	var slot = slot_actual()
	if slot == null:
		return
	var cambio := false
	for i in cantidad:
		if tope_total > 0 and total_seleccionado() >= tope_total:
			tope_alcanzado.emit("total")
			break
		if tope_por_slot > 0 and slot.veces_seleccionado >= tope_por_slot:
			tope_alcanzado.emit("por_item")
			break
		if tope_slots > 0 and slot.veces_seleccionado == 0 and slots_usados() >= tope_slots:
			tope_alcanzado.emit("ranuras")
			break
		if not slot.incrementar_seleccion():
			break
		cambio = true
	if cambio:
		seleccion_cambiada.emit()
func restar(cantidad: int = 1) -> void:
	var slot = slot_actual()
	if slot == null:
		return
	var cambio := false
	for i in cantidad:
		if not slot.decrementar_seleccion():
			break
		cambio = true
	if cambio:
		seleccion_cambiada.emit()


## { clave: unidades } de lo seleccionado
func obtener_seleccion() -> Dictionary:
	var resultado := {}
	for slot in slots:
		if slot.veces_seleccionado > 0:
			resultado[slot.clave_item] = slot.veces_seleccionado
	return resultado


func total_seleccionado() -> int:
	var total := 0
	for slot in slots:
		total += slot.veces_seleccionado
	return total


## Flechas mueven el cursor; sumar/restar con las acciones configuradas.
## Devuelve true si consumió el evento.
func manejar_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left"):
		mover(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		mover(Vector2i(1, 0))
	elif event.is_action_pressed("ui_up"):
		mover(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		mover(Vector2i(0, 1))
	elif event.is_action_pressed(accion_sumar, true):
		sumar(_cantidad(event))
	elif event.is_action_pressed(accion_restar, true):
		restar(_cantidad(event))
	else:
		return false
	return true


# ==============================================================================
# INTERNO
# ==============================================================================

func _cantidad(event: InputEvent) -> int:
	if event is InputEventKey and event.shift_pressed:
		return cantidad_rapida
	return 1


## Contenido es un Control común: hay que decirle cuánto mide la grilla para que
## el ScrollContainer sepa cuándo mostrar la barra.
func _ajustar_contenido() -> void:
	contenido.custom_minimum_size = grid.get_combined_minimum_size()


func _ir_a_slot(animado: bool) -> void:
	var slot = slot_actual()
	if slot == null:
		return
	ensure_control_visible(slot)

	# Coordenadas locales a Contenido: no dependen de cuánto se haya scrolleado
	var destino: Vector2 = grid.position + slot.position
	if _tween:
		_tween.kill()
	if animado:
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_CUBIC)
		_tween.set_ease(Tween.EASE_OUT)
		_tween.tween_property(cursor, "position", destino, segundos_cursor)
		_tween.parallel().tween_property(cursor, "size", slot.size, segundos_cursor)
	else:
		cursor.position = destino
		cursor.size = slot.size
