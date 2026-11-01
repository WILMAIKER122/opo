class_name GestorRun
extends RefCounted
## Ciclo de la run: iniciar, terminar, morir, abandonar y cambiar de sala.
## El estado vive en CodigoGlobal (g). Destino: res://codigo_global/GestorRun.gd

const RUTA_BASE := "res://niveles/base.tscn"
const RUTA_RUN := "res://niveles/suelo_2.tscn"
const CARPETAS_SALAS := {
	Sala.Tipo.COMBATE: "res://niveles/salas/combate/",
	Sala.Tipo.CAMPAMENTO: "res://niveles/salas/campamento/",
	Sala.Tipo.JEFE: "res://niveles/salas/jefe/",
}


static func iniciar(g: Node, est: estadisticas_player) -> void:
	g.en_run = true

	if est.zeta_inicial:
		est.cambiar_zeta(est.zeta_inicial)
	est.con_zeta = false
	est.dano_escudo_zeta = 0.0
	est.sabores_activos.clear()
	if est.hambre.esta_en_cero():
		g.vida_inicial_run = est.stats.vida_base * g.penalizacion_vida_inicial
		print("¡Hambre en 0! Iniciando la run con vida reducida: ", g.vida_inicial_run)
	else:
		g.vida_inicial_run = -1.0

	est.inventario.clear()
	est.buffs.limpiar_run()
	g.run_en_curso = true
	g.guardar_partida()
	g.sala_numero = 0
	g.nivel_sala = 0
	g.direccion_entrada = Vector3.ZERO
	g.tipo_sala_actual = Sala.Tipo.COMBATE
	g.tag_recompensa = -1
	g.cambiar_escena(_escena_de_sala(g, Sala.Tipo.COMBATE))
	est.sinergias.limpiar()


static func finalizar(g: Node, est: estadisticas_player) -> void:
	g.en_run = false
	est.con_zeta = true
	_transferir_a_base(g, est)
	est.buffs.limpiar_run()
	g.cambiar_escena(RUTA_BASE)
	est.sinergias.limpiar()


static func morir(g: Node, est: estadisticas_player) -> void:
	g.en_run = false
	est.con_zeta = true
	_penalizacion_muerte(g, est)
	_transferir_a_base(g, est)
	est.buffs.limpiar_run()
	g.cambiar_escena(RUTA_BASE)
	est.sinergias.limpiar()


## Volver al menú principal en plena run: se pierde el bolsillo
static func abandonar(g: Node) -> void:
	if not g.en_run:
		return
	g.en_run = false
	g.bolsillo.clear()
	g.run_en_curso = false
	g.guardar_partida()


static func siguiente_sala(g: Node, opcion: Dictionary, est: estadisticas_player) -> void:
	if opcion.get("salida", false):
		finalizar(g, est)
		return
	g.sala_numero += 1
	g.tipo_sala_actual = opcion["tipo"]
	g.nivel_sala = int(opcion.get("nivel", 0))
	g.direccion_entrada = opcion.get("dir_salida", Vector3.ZERO)
	g.tag_recompensa = opcion["tag"]
	g.cambiar_escena(_escena_de_sala(g, opcion["tipo"]))


# ==============================================================================
# INTERNO
# ==============================================================================

static func _penalizacion_muerte(g: Node, est: estadisticas_player) -> void:
	for clave in est.inventario.keys():
		var item: ItemData = est.inventario[clave]
		var perdida := int(ceil(item.cantidad * (g.porcentaje_perdida_muerte / 100.0)))
		item.cantidad = max(0, item.cantidad - perdida)
		print("Penalización por muerte: ", item.nombre, " perdió ", perdida, " unidades (quedan ", item.cantidad, ")")
		if item.cantidad <= 0:
			est.inventario.erase(clave)


static func _transferir_a_base(g: Node, est: estadisticas_player) -> void:
	g.fusionar_en_base(est.inventario)
	est.inventario.clear()
	g.run_en_curso = false
	print("Inventario transferido a la base.")
	g.guardar_partida()
	g.inventario_base_actualizado.emit()


static func _escena_de_sala(g: Node, tipo: int) -> String:
	for t in [tipo, Sala.Tipo.COMBATE]:
		var rutas := _rutas_en(CARPETAS_SALAS[t])
		if rutas.size() > 1:
			rutas.erase(g.get_tree().current_scene.scene_file_path)
		if not rutas.is_empty():
			return rutas.pick_random()
	return RUTA_RUN


static func _rutas_en(carpeta: String) -> Array[String]:
	var rutas: Array[String] = []
	for archivo in DirAccess.get_files_at(carpeta):
		var nombre := archivo.trim_suffix(".remap")
		if nombre.ends_with(".tscn"):
			rutas.append(carpeta.path_join(nombre))
	return rutas
