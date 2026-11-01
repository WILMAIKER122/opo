extends PaginaMenu
class_name PaginaTomo
## El Tomo: registro de Bestias, Recetas, Sinergias y Zetas, con pestañas.
## Lo abre MenuManager (con el juego en pausa): MenuManager.open_menu("tomo", <ruta>, true,
## {"estadisticas": estadisticas}). Maneja sus propios controles:
##   Q / E (o ← →) : cambiar de pestaña      ↑ ↓ : elegir entrada      Esc / T : cerrar
##
## Los nodos se buscan por nombre único (%): en cada nodo marcado con % hay que hacer
## clic derecho > "Acceder como nombre único". Qué se muestra lo decide RegistroTomo.

@export_group("Texturas")
## Se muestra cuando una entrada todavía no tiene ícono ("???")
@export var icono_desconocido: Texture2D

@export_group("Animación")
@export var segundos_deslizamiento: float = 0.2
@export var distancia_deslizamiento: float = 80.0

@onready var boton_bestias: Button = %BotonBestias
@onready var boton_recetas: Button = %BotonRecetas
@onready var boton_sinergias: Button = %BotonSinergias
@onready var boton_zetas: Button = %BotonZetas
@onready var cuerpo: Control = %Cuerpo
@onready var contenedor_lista: VBoxContainer = %ContenedorLista
@onready var icono_detalle: TextureRect = %IconoDetalle
@onready var titulo_detalle: Label = %TituloDetalle
@onready var texto_detalle: RichTextLabel = %TextoDetalle
@onready var label_progreso: Label = %LabelProgreso
 
var estadisticas: estadisticas_player
var pestana: int = 0

var _botones: Array = []
var _entradas: Array = []
# El mismo botón que abre el Tomo no tiene que cerrarlo en ese frame
var _tween: Tween


func _ready() -> void:
	_botones = [boton_bestias, boton_recetas, boton_sinergias, boton_zetas]
	for i in _botones.size():
		var boton: Button = _botones[i]
		boton.text = NOMBRES_PESTANAS[i]
		boton.focus_mode = Control.FOCUS_NONE
		boton.toggle_mode = true
		boton.pressed.connect(_mostrar_pestana.bind(i))
	texto_detalle.bbcode_enabled = true


func configurar(datos: Dictionary) -> void:
	estadisticas = datos.get("estadisticas")
	_mostrar_pestana(0)


func manejar_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left"):
		_mostrar_pestana(pestana - 1, -1)
	elif event.is_action_pressed("ui_right"):
		_mostrar_pestana(pestana + 1, 1)
	else:
		return false
	return true

# ==============================================================================
# CONTROLES
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("ui_left"):
		_mostrar_pestana(pestana - 1, -1)
	elif event.is_action_pressed("ui_right"):
		_mostrar_pestana(pestana + 1, 1)
	elif event.is_action_pressed("abrir_tomo"):
		MenuManager.close_current_menu({"accion": "cancelar"})
	else:
		return
	get_viewport().set_input_as_handled()


# ==============================================================================
# PESTAÑAS Y LISTA
# ==============================================================================

## direccion: -1 / 1 = el contenido entra deslizándose desde ese lado; 0 = sin animación
func _mostrar_pestana(indice: int, direccion: int = 0) -> void:
	pestana = wrapi(indice, 0, _botones.size())
	for i in _botones.size():
		_botones[i].set_pressed_no_signal(i == pestana)

	_entradas = RegistroTomo.obtener_entradas(pestana, estadisticas)
	_reconstruir_lista()

	var cuenta := RegistroTomo.contar(pestana, estadisticas)
	label_progreso.text = "Registrado: %d / %d" % [cuenta.x, cuenta.y]

	if direccion != 0:
		_animar_cambio(direccion)


func _reconstruir_lista() -> void:
	for hijo in contenedor_lista.get_children():
		contenedor_lista.remove_child(hijo)
		hijo.queue_free()

	if _entradas.is_empty():
		_mostrar_detalle({
			"titulo": "",
			"icono": null,
			"detalle": "[i]Todavía no descubriste nada en esta sección.[/i]",
		})
		return

	var primero: Button = null
	for entrada in _entradas:
		var fila := Button.new()
		fila.text = entrada["titulo"]
		fila.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fila.custom_minimum_size = Vector2(0, 44)
		fila.expand_icon = true
		fila.icon = entrada["icono"] if entrada["icono"] != null else icono_desconocido
		if entrada["estado"] == RegistroTomo.Estado.DESCONOCIDO:
			fila.modulate = Color(0.8, 0.8, 0.8)
		fila.focus_entered.connect(_mostrar_detalle.bind(entrada))
		contenedor_lista.add_child(fila)
		if primero == null:
			primero = fila

	primero.grab_focus.call_deferred()


func _mostrar_detalle(entrada: Dictionary) -> void:
	titulo_detalle.text = entrada.get("titulo", "")
	var icono = entrada.get("icono")
	icono_detalle.texture = icono if icono != null else icono_desconocido
	icono_detalle.visible = icono_detalle.texture != null
	texto_detalle.text = entrada.get("detalle", "")


## El contenido entra deslizándose (como pasar la página). Funciona porque "Pagina" es un
## Control común (no un contenedor): así nadie le pisa la posición a "Cuerpo".
func _animar_cambio(direccion: int) -> void:
	if _tween:
		_tween.kill()
	cuerpo.offset_left = distancia_deslizamiento * direccion
	cuerpo.offset_right = distancia_deslizamiento * direccion
	cuerpo.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(cuerpo, "offset_left", 0.0, segundos_deslizamiento)
	_tween.tween_property(cuerpo, "offset_right", 0.0, segundos_deslizamiento)
	_tween.tween_property(cuerpo, "modulate:a", 1.0, segundos_deslizamiento)

const NOMBRES_PESTANAS := ["Bestias", "Recetas", "Sinergias", "Zetas"]

func _preparar_layout() -> void:
	# "Pagina" es un Control común: hay que darle tamaño, y "Cuerpo" lo llena
	var pagina := cuerpo.get_parent() as Control
	pagina.custom_minimum_size = Vector2(620, 360)
	cuerpo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cuerpo.add_theme_constant_override("separation", 12)

	var scroll := contenedor_lista.get_parent() as Control
	scroll.custom_minimum_size = Vector2(240, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_detalle := icono_detalle.get_parent().get_parent() as Control
	panel_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto_detalle.custom_minimum_size = Vector2(0, 200)
