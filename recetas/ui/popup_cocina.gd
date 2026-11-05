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

var _estadisticas: estadisticas_player

const MODO_DESCUBRIR := 0
const MODO_RECETAS := 1
@onready var boton_cocinar: Button = %BotonCocinar
@onready var boton_cerrar: Button = %BotonCerrar
@onready var boton_descubrir: Button = %BotonDescubrir
@onready var boton_recetas: Button = %BotonRecetas
@onready var columnas_descubrir: Control = %Columnas
@onready var columnas_recetas: Control = %ColumnasRecetas
@onready var scroll_lista: ScrollContainer = %ScrollLista
@onready var contenedor_recetas: VBoxContainer = %ContenedorRecetas
@onready var icono_receta: TextureRect = %IconoReceta
@onready var titulo_receta: Label = %TituloReceta
@onready var texto_receta: RichTextLabel = %TextoReceta
@onready var label_mensaje_receta: Label = %LabelMensajeReceta
@onready var label_ayuda: Label = %LabelAyuda

var modo: int = MODO_DESCUBRIR
var indice_receta: int = 0
var _recetas_conocidas: Array[RecetaCocina] = []
var _botones_receta: Array[Button] = []
## true si se cocinó en modo Recetas: al volver a Descubrir hay que rearmar la grilla
var _inventario_sucio: bool = false


func configurar(datos: Dictionary) -> void:
	_estadisticas = datos.get("estadisticas")
func _ready() -> void:
	layer = 100
	_inventario = CodigoGlobal.inventario_base
	label_mensaje.text = ""
	boton_descubrir.pressed.connect(_cambiar_modo.bind(MODO_DESCUBRIR))
	boton_recetas.pressed.connect(_cambiar_modo.bind(MODO_RECETAS))
	texto_receta.bbcode_enabled = true
	boton_cocinar.pressed.connect(_aceptar)
	boton_cerrar.pressed.connect(func(): MenuManager.close_current_menu({"accion": "cancelar"}))
	boton_cocinar.text = "Cocinar (%s)" % TeclasUI.tecla(&"comer_confirmar")
	boton_cerrar.text = "Cerrar (%s)" % TeclasUI.tecla(&"ui_cancel")	
	construir()
	_aplicar_modo()

# ==============================================================================
# CONTROLES (antes los reenviaba el estado Cocinar; ahora el popup los maneja solo)
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	var consumido := true
	if event.is_action_pressed("tomo_pestana_anterior") or event.is_action_pressed("tomo_pestana_siguiente"):
		_cambiar_modo(MODO_RECETAS if modo == MODO_DESCUBRIR else MODO_DESCUBRIR)
	elif event.is_action_pressed("ui_cancel"):
		MenuManager.close_current_menu({"accion": "cancelar"})
	elif modo == MODO_DESCUBRIR:
		consumido = _input_descubrir(event)
	else:
		consumido = _input_recetas(event)
	if consumido:
		get_viewport().set_input_as_handled()


