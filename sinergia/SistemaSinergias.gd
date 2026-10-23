class_name SistemaSinergias
extends Resource
## Lleva un historial de tags comidos y detecta sinergias dentro de la ventana de tiempo
## de cada una. Las sinergias pueden ser POSITIVAS o NEGATIVAS (se deduce de sus efectos):
## una sinergia negativa por cantidad es la penalización por abusar de un tag.
##
## El jugador APRENDE una sinergia al vivirla. Mientras no la conoce, la UI solo recibe
## la ventana de tiempo; nombre, efectos y progreso salen ocultos ("???").
##
## Si consumir_tags es true, al activarse se gastan SOLO los tags que formaron la sinergia
## (las demás se evalúan contra el mismo historial). Si es false, los tags siguen contando.

# ------------------------------------------------------------------ SEÑALES (para la UI)

## Cambió el conjunto de ventanas abiertas (se comió un tag, una ventana venció o se activó
## una sinergia). ventanas = obtener_ventanas(). Para una cuenta regresiva fluida la UI
## puede volver a pedir obtener_ventanas() cada frame.
signal ventanas_cambiaron(ventanas: Array)
## Se activó una sinergia. info = info_para_ui() de la sinergia (oculta si no la conocía)
## + id, restante y nueva (true si es la primera vez que la vive).
signal sinergia_activada(info: Dictionary)
## Terminó el efecto de una sinergia (misma estructura de info)
signal sinergia_terminada(info: Dictionary)
## Primera vez que el jugador vive esta sinergia: info COMPLETA, ahora ya la conoce
signal sinergia_descubierta(info: Dictionary)

## Asignar en el Inspector todas las sinergias .tres que existan en el juego
@export var sinergias_disponibles: Array[SinergiaSabor] = []

var tiempo_actual: float = 0.0
## Cada entrada: { "tag": int, "tiempo": float }  (en orden cronológico)
var historial: Array = []
## nombre de sinergia -> { "restante", "duracion", "efecto", "valor", "sinergia", "conocida" }
## "conocida" = si el jugador la conocía ANTES de esta activación (la UI oculta los datos si no)
var activas: Dictionary = {}

var _ultima_firma: String = ""


func actualizar(delta: float) -> void:
	tiempo_actual += delta
	_purgar_historial()

	for nombre in activas.keys():
		var datos: Dictionary = activas[nombre]
		if datos["restante"] < 0.0:
			continue # -1 = dura toda la run
		datos["restante"] -= delta
		if datos["restante"] <= 0.0:
			var info := _info_activa(datos)
			activas.erase(nombre)
			sinergia_terminada.emit(info)

	_revisar_ventanas()


## Registra los tags del item comido y devuelve las sinergias recién activadas.
## El que llama (estadisticas_player) se encarga de aplicar los efectos de stats.
func registrar_comida(item: ItemData, veces: int = 1) -> Array[SinergiaSabor]:
	var activadas: Array[SinergiaSabor] = []
	if item == null or item.tags.is_empty():
		return activadas

	for tag in item.tags:
		for i in veces:
			historial.append({"tag": tag, "tiempo": tiempo_actual})

	# Todas se evalúan contra el historial tal cual está ahora (antes de consumir),
	# así una sinergia no le "roba" los tags a otra en la misma comida.
	var indices_a_consumir := {}
	for sinergia in sinergias_disponibles:
		if sinergia == null or activas.has(sinergia.nombre):
			continue
		var indices := _buscar_indices(sinergia)
		if indices.is_empty():
			continue
		if sinergia.consumir_tags:
			for i in indices:
				indices_a_consumir[i] = true
		activadas.append(sinergia)

	# Consumir de atrás hacia adelante para no correr los índices
	var lista := indices_a_consumir.keys()
	lista.sort()
	lista.reverse()
	for i in lista:
		historial.remove_at(i)

	for sinergia in activadas:
		_activar(sinergia)

	_revisar_ventanas()
	return activadas


# ------------------------------------------------------------------ CONSULTAS PARA LA UI

## Ventanas abiertas, listas para mostrar y ordenadas por tiempo restante.
## Cada una es el info_para_ui() de la sinergia (oculto si no la conoce) más:
##   id, restante (segundos que le quedan a la ventana)
## y, SOLO si la conoce: requisitos, contados, necesarios (progreso).
## "id" sirve para identificar la fila; no es un dato para mostrar.
func obtener_ventanas() -> Array:
	var resultado: Array = []
	for crudo in _calcular_ventanas():
		resultado.append(_ventana_visible(crudo))
	return resultado


## Efectos de sinergias activos ahora (info_para_ui + id, restante, nueva).
## restante = -1 si dura toda la run.
func obtener_efectos_activos() -> Array:
	var resultado: Array = []
	for datos in activas.values():
		resultado.append(_info_activa(datos))
	return resultado


## ¿Hay alguna sinergia activa que otorgue este efecto especial?
func tiene_efecto(tipo: SinergiaSabor.EfectoEspecial) -> bool:
	for datos in activas.values():
		if datos["efecto"] == tipo:
			return true
	return false


## Suma de valor_efecto_especial de todas las sinergias activas con ese efecto.
func valor_efecto(tipo: SinergiaSabor.EfectoEspecial) -> float:
	var total := 0.0
	for datos in activas.values():
		if datos["efecto"] == tipo:
			total += datos["valor"]
	return total


func limpiar() -> void:
	var habia_ventanas := _ultima_firma != ""
	historial.clear()
	activas.clear()
	tiempo_actual = 0.0
	_ultima_firma = ""
	if habia_ventanas:
		ventanas_cambiaron.emit([])


