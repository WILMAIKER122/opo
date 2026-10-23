class_name RequisitoReceta
extends Resource
## Un requisito de receta: cuántas unidades de un tag hacen falta, con rango.
## Ejemplos:  BESTIA 1–10  |  BESTIA 11–20  |  BESTIA 40 en adelante (máximo = 0)

@export var tag: ItemData.TagComida = ItemData.TagComida.BESTIA
@export var cantidad_minima: int = 1
## 0 = sin límite superior ("en adelante")
@export var cantidad_maxima: int = 0


## ¿Esta cantidad de unidades del tag entra en el rango?
func cumple(cantidad: int) -> bool:
	if cantidad < cantidad_minima:
		return false
	if cantidad_maxima > 0 and cantidad > cantidad_maxima:
		return false
	return true


## Texto para el recetario, ej. "BESTIA 11–20"
func texto() -> String:
	var nombre_tag: String = ItemData.TagComida.keys()[tag]
	if cantidad_maxima <= 0:
		return "%s %d+" % [nombre_tag, cantidad_minima]
	if cantidad_minima == cantidad_maxima:
		return "%s %d" % [nombre_tag, cantidad_minima]
	return "%s %d–%d" % [nombre_tag, cantidad_minima, cantidad_maxima]
