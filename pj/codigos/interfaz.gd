extends Control

@onready var player: Player = $"../.."
var bot:bool= true
const MAGICO = preload("uid://custue6v05y35")
const NORMAL = preload("uid://cvvbnimy5twnr")


var ver:bool


func _on_button_pressed() -> void:
	if ver:
		$inventario.visible=false
		ver = false
		return
	else:
		$inventario.visible=true
		ver = true
		return
