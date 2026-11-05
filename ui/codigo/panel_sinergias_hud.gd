class_name PanelSinergiasHud
extends VBoxContainer
## Parte del HUD: sinergias activas (con barra de tiempo) y ventanas abiertas (progreso).
## Se actualiza solo cada frame. Crearlo con PanelSinergiasHud.new() y llamar a configurar().
## Destino: res://ui/codigo/panel_sinergias_hud.gd

var _est: estadisticas_player
var _tamano_fuente: int = 18
var _ancho_barra: float = 180.0
var _tamano_icono: Vector2 = Vector2(28, 28)

var _columna_sinergias: VBoxContainer
var _columna_ventanas: VBoxContainer
## nombre de sinergia -> { "fila": Control, "etiqueta": Label, "barra": ProgressBar, "titulo": String }
var _filas_sinergias: Dictionary = {}
## id de ventana -> Label
var _filas_ventanas: Dictionary = {}


func configurar(est: estadisticas_player, tamano_fuente: int, ancho_barra: float, tamano_icono: Vector2) -> void:
	_est = est
	_tamano_fuente = tamano_fuente
	_ancho_barra = ancho_barra
	_tamano_icono = tamano_icono

	HudWidgets.ignorar(self)
	add_theme_constant_override("separation", 6)

	_columna_sinergias = VBoxContainer.new()
	_columna_sinergias.add_theme_constant_override("separation", 4)
	HudWidgets.ignorar(_columna_sinergias)
	add_child(_columna_sinergias)

	# Ventanas abiertas: sinergias en progreso (las desconocidas salen como ??? + tiempo)
	_columna_ventanas = VBoxContainer.new()
	_columna_ventanas.add_theme_constant_override("separation", 2)
	HudWidgets.ignorar(_columna_ventanas)
	add_child(_columna_ventanas)


func _process(_delta: float) -> void:
	if _est == null:
		return
	_actualizar_sinergias()
	_actualizar_ventanas()


func _label(texto: String) -> Label:
	return HudWidgets.crear_label(texto, _tamano_fuente)


func _fuente_chica() -> int:
	return maxi(_tamano_fuente - 4, 10)


# ==============================================================================
# SINERGIAS ACTIVAS (se sincroniza con SistemaSinergias.activas cada frame)
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
	var fila := HudWidgets.nueva_fila()

	var sinergia: SinergiaSabor = datos.get("sinergia")
	var conocida: bool = datos.get("conocida", false)
	if conocida and sinergia and sinergia.icono:
		fila.add_child(HudWidgets.crear_icono(sinergia.icono, _tamano_icono))

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	HudWidgets.ignorar(columna)
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

	var etiqueta := _label(titulo)
	etiqueta.add_theme_color_override("font_color", color)
	columna.add_child(etiqueta)

	var detalle := _label(texto_detalle)
	detalle.add_theme_font_size_override("font_size", _fuente_chica())
	detalle.modulate = Color(1, 1, 1, 0.75)
	columna.add_child(detalle)

	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(_ancho_barra, 6)
	HudWidgets.ignorar(barra)
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
			var nueva := _label("")
			nueva.add_theme_font_size_override("font_size", _fuente_chica())
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
