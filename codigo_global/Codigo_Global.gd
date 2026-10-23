extends Node

signal inventario_base_actualizado

const RUTA_BASE := "res://niveles/base.tscn"
const RUTA_RUN := "res://niveles/suelo_2.tscn"
const RUTA_GUARDADO :="res://guardado/datos_guardado.tres"


@export var zeta_inicial: Zeta_datos   # Asignar en el Inspector la Zeta fija con la que siempre arranca una run

var en_run: bool = false
var vida_inicial_run: float = -1.0

@export var penalizacion_vida_inicial: float = 0.3
@export var porcentaje_perdida_muerte: float = 12.0

var inventario_base: Dictionary = {}
var conocimientos: Array[String] = []


func _ready() -> void:
	call_deferred("_actualizar_en_run_segun_escena")
	cargar_partida()

func _actualizar_en_run_segun_escena() -> void:
	var escena_actual = get_tree().current_scene
	if escena_actual == null:
		push_warning("CodigoGlobal: no se pudo determinar la escena actual al iniciar.")
		return
	
	var es_base = escena_actual.has_meta("es_base") and escena_actual.get_meta("es_base") == true
	en_run = not es_base
	print("CodigoGlobal iniciado. Escena real: ", escena_actual.scene_file_path, " | ¿Es base?: ", es_base, " | en_run: ", en_run)

func iniciar_run(estadisticas: estadisticas_player, provisiones: Dictionary = {}) -> void:
	en_run = true
	
	if estadisticas.zeta_inicial:
		estadisticas.cambiar_zeta(estadisticas.zeta_inicial)
	estadisticas.con_zeta = false
	
	if estadisticas.hambre.esta_en_cero():
		vida_inicial_run = estadisticas.stats.vida_base * penalizacion_vida_inicial
		print("¡Hambre en 0! Iniciando la run con vida reducida: ", vida_inicial_run)
	else:
		vida_inicial_run = -1.0
	
	estadisticas.inventario.clear()
	estadisticas.buffs.limpiar_run()
	_cargar_provisiones(estadisticas, provisiones)
	cambiar_escena(RUTA_RUN)
	estadisticas.sinergias.limpiar()
func finalizar_run(estadisticas: estadisticas_player) -> void:
	en_run = false
	estadisticas.con_zeta = true
	_transferir_inventario_a_base(estadisticas)
	estadisticas.buffs.limpiar_run()
	cambiar_escena(RUTA_BASE)
	estadisticas.sinergias.limpiar()
	
	
func morir(estadisticas: estadisticas_player) -> void:
	en_run = false
	estadisticas.con_zeta = true
	_aplicar_penalizacion_muerte(estadisticas)
	_transferir_inventario_a_base(estadisticas)
	estadisticas.buffs.limpiar_run()
	cambiar_escena(RUTA_BASE)
	estadisticas.sinergias.limpiar()
	
	
func _aplicar_penalizacion_muerte(estadisticas: estadisticas_player) -> void:
	for clave in estadisticas.inventario.keys():
		var item: ItemData = estadisticas.inventario[clave]
		var perdida := int(ceil(item.cantidad * (porcentaje_perdida_muerte / 100.0)))
		item.cantidad = max(0, item.cantidad - perdida)
		print("Penalización por muerte: ", item.nombre, " perdió ", perdida, " unidades (quedan ", item.cantidad, ")")
		
		if item.cantidad <= 0:
			estadisticas.inventario.erase(clave)

func _transferir_inventario_a_base(estadisticas: estadisticas_player) -> void:
	for clave in estadisticas.inventario:
		var item: ItemData = estadisticas.inventario[clave]
		
		if inventario_base.has(clave):
			var item_en_base: ItemData = inventario_base[clave]
			item_en_base.cantidad = min(item_en_base.cantidad + item.cantidad, item_en_base.max_cantidad)
		else:
			inventario_base[clave] = item.duplicate()
	
	estadisticas.inventario.clear()
	print("Inventario transferido a la base.")
	
	guardar_partida()
	inventario_base_actualizado.emit()

# ==============================================================================
# GUARDADO Y CARGA
# ==============================================================================

func guardar_partida() -> void:
	var carpeta := RUTA_GUARDADO.get_base_dir()
	if not DirAccess.dir_exists_absolute(carpeta):
		DirAccess.make_dir_recursive_absolute(carpeta)
	
	var datos := DatosGuardado.new()
	datos.inventario_base = inventario_base
	datos.recetas_descubiertas = recetas_descubiertas.duplicate()
	datos.conocimientos = conocimientos.duplicate()
	var error = ResourceSaver.save(datos, RUTA_GUARDADO)
	if error == OK:
		print("Partida guardada en: ", RUTA_GUARDADO)
	else:
		push_warning("Error al guardar la partida: ", error)


func cargar_partida() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		print("No hay partida guardada todavía. Inventario de base inicia vacío.")
		return
	
	var datos: DatosGuardado = ResourceLoader.load(RUTA_GUARDADO)
	if datos:
		inventario_base = datos.inventario_base
		recetas_descubiertas.assign(datos.recetas_descubiertas)
		conocimientos.assign(datos.conocimientos)
		print("Partida cargada. Items en inventario de base: ", inventario_base.size())
		inventario_base_actualizado.emit()
	else:
		push_warning("No se pudo cargar el archivo de guardado.")
signal recetas_actualizadas

var recetas_descubiertas: Array[String] = []

func receta_descubierta(receta: RecetaCocina) -> bool:
	return receta != null and recetas_descubiertas.has(receta.nombre)

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

func _cargar_provisiones(estadisticas: estadisticas_player, provisiones: Dictionary) -> void:
	var restante: int = estadisticas.stats.capacidad_provisiones
	for clave in provisiones:
		if restante <= 0:
			break
		if not inventario_base.has(clave):
			continue
		var item: ItemData = inventario_base[clave]
		var n := mini(mini(int(provisiones[clave]), item.cantidad), restante)
		if n <= 0:
			continue
		var copia: ItemData = item.duplicate()
		copia.cantidad = n
		estadisticas.inventario[clave] = copia
		quitar_item_base(clave, n, false)
		restante -= n
	guardar_partida()
	inventario_base_actualizado.emit()



func conoce(clave: String) -> bool:
	return conocimientos.has(clave)

## Devuelve true si era algo nuevo
func aprender(clave: String) -> bool:
	if conocimientos.has(clave):
		return false
	conocimientos.append(clave)
	guardar_partida()
	return true

func cambiar_escena(ruta_escena: String) -> void:
	var error = get_tree().change_scene_to_file(ruta_escena)
	
	if error != OK:
		push_warning("CodigoGlobal: No se pudo cargar la escena en la ruta: ", ruta_escena)
		return
	
	# 1. Esperamos mientras 'current_scene' sea null (cubre el espacio vacío entre la escena vieja y la nueva)
	while get_tree().current_scene == null:
		await get_tree().process_frame
	
	# 2. Damos un fotograma extra de gracia para asegurar que el _ready() y las metadatas de la nueva escena estén listos
	await get_tree().process_frame
	
	# 3. Ahora sí, ejecutamos la verificación con seguridad
	_actualizar_en_run_segun_escena()
