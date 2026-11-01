class_name RegistroTomo
extends RefCounted
## Lógica del Tomo: qué entradas hay en cada sección y en qué estado está cada una.
##
##   OCULTO       : no aparece en la lista
##   DESCONOCIDO  : aparece como "???" (la viste o conseguiste algo relacionado)
##   COMPLETO     : se muestran todos sus datos (derrotada / cocinada / vivida / usada)
##
## Lo que el jugador "vio" se guarda en CodigoGlobal.vistos y lo "completado" en
## CodigoGlobal.derrotas / recetas_descubiertas / conocimientos.

enum Estado { OCULTO, DESCONOCIDO, COMPLETO }
enum Categoria { BESTIAS, RECETAS, SINERGIAS, ZETAS }

## Carpetas donde se buscan los recursos (cada tipo de enemigo y cada Zeta, un .tres)
const CARPETA_BESTIAS := "res://enemi/archivos_stree/"
const CARPETA_ZETAS := "res://pj/archivos_stree/zetas/zetas_items/"

## Acciones del Tomo (se crean solas si no existen; si creás una con el mismo nombre en el
## Mapa de entrada, esa tiene prioridad)
const ACCIONES_POR_DEFECTO := {
	"abrir_tomo": KEY_T,
	"tomo_pestana_anterior": KEY_Q,
	"tomo_pestana_siguiente": KEY_E,
}

static var _bestias: Array[EnemigoStats] = []
static var _zetas: Array[Zeta_datos] = []
static var _cargado: bool = false


# ==============================================================================
# API
# ==============================================================================

## Crea las acciones del Tomo que falten. Llamar una vez al arrancar (en el _ready del Player).
static func asegurar_acciones() -> void:
	for nombre in ACCIONES_POR_DEFECTO:
		if InputMap.has_action(nombre):
			continue
		InputMap.add_action(nombre)
		var evento := InputEventKey.new()
		evento.physical_keycode = ACCIONES_POR_DEFECTO[nombre]
		InputMap.action_add_event(nombre, evento)


## Entradas visibles de una sección: [{ estado, titulo, icono, detalle (BBCode) }]
static func obtener_entradas(categoria: int, estadisticas: estadisticas_player) -> Array:
	match categoria:
		Categoria.BESTIAS:
			return _entradas_bestias()
		Categoria.RECETAS:
			return _entradas_recetas()
		Categoria.SINERGIAS:
			return _entradas_sinergias(estadisticas)
		Categoria.ZETAS:
			return _entradas_zetas()
	return []


## Vector2i(completadas, total) de una sección
static func contar(categoria: int, estadisticas: estadisticas_player) -> Vector2i:
	var completas := 0
	for entrada in obtener_entradas(categoria, estadisticas):
		if entrada["estado"] == Estado.COMPLETO:
			completas += 1
	return Vector2i(completas, _total(categoria, estadisticas))


static func _total(categoria: int, estadisticas: estadisticas_player) -> int:
	match categoria:
		Categoria.BESTIAS:
			return _obtener_bestias().size()
		Categoria.RECETAS:
			return SistemaCocina.obtener_recetas().size()
		Categoria.SINERGIAS:
			return estadisticas.sinergias.sinergias_disponibles.size() if estadisticas else 0
		Categoria.ZETAS:
			return _obtener_zetas().size()
	return 0


# ==============================================================================
# BESTIAS: ??? al verla (te detectó), completa al derrotarla
# ==============================================================================

static func _entradas_bestias() -> Array:
	var lista: Array = []
	for stats in _obtener_bestias():
		var id = stats.id_registro()
		var derrotas = CodigoGlobal.cantidad_derrotas(id)
		var estado := Estado.OCULTO
		if derrotas > 0:
			estado = Estado.COMPLETO
		elif CodigoGlobal.fue_visto("bestia:" + id):
			estado = Estado.DESCONOCIDO
		if estado == Estado.OCULTO:
			continue

		if estado == Estado.DESCONOCIDO:
			lista.append(_entrada_oculta("Todavía no sabés nada de esta bestia.\nDerrotala para registrarla."))
			continue

		var texto := "[b]%s[/b]\n\n%s\n\nDerrotada: %d veces\nVida: %s\nDaño: %s" % [
			stats.nombre, stats.descripcion, derrotas, stats.vida_maxima, stats.danio_ataque]
		if not stats.partes.is_empty():
			var nombres := PackedStringArray()
			for parte in stats.partes:
				if parte != null:
					nombres.append(parte.nombre)
			texto += "\nPartes: " + ", ".join(nombres)
		lista.append(_entrada(Estado.COMPLETO, stats.nombre, stats.icono, texto))
	return lista


