class_name TeclasUI
extends RefCounted
## Nombre de la primera tecla de teclado de una acción, para textos de ayuda y botones.

static func tecla(accion: StringName) -> String:
	if InputMap.has_action(accion):
		for evento in InputMap.action_get_events(accion):
			if evento is InputEventKey:
				return evento.as_text().replace(" (Physical)", "")
	return "?"
