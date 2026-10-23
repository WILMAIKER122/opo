class_name SistemaMutaciones
extends Resource

var contador_tag_actual: int = 0

func registrar_comida(item: ItemData, zeta_actual: Zeta_datos) -> Zeta_datos:
	if not zeta_actual:
		return null
	
	if not (zeta_actual.tag_mutacion in item.tags):
		return null
	
	contador_tag_actual += 1
	print("Mutación [", zeta_actual.nombre, "]: ", contador_tag_actual, " / ", zeta_actual.umbral_mutacion)
	
	if contador_tag_actual >= zeta_actual.umbral_mutacion:
		print("¡Umbral superado! Girando ruleta de mutación...")
		contador_tag_actual = 0
		return _girar_ruleta(zeta_actual)
	
	return null

func _girar_ruleta(zeta_actual: Zeta_datos) -> Zeta_datos:
	var opciones_validas: Array[MutacionPosible] = []
	
	for opcion in zeta_actual.posibles_mutaciones:
		if opcion.seta and opcion.seta.desbloqueada:
			opciones_validas.append(opcion)
	
	if opciones_validas.is_empty():
		print("No hay mutaciones desbloqueadas disponibles. La seta se queda igual.")
		return null
	
	var peso_total := 0.0
	for opcion in opciones_validas:
		peso_total += opcion.peso_probabilidad
	
	var sorteo := randf() * peso_total
	var acumulado := 0.0
	
	for opcion in opciones_validas:
		acumulado += opcion.peso_probabilidad
		if sorteo <= acumulado:
			print("Seta elegida por la ruleta: ", opcion.seta.nombre)
			return opcion.seta
	
	print("Seta elegida por la ruleta (fallback): ", opciones_validas[-1].seta.nombre)
	return opciones_validas[-1].seta
