extends Node
## Estado global del juego (autoload "CodigoGlobal"). La lógica pesada vive en:
##   GestorGuardado   (guardar/cargar)         GestorRun  (ciclo de la run y salas)
##   GeneradorPuertas (puertas, costos, botín)
## Acá quedan el estado, el registro de conocimiento, la base, la cocina y el tiempo.

signal inventario_base_actualizado
signal recetas_actualizadas

@export var zeta_inicial: Zeta_datos   # Asignar en el Inspector la Zeta fija con la que siempre arranca una run
@export var penalizacion_vida_inicial: float = 0.3
@export var porcentaje_perdida_muerte: float = 12.0

# --- Partida guardada ---
var inventario_base: Dictionary = {}
var bolsillo: Dictionary = {}     # provisiones equipadas (clave -> ItemData)
var conocimientos: Array[String] = []
var vistos: Array[String] = []     # "tag:3", "item:Pata", "bestia:lobo"
var derrotas: Dictionary = {}      # id de bestia -> veces derrotada
var recetas_descubiertas: Array[String] = []
var run_en_curso: bool = false    # si el juego se cierra con esto en true, se pierde el bolsillo
var carga_ok: bool = false

# --- Estado de la run (no se guarda) ---
var en_run: bool = false
var vida_inicial_run: float = -1.0
var sala_numero: int = 0
var nivel_sala: int = 0
var tipo_sala_actual: int = 0
## Tag del ingrediente que soltará la sala actual (-1 = ninguno)
var tag_recompensa: int = -1
## Dirección (un eje XZ) por la que se salió de la sala anterior. ZERO = aparición por defecto
var direccion_entrada: Vector3 = Vector3.ZERO

var _efectos_tiempo: Array = []   # {"escala": float, "fin": int (ms reales)}

var plantilla_bolsillo: Dictionary = {}   # clave -> cantidad objetivo (se guarda)
var refuerzos: int = 0                    # enemigos extra que traerá la próxima sala
## % de lo puesto en la olla que se pierde en una mezcla fallida (mínimo 1 unidad)
@export var porcentaje_perdida_fallo: float = 30.0
var mejoras_obtenidas: Dictionary = {}   # nombre de receta -> nivel obtenido (se guarda)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_actualizar_en_run_segun_escena")
	cargar_partida()


# ==============================================================================
# FACHADA (los demás scripts siguen llamando a CodigoGlobal.xxx igual que antes)
# ==============================================================================

func guardar_partida() -> void: GestorGuardado.guardar(self)
func cargar_partida() -> void: GestorGuardado.cargar(self)
func iniciar_run(est: estadisticas_player) -> void: GestorRun.iniciar(self, est)
func finalizar_run(est: estadisticas_player) -> void: GestorRun.finalizar(self, est)
func morir(est: estadisticas_player) -> void: GestorRun.morir(self, est)
func abandonar_run() -> void: GestorRun.abandonar(self)
func siguiente_sala(opcion: Dictionary, est: estadisticas_player) -> void: GestorRun.siguiente_sala(self, opcion, est)


# ==============================================================================
# ESCENAS
# ==============================================================================

func _actualizar_en_run_segun_escena() -> void:
	var escena_actual = get_tree().current_scene
	if escena_actual == null:
		push_warning("CodigoGlobal: no se pudo determinar la escena actual al iniciar.")
		return
	var es_base = escena_actual.has_meta("es_base") and escena_actual.get_meta("es_base") == true
	en_run = not es_base
	print("CodigoGlobal iniciado. Escena real: ", escena_actual.scene_file_path, " | ¿Es base?: ", es_base, " | en_run: ", en_run)


func cambiar_escena(ruta_escena: String) -> void:
	var error = get_tree().change_scene_to_file(ruta_escena)
	if error != OK:
		push_warning("CodigoGlobal: No se pudo cargar la escena en la ruta: ", ruta_escena)
		return

	# Esperamos mientras 'current_scene' sea null (espacio vacío entre la escena vieja y la nueva)
	while get_tree().current_scene == null:
		await get_tree().process_frame
	# Un fotograma extra para que el _ready() y las metadatas de la nueva escena estén listos
	await get_tree().process_frame
	_actualizar_en_run_segun_escena()


# ==============================================================================
# INVENTARIO DE LA BASE
# ==============================================================================

func quitar_item_base(clave: String, cantidad_a_quitar: int, guardar: bool = true) -> void:
	if not inventario_base.has(clave):
		return
	var item: ItemData = inventario_base[clave]
	item.cantidad -= cantidad_a_quitar
	if item.cantidad <= 0:
		inventario_base.erase(clave)
	if guardar:
		guardar_partida()
		inventario_base_actualizado.emit()


func agregar_item_base(item: ItemData, cantidad: int = 1) -> void:
	var clave := item.nombre
	if inventario_base.has(clave) and inventario_base[clave].apilable:
		inventario_base[clave].cantidad += cantidad
		return
	var nuevo: ItemData = item.duplicate()
	nuevo.cantidad = cantidad
	if inventario_base.has(clave):
		clave += "_" + str(randi())
	inventario_base[clave] = nuevo


