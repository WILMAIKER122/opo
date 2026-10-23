class_name RecetaCocina
extends Resource
## Una receta de cocina. Se crea como .tres dentro de res://recetas/
## (Nuevo Resource > RecetaCocina). Cada receta apunta a un plato ya creado a mano.

## Tiene que ser ÚNICO: se usa para guardar qué recetas descubrió el jugador
@export var nombre: String = ""
@export_multiline var descripcion: String = ""

@export_group("Requisitos")
## Un requisito por cada tag que lleva la receta, cada uno con su rango (mínimo–máximo)
@export var requisitos: Array[RequisitoReceta] = []
## false: solo pueden estar en la olla los tags de la receta.
## true: se permiten ingredientes de otros tags además de los pedidos.
@export var permitir_tags_extra: bool = false
## Si una mezcla encaja en varias recetas gana la de mayor prioridad
@export var prioridad: int = 0

@export_group("Resultado")
## El plato (ItemData ya armado como .tres, con sus efectos)
@export var plato: ItemData
@export var cantidad_resultado: int = 1


## conteo: { tag (int) : unidades de ese tag en la olla }
func coincide(conteo: Dictionary) -> bool:
	if requisitos.is_empty():
		return false

	var tags_de_la_receta := {}
	for requisito in requisitos:
		if requisito == null:
			continue
		tags_de_la_receta[requisito.tag] = true
		if not requisito.cumple(int(conteo.get(requisito.tag, 0))):
			return false

	if not permitir_tags_extra:
		for tag in conteo:
			if int(conteo[tag]) > 0 and not tags_de_la_receta.has(tag):
				return false
	return true


## Texto para el recetario, ej. "BESTIA 11–20 + DULCE 1–3"
func texto_requisitos() -> String:
	var partes := PackedStringArray()
	for requisito in requisitos:
		if requisito != null:
			partes.append(requisito.texto())
	return " + ".join(partes)
