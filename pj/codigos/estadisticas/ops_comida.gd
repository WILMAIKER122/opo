class_name OpsComida
extends RefCounted
## Comer: efectos de ítems, sinergias y sabores activos. Datos en estadisticas_player (est).
## Destino: res://pj/codigos/estadisticas/ops_comida.gd


static func aplicar_efecto(est: estadisticas_player, efecto: EfectoItem) -> void:
	match efecto.tipo:
		EfectoItem.TipoEfecto.CURACION:
			est.buffs.agregar_buff(efecto.stat_afectado, efecto.valor, efecto.es_porcentaje, -1.0)

		EfectoItem.TipoEfecto.COSTO_VIDA:
			if randf() <= efecto.probabilidad:
				est.buffs.agregar_buff(efecto.stat_afectado, -efecto.valor, efecto.es_porcentaje, -1.0)

		EfectoItem.TipoEfecto.BUFF_TEMPORAL:
			est.buffs.agregar_buff(efecto.stat_afectado, efecto.valor, efecto.es_porcentaje, efecto.duracion)

	est.emit_changed()


## Efectos de buffs, hambre, afinidad, mutación, sabores y sinergias (en la base solo hambre/afinidad/mutación)
static func comer(est: estadisticas_player, item: ItemData, veces: int) -> void:
	var en_base := est._en_base()
	for i in veces:
		if not en_base:
			for efecto in item.efectos:
				aplicar_efecto(est, efecto)
		est.afinidad.registrar_comida(item, est.zeta_actual)
		est.hambre.comer(item.hambre_restaurada)
		var nueva_zeta = est.mutaciones.registrar_comida(item, est.zeta_actual)
		if nueva_zeta:
			est.zeta_actual = nueva_zeta
			print("¡La Zeta mutó a: ", nueva_zeta.nombre, "!")

	if not en_base:
		for tag in item.tags:
			activar_sabor(est, tag)
		for s in est.sinergias.registrar_comida(item, veces):
			_aplicar_sinergia(est, s)

	est.emit_changed()


static func activar_sabor(est: estadisticas_player, tag: int) -> void:
	if SaboresCombate.tiene_efecto(tag):
		est.sabores_activos[tag] = SaboresCombate.DURACION


static func _aplicar_sinergia(est: estadisticas_player, s: SinergiaSabor) -> void:
	for efecto in s.efectos_stats:
		if efecto == null:
			continue
		var copia := efecto.duplicate() as EfectoItem
		if copia.duracion != 0.0: # los instantáneos (curación) quedan como están
			copia.duracion = s.duracion_segundos
		aplicar_efecto(est, copia)
	print("¡Sinergia activada!: ", s.nombre)