func _input_descubrir(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left"):
		mover_seleccion(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		mover_seleccion(Vector2i(1, 0))
	elif event.is_action_pressed("ui_up"):
		mover_seleccion(Vector2i(0, -1))
	elif event.is_action_pressed("ui_down"):
		mover_seleccion(Vector2i(0, 1))
	elif event.is_action_pressed("comer_sumar", true):
		agregar_actual(_cantidad(event))
	elif event.is_action_pressed("comer_restar", true):
		quitar_actual(_cantidad(event))
	elif event.is_action_pressed("comer_confirmar"):
		cocinar()
	else:
		return false
	return true


func _input_recetas(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		_seleccionar_receta(indice_receta - 1)
	elif event.is_action_pressed("ui_down"):
		_seleccionar_receta(indice_receta + 1)
	elif event.is_action_pressed("comer_confirmar"):
		_cocinar_receta()
	else:
		return false
	return true

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


## Mezcla libre (modo Descubrir)
func cocinar() -> void:
	var resultado: Dictionary = CodigoGlobal.cocinar(obtener_seleccion())
	label_mensaje.text = _mensaje_resultado(resultado)
	if resultado["estado"] in ["ok", "fallida", "invalida"]:
		construir()   # el inventario cambió: se rearma la grilla y la olla queda vacía


func _mensaje_resultado(resultado: Dictionary) -> String:
	match resultado["estado"]:
		"ok":
			var receta: RecetaCocina = resultado["receta"]
			if _estadisticas:
				_estadisticas.sincronizar_mejoras()
			var mensaje := "¡Mejora obtenida: %s!\n%s" % [receta.mejora.nombre, receta.mejora.texto_efecto()]
			if resultado["nueva"]:
				mensaje += "\n¡Receta nueva descubierta: %s!" % receta.nombre
			return mensaje
		"fallida":
			var partes := PackedStringArray()
			for p in resultado["perdido"]:
				partes.append("-%d %s" % [p["cantidad"], p["nombre"]])
			return "La mezcla no resultó en nada.\nPerdiste: " + ", ".join(partes)
		"completa":
			return "Ya tenés al máximo «%s». No se gastó nada." % resultado["receta"].mejora.nombre
		"vacia":
			return "La olla está vacía."
	return "Algunos ingredientes ya no están disponibles."
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
	if receta != null and receta.mejora != null:
		label_resultado.text = receta.mejora.nombre
		icono_resultado.texture = receta.mejora.icono
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
			lineas.append("• %s — %s  [%d/%d]" % [receta.nombre, receta.texto_requisitos(), CodigoGlobal.nivel_mejora(receta), receta.nivel_max])
	var texto := "Recetario (%d/%d)" % [descubiertas, todas.size()]
	if not lineas.is_empty():
		texto += "\n" + "\n".join(lineas)
	label_recetario.text = texto

# ==============================================================================
# MODOS
# ==============================================================================

func _cambiar_modo(nuevo: int) -> void:
	if nuevo == modo:
		return
	modo = nuevo
	if modo == MODO_DESCUBRIR and _inventario_sucio:
		_inventario_sucio = false
		construir()
	_aplicar_modo()


func _aplicar_modo() -> void:
	boton_descubrir.set_pressed_no_signal(modo == MODO_DESCUBRIR)
	boton_recetas.set_pressed_no_signal(modo == MODO_RECETAS)
	columnas_descubrir.visible = modo == MODO_DESCUBRIR
	columnas_recetas.visible = modo == MODO_RECETAS
	label_ayuda.text = _texto_ayuda()
	if modo == MODO_RECETAS:
		_construir_recetas()


# ==============================================================================
# MODO RECETAS (solo las ya descubiertas)
# ==============================================================================

func _construir_recetas() -> void:
	_recetas_conocidas.clear()
	for receta in SistemaCocina.obtener_recetas():
		if CodigoGlobal.receta_descubierta(receta):
			_recetas_conocidas.append(receta)

	for hijo in contenedor_recetas.get_children():
		contenedor_recetas.remove_child(hijo)
		hijo.queue_free()
	_botones_receta.clear()

	for i in _recetas_conocidas.size():
		var receta := _recetas_conocidas[i]
		var boton := Button.new()
		boton.text = "%s  [%d/%d]" % [receta.nombre, CodigoGlobal.nivel_mejora(receta), receta.nivel_max]
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.custom_minimum_size = Vector2(0, 40)
		boton.focus_mode = Control.FOCUS_NONE
		boton.toggle_mode = true
		boton.expand_icon = true
		boton.icon = receta.mejora.icono if receta.mejora else null
		boton.pressed.connect(_seleccionar_receta.bind(i))
		contenedor_recetas.add_child(boton)
		_botones_receta.append(boton)

	_seleccionar_receta(indice_receta)


func _seleccionar_receta(indice: int) -> void:
	label_mensaje_receta.text = ""
	if _recetas_conocidas.is_empty():
		titulo_receta.text = ""
		icono_receta.texture = null
		texto_receta.text = "[i]Todavía no descubriste ninguna receta.\nProbá mezclas en «Descubrir».[/i]"
		return

	indice_receta = wrapi(indice, 0, _recetas_conocidas.size())
	for i in _botones_receta.size():
		_botones_receta[i].set_pressed_no_signal(i == indice_receta)
	scroll_lista.ensure_control_visible(_botones_receta[indice_receta])

	var receta := _recetas_conocidas[indice_receta]
	titulo_receta.text = receta.nombre
	icono_receta.texture = receta.mejora.icono if receta.mejora else null
	texto_receta.text = _detalle_receta(receta)


func _detalle_receta(receta: RecetaCocina) -> String:
	var texto := ""
	if receta.mejora != null:
		texto += "[b]Mejora:[/b] %s\n%s\n[b]Efecto:[/b] %s\n" % [
			receta.mejora.nombre, receta.mejora.descripcion, receta.mejora.texto_efecto()]
	var nivel := CodigoGlobal.nivel_mejora(receta)
	texto += "[b]Nivel:[/b] %d / %d\n\n[b]Ingredientes:[/b] %s\n" % [nivel, receta.nivel_max, receta.texto_requisitos()]

	if nivel >= receta.nivel_max:
		return texto + "\n[color=#7fdc7f]Ya está al máximo.[/color]"

	var plan := SistemaCocina.armar_olla(receta, _inventario)
	if plan["faltan"].is_empty():
		var partes := PackedStringArray()
		for clave in plan["olla"]:
			partes.append("%dx %s" % [plan["olla"][clave], (_inventario[clave] as ItemData).nombre])
		texto += "\n[b]Se usará:[/b] " + ", ".join(partes)
	else:
		var faltas := PackedStringArray()
		for tag in plan["faltan"]:
			faltas.append("%s x%d" % [SistemaCocina.nombre_tag(tag), plan["faltan"][tag]])
		texto += "\n[color=#e86d6d]Te faltan: %s[/color]" % ", ".join(faltas)
	return texto


func _cocinar_receta() -> void:
	if _recetas_conocidas.is_empty():
		return
	var receta := _recetas_conocidas[indice_receta]
	var plan := SistemaCocina.armar_olla(receta, _inventario)
	if not plan["faltan"].is_empty():
		label_mensaje_receta.text = "Te faltan ingredientes."
		return

	var resultado: Dictionary = CodigoGlobal.cocinar(plan["olla"])
	_inventario_sucio = true
	_construir_recetas()   # refresca niveles, detalle y lo que queda en la despensa
	label_mensaje_receta.text = _mensaje_resultado(resultado)

func _aceptar() -> void:
	if modo == MODO_DESCUBRIR:
		cocinar()
	else:
		_cocinar_receta()


func _texto_ayuda() -> String:
	var ok := TeclasUI.tecla(&"comer_confirmar")
	if modo == MODO_DESCUBRIR:
		return "Flechas: mover · Z/X: ±1 (Shift ±5) · %s: cocinar · Q/E: modo · Esc: cerrar" % ok
	return "↑↓: elegir receta · %s: cocinar · Q/E: modo · Esc: cerrar" % ok