# ==============================================================================
# RECETAS: ??? al conseguir un ingrediente de sus tags, completa al cocinarla
# ==============================================================================

static func _entradas_recetas() -> Array:
	var lista: Array = []
	for receta in SistemaCocina.obtener_recetas():
		if CodigoGlobal.receta_descubierta(receta):
			var texto := "[b]%s[/b]\n\n%s\n\nIngredientes: %s" % [
				receta.nombre, receta.descripcion, receta.texto_requisitos()]
			var icono: Texture2D = null
			if receta.plato != null:
				icono = receta.plato.icono
				texto += "\n\nPlato: %s\n%s\nHambre: +%s" % [
					receta.plato.nombre, receta.plato.descripcion, receta.plato.hambre_restaurada]
			lista.append(_entrada(Estado.COMPLETO, receta.nombre, icono, texto))
		elif _receta_tiene_tag_visto(receta):
			lista.append(_entrada_oculta("Encontraste ingredientes de esta receta.\nProbá cocinar combinaciones distintas para descubrirla."))
	return lista


static func _receta_tiene_tag_visto(receta: RecetaCocina) -> bool:
	for requisito in receta.requisitos:
		if requisito != null and tag_visto(requisito.tag):
			return true
	return false


# ==============================================================================
# SINERGIAS: ??? al conseguir un ingrediente de sus tags, completa al vivirla
# ==============================================================================

static func _entradas_sinergias(estadisticas: estadisticas_player) -> Array:
	var lista: Array = []
	if estadisticas == null:
		return lista
	for sinergia in estadisticas.sinergias.sinergias_disponibles:
		if sinergia == null:
			continue
		if CodigoGlobal.conoce(sinergia.clave_conocimiento()):
			lista.append(_entrada_sinergia(sinergia))
		elif _sinergia_tiene_tag_visto(sinergia):
			lista.append(_entrada_oculta("Algo se puede combinar con lo que encontraste.\nComé distintas partes y descubrilo."))
	return lista


static func _sinergia_tiene_tag_visto(sinergia: SinergiaSabor) -> bool:
	for tag in sinergia.lista_de_tags():
		if tag_visto(tag):
			return true
	return false


static func _entrada_sinergia(sinergia: SinergiaSabor) -> Dictionary:
	var info := sinergia.info_para_ui(true)
	var flecha := "▲" if info["es_positiva"] else "▼"
	var texto := "[b]%s %s[/b]\n\n%s\n\nIngredientes: %s\nVentana: %ds   ·   Dura: %s" % [
		flecha, sinergia.nombre, sinergia.descripcion, sinergia.texto_requisitos(),
		int(info["ventana"]), _texto_duracion(info["duracion"])]
	for efecto in info["efectos"]:
		var signo := "+" if efecto["valor"] >= 0.0 else ""
		var sufijo := "%" if efecto["es_porcentaje"] else ""
		var color := "#7fdc7f" if efecto["sube"] else "#e86d6d"
		texto += "\n[color=%s]%s %s%s%s[/color]" % [color, efecto["stat"], signo, efecto["valor"], sufijo]
	return _entrada(Estado.COMPLETO, "%s %s" % [flecha, sinergia.nombre], sinergia.icono, texto)


static func _texto_duracion(segundos: float) -> String:
	return "toda la run" if segundos < 0.0 else "%ds" % int(segundos)


# ==============================================================================
# ZETAS: ??? si es una mutación posible de una Zeta que ya usaste, completa al usarla
# ==============================================================================

