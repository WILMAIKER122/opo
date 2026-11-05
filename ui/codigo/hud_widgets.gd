class_name HudWidgets
extends RefCounted
## Constructores de controles simples para el HUD (todo ignora el mouse).
## Destino: res://ui/codigo/hud_widgets.gd


static func ignorar(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


static func nueva_fila() -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	ignorar(fila)
	return fila


static func crear_label(texto: String, tamano_fuente: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano_fuente)
	ignorar(etiqueta)
	return etiqueta


static func crear_icono(textura: Texture2D, tamano: Vector2) -> TextureRect:
	var icono := TextureRect.new()
	icono.texture = textura
	icono.custom_minimum_size = tamano
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.visible = textura != null
	ignorar(icono)
	return icono
