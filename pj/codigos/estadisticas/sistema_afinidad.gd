class_name SistemaAfinidad
extends Resource

@export var experiencia_afinidad: float = 0.0
@export var experiencia_por_mejora: float = 100.0

func registrar_comida(item: ItemData, zeta_actual: Zeta_datos) -> void:
	if not zeta_actual:
		return
	
	var puntos := 0.0
	for tag in item.tags:
		if tag in zeta_actual.gustos:
			puntos += 10.0
		elif tag in zeta_actual.odios:
			puntos -= 5.0
	
	experiencia_afinidad = max(0.0, experiencia_afinidad + puntos)
	
	if experiencia_afinidad >= experiencia_por_mejora:
		print("¡Afinidad lista para mejorar! (lógica de mejora pendiente)")
	
	emit_changed()