static func _entradas_zetas() -> Array:
	var lista: Array = []
	var conocidas := {}
	for zeta in _obtener_zetas():
		if CodigoGlobal.conoce("zeta:" + zeta.nombre):
			conocidas[zeta.nombre] = true

	# Mutaciones posibles de las Zetas ya conocidas
	var sospechadas := {}
	for zeta in _obtener_zetas():
		if not conocidas.has(zeta.nombre):
			continue
		for mutacion in zeta.posibles_mutaciones:
			if mutacion != null and mutacion.seta != null:
				sospechadas[mutacion.seta.nombre] = true

	for zeta in _obtener_zetas():
		if conocidas.has(zeta.nombre):
			lista.append(_entrada_zeta(zeta))
		elif sospechadas.has(zeta.nombre):
			lista.append(_entrada_oculta("Una Zeta a la que podrías mutar.\nUsala para registrarla."))
	return lista


static func _entrada_zeta(zeta: Zeta_datos) -> Dictionary:
	var texto := "[b]%s[/b]\n\n%s" % [zeta.nombre, zeta.descripcion]
	if zeta.estadisticas != null:
		texto += "\n\nVida: %s\nFuerza: %s\nPeso: %s" % [
			_con_signo(zeta.estadisticas.bonus_vida_max),
			_con_signo(zeta.estadisticas.bonus_fuerza_ataque),
			zeta.estadisticas.peso]
	if not zeta.gustos.is_empty():
		texto += "\nLe gusta: " + _nombres_de_tags(zeta.gustos)
	if not zeta.odios.is_empty():
		texto += "\nOdia: " + _nombres_de_tags(zeta.odios)
	if not zeta.posibles_mutaciones.is_empty():
		texto += "\n\nMuta con %s (x%d) a: %d Zeta(s)" % [
			ItemData.TagComida.keys()[zeta.tag_mutacion], zeta.umbral_mutacion, zeta.posibles_mutaciones.size()]
	return _entrada(Estado.COMPLETO, zeta.nombre, zeta.textura, texto)


# ==============================================================================
# UTILIDADES
# ==============================================================================

static func tag_visto(tag: int) -> bool:
	return CodigoGlobal.fue_visto("tag:%d" % tag)


static func _entrada(estado: int, titulo: String, icono: Texture2D, detalle: String) -> Dictionary:
	return {"estado": estado, "titulo": titulo, "icono": icono, "detalle": detalle}


static func _entrada_oculta(pista: String) -> Dictionary:
	return _entrada(Estado.DESCONOCIDO, "???", null, "[i]%s[/i]" % pista)


static func _con_signo(valor: float) -> String:
	return ("+%s" % valor) if valor >= 0.0 else str(valor)


static func _nombres_de_tags(tags: Array) -> String:
	var nombres := PackedStringArray()
	for tag in tags:
		nombres.append(ItemData.TagComida.keys()[tag])
	return ", ".join(nombres)


static func _obtener_bestias() -> Array[EnemigoStats]:
	_cargar_recursos()
	return _bestias


static func _obtener_zetas() -> Array[Zeta_datos]:
	_cargar_recursos()
	return _zetas


static func _cargar_recursos() -> void:
	if _cargado:
		return
	_cargado = true
	_bestias.clear()
	_zetas.clear()
	for recurso in _leer_carpeta(CARPETA_BESTIAS):
		if recurso is EnemigoStats:
			_bestias.append(recurso)
	for recurso in _leer_carpeta(CARPETA_ZETAS):
		if recurso is Zeta_datos:
			_zetas.append(recurso)


static func _leer_carpeta(carpeta: String) -> Array:
	var recursos: Array = []
	for archivo in DirAccess.get_files_at(carpeta):
		# En un juego exportado los recursos aparecen como "nombre.tres.remap"
		var nombre := archivo.trim_suffix(".remap")
		if not (nombre.ends_with(".tres") or nombre.ends_with(".res")):
			continue
		var recurso := load(carpeta + "/" + nombre)
		if recurso:
			recursos.append(recurso)
	return recursos
