class_name PaginaHubData
extends Resource

@export var id: StringName
@export var titulo: String = ""
@export var escena: PackedScene
@export var en_base: bool = true
@export var en_run: bool = true
## Acción que abre el hub en esta pestaña (y lo cierra si ya estás en ella)
@export var accion_atajo: StringName = &""
