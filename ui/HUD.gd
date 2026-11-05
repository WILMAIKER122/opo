extends CanvasLayer
class_name HUD
## HUD del jugador. Se arma solo por código: agregá un nodo CanvasLayer con este script
## a la escena (run y/o base) y, si no lo asignás, encuentra solo al Player.
##
## Muestra: vida (solo número, sin tope), hambre (barra), Zeta actual, sabores activos y
## el panel de sinergias (PanelSinergiasHud). Las texturas son opcionales: sin ellas usa barras simples.

@export var player: Player

@export_group("Diseño")
@export var margen_pantalla: int = 16
@export var tamano_fuente: int = 18
@export var tamano_barra_hambre: Vector2 = Vector2(180, 16)
@export var tamano_icono: Vector2 = Vector2(28, 28)

@export_group("Texturas (opcionales)")
@export var icono_vida: Texture2D
@export var icono_hambre: Texture2D
## Si asignás la textura de relleno se usa una TextureProgressBar con tus texturas
@export var textura_hambre_fondo: Texture2D
@export var textura_hambre_relleno: Texture2D

var _est: estadisticas_player
var _label_vida: Label
var _barra_hambre: Range
var _fila_zeta: HBoxContainer
var _icono_zeta: TextureRect
var _label_zeta: Label
var _panel_sinergias: PanelSinergiasHud
var _label_sabores: Label


func _ready() -> void:
	if player == null:
		player = _buscar_player()
	if player == null or player.estadisticas == null:
		push_warning("HUD: no encontré al Player. Asignalo en el Inspector.")
		set_process(false)
		return

	_est = player.estadisticas
	_construir_ui()

	_est.zeta_cambiada.connect(_al_cambiar_zeta)
	_al_cambiar_zeta(_est.zeta_actual)
	player.connect("dano_recibido", _al_recibir_dano)

	_mostrar_aviso_pago()


func _process(_delta: float) -> void:
	_label_vida.text = str(maxi(0, ceili(_est.vida)))

	var hambre := _est.hambre
	_barra_hambre.max_value = hambre.maximo()
	_barra_hambre.value = hambre.hambre_actual
	_barra_hambre.modulate = Color(1.0, 0.4, 0.4) if hambre.esta_en_cero() else Color.WHITE

	# La Zeta se ve apagada cuando no la tiene puesta
	_fila_zeta.modulate.a = 1.0 if _est.con_zeta else 0.45

	_actualizar_sabores()


# ==============================================================================
# CONSTRUCCIÓN
# ==============================================================================

func _construir_ui() -> void:
	var margen := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, margen_pantalla)
	_ignorar(margen)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	_ignorar(columna)
	margen.add_child(columna)

	# --- Vida (solo número) ---
	var fila_vida := _nueva_fila()
	fila_vida.add_child(_crear_icono(icono_vida))
	_label_vida = _crear_label("0")
	fila_vida.add_child(_label_vida)
	columna.add_child(fila_vida)

	# --- Hambre (barra) ---
	var fila_hambre := _nueva_fila()
	fila_hambre.add_child(_crear_icono(icono_hambre))
	_barra_hambre = _crear_barra_hambre()
	fila_hambre.add_child(_barra_hambre)
	columna.add_child(fila_hambre)

	# --- Zeta actual ---
	_fila_zeta = _nueva_fila()
	_icono_zeta = _crear_icono(null)
	_label_zeta = _crear_label("")
	_fila_zeta.add_child(_icono_zeta)
	_fila_zeta.add_child(_label_zeta)
	columna.add_child(_fila_zeta)

	# --- Sinergias activas y ventanas abiertas ---
	_panel_sinergias = PanelSinergiasHud.new()
	_panel_sinergias.configurar(_est, tamano_fuente, tamano_barra_hambre.x, tamano_icono)
	columna.add_child(_panel_sinergias)

	# --- Sabores activos ---
	_label_sabores = _crear_label("")
	_label_sabores.add_theme_font_size_override("font_size", maxi(tamano_fuente - 4, 10))
	columna.add_child(_label_sabores)


func _crear_barra_hambre() -> Range:
	var barra: Range
	if textura_hambre_relleno != null:
		var con_textura := TextureProgressBar.new()
		con_textura.texture_under = textura_hambre_fondo
		con_textura.texture_progress = textura_hambre_relleno
		barra = con_textura
	else:
		var simple := ProgressBar.new()
		simple.show_percentage = false
		simple.custom_minimum_size = tamano_barra_hambre
		barra = simple
	barra.min_value = 0.0
	barra.step = 0.01
	_ignorar(barra)
	return barra


# Atajos a HudWidgets con los tamaños de este HUD
func _ignorar(control: Control) -> Control: return HudWidgets.ignorar(control)
func _nueva_fila() -> HBoxContainer: return HudWidgets.nueva_fila()
func _crear_label(texto: String) -> Label: return HudWidgets.crear_label(texto, tamano_fuente)
func _crear_icono(textura: Texture2D) -> TextureRect: return HudWidgets.crear_icono(textura, tamano_icono)


# ==============================================================================
# ZETA
# ==============================================================================

func _al_cambiar_zeta(zeta: Zeta_datos) -> void:
	if zeta == null:
		_label_zeta.text = "Sin Zeta"
		_icono_zeta.texture = null
		_icono_zeta.visible = false
		return
	_label_zeta.text = zeta.nombre
	if zeta.textura is Texture2D:
		_icono_zeta.texture = zeta.textura
		_icono_zeta.visible = true
	else:
		_icono_zeta.texture = null
		_icono_zeta.visible = false


# ==============================================================================
# SABORES Y EXTRAS
# ==============================================================================

func _actualizar_sabores() -> void:
	var lineas := PackedStringArray()
	for tag in _est.sabores_activos:
		lineas.append("%s  %ds" % [ItemData.TagComida.keys()[tag], ceili(_est.sabores_activos[tag])])
	_label_sabores.text = "\n".join(lineas)


## Destello rojo en el número de vida al recibir daño
func _al_recibir_dano(_cantidad: float) -> void:
	_label_vida.modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(_label_vida, "modulate", Color.WHITE, 0.3)


func _buscar_player() -> Player:
	for nodo in get_tree().current_scene.find_children("*", "", true, false):
		if nodo is Player:
			return nodo as Player
	return null


## Aviso de lo que cobró la puerta por la que se entró: "-3 Pata (quedan 5)"
func _mostrar_aviso_pago() -> void:
	var pagos: Array = GeneradorPuertas.aviso_pago
	if pagos.is_empty():
		return
	GeneradorPuertas.aviso_pago = []
	var caja := VBoxContainer.new()
	_ignorar(caja)
	for p in pagos:
		var fila := _nueva_fila()
		fila.add_child(_crear_icono(p["icono"]))
		var l := _crear_label("-%d  %s  (quedan %d)" % [p["cantidad"], p["nombre"], p["restante"]])
		l.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
		fila.add_child(l)
		caja.add_child(fila)
	add_child(caja)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 40)
	var t := create_tween()
	t.tween_interval(3.0)
	t.tween_property(caja, "modulate:a", 0.0, 0.6)
	t.tween_callback(caja.queue_free)