## Texto para debug / label (una línea por sinergia activa)
func resumen() -> String:
	if activas.is_empty():
		return ""
	var lineas := PackedStringArray()
	for nombre in activas:
		var restante: float = activas[nombre]["restante"]
		var texto_tiempo := "run" if restante < 0.0 else "%ds" % ceili(restante)
		lineas.append("%s (%s)" % [nombre, texto_tiempo])
	return "\n".join(lineas)


# ------------------------------------------------------------------ PRIVADAS

## Devuelve los índices del historial que formarían la sinergia, o [] si no se cumple.
## Usa las entradas más viejas dentro de la ventana (así las nuevas duran más).
func _buscar_indices(sinergia: SinergiaSabor) -> Array:
	var requeridos := sinergia.lista_de_tags()
	if requeridos.is_empty():
		return []
	var usados: Array = []
	for tag in requeridos:
		var encontrado := -1
		for i in historial.size():
			if i in usados:
				continue
			var entrada: Dictionary = historial[i]
			if entrada["tag"] != tag:
				continue
			if tiempo_actual - entrada["tiempo"] > sinergia.ventana_segundos:
				continue
			encontrado = i
			break
		if encontrado == -1:
			return []
		usados.append(encontrado)
	return usados


func _activar(sinergia: SinergiaSabor) -> void:
	var conocida_antes := _es_conocida(sinergia)
	activas[sinergia.nombre] = {
		"restante": sinergia.duracion_segundos,
		"duracion": sinergia.duracion_segundos,
		"efecto": sinergia.efecto_especial,
		"valor": sinergia.valor_efecto_especial,
		"sinergia": sinergia,
		"conocida": conocida_antes,
	}
	# Vivirla hace que el jugador la conozca de ahora en adelante
	var era_nueva := CodigoGlobal.aprender(sinergia.clave_conocimiento())

	var info := _info_activa(activas[sinergia.nombre])
	info["nueva"] = era_nueva
	sinergia_activada.emit(info)

	if era_nueva:
		var completa := sinergia.info_para_ui(true)
		completa["id"] = sinergias_disponibles.find(sinergia)
		sinergia_descubierta.emit(completa)


func _info_activa(datos: Dictionary) -> Dictionary:
	var sinergia: SinergiaSabor = datos["sinergia"]
	var info := sinergia.info_para_ui(datos["conocida"])
	info["id"] = sinergias_disponibles.find(sinergia)
	info["restante"] = datos["restante"]
	info["nueva"] = false
	return info


func _es_conocida(sinergia: SinergiaSabor) -> bool:
	return CodigoGlobal.conoce(sinergia.clave_conocimiento())


## Datos internos de cada ventana abierta (sin filtrar por conocimiento)
func _calcular_ventanas() -> Array:
	var lista: Array = []
	for i in sinergias_disponibles.size():
		var sinergia := sinergias_disponibles[i]
		if sinergia == null or activas.has(sinergia.nombre):
			continue
		var progreso := _evaluar_progreso(sinergia)
		if progreso.is_empty():
			continue
		progreso["indice"] = i
		progreso["sinergia"] = sinergia
		lista.append(progreso)
	lista.sort_custom(func(a, b): return a["restante"] < b["restante"])
	return lista


## Cuántos de los tags requeridos ya hay dentro de la ventana y cuánto le queda a la ventana.
## Devuelve {} si todavía no hay ningún tag relevante.
func _evaluar_progreso(sinergia: SinergiaSabor) -> Dictionary:
	var requeridos := sinergia.lista_de_tags()
	if requeridos.is_empty():
		return {}

	var necesarios := {}
	for tag in requeridos:
		necesarios[tag] = int(necesarios.get(tag, 0)) + 1

	var disponibles := {}
	var mas_vieja: float = INF
	for entrada in historial:
		if tiempo_actual - entrada["tiempo"] > sinergia.ventana_segundos:
			continue
		var tag = entrada["tag"]
		if not necesarios.has(tag):
			continue
		disponibles[tag] = int(disponibles.get(tag, 0)) + 1
		mas_vieja = minf(mas_vieja, entrada["tiempo"])

	if disponibles.is_empty():
		return {}

	var contados := 0
	for tag in necesarios:
		contados += mini(int(disponibles.get(tag, 0)), int(necesarios[tag]))

	return {
		"contados": contados,
		"necesarios": requeridos.size(),
		"restante": sinergia.ventana_segundos - (tiempo_actual - mas_vieja),
	}


## Convierte una ventana interna en lo que el jugador tiene permitido ver
func _ventana_visible(crudo: Dictionary) -> Dictionary:
	var sinergia: SinergiaSabor = crudo["sinergia"]
	var conocida := _es_conocida(sinergia)
	var info := sinergia.info_para_ui(conocida)
	info["id"] = crudo["indice"]
	info["restante"] = crudo["restante"]
	if conocida:
		info["requisitos"] = sinergia.texto_requisitos()
		info["contados"] = crudo["contados"]
		info["necesarios"] = crudo["necesarios"]
	return info


## Emite ventanas_cambiaron solo cuando cambió QUÉ ventanas hay o su progreso
func _revisar_ventanas() -> void:
	var firma := ""
	for crudo in _calcular_ventanas():
		firma += "%d:%d;" % [crudo["indice"], crudo["contados"]]
	if firma == _ultima_firma:
		return
	_ultima_firma = firma
	ventanas_cambiaron.emit(obtener_ventanas())


func _purgar_historial() -> void:
	var ventana_max := 0.0
	for sinergia in sinergias_disponibles:
		if sinergia != null:
			ventana_max = maxf(ventana_max, sinergia.ventana_segundos)
	while not historial.is_empty() and tiempo_actual - historial[0]["tiempo"] > ventana_max:
		historial.pop_front()
