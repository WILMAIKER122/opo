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


## olla: { clave : unidades }. Devuelve { "estado": "ok" | "fallida" | "vacia" | "invalida", ... }
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
	if receta == null or receta.plato == null:
		return {"estado": "fallida"} # no se gasta ningún ingrediente

	for clave in olla.keys():
		var n := int(olla[clave])
		if n > 0:
			quitar_item_base(clave, n, false)
	agregar_item_base(receta.plato, receta.cantidad_resultado)

	var nueva := not recetas_descubiertas.has(receta.nombre)
	if nueva:
		recetas_descubiertas.append(receta.nombre)
	guardar_partida()
	inventario_base_actualizado.emit()
	if nueva:
		recetas_actualizadas.emit()
	return {"estado": "ok", "receta": receta, "nueva": nueva}


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
