extends CanvasLayer
class_name HUD
## HUD del jugador. Se arma solo por código: agregá un nodo CanvasLayer con este script
## a la escena (run y/o base) y, si no lo asignás, encuentra solo al Player.
##
## Muestra: vida (solo número, sin tope), hambre (barra), Zeta actual y sinergias activas
## con su tiempo restante. Las texturas son opcionales: sin ellas usa barras simples.

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
var _columna_sinergias: VBoxContainer
## nombre de sinergia -> { "fila": Control, "etiqueta": Label, "barra": ProgressBar }
var _filas_sinergias: Dictionary = {}
var _columna_ventanas: VBoxContainer
## id de ventana -> Label
var _filas_ventanas: Dictionary = {}


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


func _process(_delta: float) -> void:
	_label_vida.text = str(maxi(0, ceili(_est.vida)))

	var hambre := _est.hambre
	_barra_hambre.max_value = hambre.hambre_maxima
	_barra_hambre.value = hambre.hambre_actual
	_barra_hambre.modulate = Color(1.0, 0.4, 0.4) if hambre.esta_en_cero() else Color.WHITE

	# La Zeta se ve apagada cuando no la tiene puesta
	_fila_zeta.modulate.a = 1.0 if _est.con_zeta else 0.45

	_actualizar_sinergias()
	_actualizar_ventanas()


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

	# --- Sinergias activas ---
	_columna_sinergias = VBoxContainer.new()
	_columna_sinergias.add_theme_constant_override("separation", 4)
	_ignorar(_columna_sinergias)
	columna.add_child(_columna_sinergias)

	# --- Ventanas abiertas: sinergias en progreso (las desconocidas salen como ??? + tiempo) ---
	_columna_ventanas = VBoxContainer.new()
	_columna_ventanas.add_theme_constant_override("separation", 2)
	_ignorar(_columna_ventanas)
	columna.add_child(_columna_ventanas)


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


func _nueva_fila() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_ignorar(fila)
	return fila


func _crear_label(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano_fuente)
	_ignorar(etiqueta)
	return etiqueta


func _crear_icono(textura: Texture2D) -> TextureRect:
	var icono := TextureRect.new()
	icono.texture = textura
	icono.custom_minimum_size = tamano_icono
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.visible = textura != null
	_ignorar(icono)
	return icono


func _ignorar(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


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
# SINERGIAS (se sincroniza con SistemaSinergias.activas cada frame)
# ==============================================================================

func _actualizar_sinergias() -> void:
	var activas: Dictionary = _est.sinergias.activas

	# Quitar las que ya terminaron (o se limpiaron al terminar la run)
	for nombre in _filas_sinergias.keys():
		if not activas.has(nombre):
			_filas_sinergias[nombre]["fila"].queue_free()
			_filas_sinergias.erase(nombre)

	# Crear las nuevas y refrescar el tiempo de todas
	for nombre in activas:
		if not _filas_sinergias.has(nombre):
			_crear_fila_sinergia(nombre, activas[nombre])
		_refrescar_fila_sinergia(nombre, activas[nombre])


func _crear_fila_sinergia(nombre: String, datos: Dictionary) -> void:
	var fila := _nueva_fila()

	var sinergia: SinergiaSabor = datos.get("sinergia")
	var conocida: bool = datos.get("conocida", false)
	if conocida and sinergia and sinergia.icono:
		fila.add_child(_crear_icono(sinergia.icono))

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	_ignorar(columna)
	fila.add_child(columna)

	# Título y color: conocida -> nombre con flecha (verde sube / rojo baja); desconocida -> "???"
	var titulo := "???"
	var color := Color(0.8, 0.8, 0.8)
	var texto_detalle := "Efectos desconocidos"
	if conocida and sinergia:
		var positiva := sinergia.es_positiva()
		titulo = ("▲ " if positiva else "▼ ") + sinergia.nombre
		color = Color(0.6, 1.0, 0.6) if positiva else Color(1.0, 0.55, 0.55)
		texto_detalle = _texto_efectos(sinergia)

	var etiqueta := _crear_label(titulo)
	etiqueta.add_theme_color_override("font_color", color)
	columna.add_child(etiqueta)

	var detalle := _crear_label(texto_detalle)
	detalle.add_theme_font_size_override("font_size", maxi(tamano_fuente - 4, 10))
	detalle.modulate = Color(1, 1, 1, 0.75)
	columna.add_child(detalle)

	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(tamano_barra_hambre.x, 6)
	_ignorar(barra)
	columna.add_child(barra)

	_columna_sinergias.add_child(fila)
	_filas_sinergias[nombre] = {
		"fila": fila, "etiqueta": etiqueta, "barra": barra, "titulo": titulo}


func _refrescar_fila_sinergia(nombre: String, datos: Dictionary) -> void:
	var fila: Dictionary = _filas_sinergias[nombre]
	var etiqueta: Label = fila["etiqueta"]
	var barra: ProgressBar = fila["barra"]
	var titulo: String = fila["titulo"]
	var restante: float = datos["restante"]

	if restante < 0.0: # dura toda la run
		etiqueta.text = titulo
		barra.visible = false
	else:
		etiqueta.text = "%s  %ds" % [titulo, ceili(restante)]
		barra.visible = true
		barra.max_value = maxf(datos["duracion"], 0.01)
		barra.value = restante


## Una línea por efecto: "▲ velocidad_ataque +20%" / "▼ velocidad_max -30%"
func _texto_efectos(sinergia: SinergiaSabor) -> String:
	var lineas := PackedStringArray()
	for efecto in sinergia.info_para_ui(true)["efectos"]:
		var flecha := "▲" if efecto["sube"] else "▼"
		if efecto["especial"]:
			lineas.append("%s %s" % [flecha, efecto["stat"]])
		else:
			var signo := "+" if efecto["valor"] > 0.0 else ""
			var unidad := "%" if efecto["es_porcentaje"] else ""
			lineas.append("%s %s %s%s%s" % [
				flecha, efecto["stat"], signo, str(snappedf(efecto["valor"], 0.1)), unidad])
	return "\n".join(lineas)


# ==============================================================================
# VENTANAS ABIERTAS (SistemaSinergias.obtener_ventanas)
# ==============================================================================

func _actualizar_ventanas() -> void:
	var vistos := {}
	for ventana in _est.sinergias.obtener_ventanas():
		var id: int = ventana["id"]
		vistos[id] = true

		if not _filas_ventanas.has(id):
			var nueva := _crear_label("")
			nueva.add_theme_font_size_override("font_size", maxi(tamano_fuente - 4, 10))
			_columna_ventanas.add_child(nueva)
			_filas_ventanas[id] = nueva

		var etiqueta: Label = _filas_ventanas[id]
		var segundos := maxi(0, ceili(ventana["restante"]))
		if ventana["conocida"]:
			var positiva: bool = ventana["es_positiva"]
			etiqueta.text = "%s %s  %d/%d  (%ds)" % [
				"▲" if positiva else "▼", ventana["nombre"],
				ventana["contados"], ventana["necesarios"], segundos]
			etiqueta.add_theme_color_override("font_color",
				Color(0.6, 1.0, 0.6) if positiva else Color(1.0, 0.55, 0.55))
		else:
			etiqueta.text = "???  (%ds)" % segundos
			etiqueta.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	for id in _filas_ventanas.keys():
		if not vistos.has(id):
			_filas_ventanas[id].queue_free()
			_filas_ventanas.erase(id)


# ==============================================================================
# EXTRAS
# ==============================================================================

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
