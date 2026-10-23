extends CanvasLayer
class_name PopupCocina
## Interfaz de cocina hecha con NODOS (escena PopupCocina.tscn). Este script va en el
## nodo raíz (CanvasLayer). Los nodos se referencian por "nombre único" (%Nombre):
## en cada nodo marcado con % hay que hacer clic derecho > "Acceder como nombre único".
##
## Reutiliza res://items/ui/ItemSlot.tscn igual que PopupComer (configurar, veces_seleccionado,
## incrementar_seleccion, decrementar_seleccion, item_data, clave_item).
##
## Lo abre MenuManager y maneja sus PROPIOS controles (funciona con el juego en pausa).
## Al cerrarse con Esc devuelve {"accion": "cancelar"}.

@export_group("Texturas")
## Se muestra en el resultado mientras la receta no esté descubierta
@export var icono_desconocido: Texture2D

@export_group("Comportamiento")
## true: si la mezcla coincide con una receta YA descubierta, se muestra su plato.
## false: siempre se muestra "???" hasta que cocinás.
@export var mostrar_resultado_conocido: bool = true
## Cuántas unidades suma/resta Z/X al mantener Shift
@export var cantidad_rapida: int = 5

@export_group("Textos")
@export var texto_olla_vacia: String = "La olla está vacía."
@export var texto_sin_ingredientes: String = "No tenés ingredientes en la base."
@export var texto_desconocido: String = "???"

@onready var grid: GridContainer = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaIngredientes/ContenedorGrid/GridIngredientes
@onready var cursor: TextureRect = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaIngredientes/ContenedorGrid/Cursor
@onready var vista_previa: Container = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaOlla/VistaPrevia
@onready var label_conteo: Label = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaOlla/LabelConteo
@onready var icono_resultado: TextureRect = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaOlla/PanelResultado/FilaResultadooxContainer/IconoResultado
@onready var label_resultado: Label = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaOlla/PanelResultado/FilaResultadooxContainer/LabelResultado
@onready var label_mensaje: Label = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaOlla/LabelMensaje
@onready var label_recetario: Label = $Control/PanelPrincipal/MarginContainer/VBoxContainer/Columnas/ColumnaOlla/LabelRecetario

const ITEM_SLOT_SCENE := preload("res://items/ui/ItemSlot.tscn")

var slots: Array = []
var indice_actual: int = 0
var tween: Tween
var _inventario: Dictionary = {}


func _ready() -> void:
	layer = 100
	_inventario = CodigoGlobal.inventario_base
	label_mensaje.text = ""
	construir()


# ==============================================================================
# CONTROLES (antes los reenviaba el estado Cocinar; ahora el popup los maneja solo)
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
	elif event.is_action_pressed("comer_sumar", true):    # true = también al mantener apretado
		agregar_actual(_cantidad(event))
	elif event.is_action_pressed("comer_restar", true):
		quitar_actual(_cantidad(event))
	elif event.is_action_pressed("comer_confirmar"):
		cocinar()
	elif event.is_action_pressed("ui_cancel"):
		MenuManager.close_current_menu({"accion": "cancelar"})
	else:
		return
	get_viewport().set_input_as_handled()


## 1 unidad normal, cantidad_rapida si se mantiene Shift
func _cantidad(event: InputEvent) -> int:
	if event is InputEventKey and event.shift_pressed:
		return cantidad_rapida
	return 1


# ==============================================================================
# CONSTRUCCIÓN
# ==============================================================================

func construir() -> void:
	for hijo in grid.get_children():
		grid.remove_child(hijo)
		hijo.queue_free()
	slots.clear()

	for clave in _inventario:
		var item: ItemData = _inventario[clave]
		if not SistemaCocina.es_ingrediente(item) or item.cantidad <= 0:
			continue
		var slot = ITEM_SLOT_SCENE.instantiate()
		grid.add_child(slot)
		slot.configurar(clave, item)
		slots.append(slot)

	indice_actual = clampi(indice_actual, 0, maxi(slots.size() - 1, 0))
	cursor.visible = not slots.is_empty()
	_actualizar_todo()

	# Esperamos un frame para que el GridContainer calcule tamaños/posiciones reales
	await get_tree().process_frame
	_mover_cursor_instantaneo()


# ==============================================================================
# CURSOR
# ==============================================================================

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


# ==============================================================================
# OLLA: sumar / restar / cocinar (los llama el estado Cocinar)
# ==============================================================================

func agregar_actual(cantidad: int = 1) -> void:
	if slots.is_empty():
		return
	var slot = slots[indice_actual]
	var cambio := false
	for i in cantidad:
		if slot.veces_seleccionado >= slot.item_data.cantidad:
			break
		if not slot.incrementar_seleccion():
			break
		cambio = true
	if cambio:
		label_mensaje.text = ""
		_actualizar_todo()