func fusionar_en_base(origen: Dictionary) -> void:
	for clave in origen:
		var item: ItemData = origen[clave]
		if inventario_base.has(clave):
			var item_en_base: ItemData = inventario_base[clave]
			item_en_base.cantidad = mini(item_en_base.cantidad + item.cantidad, item_en_base.max_cantidad)
		else:
			inventario_base[clave] = item.duplicate()


func hay_comestibles_en_base() -> bool:
	for clave in inventario_base:
		var item: ItemData = inventario_base[clave]
		if item.tipo == ItemData.TipoItem.COMESTIBLE and item.cantidad > 0:
			return true
	return false


## Para partidas viejas: lo que ya tenés en la base cuenta como "visto"
func marcar_inventario_base_como_visto() -> void:
	for clave in inventario_base:
		var item: ItemData = inventario_base[clave]
		marcar_visto("item:" + item.nombre)
		for tag in item.tags:
			marcar_visto("tag:%d" % tag)


# ==============================================================================
# COCINA
# ==============================================================================

func receta_descubierta(receta: RecetaCocina) -> bool:
	return receta != null and recetas_descubiertas.has(receta.nombre)


func nivel_mejora(receta: RecetaCocina) -> int:
	return int(mejoras_obtenidas.get(receta.nombre, 0)) if receta else 0


## olla: { clave : unidades }. Devuelve { "estado": "ok" | "fallida" | "completa" | "vacia" | "invalida", ... }
func cocinar(olla: Dictionary) -> Dictionary:
	var total := 0
	for clave in olla:
		var n := int(olla[clave])
		if n <= 0:
			continue
		if not inventario_base.has(clave) or inventario_base[clave].cantidad < n:
			return {"estado": "invalida"}
		total += n
	if total <= 0:
		return {"estado": "vacia"}

	var conteo := SistemaCocina.contar_tags(olla, inventario_base)
	var receta := SistemaCocina.buscar_receta(conteo)
	if receta == null or receta.mejora == null:
		return _cocina_fallida(olla)
	if nivel_mejora(receta) >= receta.nivel_max:
		return {"estado": "completa", "receta": receta}   # no se gasta nada

	for clave in olla.keys():
		var n := int(olla[clave])
		if n > 0:
			quitar_item_base(clave, n, false)
	mejoras_obtenidas[receta.nombre] = nivel_mejora(receta) + 1

	var nueva := not recetas_descubiertas.has(receta.nombre)
	if nueva:
		recetas_descubiertas.append(receta.nombre)
	guardar_partida()
	inventario_base_actualizado.emit()
	if nueva:
		recetas_actualizadas.emit()
	return {"estado": "ok", "receta": receta, "nueva": nueva}


## Mezcla sin receta: se pierde un % de lo puesto (mínimo 1 unidad en total)
func _cocina_fallida(olla: Dictionary) -> Dictionary:
	var perdidas := {}
	var suma := 0
	var mayor := ""
	for clave in olla:
		var n := int(olla[clave])
		if n <= 0:
			continue
		var perdida := mini(n, roundi(n * porcentaje_perdida_fallo / 100.0))
		perdidas[clave] = perdida
		suma += perdida
		if mayor == "" or n > int(olla[mayor]):
			mayor = clave
	if suma == 0:
		perdidas[mayor] = 1

	var resumen: Array = []
	for clave in perdidas:
		var perdida := int(perdidas[clave])
		if perdida <= 0:
			continue
		resumen.append({"nombre": (inventario_base[clave] as ItemData).nombre, "cantidad": perdida})
		quitar_item_base(clave, perdida, false)
	guardar_partida()
	inventario_base_actualizado.emit()
	return {"estado": "fallida", "perdido": resumen}


# ==============================================================================
# REGISTRO DE CONOCIMIENTO (Tomo)
# ==============================================================================

func conoce(clave: String) -> bool:
	return conocimientos.has(clave)


## Devuelve true si era algo nuevo
func aprender(clave: String) -> bool:
	if conocimientos.has(clave):
		return false
	conocimientos.append(clave)
	guardar_partida()
	return true


func marcar_visto(clave: String) -> bool:
	if vistos.has(clave):
		return false
	vistos.append(clave)
	return true


func fue_visto(clave: String) -> bool:
	return vistos.has(clave)


func registrar_derrota(id_bestia: String) -> void:
	derrotas[id_bestia] = int(derrotas.get(id_bestia, 0)) + 1


func cantidad_derrotas(id_bestia: String) -> int:
	return int(derrotas.get(id_bestia, 0))


# ==============================================================================
# TIEMPO (hitstop / slowmo)
# ==============================================================================

## Baja la velocidad del juego un rato. Varios efectos a la vez: manda el más lento.
func slowmo(escala: float, segundos: float) -> void:
	_efectos_tiempo.append({
		"escala": escala,
		"fin": Time.get_ticks_msec() + int(segundos * 1000.0),
	})


## Congela el juego un instante (impacto de un golpe)
func hitstop(segundos: float = 0.05) -> void:
	slowmo(0.05, segundos)


func _process(_delta: float) -> void:
	if _efectos_tiempo.is_empty():
		return
	var ahora := Time.get_ticks_msec()
	var escala := 1.0
	for i in range(_efectos_tiempo.size() - 1, -1, -1):
		if _efectos_tiempo[i]["fin"] <= ahora:
			_efectos_tiempo.remove_at(i)
		else:
			escala = minf(escala, _efectos_tiempo[i]["escala"])
	Engine.time_scale = escala
