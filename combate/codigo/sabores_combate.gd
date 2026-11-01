class_name SaboresCombate
extends RefCounted
## Qué le hace al enemigo cada sabor (tag) activo cuando lo golpeás.
## Los tags que no están acá todavía no hacen nada.

## Segundos que dura un sabor tras comerlo
const DURACION := 30.0

## dps: daño por segundo · segundos: duración en el enemigo · lentitud: 0.5 = va a la mitad de velocidad
const EFECTOS := {
	ItemData.TagComida.TOXICO: {"id": &"veneno", "dps": 3.0, "segundos": 3.0, "lentitud": 0.0, "color": Color(0.5, 1.0, 0.4)},
	ItemData.TagComida.PICANTE: {"id": &"quemadura", "dps": 5.0, "segundos": 2.0, "lentitud": 0.0, "color": Color(1.0, 0.55, 0.2)},
	ItemData.TagComida.VISCOSO: {"id": &"viscoso", "dps": 0.0, "segundos": 2.5, "lentitud": 0.55, "color": Color(0.5, 0.8, 1.0)},
	ItemData.TagComida.DULCE: {"id": &"azucar", "dps": 0.0, "segundos": 2.0, "lentitud": 0.3, "color": Color(1.0, 0.6, 0.85)},
}


static func tiene_efecto(tag: int) -> bool:
	return EFECTOS.has(tag)