func quitar_actual(cantidad: int = 1) -> void:
	if slots.is_empty():
		return
	var slot = slots[indice_actual]
	var cambio := false
	for i in cantidad:
		if slot.veces_seleccionado <= 0:
			break
		slot.decrementar_seleccion()
		cambio = true
	if cambio:
		label_mensaje.text = ""
		_actualizar_todo()


func obtener_seleccion() -> Dictionary:
	var resultado := {}
	for slot in slots:
		if slot.veces_seleccionado > 0:
			resultado[slot.clave_item] = slot.veces_seleccionado
	return resultado


## Aquí (y solo aquí) se aprende una receta: al intentar cocinar, no al armar la mezcla.
func cocinar() -> void:
	var resultado: Dictionary = CodigoGlobal.cocinar(obtener_seleccion())
	match resultado["estado"]:
		"ok":
			var receta: RecetaCocina = resultado["receta"]
			var mensaje := "¡Cocinaste %s!" % receta.plato.nombre
			if resultado["nueva"]:
				mensaje += "\n¡Receta nueva descubierta: %s!" % receta.nombre
			label_mensaje.text = mensaje
			construir() # el inventario cambió: se rearma la grilla y la olla queda vacía
		"fallida":
			# La selección se mantiene para poder ajustarla
			label_mensaje.text = "La mezcla no resultó en nada.\nNo se gastó ningún ingrediente."
		"vacia":
			label_mensaje.text = "La olla está vacía."
		"invalida":
			label_mensaje.text = "Algunos ingredientes ya no están disponibles."
			construir()


# ==============================================================================
# REFRESCO DE LA UI
# ==============================================================================

func _actualizar_todo() -> void:
	_actualizar_vista_previa()
	_actualizar_olla()
	_actualizar_recetario()


func _actualizar_vista_previa() -> void:
	for hijo in vista_previa.get_children():
		vista_previa.remove_child(hijo)
		hijo.queue_free()

	for slot in slots:
		if slot.veces_seleccionado <= 0:
			continue

		var contenedor := VBoxContainer.new()
		contenedor.alignment = BoxContainer.ALIGNMENT_CENTER

		var mini_icono := TextureRect.new()
		mini_icono.texture = slot.item_data.icono
		mini_icono.custom_minimum_size = Vector2(32, 32)
		mini_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mini_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var mini_label := Label.new()
		mini_label.text = "x%d" % slot.veces_seleccionado
		mini_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		contenedor.add_child(mini_icono)
		contenedor.add_child(mini_label)
		vista_previa.add_child(contenedor)


func _actualizar_olla() -> void:
	if slots.is_empty():
		label_conteo.text = texto_sin_ingredientes
		_mostrar_resultado(null, false)
		return

	var seleccion := obtener_seleccion()
	if seleccion.is_empty():
		label_conteo.text = texto_olla_vacia
		_mostrar_resultado(null, false)
		return

	var conteo := SistemaCocina.contar_tags(seleccion, _inventario)
	var lineas := PackedStringArray()
	for tag in conteo:
		lineas.append("%s: %d" % [SistemaCocina.nombre_tag(tag), conteo[tag]])
	label_conteo.text = "\n".join(lineas)

	# Solo se revela el plato si la receta ya fue descubierta
	var receta := SistemaCocina.buscar_receta(conteo)
	var conocida := mostrar_resultado_conocido and receta != null and CodigoGlobal.receta_descubierta(receta)
	_mostrar_resultado(receta if conocida else null, true)


func _mostrar_resultado(receta: RecetaCocina, hay_mezcla: bool) -> void:
	if not hay_mezcla:
		label_resultado.text = ""
		icono_resultado.texture = null
		return
	if receta != null and receta.plato != null:
		label_resultado.text = receta.plato.nombre
		icono_resultado.texture = receta.plato.icono
	else:
		label_resultado.text = texto_desconocido
		icono_resultado.texture = icono_desconocido


func _actualizar_recetario() -> void:
	var todas := SistemaCocina.obtener_recetas()
	var lineas := PackedStringArray()
	var descubiertas := 0
	for receta in todas:
		if CodigoGlobal.receta_descubierta(receta):
			descubiertas += 1
			lineas.append("• %s — %s" % [receta.nombre, receta.texto_requisitos()])
	var texto := "Recetario (%d/%d)" % [descubiertas, todas.size()]
	if not lineas.is_empty():
		texto += "\n" + "\n".join(lineas)
	label_recetario.text = texto
